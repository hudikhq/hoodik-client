import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/crypto/file_crypto.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/services/binary_upload_pipeline.dart'
    show kUploadChunkSize;
import '../../../core/services/thumbnail_loader.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../helpers/file_helpers.dart';
import '../providers/files_notifier.dart';

/// Outcome of a fork. Exactly one branch is taken; the success branch carries
/// the new file's row so the browser can refresh and surface it, the failure
/// branch a UI-ready message.
sealed class ForkOutcome {
  const ForkOutcome();

  const factory ForkOutcome.success(FileItem file) = ForkSuccess;
  const factory ForkOutcome.failure(String message) = ForkFailure;
}

class ForkSuccess extends ForkOutcome {
  const ForkSuccess(this.file);

  final FileItem file;
}

class ForkFailure extends ForkOutcome {
  const ForkFailure(this.message);

  final String message;
}

/// Orchestrates "save to my drive" — forking a shared file into the caller's
/// own root. Mirrors the web `forkFile` flow in
/// `web/services/shares/fork.ts`: decrypt the source under the caller's
/// existing wrap, generate a fresh key in the *same* cipher, re-encrypt the
/// content + metadata under it, wrap the new key for the caller, sign the
/// `fork` audit event over the **source** file id, POST the metadata, then
/// upload the re-encrypted chunks under the returned id via the standard
/// chunk path.
///
/// The audit event is signed over the source id so the original owner's log
/// attributes the copy back to the source (chapter 02 §7.7); the server
/// reconstructs the same canonical from its own state
/// (`shares/src/repository/fork.rs`), so every signed field here must match
/// that reconstruction exactly.
class FilesForkController {
  FilesForkController(this._ref, this._dirId);

  final Ref _ref;
  final String? _dirId;

  Future<ForkOutcome> fork(FileItem source) async {
    if (source.isDir) {
      return ForkOutcome.failure(ambientL10n.filesForkFolderUnsupported);
    }

    final shareCrypto = _ref.read(shareCryptoProvider);
    final fileCrypto = _ref.read(fileCryptoProvider);
    final client = _ref.read(apiClientProvider);
    final downloader = _ref.read(fileDownloaderProvider);
    final callerId = _ref.read(activeServerUserIdProvider);
    final callerPubkey = _ref.read(activeAccountProvider)?.publicKey;

    if (shareCrypto == null ||
        fileCrypto == null ||
        client == null ||
        downloader == null) {
      return ForkOutcome.failure(ambientL10n.filesNotAuthenticated);
    }
    if (callerId == null || callerPubkey == null) {
      return ForkOutcome.failure(ambientL10n.filesAccountNotInitialized);
    }

    final sourceKey = _resolveSourceKey(source);
    if (sourceKey == null) {
      return ForkOutcome.failure(ambientL10n.filesCannotDecryptSharedKey);
    }

    final cipher = source.cipher;

    try {
      // The source's true plaintext name: the listing's decrypted cache when
      // warm, else decrypt it from the source ciphertext under the source key.
      // Never the `[Encrypted]…` placeholder `displayName` returns on a cache
      // miss — name_hash and search tokens are persisted and indexed
      // server-side, so a placeholder would poison dedup and search for the
      // forked copy.
      final displayName =
          _ref.read(filesNotifierProvider(_dirId)).decryptedNames[source.id] ??
          fileCrypto.decryptFileName(
            encryptedNameHex: source.encryptedName,
            fileKey: sourceKey,
            cipher: cipher,
          );

      // 1 + 2 — download + decrypt the source under the caller's wrap. Reuses
      // the existing download pipeline, which decrypts each chunk with the
      // supplied key and returns the full plaintext.
      final plaintext = await downloader.downloadFile(
        source,
        fileKey: sourceKey,
        displayName: displayName,
      );

      // 3 — fresh key in the same cipher so `files.cipher` is preserved and
      // old/forked files keep decrypting under the algorithm they were
      // written with.
      final newKey = fileCrypto.generateFileKey(cipher: cipher);

      // 4 — wrap the new key under the caller's own pubkey.
      final wrappedKey = fileCrypto.encryptFileKey(
        fileKey: newKey,
        publicKeyPem: callerPubkey,
      );

      // 5 — re-encrypt the plaintext name + thumbnail under the new key, and
      // recompute the name hash + search tokens from the plaintext name. The
      // thumbnail is decrypted from the source's ciphertext (under the source
      // key) before being re-encrypted under the new key.
      final encryptedName = fileCrypto.encryptFileName(
        name: displayName,
        fileKey: newKey,
        cipher: cipher,
      );
      final sourceThumbnail = await _ref
          .read(thumbnailLoaderProvider)
          .loadDataUrl(source, sourceKey);
      final encryptedThumbnail = sourceThumbnail == null
          ? null
          : fileCrypto.encryptThumbnail(
              thumbnailDataUrl: sourceThumbnail,
              fileKey: newKey,
              cipher: cipher,
            );

      // Name and body on separate sources. Concatenating them left stale body
      // words in the name source after a later rename, and nothing revisits a
      // fork to repair it. Only for a note: decoding arbitrary bytes as text
      // would tag a video with whatever its header happened to look like.
      final nameTokens = fileCrypto.tokenizeForSearch(displayName);
      final nameTokensFile = fileCrypto.tokenizeForSearchWithFileKey(
        newKey,
        displayName,
      );
      final noteBody = source.editable
          ? utf8.decode(plaintext, allowMalformed: true)
          : null;

      final size = plaintext.length;
      final chunks = (size / kUploadChunkSize).ceil().clamp(1, 1 << 30);
      // Keyed under the fork's new key before it touches the wire, like
      // every other digest write.
      final sha256 = fileCrypto.sha256(plaintext);
      final keyedSha256 = fileCrypto.exactTag(
        fileCrypto.searchFileKeyHex(newKey),
        sha256,
      );
      final newFileId = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 6 — sign the fork audit event over the SOURCE id, recipient null, so
      // the original owner's audit log attributes the copy back to the source.
      final eventSignature = shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: callerId,
          recipientId: null,
          fileId: source.id,
          action: AuditEventAction.fork,
          shareRoleBefore: null,
          shareRoleAfter: null,
          timestamp: timestamp,
        ),
      );

      final body = <String, dynamic>{
        'new_file_id': newFileId,
        'encrypted_metadata': encryptedName,
        'encrypted_thumbnail': ?encryptedThumbnail,
        'name_hash': fileCrypto.hashFileName(displayName),
        'mime': source.mime,
        'size': size,
        'chunks': chunks,
        'sha256': keyedSha256,
        'cipher': cipher,
        'encrypted_key': wrappedKey,
        'search_tokens_root': nameTokens,
        // The fork is a distinct file under `newKey`, so its file scope is
        // keyed on that — tagging under the source's key would index it for
        // whoever holds the original instead.
        'search_tokens_file': nameTokensFile,
        if (noteBody != null) ...{
          'content_tokens_root': fileCrypto.tokenizeForSearch(noteBody),
          'content_tokens_file': fileCrypto.tokenizeForSearchWithFileKey(
            newKey,
            noteBody,
          ),
        },
        'event_signature': eventSignature,
        'timestamp': timestamp,
      };

      // 7 — server creates the owned file + user_files rows + audit row.
      final returnedId = await client.shares.forkFile(source.id, body);

      // 8 — upload the re-encrypted chunks under the returned id. The plaintext
      // is re-sliced at the upload chunk size (the source's chunk boundaries
      // are irrelevant to the new file) and each slice is encrypted under the
      // new key + cipher, matching the `chunks`/`sha256` posted above.
      await _uploadReencryptedChunks(
        client: client,
        fileCrypto: fileCrypto,
        fileId: returnedId,
        plaintext: plaintext,
        fileKey: newKey,
        cipher: cipher,
        chunks: chunks,
        sha256: sha256,
      );

      final created = await client.files.getFileMetadata(returnedId);
      return ForkOutcome.success(FileItem.fromJson(created));
    } on ForkQuotaExceededError {
      return ForkOutcome.failure(ambientL10n.filesForkQuotaExceeded);
    } catch (e) {
      return ForkOutcome.failure(
        ambientL10n.filesForkFailed(formatErrorMessage(e)),
      );
    }
  }

  Future<void> _uploadReencryptedChunks({
    required ApiClient client,
    required FileCrypto fileCrypto,
    required String fileId,
    required Uint8List plaintext,
    required Uint8List fileKey,
    required String cipher,
    required int chunks,
    required String sha256,
  }) async {
    final token = await client.auth.requestTransferToken(
      fileId: fileId,
      action: 'upload',
    );

    for (var i = 0; i < chunks; i++) {
      final start = i * kUploadChunkSize;
      final end = (start + kUploadChunkSize).clamp(0, plaintext.length);
      final chunkPlain = plaintext.sublist(start, end);
      final encrypted = fileCrypto.encryptChunk(
        data: chunkPlain,
        fileKey: fileKey,
        cipher: cipher,
        chunkIndex: i,
      );
      await client.files.uploadChunk(fileId: fileId, chunk: i, data: encrypted);
    }

    // Same keying as every hash persist: the column under the file's search
    // key, plus the digest tags that answer a pasted-digest search.
    final fileSearchKey = fileCrypto.searchFileKeyHex(fileKey);
    final keyed = fileCrypto.exactTag(fileSearchKey, sha256);
    await client.files.updateFileHashesWithToken(
      fileId: fileId,
      transferToken: token.token,
      sha256: keyed,
      searchTokensRoot: [
        '${fileCrypto.exactTag(fileCrypto.searchRootKey, sha256)}:1',
      ],
      searchTokensFile: ['$keyed:1'],
    );
  }

  /// Prefer the file key [FilesNotifier] already decrypted for this listing;
  /// fall back to RSA-decrypting the row's own wrap when the cache is cold.
  /// Both decrypt the caller's existing per-user wrap of the *source* key —
  /// the same wrap the recipient uses to open the file.
  Uint8List? _resolveSourceKey(FileItem source) {
    final cached = _ref
        .read(filesNotifierProvider(_dirId))
        .decryptedKeys[source.id];
    if (cached != null) return cached;

    final encryptedKey = source.encryptedKey;
    final fileCrypto = _ref.read(fileCryptoProvider);
    if (fileCrypto == null || encryptedKey == null || encryptedKey.isEmpty) {
      return null;
    }
    try {
      return fileCrypto.decryptFileKey(encryptedKey);
    } catch (_) {
      return null;
    }
  }
}

final filesForkControllerProvider =
    Provider.family<FilesForkController, String?>((ref, dirId) {
      return FilesForkController(ref, dirId);
    });
