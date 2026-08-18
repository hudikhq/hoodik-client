import 'dart:typed_data';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import 'shared_folder_target.dart';
import 'shared_folder_upload.dart';
import 'thumbnail_generator.dart';

/// Build and POST the server-side file entry that an upload needs before
/// it can start sending chunks. Kept out of [BinaryUploadPipeline] to
/// hold the orchestration file under the 500-line ceiling.
class BinaryUploadMetadata {
  final ApiClient _client;
  final FileCrypto _fileCrypto;
  final String _publicKeyPem;
  final SharedFolderTargetResolver? _sharedTarget;
  final SharedFolderUpload? _sharedUpload;

  BinaryUploadMetadata({
    required ApiClient client,
    required FileCrypto fileCrypto,
    required String publicKeyPem,
    SharedFolderTargetResolver? sharedTarget,
    SharedFolderUpload? sharedUpload,
  }) : _client = client,
       _fileCrypto = fileCrypto,
       _publicKeyPem = publicKeyPem,
       _sharedTarget = sharedTarget,
       _sharedUpload = sharedUpload;

  /// Create the file row for an upload landing in [parentDirId] and return the
  /// `{'id': ...}` the chunk pipeline uploads against.
  ///
  /// A destination that is a shared folder fans the file key out to every
  /// member through [SharedFolderUpload] under a client-minted id (the same id
  /// the chunk pipeline then targets, so the audit signature binds to it);
  /// every other destination takes the unchanged owner-only single-key create.
  /// [parentItem], when the caller holds it, spares the share-status check a
  /// metadata round-trip.
  Future<Map<String, dynamic>> createEntry({
    required String fileName,
    required int fileSize,
    required int totalChunks,
    required String mime,
    required String cipher,
    required Uint8List fileKey,
    required String nameHash,
    required String? parentDirId,
    required String localPath,
    required String sha256,
    FileItem? parentItem,
  }) async {
    final encryptedName = _fileCrypto.encryptFileName(
      name: fileName,
      fileKey: fileKey,
      cipher: cipher,
    );
    final searchTokens = _fileCrypto.tokenizeForSearch(fileName);
    final searchTokensFile =
        _fileCrypto.tokenizeForSearchWithFileKey(fileKey, fileName);

    String? encryptedThumbnail;
    if (canGenerateThumbnail(mime)) {
      final thumbnailDataUrl = await generateThumbnail(localPath, mime);
      if (thumbnailDataUrl != null) {
        encryptedThumbnail = _fileCrypto.encryptThumbnail(
          thumbnailDataUrl: thumbnailDataUrl,
          fileKey: fileKey,
          cipher: cipher,
        );
      }
    }

    final sharedId = await multiKeyCreateOrNull(
      resolver: _sharedTarget,
      upload: _sharedUpload,
      parentDirId: parentDirId,
      parentItem: parentItem,
      fileKey: fileKey,
      nameHash: nameHash,
      encryptedName: encryptedName,
      mime: mime,
      cipher: cipher,
      chunks: totalChunks,
      size: fileSize,
      sha256: sha256,
      searchTokensRoot: searchTokens,
      searchTokensFile: searchTokensFile,
      encryptedThumbnail: encryptedThumbnail,
    );
    if (sharedId != null) return {'id': sharedId};

    final encryptedKey = _fileCrypto.encryptFileKey(
      fileKey: fileKey,
      publicKeyPem: _publicKeyPem,
    );
    return _client.files.createFileEntry(
      encryptedKey: encryptedKey,
      nameHash: nameHash,
      encryptedName: encryptedName,
      mime: mime,
      size: fileSize,
      chunks: totalChunks,
      parentDirId: parentDirId,
      cipher: cipher,
      searchTokensRoot: searchTokens,
      searchTokensFile: searchTokensFile,
      encryptedThumbnail: encryptedThumbnail,
      sha256: sha256,
    );
  }
}
