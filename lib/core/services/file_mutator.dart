import 'dart:convert';
import 'dart:typed_data';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import 'file_downloader.dart';
import 'shared_folder_target.dart';
import 'shared_folder_upload.dart';

/// Metadata-only "write" operations against the files tree: create folder,
/// rename, delete, move. Every operation that mutates a file or directory
/// without moving bytes lives here.
///
/// Crypto happens client-side — names are encrypted with the per-file key,
/// hashed for dedup/lookup, and tokenised for privacy-preserving search.
/// The service is stateless; all session state lives in the injected
/// [FileCrypto] and [ApiClient].
class FileMutator {
  final ApiClient _client;
  final FileCrypto _fileCrypto;
  final String _publicKeyPem;
  final String _defaultCipher;
  final SharedFolderTargetResolver? _sharedTarget;
  final SharedFolderUpload? _sharedUpload;

  /// Only a note's rename needs this: its body has to be re-indexed with its
  /// new name, and the body exists only as ciphertext server-side.
  final FileDownloader? _downloader;

  FileMutator({
    required ApiClient client,
    required FileCrypto fileCrypto,
    required String publicKeyPem,
    String defaultCipher = 'aegis128l',
    SharedFolderTargetResolver? sharedTarget,
    SharedFolderUpload? sharedUpload,
    FileDownloader? downloader,
  }) : _client = client,
       _fileCrypto = fileCrypto,
       _publicKeyPem = publicKeyPem,
       _defaultCipher = defaultCipher,
       _sharedTarget = sharedTarget,
       _sharedUpload = sharedUpload,
       _downloader = downloader;

  /// Create a new encrypted folder. Generates a per-folder symmetric key
  /// the owner can later use to encrypt names of children, hashes the
  /// name for lookup, and tokenizes it for search.
  ///
  /// A sub-folder created inside a shared folder is wrapped for every member
  /// via the multi-key path (the server honours `mime: 'dir'` there), so the
  /// roster can decrypt the names of its children; [parentItem], when held,
  /// spares the share-status check a metadata round-trip.
  Future<void> createFolder(
    String name, {
    String? parentDirId,
    FileItem? parentItem,
  }) async {
    final cipher = _defaultCipher;

    final fileKey = _fileCrypto.generateFileKey(cipher: cipher);
    final nameHash = _fileCrypto.hashFileName(name);
    final encryptedName = _fileCrypto.encryptFileName(
      name: name,
      fileKey: fileKey,
      cipher: cipher,
    );
    final searchTokens = _fileCrypto.tokenizeForSearch(name);
    final searchTokensFile = _fileCrypto.tokenizeForSearchWithFileKey(
      fileKey,
      name,
    );

    final sharedId = await multiKeyCreateOrNull(
      resolver: _sharedTarget,
      upload: _sharedUpload,
      parentDirId: parentDirId,
      parentItem: parentItem,
      fileKey: fileKey,
      nameHash: nameHash,
      encryptedName: encryptedName,
      mime: 'dir',
      cipher: cipher,
      chunks: 0,
      searchTokensRoot: searchTokens,
      searchTokensFile: searchTokensFile,
    );
    if (sharedId != null) return;

    final encryptedKey = _fileCrypto.encryptFileKey(
      fileKey: fileKey,
      publicKeyPem: _publicKeyPem,
    );
    await _client.files.createDirectory(
      encryptedKey: encryptedKey,
      nameHash: nameHash,
      encryptedName: encryptedName,
      parentDirId: parentDirId,
      cipher: cipher,
      searchTokensRoot: searchTokens,
      searchTokensFile: searchTokensFile,
    );
  }

  /// Rename a file or directory. The caller must provide the decrypted
  /// file key so the new name can be re-encrypted under it.
  Future<void> rename(
    FileItem file,
    String newName, {
    required Uint8List fileKey,
  }) async {
    final cipher = file.cipher;

    final nameHash = _fileCrypto.hashFileName(newName);
    final encryptedName = _fileCrypto.encryptFileName(
      name: newName,
      fileKey: fileKey,
      cipher: cipher,
    );
    // An editor holds the file key but not the owner's root key, so it refreshes
    // only the file-scoped tags it can produce. The root scope and name_hash are
    // the owner's, keyed under a key this device does not have — sending ours
    // would overwrite the owner's index with tags they can never match. The
    // server enforces this too; this just keeps us from sending garbage.
    final indexed = await _indexedText(file, newName, fileKey);

    await _client.files.renameFile(
      fileId: file.id,
      nameHash: nameHash,
      encryptedName: encryptedName,
      searchTokensRoot: indexed != null && file.isOwner
          ? _fileCrypto.tokenizeForSearch(indexed)
          : null,
      searchTokensFile: indexed == null
          ? null
          : _fileCrypto.tokenizeForSearchWithFileKey(fileKey, indexed),
    );
  }

  /// The text a file's word tokens are built from: its name, and for a note
  /// its body as well.
  ///
  /// A rename replaces every word token it sends, so a note renamed on its
  /// name alone would lose its contents from search until the next save. The
  /// body is only reachable by downloading and decrypting it — the server
  /// holds ciphertext — which is affordable because notes are small and this
  /// runs once per rename.
  ///
  /// Null means the body could not be read. The caller then sends no tokens
  /// at all: the server replaces only the scopes it is given, so the note
  /// keeps the ones it has rather than being reduced to its new name.
  Future<String?> _indexedText(
    FileItem file,
    String name,
    Uint8List fileKey,
  ) async {
    if (!file.editable) return name;

    final downloader = _downloader;
    if (downloader == null) return null;

    try {
      final bytes = await downloader.downloadFile(
        file,
        fileKey: fileKey,
        showInTransfers: false,
      );

      return '$name\n${utf8.decode(bytes, allowMalformed: true)}';
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String fileId) => _client.files.deleteFile(fileId);

  Future<void> deleteMany(List<String> fileIds) =>
      _client.files.deleteMany(fileIds);

  /// Move files/directories to [targetDirId]. `null` moves them to the
  /// account root.
  Future<void> moveMany(List<String> fileIds, {String? targetDirId}) =>
      _client.files.moveMany(ids: fileIds, targetDirId: targetDirId);
}
