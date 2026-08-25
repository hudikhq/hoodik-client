import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import '../utils/mime.dart';
import '../workers/worker_manager.dart';
import '../workers/worker_messages.dart';
import 'background_upload_service.dart';
import 'binary_upload_metadata.dart';
import 'binary_upload_runner.dart';
import 'binary_upload_transport.dart';
import 'offline_manager.dart';
import 'shared_folder_target.dart';
import 'shared_folder_upload.dart';
import 'staging_manifest.dart';
import 'transfer_errors.dart';
import 'transfer_manager.dart';
import 'direct_chunk_upload.dart';
import 'upload_resume.dart';
import 'upload_staging.dart';

const _log = Logger('BinaryUploadPipeline');

/// Chunk size for file uploads: 4 MB (matches web frontend and server max).
const int kUploadChunkSize = 1024 * 1024 * 4;

/// Three-phase binary upload:
///
/// * **encrypt** — reads the plaintext file, encrypts each chunk with the
///   file's per-file key, writes ciphertext to the upload-staging dir on
///   disk. A retry that finds chunks already in staging reuses them — the
///   file key is the same (regenerated per *attempt*, reused within an
///   attempt), so re-encrypting would only waste CPU.
/// * **upload** — posts the encrypted chunks to the server. Tries tar
///   every time: Rust FFI packs staging into a tar file on disk, then
///   `background_downloader` uploads it in one HTTP request (URLSession
///   on iOS/macOS, WorkManager on Android) so the transfer survives app
///   suspension. Drops to per-chunk POSTs against [BackgroundUploadService]
///   for *this upload only* if the server rejects the tar probe — never
///   caches the verdict, so a self-hoster who upgrades mid-session
///   recovers automatically on their next upload. Per-chunk reads the
///   already-encrypted bytes from staging, so the CPU-heavy encrypt step
///   runs exactly once per attempt regardless of which variant handles
///   the wire.
/// * **cleanup** — on success, the staging chunks are promoted into the
///   offline cache (so the file is available offline for free) and the
///   staging dir is removed. On cancel or error, staging is left alone
///   so a follow-up attempt can resume without re-encrypting.
class BinaryUploadPipeline {
  final ApiClient _client;
  final FileCrypto _fileCrypto;
  final TransferManager? _transferManager;
  final WorkerManager _workerManager;
  final OfflineManager _offlineManager;
  final BackgroundUploadService? _backgroundUploadService;
  final DirectChunkUploadService? _directUpload;
  final BinaryUploadRunner _runner;
  final String _accountId;
  final String _defaultCipher;
  final Set<String> _cancelledFileIds;

  /// Whether this server will accept a whole file as one archive. False only
  /// when it says so outright; a server that does not advertise either way is
  /// still probed, so an upgrade is picked up without a restart.
  final bool _tarSupported;

  BinaryUploadPipeline({
    required ApiClient client,
    required FileCrypto fileCrypto,
    required String publicKeyPem,
    required WorkerManager workerManager,
    required OfflineManager offlineManager,
    required String accountId,
    required Set<String> cancelledFileIds,
    required UploadTarTransport tarTransport,
    String defaultCipher = 'aegis128l',
    TransferManager? transferManager,
    BackgroundUploadService? backgroundUploadService,
    DirectChunkUploadService? directUpload,
    UploadStaging? uploadStaging,
    SharedFolderTargetResolver? sharedTarget,
    SharedFolderUpload? sharedUpload,
    bool tarSupported = true,
  }) : _client = client,
       _tarSupported = tarSupported,
       _workerManager = workerManager,
       _offlineManager = offlineManager,
       _accountId = accountId,
       _defaultCipher = defaultCipher,
       _cancelledFileIds = cancelledFileIds,
       _transferManager = transferManager,
       _backgroundUploadService = backgroundUploadService,
       _directUpload = directUpload,
       _runner = BinaryUploadRunner(tarTransport: tarTransport),
       _staging = uploadStaging ?? UploadStaging(accountId: accountId),
       _fileCrypto = fileCrypto,
       _metadata = BinaryUploadMetadata(
         client: client,
         fileCrypto: fileCrypto,
         publicKeyPem: publicKeyPem,
         sharedTarget: sharedTarget,
         sharedUpload: sharedUpload,
       );

  final UploadStaging _staging;
  final BinaryUploadMetadata _metadata;

  Future<void> run(
    String localPath, {
    String? parentDirId,
    void Function(double progress)? onProgress,
    String? stagingId,
  }) async {
    await _client.ensureFreshSession();

    final file = File(localPath);
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final totalChunks = (fileSize / kUploadChunkSize).ceil().clamp(1, 1 << 30);
    final mime = guessMimeFromFileName(fileName);

    final nameHash = _fileCrypto.hashFileName(fileName);

    // The server refuses a duplicate create, so a name-hash hit on a partial
    // row is adopted — its id, its key, its cipher — and only the chunks the
    // server cannot prove it holds go over the wire.
    final resume = UploadResume.of(
      await _existingByName(nameHash, parentDirId),
      totalChunks: totalChunks,
      fileCrypto: _fileCrypto,
    );
    final cipher = resume?.cipher ?? _defaultCipher;
    final fileKey =
        resume?.fileKey ?? _fileCrypto.generateFileKey(cipher: cipher);

    final resolvedStagingId = stagingId ?? const Uuid().v4();
    final stagingDir = await _staging.stagingDir(resolvedStagingId);

    final sourceModifiedAt =
        (await file.stat()).modified.millisecondsSinceEpoch;
    final reusable = await StagingManifest.tryReuse(
      stagingDir: stagingDir,
      fileKey: fileKey,
      totalChunks: totalChunks,
      fileSize: fileSize,
      sourceModifiedAt: sourceModifiedAt,
    );

    final _EncryptStageResult encryptResult;
    if (reusable != null) {
      _log.info(
        'reusing staged ciphertext — skipping encrypt',
        fields: {'staging_id': resolvedStagingId, 'chunks': totalChunks},
      );
      encryptResult = _EncryptStageResult(
        sha256: reusable.sha256,
        checksums: reusable.checksums,
      );
    } else {
      encryptResult = await _encryptToStaging(
        localPath: localPath,
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        cipher: cipher,
        fileKey: fileKey,
        stagingDir: stagingDir,
        tempId: resolvedStagingId,
      );
      await StagingManifest.write(
        stagingDir: stagingDir,
        fileKey: fileKey,
        sha256: encryptResult.sha256,
        checksums: encryptResult.checksums,
        totalChunks: totalChunks,
        fileSize: fileSize,
        sourceModifiedAt: sourceModifiedAt,
      );
    }

    resume?.ensureSameContent(encryptResult.sha256);

    final String fileId;
    if (resume != null) {
      fileId = resume.fileId;
      _log.info(
        'adopting interrupted upload',
        fields: {
          'file_id': fileId,
          'stored_chunks': resume.uploadedChunks.length,
          'total_chunks': totalChunks,
        },
      );
    } else {
      final entry = await _metadata.createEntry(
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        mime: mime,
        cipher: cipher,
        fileKey: fileKey,
        nameHash: nameHash,
        parentDirId: parentDirId,
        localPath: localPath,
        sha256: encryptResult.sha256,
      );
      fileId = entry['id'] as String;

      _log.info(
        'file entry created — starting upload',
        fields: {
          'file_id': fileId,
          'total_chunks': totalChunks,
          'chunk_mb': kUploadChunkSize ~/ 1024 ~/ 1024,
        },
      );
    }

    final token = await _client.auth.requestTransferToken(
      fileId: fileId,
      action: 'upload',
    );

    try {
      await _uploadFromStaging(
        fileId: fileId,
        stagingId: resolvedStagingId,
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        stagingDir: stagingDir,
        transferToken: token.token,
        checksums: encryptResult.checksums,
        skipChunks: resume?.uploadedChunks ?? const <int>{},
      );
    } on TransferCancelledException {
      rethrow;
    } catch (e) {
      _log.warn(
        'upload failed — staging preserved for retry',
        fields: {'file_id': fileId, 'error': describeError(e)},
      );
      rethrow;
    }

    await _promoteStagingToOffline(
      fileId: fileId,
      stagingDir: stagingDir,
      totalChunks: totalChunks,
    );
    await _staging.clear(resolvedStagingId);

    _log.info('upload complete', fields: {'file_id': fileId});
  }

  Future<FileItem?> _existingByName(
    String nameHash,
    String? parentDirId,
  ) async {
    final existing = await _client.files.checkNameHash(
      nameHash,
      parentId: parentDirId,
    );
    return existing == null ? null : FileItem.fromJson(existing);
  }

  Future<_EncryptStageResult> _encryptToStaging({
    required String localPath,
    required String fileName,
    required int fileSize,
    required int totalChunks,
    required String cipher,
    required Uint8List fileKey,
    required String stagingDir,
    required String tempId,
  }) async {
    final encryptItem = _transferManager?.startTransfer(
      fileName: fileName,
      type: TransferType.uploadEncrypt,
      totalBytes: fileSize,
      totalChunks: totalChunks,
      fileId: tempId,
      groupId: tempId,
      onWorker: true,
    );

    try {
      final result = await _workerManager.encryptFile(
        EncryptFileCommand(
          localPath: localPath,
          outputDir: stagingDir,
          fileKey: fileKey,
          cipher: cipher,
          totalChunks: totalChunks,
          fileSize: fileSize,
          tempFileId: tempId,
        ),
        transferId: encryptItem?.id,
      );

      // The worker runs to completion even after a cancel — it has no
      // cancellation channel of its own — so the request is honoured here,
      // before any of this reaches the network.
      if (_cancelledFileIds.remove(tempId)) {
        if (encryptItem != null) {
          _transferManager?.markCancelled(encryptItem.id);
        }
        throw TransferCancelledException(tempId);
      }

      if (encryptItem != null) {
        _transferManager?.completeTransfer(encryptItem.id);
      }

      return _EncryptStageResult(
        sha256: result.sha256,
        checksums: result.checksums,
      );
    } on TransferCancelledException {
      rethrow;
    } catch (e) {
      // A cancel mid-encryption pulls the staging directory out from under
      // the worker, and what it reports is the read that then failed — a
      // filesystem path the user has no use for, shown in red next to a
      // transfer they stopped on purpose. Report the cancellation instead.
      if (_cancelledFileIds.remove(tempId)) {
        if (encryptItem != null) {
          _transferManager?.markCancelled(encryptItem.id);
        }
        throw TransferCancelledException(tempId);
      }

      if (encryptItem != null) {
        _transferManager?.failTransfer(
          encryptItem.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }
  }

  Future<void> _uploadFromStaging({
    required String fileId,
    required String stagingId,
    required String fileName,
    required int fileSize,
    required int totalChunks,
    required String stagingDir,
    required String transferToken,
    required Map<int, String> checksums,
    Set<int> skipChunks = const <int>{},
  }) async {
    final useBgUploader = _backgroundUploadService != null;
    final uploadItem = _transferManager?.startTransfer(
      fileName: fileName,
      type: TransferType.uploadHttp,
      totalBytes: fileSize,
      totalChunks: totalChunks,
      fileId: fileId,
      groupId: stagingId,
      onWorker: useBgUploader,
    );

    try {
      // Straight into the bucket when the server can sign for it — resumes
      // included: they request URLs for the missing chunks only, so a resumed
      // upload runs at the same speed as a fresh one instead of crawling
      // through the relay. Tar exists to spare the server N requests; when
      // the bytes never touch the server there is nothing left for it to
      // spare, and it cannot resume anyway (it ships the whole archive).
      //
      // Falls through rather than returning: the transfer is marked complete at
      // the end of this method, and a direct upload that returned early from
      // here left its row sitting at 100% for the rest of the session.
      final wentDirect = await _uploadDirect(
        fileId: fileId,
        fileSize: fileSize,
        totalChunks: totalChunks,
        stagingDir: stagingDir,
        transferToken: transferToken,
        uploadItem: uploadItem,
        skipChunks: skipChunks,
      );

      if (!wentDirect && skipChunks.isNotEmpty) {
        await _uploadPerChunk(
          fileId: fileId,
          fileSize: fileSize,
          totalChunks: totalChunks,
          stagingDir: stagingDir,
          transferToken: transferToken,
          checksums: checksums,
          uploadItem: uploadItem,
          skipChunks: skipChunks,
        );
      } else if (!wentDirect) {
        await _runner.run(
          tarSupported: _tarSupported,
          baseUrl: _client.baseUrl,
          transferToken: transferToken,
          fileId: fileId,
          stagingDir: stagingDir,
          chunkCount: totalChunks,
          perChunk: () => _uploadPerChunk(
            fileId: fileId,
            fileSize: fileSize,
            totalChunks: totalChunks,
            stagingDir: stagingDir,
            transferToken: transferToken,
            checksums: checksums,
            uploadItem: uploadItem,
          ),
          onTarResult: (result) {
            if (uploadItem != null) {
              _transferManager?.updateProgress(
                uploadItem.id,
                completedChunks: result.chunksStored,
                transferredBytes: fileSize,
              );
            }
          },
          onTarProgress: uploadItem == null
              ? null
              : (transferred, total) {
                  // Tar progress is in tar-archive bytes; the UI's totalBytes
                  // is plaintext fileSize. Map proportionally so the bar
                  // stays accurate even though the wire size is slightly
                  // larger (16 B AEAD tag per chunk + tar headers).
                  final fraction = total > 0
                      ? (transferred / total).clamp(0.0, 1.0)
                      : 0.0;
                  final mappedBytes = (fraction * fileSize).round();
                  final mappedChunks = (fraction * totalChunks).floor().clamp(
                    0,
                    totalChunks,
                  );
                  _transferManager?.updateProgress(
                    uploadItem.id,
                    completedChunks: mappedChunks,
                    transferredBytes: mappedBytes,
                  );
                },
        );
      }
    } catch (e) {
      if (uploadItem != null) {
        _transferManager?.failTransfer(
          uploadItem.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }

    if (uploadItem != null) {
      _transferManager?.completeTransfer(uploadItem.id);
    }
  }

  /// Write the staged chunks straight into the bucket.
  ///
  /// Returns false when that cannot be done and the caller should fall back:
  /// no direct-upload service on this build, staging not fully encrypted yet,
  /// or a server that will not sign the URLs — which is every local-disk
  /// deployment and any S3 one whose bucket failed its startup checks.
  Future<bool> _uploadDirect({
    required String fileId,
    required int fileSize,
    required int totalChunks,
    required String stagingDir,
    required String transferToken,
    required TransferItem? uploadItem,
    Set<int> skipChunks = const <int>{},
  }) async {
    final direct = _directUpload;
    if (direct == null) return false;

    // Declared per chunk because the server signs each length into its URL, so
    // these must be the on-disk ciphertext sizes rather than the plaintext
    // chunk size. A gap means the encrypt phase did not finish, and the
    // relaying path is the one that knows how to pick that up.
    final sizes = await stagedChunkSizes(stagingDir, totalChunks);
    if (sizes.length != totalChunks) return false;

    // A resume declares (and is charged for) only what it still has to
    // write; the bucket already holds the rest.
    final requestSizes = {
      for (final entry in sizes.entries)
        if (!skipChunks.contains(entry.key)) entry.key: entry.value,
    };

    if (requestSizes.isNotEmpty) {
      final manifest = await _client.files.fetchUploadUrls(
        fileId: fileId,
        transferToken: transferToken,
        chunkSizes: requestSizes,
      );
      final urls = resumeUrlPlan(
        manifest: manifest,
        totalChunks: totalChunks,
        skipChunks: skipChunks,
      );
      if (urls == null) return false;

      await direct.upload(
        accountId: _accountId,
        fileId: fileId,
        urls: urls,
        stagingDir: stagingDir,
        fileSize: fileSize,
        onProgress: uploadItem == null
            ? null
            : (completedChunks, transferredBytes) =>
                  _transferManager?.updateProgress(
                    uploadItem.id,
                    completedChunks: completedChunks,
                    transferredBytes: transferredBytes,
                  ),
      );
    }

    // Nothing tells the server that a direct write landed, so the client says
    // so. It does not take our word for it: the bucket is listed and every
    // chunk has to be there before the version pointer moves.
    await _client.files.finalizeDirectUpload(
      fileId: fileId,
      transferToken: transferToken,
    );

    _log.info(
      'direct upload committed',
      fields: {'file_id': fileId, 'chunks': requestSizes.length},
    );
    return true;
  }

  Future<void> _uploadPerChunk({
    required String fileId,
    required int fileSize,
    required int totalChunks,
    required String stagingDir,
    required String transferToken,
    required Map<int, String> checksums,
    required TransferItem? uploadItem,
    Set<int> skipChunks = const <int>{},
  }) async {
    final useBg = _backgroundUploadService != null;
    if (useBg) {
      await _backgroundUploadService.uploadChunks(
        cmd: UploadChunksCommand(
          fileId: fileId,
          chunksDir: stagingDir,
          totalChunks: totalChunks,
          fileSize: fileSize,
          transferToken: transferToken,
          checksums: checksums,
          alreadyUploaded: skipChunks.toList(),
        ),
        transferId: uploadItem?.id,
      );
      return;
    }

    await _uploadChunksMainThread(
      fileId: fileId,
      stagingDir: stagingDir,
      totalChunks: totalChunks,
      fileSize: fileSize,
      checksums: checksums,
      transferItem: uploadItem,
      skipChunks: skipChunks,
    );
  }

  /// Used when [BackgroundUploadService] is unavailable (e.g. self-signed
  /// cert servers where URLSession can't bypass certificate validation).
  Future<void> _uploadChunksMainThread({
    required String fileId,
    required String stagingDir,
    required int totalChunks,
    required int fileSize,
    required Map<int, String> checksums,
    TransferItem? transferItem,
    Set<int> skipChunks = const <int>{},
  }) async {
    for (var i = 0; i < totalChunks; i++) {
      if (_cancelledFileIds.remove(fileId)) {
        if (transferItem != null) {
          _transferManager?.markCancelled(transferItem.id);
        }
        throw TransferCancelledException(fileId);
      }

      if (!skipChunks.contains(i)) {
        final chunkFile = File(
          p.join(stagingDir, '${i.toString().padLeft(6, '0')}.enc'),
        );
        final data = await chunkFile.readAsBytes();
        await _client.files.uploadChunk(
          fileId: fileId,
          chunk: i,
          data: data,
          checksum: checksums[i],
          checksumFunction: checksums[i] != null ? 'crc16' : null,
        );
      }

      if (transferItem != null) {
        final transferred = (fileSize * (i + 1) / totalChunks).round();
        _transferManager?.updateProgress(
          transferItem.id,
          completedChunks: i + 1,
          transferredBytes: transferred,
        );
      }
    }
  }

  /// Rename the staging directory into the offline cache location so the
  /// file is immediately available offline without having to re-download
  /// the ciphertext we already have on disk.
  Future<void> _promoteStagingToOffline({
    required String fileId,
    required String stagingDir,
    required int totalChunks,
  }) async {
    final offlinePath = await _offlineManager.chunksDir(_accountId, fileId);
    try {
      await _staging.moveTo(stagingDir, offlinePath);
      await _offlineManager.registerChunks(
        accountId: _accountId,
        fileId: fileId,
        chunksDir: offlinePath,
        chunkCount: totalChunks,
      );
    } catch (e) {
      _log.warn(
        'promote-to-offline failed',
        fields: {'file_id': fileId, 'error': describeError(e)},
      );
    }
  }
}

class _EncryptStageResult {
  final String sha256;
  final Map<int, String> checksums;

  _EncryptStageResult({required this.sha256, required this.checksums});
}
