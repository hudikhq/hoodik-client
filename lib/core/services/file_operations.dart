import 'package:flutter/foundation.dart' show ValueNotifier;
import 'dart:typed_data';

import '../api/api_client.dart';
import '../storage/database.dart';
import '../crypto/crypto_service.dart';
import '../crypto/file_crypto.dart';
import '../workers/worker_manager.dart';
import 'background_upload_service.dart';
import 'binary_upload_transport.dart';
import 'chunk_download_transport.dart';
import 'file_downloader.dart';
import 'file_mutator.dart';
import 'file_uploader.dart';
import 'direct_chunk_upload.dart';
import 'offline_manager.dart';
import 'shared_folder_target.dart';
import 'shared_folder_upload.dart';
import 'tar_fallback.dart';
import 'transfer_manager.dart';

export 'file_uploader.dart' show SaveConflictException, kUploadChunkSize;
export 'transfer_errors.dart' show TransferCancelledException;

/// Thin facade over [FileMutator], [FileUploader] and [FileDownloader].
///
/// Exists so existing callers that resolve `fileOperationsProvider` keep
/// the same `ops.x()` ergonomics — the three underlying services hold the
/// real implementation. New code can also resolve each service directly
/// through its own provider.
class FileOperations {
  /// Ticks whenever the set of files changes shape — created, renamed, moved
  /// or deleted. Surfaces that hold their own copy of a listing watch this
  /// instead of each mutation site remembering to tell them, which is how the
  /// recent-notes panel ended up showing notes that had been deleted.
  final ValueNotifier<int> revision = ValueNotifier(0);

  final FileMutator _mutator;
  final FileUploader _uploader;
  final FileDownloader _downloader;
  final FileCrypto _fileCrypto;

  FileOperations._({
    required FileMutator mutator,
    required FileUploader uploader,
    required FileDownloader downloader,
    required FileCrypto fileCrypto,
  }) : _mutator = mutator,
       _uploader = uploader,
       _downloader = downloader,
       _fileCrypto = fileCrypto;

  factory FileOperations({
    required ApiClient client,
    required String privateKeyPem,
    required String publicKeyPem,
    required CryptoService crypto,
    String? wrappingPrivateKeyPem,
    String? wrappingPublicKeyPem,
    String defaultCipher = 'aegis128l',
    TransferManager? transferManager,
    WorkerManager? workerManager,
    OfflineManager? offlineManager,
    BackgroundUploadService? backgroundUploadService,
    DirectChunkUploadService? directUpload,
    TarCapabilityCache? tarCapabilityCache,
    ChunkDownloadTransport? chunkDownloadTransport,
    UploadTarTransport? uploadTarTransport,
    bool tarSupported = true,
    AppDatabase? database,
    String? accountId,
    SharedFolderTargetResolver? sharedTarget,
    SharedFolderUpload? sharedUpload,
    bool directTransfer = true,
  }) {
    final fileCrypto = FileCrypto(
      privateKeyPem: privateKeyPem,
      wrappingPrivateKeyPem: wrappingPrivateKeyPem,
      crypto: crypto,
    );
    // Curve accounts wrap their own file keys to the hybrid wrapping key — the
    // Ed25519 identity key can't do key wrapping. Legacy RSA accounts have no wrapping
    // key and fall back to their RSA public key. FileCrypto keys the algorithm
    // off the private material it holds, so call sites only need the right key.
    final ownWrapPublicKey = wrappingPublicKeyPem ?? publicKeyPem;
    // Built up front rather than inline: renaming a note re-indexes its body,
    // which means reading it back, so the mutator needs the same downloader
    // this instance hands out.
    final downloader = FileDownloader(
      client: client,
      fileCrypto: fileCrypto,
      transferManager: transferManager,
      offlineManager: offlineManager,
      tarCapabilityCache: tarCapabilityCache,
      chunkDownloadTransport: chunkDownloadTransport,
      database: database,
      accountId: accountId,
      directTransfer: directTransfer,
    );
    return FileOperations._(
      fileCrypto: fileCrypto,
      mutator: FileMutator(
        client: client,
        fileCrypto: fileCrypto,
        publicKeyPem: ownWrapPublicKey,
        defaultCipher: defaultCipher,
        sharedTarget: sharedTarget,
        sharedUpload: sharedUpload,
      ),
      uploader: FileUploader(
        client: client,
        fileCrypto: fileCrypto,
        publicKeyPem: ownWrapPublicKey,
        defaultCipher: defaultCipher,
        transferManager: transferManager,
        workerManager: workerManager,
        offlineManager: offlineManager,
        backgroundUploadService: backgroundUploadService,
        directUpload: directUpload,
        directTransfer: directTransfer,
        uploadTarTransport: uploadTarTransport,
        tarSupported: tarSupported,
        accountId: accountId,
        sharedTarget: sharedTarget,
        sharedUpload: sharedUpload,
      ),
      downloader: downloader,
    );
  }

  FileMutator get mutator => _mutator;
  FileUploader get uploader => _uploader;
  FileDownloader get downloader => _downloader;

  /// Request cancellation of a main-thread transfer loop. Upload and
  /// download each keep their own cancellation set — the request is
  /// forwarded to both so the caller doesn't have to know which loop is
  /// currently running for the file.
  void requestCancel(String fileId) {
    _uploader.requestCancel(fileId);
    _downloader.requestCancel(fileId);
  }

  Future<void> createFolder(String name, {String? parentDirId}) =>
      _mutator.createFolder(name, parentDirId: parentDirId).then(_bump);

  Future<void> rename(
    FileItem file,
    String newName, {
    required Uint8List fileKey,
  }) => _mutator.rename(file, newName, fileKey: fileKey).then(_bump);

  Future<void> delete(String fileId) => _mutator.delete(fileId).then(_bump);

  Future<void> deleteMany(List<String> fileIds) =>
      _mutator.deleteMany(fileIds).then(_bump);

  Future<void> moveMany(List<String> fileIds, {String? targetDirId}) =>
      _mutator.moveMany(fileIds, targetDirId: targetDirId).then(_bump);

  /// Only fires on success — a failed mutation changed nothing to reload.
  void _bump([void _]) => revision.value++;

  Future<void> uploadFile(
    String localPath, {
    String? parentDirId,
    void Function(double progress)? onProgress,
    String? stagingId,
  }) => _uploader.uploadFile(
    localPath,
    parentDirId: parentDirId,
    onProgress: onProgress,
    stagingId: stagingId,
  );

  Future<String> createNote(
    String name,
    String content, {
    String? parentDirId,
  }) =>
      _uploader.createNote(name, content, parentDirId: parentDirId).then((id) {
        _bump();
        return id;
      });

  Future<void> updateNoteContent(
    String fileId,
    String content, {
    String? name,
    bool force = false,
  }) => _uploader.updateNoteContent(fileId, content, name: name, force: force);

  Future<Uint8List> downloadFile(
    FileItem file, {
    required Uint8List fileKey,
    void Function(double progress)? onProgress,
    String? displayName,
    bool showInTransfers = true,
  }) => _downloader.downloadFile(
    file,
    fileKey: fileKey,
    onProgress: onProgress,
    displayName: displayName,
    showInTransfers: showInTransfers,
  );

  void downloadFileToDisk(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    String? displayName,
    Future<void> Function()? onComplete,
    void Function(String error)? onError,
  }) => _downloader.downloadFileToDisk(
    file,
    fileKey: fileKey,
    outputPath: outputPath,
    displayName: displayName,
    onComplete: onComplete,
    onError: onError,
  );

  /// [silent] marks a fetch the user did not ask for — opening a note or a
  /// preview — so the ambient transfer strip leaves it alone.
  void downloadAndPinOffline(
    FileItem file, {
    String? displayName,
    bool pinned = true,
    bool silent = false,
    void Function()? onComplete,
    void Function(String error)? onError,
  }) => _downloader.downloadAndPinOffline(
    file,
    displayName: displayName,
    pinned: pinned,
    silent: silent,
    onComplete: onComplete,
    onError: onError,
  );

  /// Decrypt the per-file symmetric key from a FileItem's encrypted_key field.
  Uint8List decryptFileKey(String encryptedKeyBase64) =>
      _fileCrypto.decryptFileKey(encryptedKeyBase64);

  /// Decrypt a file's display name given its encrypted fields and key.
  String decryptFileName(FileItem file, Uint8List fileKey) =>
      _fileCrypto.decryptFileName(
        encryptedNameHex: file.encryptedName,
        fileKey: fileKey,
        cipher: file.cipher,
      );
}
