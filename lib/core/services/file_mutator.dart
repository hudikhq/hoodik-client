import 'dart:typed_data';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import 'shared_folder_target.dart';
import 'shared_folder_upload.dart';
import '../crypto/off_ui_crypto.dart';

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

  FileMutator({
    required ApiClient client,
    required FileCrypto fileCrypto,
    required String publicKeyPem,
    String defaultCipher = 'aegis128l',
    SharedFolderTargetResolver? sharedTarget,
    SharedFolderUpload? sharedUpload,
  }) : _client = client,
       _fileCrypto = fileCrypto,
       _publicKeyPem = publicKeyPem,
       _defaultCipher = defaultCipher,
       _sharedTarget = sharedTarget,
       _sharedUpload = sharedUpload;

  /// Create a new encrypted folder. Generates a per-folder symmetric key
  /// the owner can later use to encrypt names of children, hashes the
  /// name for lookup, and tokenizes it for search.
  ///
  /// A sub-folder created inside a shared folder is wrapped for every member
  /// via the multi-key path (the server honours `mime: 'dir'` there), so the
  /// roster can decrypt the names of its children; [parentItem], when held,
  /// spares the share-status check a metadata round-trip.
  Future<String> createFolder(
    String name, {
    String? parentDirId,
    FileItem? parentItem,
  }) async {
    final cipher = _defaultCipher;

    final prepared = await prepareFolderCreateOffUi(
      name: name,
      cipher: cipher,
      privateKeyPem: _fileCrypto.privateKeyPem,
      wrappingPrivateKeyPem: _fileCrypto.wrappingPrivateKeyPem,
      publicKeyPem: _publicKeyPem,
    );
    final fileKey = prepared.fileKey;

    final sharedId = await multiKeyCreateOrNull(
      resolver: _sharedTarget,
      upload: _sharedUpload,
      parentDirId: parentDirId,
      parentItem: parentItem,
      fileKey: fileKey,
      nameHash: prepared.nameHash,
      encryptedName: prepared.encryptedName,
      mime: 'dir',
      cipher: cipher,
      chunks: 0,
      searchTokensRoot: prepared.searchTokensRoot,
      searchTokensFile: prepared.searchTokensFile,
    );
    if (sharedId != null) return sharedId;

    final data = await _client.files.createDirectory(
      encryptedKey: prepared.encryptedKey,
      nameHash: prepared.nameHash,
      encryptedName: prepared.encryptedName,
      parentDirId: parentDirId,
      cipher: cipher,
      searchTokensRoot: prepared.searchTokensRoot,
      searchTokensFile: prepared.searchTokensFile,
    );
    final id = data['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('createDirectory returned no id');
    }
    return id;
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
    // Name tokens only: the body lives in a different source.
    await _client.files.renameFile(
      fileId: file.id,
      nameHash: nameHash,
      encryptedName: encryptedName,
      searchTokensRoot: file.isOwner
          ? _fileCrypto.tokenizeForSearch(newName)
          : null,
      searchTokensFile: _fileCrypto.tokenizeForSearchWithFileKey(
        fileKey,
        newName,
      ),
    );
  }

  Future<void> delete(String fileId) => _client.files.deleteFile(fileId);

  Future<void> deleteMany(List<String> fileIds) =>
      _client.files.deleteMany(fileIds);

  /// Move files/directories to [targetDirId]. `null` moves them to the
  /// account root.
  Future<void> moveMany(List<String> fileIds, {String? targetDirId}) =>
      _client.files.moveMany(ids: fileIds, targetDirId: targetDirId);
}
