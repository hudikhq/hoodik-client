import 'dart:typed_data';

import '../api/file_item.dart';
import '../crypto/file_crypto.dart';
import '../utils/l10n_lookup.dart';

/// What to do about an upload whose name hash already exists in the target
/// directory.
///
/// The server refuses a second create for the same name, so an interrupted
/// upload can only ever complete by adopting the row the first attempt made:
/// same file id, same key, and only the chunks the server cannot prove it
/// holds. The name-hash route lists stored chunks live from the storage
/// provider, which makes [uploadedChunks] trustworthy even for a direct
/// upload the server never relayed.
class UploadResume {
  UploadResume._({
    required this.fileId,
    required this.cipher,
    required this.fileKey,
    required this.uploadedChunks,
    required String? sha256,
    required FileCrypto fileCrypto,
  }) : _sha256 = sha256,
       _fileCrypto = fileCrypto;

  final String fileId;
  final String cipher;
  final Uint8List fileKey;
  final Set<int> uploadedChunks;
  final String? _sha256;
  final FileCrypto _fileCrypto;

  /// Decide between a fresh upload (`null`) and adopting [existing].
  ///
  /// Throws when neither is possible: the row is already complete, it is a
  /// directory, the caller holds no key for it, or it expects a different
  /// number of chunks than the local file produces — each of those means
  /// "this name is taken by something this upload cannot finish".
  static UploadResume? of(
    FileItem? existing, {
    required int totalChunks,
    required FileCrypto fileCrypto,
  }) {
    if (existing == null) return null;

    final total = existing.chunks ?? 0;
    final stored = existing.chunksStored ?? 0;
    final complete =
        existing.finishedUploadAt != null || (total > 0 && stored >= total);
    if (existing.isDir || complete) {
      throw Exception(ambientL10n.serviceFileAlreadyExists);
    }

    if (existing.encryptedKey == null || total != totalChunks) {
      throw Exception(ambientL10n.serviceUploadPartialConflict);
    }

    return UploadResume._(
      fileId: existing.id,
      cipher: existing.cipher,
      fileKey: fileCrypto.decryptFileKey(existing.encryptedKey!),
      uploadedChunks: {...?existing.uploadedChunks},
      sha256: existing.sha256,
      fileCrypto: fileCrypto,
    );
  }

  /// Guard against resuming a row whose content is not the file on disk.
  /// Chunk counts can collide; the content hash cannot.
  ///
  /// A row that already stores chunks but carries no hash is refused
  /// outright: chunks are write-once, so whatever the first attempt stored
  /// stays in place no matter what this run uploads, and without a hash
  /// nothing can prove the two attempts read the same bytes. Skipping the
  /// stored indexes anyway could commit a file that decrypts to a silent
  /// splice of two different contents.
  void ensureSameContent(String sha256) {
    // The row stores the digest keyed under the file's search key, so the
    // local plaintext digest is keyed the same way before comparing. A row
    // from before the keying — a bare digest — can never equal the keyed
    // form and is refused with the rest of the unprovable cases.
    final keyed = _fileCrypto.exactTag(
      _fileCrypto.searchFileKeyHex(fileKey),
      sha256,
    );
    final unprovable = _sha256 == null && uploadedChunks.isNotEmpty;
    if (unprovable || (_sha256 != null && _sha256 != keyed)) {
      throw Exception(ambientL10n.serviceUploadPartialConflict);
    }
  }
}
