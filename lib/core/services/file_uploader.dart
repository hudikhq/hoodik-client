import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../utils/l10n_lookup.dart';
import '../workers/worker_manager.dart';
import '../workers/worker_messages.dart';
import 'background_upload_service.dart';
import 'binary_upload_pipeline.dart';
import 'direct_chunk_upload.dart';
import 'binary_upload_transport.dart';
import 'offline_manager.dart';
import 'shared_folder_target.dart';
import 'shared_folder_upload.dart';
import 'transfer_manager.dart';

export 'binary_upload_pipeline.dart' show kUploadChunkSize;

/// Thrown by [FileUploader.updateNoteContent] when the server keeps
/// returning 409 even after the automatic `force = true` retry — another
/// client is actively writing right now. The caller (UI) decides whether
/// to re-issue with `force = true` and take over anyway.
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
/// encrypt + background uploader). Note create/update shares the same
/// encrypt worker — chunk encryption must never run FRB on the UI
/// isolate or in a throwaway isolate with its own `RustLib.init`, both
/// of which SIGSEGV iOS AOT — but keeps its own single-pass upload so
/// the server's pending-version book-keeping stays tidy.
class FileUploader {
  final ApiClient _client;
  final FileCrypto _fileCrypto;
  final String _publicKeyPem;
  final String _defaultCipher;
  final TransferManager? _transferManager;
  final WorkerManager? _workerManager;
  final OfflineManager? _offlineManager;
  final BackgroundUploadService? _backgroundUploadService;
  final DirectChunkUploadService? _directUpload;

  /// Whether the server advertises bucket URLs. The binary pipeline learns
  /// this from [_directUpload] being present; a note is written here instead,
  /// so it needs the flag itself.
  final bool _directTransfer;
  final UploadTarTransport? _uploadTarTransport;

  /// Passed to the pipeline so an upload skips the archive on a server that
  /// says it will not serve one, instead of learning it from a refusal.
  final bool _tarSupported;
  final String? _accountId;
  final SharedFolderTargetResolver? _sharedTarget;
  final SharedFolderUpload? _sharedUpload;

  /// Shared with [BinaryUploadPipeline] so a single `requestCancel` call
  /// reaches whichever loop is currently running.
  final Set<String> _cancelledFileIds = {};

  /// One in-flight note save per file. Autosave + editor save used to
  /// PUT /content twice; the second 409'd and iOS AOT SIGSEGV'd in encrypt.
  /// A save arriving while one is on the wire is queued, newest body wins.
  final Map<String, Future<void>> _noteSaves = {};
  final Map<String, _QueuedNoteSave> _queuedNoteSaves = {};

  FileUploader({
    required ApiClient client,
    required FileCrypto fileCrypto,
    required String publicKeyPem,
    String defaultCipher = 'aegis128l',
    TransferManager? transferManager,
    WorkerManager? workerManager,
    OfflineManager? offlineManager,
    BackgroundUploadService? backgroundUploadService,
    DirectChunkUploadService? directUpload,
    bool directTransfer = true,
    UploadTarTransport? uploadTarTransport,
    bool tarSupported = true,
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
       _directUpload = directUpload,
       _directTransfer = directTransfer,
       _uploadTarTransport = uploadTarTransport,
       _tarSupported = tarSupported,
       _accountId = accountId,
       _sharedTarget = sharedTarget,
       _sharedUpload = sharedUpload;

  /// Mark the main-thread upload loop for [fileId] as cancelled. The next
  /// chunk-boundary check throws [TransferCancelledException]; background
  /// uploader tasks are cancelled directly through their own service.
  void requestCancel(String fileId) {
    _cancelledFileIds.add(fileId);
  }

  /// Note crypto runs only on the encrypt worker — the UI isolate and
  /// throwaway isolates both SIGSEGV iOS AOT — so a note flow refuses to
  /// start without it rather than leave half-created server state behind.
  WorkerManager _requireEncryptWorker() {
    final wm = _workerManager;
    if (wm == null || !wm.encryptWorkerActive) {
      throw Exception(ambientL10n.serviceUploadWorkerUnavailable);
    }
    return wm;
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
    String? stagingId,
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
      tarSupported: _tarSupported,
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
      directUpload: _directUpload,
      sharedTarget: _sharedTarget,
      sharedUpload: _sharedUpload,
    );
    await pipeline.run(
      localPath,
      parentDirId: parentDirId,
      onProgress: onProgress,
      stagingId: stagingId,
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
    _requireEncryptWorker();
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
    final nameTokens = _fileCrypto.tokenizeForSearch(name);
    final nameTokensFile = _fileCrypto.tokenizeForSearchWithFileKey(
      fileKey,
      name,
    );
    final contentTokens = _fileCrypto.tokenizeForSearch(content);
    final contentTokensFile = _fileCrypto.tokenizeForSearchWithFileKey(
      fileKey,
      content,
    );

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
      searchTokensRoot: nameTokens,
      searchTokensFile: nameTokensFile,
      contentTokensRoot: contentTokens,
      contentTokensFile: contentTokensFile,
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
        searchTokensRoot: nameTokens,
        searchTokensFile: nameTokensFile,
        contentTokensRoot: contentTokens,
        contentTokensFile: contentTokensFile,
        editable: true,
      );
      fileId = entry['id'] as String;
    }
    // The creator of a note owns it on every create path, shared folders
    // included.
    await _encryptAndUploadContent(
      fileId,
      bytes,
      fileKey,
      cipher,
      totalChunks,
      isOwner: true,
    );

    return fileId;
  }

  /// Update the content of an existing editable note.
  ///
  /// Two-phase under the hood: server allocates a pending version and
  /// stages metadata (no on-disk side effects), then chunks land via
  /// [uploadChunk]. The active version remains readable throughout.
  ///
  /// One save per file runs at a time. A call arriving while one is on
  /// the wire is queued and coalesced — the newest body replaces any
  /// queued one, so no caller's text is ever silently dropped and the
  /// server never sees two writers from this client.
  ///
  /// A 409 on the first attempt is retried once with `force = true`
  /// automatically: a pending version that blocks the save is nearly
  /// always our own, left behind by a save that died between allocating
  /// the version and finishing the chunks. [SaveConflictException]
  /// surfaces only when the forced retry conflicts too.
  Future<void> updateNoteContent(
    String fileId,
    String content, {
    String? name,
    bool force = false,
  }) {
    if (_noteSaves.containsKey(fileId)) {
      final queued = _queuedNoteSaves[fileId];
      if (queued != null) {
        queued.content = content;
        queued.name = name ?? queued.name;
        queued.force = queued.force || force;
        return queued.completer.future;
      }
      final pending = _QueuedNoteSave(content, name, force);
      _queuedNoteSaves[fileId] = pending;
      return pending.completer.future;
    }
    final run = _runNoteSave(fileId, content, name: name, force: force);
    _noteSaves[fileId] = run;
    return run;
  }

  Future<void> _runNoteSave(
    String fileId,
    String content, {
    String? name,
    bool force = false,
  }) async {
    try {
      await _updateNoteContent(fileId, content, name: name, force: force);
    } finally {
      // Map.remove returns the stored Future; the caller holds it already.
      _noteSaves.remove(fileId)?.ignore();
      final queued = _queuedNoteSaves.remove(fileId);
      if (queued != null) {
        final next = _runNoteSave(
          fileId,
          queued.content,
          name: queued.name,
          force: queued.force,
        );
        _noteSaves[fileId] = next;
        queued.completer.complete(next);
      }
    }
  }

  Future<void> _updateNoteContent(
    String fileId,
    String content, {
    String? name,
    bool force = false,
  }) async {
    // Checked before the PUT: allocating a pending version and then
    // failing to encrypt would orphan it on the server.
    _requireEncryptWorker();
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
    if (name != null) {
      encryptedName = _fileCrypto.encryptFileName(
        name: name,
        fileKey: fileKey,
        cipher: cipher,
      );
    }

    // Body only. The title lives in a different source; sending it here would
    // wipe the name the moment a save follows a rename. An editor does not
    // hold the owner's root key, so they refresh only the file scope.
    final searchTokensFile = _fileCrypto.tokenizeForSearchWithFileKey(
      fileKey,
      content,
    );
    final searchTokens = file.isOwner
        ? _fileCrypto.tokenizeForSearch(content)
        : null;

    Future<Map<String, dynamic>> put({required bool force}) =>
        _client.storage.replaceContent(
          fileId: fileId,
          size: fileSize,
          chunks: totalChunks,
          encryptedName: encryptedName,
          searchTokensRoot: searchTokens,
          searchTokensFile: searchTokensFile,
          force: force,
        );

    try {
      await put(force: force);
    } on DioException catch (e) {
      if (e.response?.statusCode != 409) rethrow;
      if (force) throw SaveConflictException(fileId, content);
      // The blocking pending version is nearly always our own, orphaned
      // by a save that died after allocating it — nothing ever reaps it,
      // so without this retry every future save of the file 409s. Take
      // it over; the server parks the new version above the abandoned
      // one so straggler chunks from a dying client can't land in it.
      try {
        await put(force: true);
      } on DioException catch (retry) {
        if (retry.response?.statusCode == 409) {
          throw SaveConflictException(fileId, content);
        }
        rethrow;
      }
    }

    await _encryptAndUploadContent(
      fileId,
      bytes,
      fileKey,
      cipher,
      totalChunks,
      isOwner: file.isOwner,
    );
    final accountId = _accountId;
    final offline = _offlineManager;
    if (accountId != null && offline != null) {
      await offline.removeCachedFile(accountId, fileId);
    }
  }

  /// Encrypt [plaintext] on the encrypt worker and upload it as chunks,
  /// then finalize the server entry with its SHA-256. Used by both
  /// note-create and note-update flows — the server-side pending-version
  /// dance happens upstream in [updateNoteContent].
  ///
  /// [isOwner] gates the digest's root-scope tag the same way the word
  /// tokens are gated upstream: an editor does not hold the owner's root
  /// key, so a tag produced here would sit in the owner's scope unmatchable.
  Future<void> _encryptAndUploadContent(
    String fileId,
    Uint8List plaintext,
    Uint8List fileKey,
    String cipher,
    int totalChunks, {
    required bool isOwner,
  }) async {
    final wm = _requireEncryptWorker();

    final token = await _client.auth.requestTransferToken(
      fileId: fileId,
      action: 'upload',
    );

    // Encrypted on the long-lived encrypt worker, same as binary uploads.
    // Running the chunk FFI on the UI isolate SIGSEGV'd Dart AOT at 0xf,
    // and so did a throwaway Isolate.run with a third RustLib.init (iOS
    // note save after a 409, MCP create_note after a failed mkdir).
    final staging = await Directory.systemTemp.createTemp('hoodik-note-');
    final Map<int, Uint8List> encrypted;
    final String plaintextSha256;
    try {
      final plainFile = File('${staging.path}/plain.md');
      await plainFile.writeAsBytes(plaintext, flush: true);
      final result = await wm.encryptFile(
        EncryptFileCommand(
          localPath: plainFile.path,
          outputDir: staging.path,
          fileKey: fileKey,
          cipher: cipher,
          totalChunks: totalChunks,
          fileSize: plaintext.length,
          tempFileId: fileId,
        ),
      );
      plaintextSha256 = result.sha256;
      encrypted = {
        for (var i = 0; i < totalChunks; i++)
          i: await File(
            '${staging.path}/${i.toString().padLeft(6, '0')}.enc',
          ).readAsBytes(),
      };
    } finally {
      try {
        await staging.delete(recursive: true);
      } catch (_) {}
    }

    // Not asked for at all on a server that does not serve bucket URLs: the
    // request is refused every time, and a note save is frequent enough that
    // one dead round trip per keystroke-batch is worth skipping. The refusal
    // still decides it whenever the flag says yes.
    final manifest = !_directTransfer
        ? null
        : await _client.files.fetchUploadUrls(
            fileId: fileId,
            transferToken: token.token,
            chunkSizes: {
              for (final entry in encrypted.entries)
                entry.key: entry.value.length,
            },
          );

    // Covers every chunk or none of them: a note is written in one shot, and a
    // half-direct write would need the same commit either way for no gain.
    final direct =
        manifest != null &&
        manifest.urls.length >= totalChunks &&
        !manifest.urls.take(totalChunks).any((url) => url.isEmpty);

    for (var i = 0; i < totalChunks; i++) {
      if (direct) {
        await _client.files.putChunkDirect(
          url: manifest.urls[i],
          data: encrypted[i]!,
        );
      } else {
        await _client.files.uploadChunk(
          fileId: fileId,
          chunk: i,
          data: encrypted[i]!,
        );
      }
    }

    // Nothing tells the server a bucket write landed, so the client says so.
    // The relaying route commits itself as its own last chunk arrives.
    if (direct) {
      await _client.files.finalizeDirectUpload(
        fileId: fileId,
        transferToken: token.token,
      );
    }

    // Keyed before it touches the wire: the column stores the digest under
    // the file's search key so any key-holder can run the resume equality
    // check, and the digest tags are what make the note findable by pasting
    // its digest into search. The bare digest never leaves this function.
    final fileSearchKey = _fileCrypto.searchFileKeyHex(fileKey);
    final keyed = _fileCrypto.exactTag(fileSearchKey, plaintextSha256);
    await _client.files.updateFileHashesWithToken(
      fileId: fileId,
      transferToken: token.token,
      sha256: keyed,
      searchTokensRoot: isOwner
          ? [
              '${_fileCrypto.exactTag(_fileCrypto.searchRootKey, plaintextSha256)}:1',
            ]
          : null,
      searchTokensFile: ['$keyed:1'],
    );
  }
}

/// A note save waiting for the in-flight one to finish. Holds the newest
/// body handed to [FileUploader.updateNoteContent] while a save runs; every
/// coalesced caller awaits [completer], which resolves with the follow-up
/// save's outcome.
class _QueuedNoteSave {
  String content;
  String? name;
  bool force;
  final Completer<void> completer = Completer<void>();
  _QueuedNoteSave(this.content, this.name, this.force);
}
