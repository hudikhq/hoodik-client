import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../utils/l10n_lookup.dart';
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
import 'transfer_errors.dart';
import 'transfer_manager.dart';
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
  final BinaryUploadRunner _runner;
  final String _accountId;
  final String _defaultCipher;
  final Set<String> _cancelledFileIds;

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
    UploadStaging? uploadStaging,
    SharedFolderTargetResolver? sharedTarget,
    SharedFolderUpload? sharedUpload,
  }) : _client = client,
       _workerManager = workerManager,
       _offlineManager = offlineManager,
       _accountId = accountId,
       _defaultCipher = defaultCipher,
       _cancelledFileIds = cancelledFileIds,
       _transferManager = transferManager,
       _backgroundUploadService = backgroundUploadService,
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
    final cipher = _defaultCipher;

    final file = File(localPath);
    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final totalChunks = (fileSize / kUploadChunkSize).ceil().clamp(1, 1 << 30);
    final mime = guessMimeFromFileName(fileName);

    final fileKey = _fileCrypto.generateFileKey(cipher: cipher);
    final nameHash = _fileCrypto.hashFileName(fileName);

    await _assertNotFullyUploaded(nameHash, parentDirId);

    final resolvedStagingId = stagingId ?? const Uuid().v4();
    final stagingDir = await _staging.stagingDir(resolvedStagingId);

    final encryptResult = await _encryptToStaging(
      localPath: localPath,
      fileName: fileName,
      fileSize: fileSize,
      totalChunks: totalChunks,
      cipher: cipher,
      fileKey: fileKey,
      stagingDir: stagingDir,
      tempId: resolvedStagingId,
    );

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
    final fileId = entry['id'] as String;

    _log.info(
      'file entry created — starting upload',
      fields: {
        'file_id': fileId,
        'sha256': encryptResult.sha256,
        'total_chunks': totalChunks,
        'chunk_mb': kUploadChunkSize ~/ 1024 ~/ 1024,
      },
    );

    final token = await _client.auth.requestTransferToken(
      fileId: fileId,
      action: 'upload',
    );

    try {
      await _uploadFromStaging(
        fileId: fileId,
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        stagingDir: stagingDir,
        transferToken: token.token,
        checksums: encryptResult.checksums,
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

  Future<void> _assertNotFullyUploaded(
    String nameHash,
    String? parentDirId,
  ) async {
    final existing = await _client.files.checkNameHash(
      nameHash,
      parentId: parentDirId,
    );
    if (existing == null) return;

    final existingItem = FileItem.fromJson(existing);
    final storedChunks = existingItem.chunksStored ?? 0;
    final totalExisting = existingItem.chunks ?? 0;
    if (totalExisting > 0 && storedChunks >= totalExisting) {
      throw Exception(ambientL10n.serviceFileAlreadyExists);
    }
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

      if (encryptItem != null) {
        _transferManager?.completeTransfer(encryptItem.id);
      }

      return _EncryptStageResult(
        sha256: result.sha256,
        checksums: result.checksums,
      );
    } catch (e) {
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
    required String fileName,
    required int fileSize,
    required int totalChunks,
    required String stagingDir,
    required String transferToken,
    required Map<int, String> checksums,
  }) async {
    final useBgUploader = _backgroundUploadService != null;
    final uploadItem = _transferManager?.startTransfer(
      fileName: fileName,
      type: TransferType.uploadHttp,
      totalBytes: fileSize,
      totalChunks: totalChunks,
      fileId: fileId,
      onWorker: useBgUploader,
    );

    try {
      await _runner.run(
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

  Future<void> _uploadPerChunk({
    required String fileId,
    required int fileSize,
    required int totalChunks,
    required String stagingDir,
    required String transferToken,
    required Map<int, String> checksums,
    required TransferItem? uploadItem,
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
  }) async {
    for (var i = 0; i < totalChunks; i++) {
      if (_cancelledFileIds.remove(fileId)) {
        if (transferItem != null) {
          _transferManager?.markCancelled(transferItem.id);
        }
        throw TransferCancelledException(fileId);
      }

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
