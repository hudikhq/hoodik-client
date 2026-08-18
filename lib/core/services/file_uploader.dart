import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../utils/l10n_lookup.dart';
import '../workers/worker_manager.dart';
import 'background_upload_service.dart';
import 'binary_upload_pipeline.dart';
import 'binary_upload_transport.dart';
import 'offline_manager.dart';
import 'shared_folder_target.dart';
import 'shared_folder_upload.dart';
import 'transfer_manager.dart';

export 'binary_upload_pipeline.dart' show kUploadChunkSize;

/// Thrown by [FileUploader.updateNoteContent] when the server returns
/// 409 — another save is in flight. The caller (UI) decides whether to
/// re-issue with `force = true` to abandon the previous edit and take over.
class SaveConflictException implements Exception {
  final String fileId;
  final String content;
  SaveConflictException(this.fileId, this.content);
  @override
  String toString() => 'SaveConflictException(fileId: $fileId)';
}

/// Upload pipeline: binary files and editable markdown notes.
///
/// Binary uploads run through [BinaryUploadPipeline] (worker-offloaded
/// encrypt + background uploader). Note create/update stays on the main
/// thread — the payload is small enough that the crypto cost is trivial,
/// and the update flow needs to stay single-pass to keep the server's
/// pending-version book-keeping tidy.
class FileUploader {
  final ApiClient _client;
  final FileCrypto _fileCrypto;
  final String _publicKeyPem;
  final String _defaultCipher;
  final TransferManager? _transferManager;
  final WorkerManager? _workerManager;
  final OfflineManager? _offlineManager;
  final BackgroundUploadService? _backgroundUploadService;
  final UploadTarTransport? _uploadTarTransport;
  final String? _accountId;
  final SharedFolderTargetResolver? _sharedTarget;
  final SharedFolderUpload? _sharedUpload;

  /// Shared with [BinaryUploadPipeline] so a single `requestCancel` call
  /// reaches whichever loop is currently running.
  final Set<String> _cancelledFileIds = {};

  FileUploader({
    required ApiClient client,
    required FileCrypto fileCrypto,
    required String publicKeyPem,
    String defaultCipher = 'aegis128l',
    TransferManager? transferManager,
    WorkerManager? workerManager,
    OfflineManager? offlineManager,
    BackgroundUploadService? backgroundUploadService,
    UploadTarTransport? uploadTarTransport,
    String? accountId,
    SharedFolderTargetResolver? sharedTarget,
    SharedFolderUpload? sharedUpload,
  }) : _client = client,
       _fileCrypto = fileCrypto,
       _publicKeyPem = publicKeyPem,
       _defaultCipher = defaultCipher,
       _transferManager = transferManager,
       _workerManager = workerManager,
       _offlineManager = offlineManager,
       _backgroundUploadService = backgroundUploadService,
       _uploadTarTransport = uploadTarTransport,
       _accountId = accountId,
       _sharedTarget = sharedTarget,
       _sharedUpload = sharedUpload;

  /// Mark the main-thread upload loop for [fileId] as cancelled. The next
  /// chunk-boundary check throws [TransferCancelledException]; background
  /// uploader tasks are cancelled directly through their own service.
  void requestCancel(String fileId) {
    _cancelledFileIds.add(fileId);
  }

  /// Upload a file from [localPath] to [parentDirId] (null = root).
  ///
  /// Delegates to [BinaryUploadPipeline] — see there for the stage-by-stage
  /// breakdown. Throws up-front if the encrypt worker isn't live because
  /// the pipeline can't safely run in-process without it.
  Future<void> uploadFile(
    String localPath, {
    String? parentDirId,
    void Function(double progress)? onProgress,
  }) async {
    final wm = _workerManager;
    final offline = _offlineManager;
    final acct = _accountId;
    final tarTransport = _uploadTarTransport;
    if (wm == null ||
        !wm.encryptWorkerActive ||
        offline == null ||
        acct == null ||
        tarTransport == null) {
      throw Exception(ambientL10n.serviceUploadWorkerUnavailable);
    }

    final pipeline = BinaryUploadPipeline(
      client: _client,
      fileCrypto: _fileCrypto,
      publicKeyPem: _publicKeyPem,
      defaultCipher: _defaultCipher,
      workerManager: wm,
      offlineManager: offline,
      accountId: acct,
      cancelledFileIds: _cancelledFileIds,
      tarTransport: tarTransport,
      transferManager: _transferManager,
      backgroundUploadService: _backgroundUploadService,
      sharedTarget: _sharedTarget,
      sharedUpload: _sharedUpload,
    );
    await pipeline.run(
      localPath,
      parentDirId: parentDirId,
      onProgress: onProgress,
    );
  }

  /// Create a new editable note (markdown file with `editable: true`).
  /// Returns the server file ID of the newly-created note.
  ///
  /// A note landing in a shared folder is created via the multi-key path so
  /// every member can open it; [parentItem], when held, spares the
  /// share-status check a metadata round-trip.
  Future<String> createNote(
    String name,
    String content, {
    String? parentDirId,
    FileItem? parentItem,
  }) async {
    await _client.ensureFreshSession();
    final cipher = _defaultCipher;

    final bytes = Uint8List.fromList(utf8.encode(content));
    final fileSize = bytes.length;
    final totalChunks = (fileSize / kUploadChunkSize).ceil().clamp(1, 1 << 30);

    final fileKey = _fileCrypto.generateFileKey(cipher: cipher);
    final nameHash = _fileCrypto.hashFileName(name);
    final encryptedName = _fileCrypto.encryptFileName(
      name: name,
      fileKey: fileKey,
      cipher: cipher,
    );
    final searchTokens = _fileCrypto.tokenizeForSearch(name);
    final searchTokensFile = _fileCrypto.tokenizeForSearchWithFileKey(fileKey, name);

    var fileId = await multiKeyCreateOrNull(
      resolver: _sharedTarget,
      upload: _sharedUpload,
      parentDirId: parentDirId,
      parentItem: parentItem,
      fileKey: fileKey,
      nameHash: nameHash,
      encryptedName: encryptedName,
      mime: 'text/markdown',
      cipher: cipher,
      chunks: totalChunks,
      size: fileSize,
      editable: true,
      searchTokensRoot: searchTokens,
      searchTokensFile: searchTokensFile,
    );
    if (fileId == null) {
      final encryptedKey = _fileCrypto.encryptFileKey(
        fileKey: fileKey,
        publicKeyPem: _publicKeyPem,
      );
      final entry = await _client.files.createFileEntry(
        encryptedKey: encryptedKey,
        nameHash: nameHash,
        encryptedName: encryptedName,
        mime: 'text/markdown',
        size: fileSize,
        chunks: totalChunks,
        parentDirId: parentDirId,
        cipher: cipher,
        searchTokensRoot: searchTokens,
        searchTokensFile: searchTokensFile,
        editable: true,
      );
      fileId = entry['id'] as String;
    }
    await _encryptAndUploadContent(fileId, bytes, fileKey, cipher, totalChunks);

    return fileId;
  }

  /// Update the content of an existing editable note.
  ///
  /// Two-phase under the hood: server allocates a pending version and
  /// stages metadata (no on-disk side effects), then chunks land via
  /// [uploadChunk]. The active version remains readable throughout.
  ///
  /// Pass `force: true` to bypass the 409 raised when another save is
  /// already in flight — the prior pending dir gets reaped on the
  /// server side.
  Future<void> updateNoteContent(
    String fileId,
    String content, {
    String? name,
    bool force = false,
  }) async {
    await _client.ensureFreshSession();

    final metadata = await _client.files.getFileMetadata(fileId);
    final file = FileItem.fromJson(metadata);

    if (file.encryptedKey == null) {
      throw Exception(ambientL10n.serviceFileNoEncryptionKey);
    }

    final fileKey = _fileCrypto.decryptFileKey(file.encryptedKey!);
    final cipher = file.cipher;
    final bytes = Uint8List.fromList(utf8.encode(content));
    final fileSize = bytes.length;
    final totalChunks = (fileSize / kUploadChunkSize).ceil().clamp(1, 1 << 30);

    String? encryptedName;
    List<String>? searchTokens;
    List<String>? searchTokensFile;
    if (name != null) {
      encryptedName = _fileCrypto.encryptFileName(
        name: name,
        fileKey: fileKey,
        cipher: cipher,
      );
      searchTokens = _fileCrypto.tokenizeForSearch(name);
      searchTokensFile = _fileCrypto.tokenizeForSearchWithFileKey(fileKey, name);
    }

    try {
      await _client.storage.replaceContent(
        fileId: fileId,
        size: fileSize,
        chunks: totalChunks,
        encryptedName: encryptedName,
        searchTokensRoot: searchTokens,
        searchTokensFile: searchTokensFile,
        force: force,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw SaveConflictException(fileId, content);
      }
      rethrow;
    }

    await _encryptAndUploadContent(fileId, bytes, fileKey, cipher, totalChunks);
  }

  /// Encrypt [plaintext] and upload it as chunks on the main thread, then
  /// finalize the server entry with its SHA-256. Used by both note-create
  /// and note-update flows — the server-side pending-version dance
  /// happens upstream in [updateNoteContent].
  Future<void> _encryptAndUploadContent(
    String fileId,
    Uint8List plaintext,
    Uint8List fileKey,
    String cipher,
    int totalChunks,
  ) async {
    final token = await _client.auth.requestTransferToken(
      fileId: fileId,
      action: 'upload',
    );

    for (var i = 0; i < totalChunks; i++) {
      final start = i * kUploadChunkSize;
      final end = (start + kUploadChunkSize).clamp(0, plaintext.length);
      final chunkPlain = plaintext.sublist(start, end);

      final encrypted = _fileCrypto.encryptChunk(
        data: chunkPlain,
        fileKey: fileKey,
        cipher: cipher,
        chunkIndex: i,
      );

      await _client.files.uploadChunk(
        fileId: fileId,
        chunk: i,
        data: encrypted,
      );
    }

    final sha256 = _fileCrypto.sha256(plaintext);
    await _client.files.updateFileHashesWithToken(
      fileId: fileId,
      transferToken: token.token,
      sha256: sha256,
    );
  }
}
