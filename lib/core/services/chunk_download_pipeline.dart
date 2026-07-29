import 'package:flutter/foundation.dart';

import '../../src/rust/api.dart' as rust;
import '../api/api_client.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'chunk_download_runner.dart';
import 'chunk_download_transport.dart';
import 'offline_manager.dart';
import 'tar_fallback.dart';
import 'transfer_manager.dart';

const _log = Logger('ChunkDownloadPipeline');

/// Encrypted-chunk download + decrypt pipeline used by
/// [FileDownloader.downloadFileToDisk].
///
/// Phase 1 pulls the whole archive in a single round-trip: `background_downloader`
/// runs the HTTP leg so the transfer survives app suspension on iOS/Android,
/// and the Rust FFI unpacks the landed tar into individual `.enc` chunks.
/// Servers that don't recognise `?format=tar` surface that through
/// [shouldFallbackToPerChunk]; the capability cache remembers the answer
/// for the rest of the session so the next file skips the probe. Phase 2
/// decrypts the cached `.enc` chunks via [rust.decryptChunksToFile]. Each
/// phase owns its own transfer-overlay entry so the UI shows "downloading"
/// then "decrypting" instead of one opaque bar.
class ChunkDownloadPipeline {
  final ApiClient _client;
  final OfflineManager _offlineManager;
  final TransferManager? _transferManager;
  final ChunkDownloadRunner _runner;
  final String _accountId;

  ChunkDownloadPipeline({
    required ApiClient client,
    required OfflineManager offlineManager,
    required TarCapabilityCache tarCapabilityCache,
    required String accountId,
    required ChunkDownloadTransport transport,
    TransferManager? transferManager,
  }) : _client = client,
       _offlineManager = offlineManager,
       _accountId = accountId,
       _transferManager = transferManager,
       _runner = ChunkDownloadRunner(
         transport: transport,
         tarCapabilityCache: tarCapabilityCache,
       );

  /// Fire-and-forget: runs the download + decrypt chain off the caller's
  /// frame. Progress flows through [TransferManager] so the UI can render
  /// the overlay regardless of where the call originated.
  void run(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    required String displayName,
    required int totalChunks,
    required int totalBytes,
    Future<void> Function()? onComplete,
  }) {
    () async {
      try {
        final chunksPath = await _offlineManager.chunksDir(_accountId, file.id);
        final allChunksCached = await _offlineManager.hasCachedFile(
          _accountId,
          file.id,
        );

        if (allChunksCached) {
          _log.debug(
            'all chunks cached — skipping download',
            fields: {'file_id': file.id},
          );
          await _decryptChunksToOutput(
            file,
            fileKey: fileKey,
            outputPath: outputPath,
            chunksPath: chunksPath,
            displayName: displayName,
            totalChunks: totalChunks,
            totalBytes: totalBytes,
            onComplete: onComplete,
          );
          return;
        }

        final downloadItem = _transferManager?.startTransfer(
          fileName: displayName,
          type: TransferType.downloadHttp,
          totalBytes: totalBytes,
          totalChunks: totalChunks,
          fileId: file.id,
          onWorker: true,
        );

        final downloadStartTime = DateTime.now();

        try {
          await _downloadChunks(
            fileId: file.id,
            fileSize: totalBytes,
            chunkCount: totalChunks,
            chunksPath: chunksPath,
          );
        } catch (e) {
          if (downloadItem != null) {
            _transferManager?.failTransfer(
              downloadItem.id,
              e.toString().replaceFirst('Exception: ', ''),
            );
          }
          rethrow;
        }

        _logDownloadTiming(
          fileId: file.id,
          totalBytes: totalBytes,
          started: downloadStartTime,
        );
        if (downloadItem != null) {
          _transferManager?.completeTransfer(downloadItem.id);
        }
        await _offlineManager.registerChunks(
          accountId: _accountId,
          fileId: file.id,
          chunksDir: chunksPath,
          chunkCount: totalChunks,
        );
        await _decryptChunksToOutput(
          file,
          fileKey: fileKey,
          outputPath: outputPath,
          chunksPath: chunksPath,
          displayName: displayName,
          totalChunks: totalChunks,
          totalBytes: totalBytes,
          onComplete: onComplete,
        );
      } catch (e) {
        _log.warn(
          'download setup failed',
          fields: {'file_id': file.id, 'error': describeError(e)},
        );
      }
    }();
  }

  Future<void> _downloadChunks({
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String chunksPath,
  }) async {
    final alreadyDownloaded = await _offlineManager.getDownloadedChunks(
      _accountId,
      fileId,
    );
    await _client.ensureFreshSession();
    final cookie = await _client.getCookieHeader();

    await _runner.run(
      baseUrl: _client.baseUrl,
      cookie: cookie,
      fileId: fileId,
      fileSize: fileSize,
      chunkCount: chunkCount,
      outputDir: chunksPath,
      alreadyDownloaded: alreadyDownloaded,
    );
  }

  Future<void> _decryptChunksToOutput(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    required String chunksPath,
    required String displayName,
    required int totalChunks,
    required int totalBytes,
    Future<void> Function()? onComplete,
  }) async {
    final decryptItem = _transferManager?.startTransfer(
      fileName: displayName,
      type: TransferType.downloadDecrypt,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
      fileId: file.id,
    );

    try {
      final decryptStart = DateTime.now();
      await rust.decryptChunksToFile(
        chunksDir: chunksPath,
        chunkCount: BigInt.from(totalChunks),
        decryptionKey: fileKey,
        cipher: file.cipher,
        outputPath: outputPath,
        fileId: file.id,
      );
      final decryptDuration = DateTime.now().difference(decryptStart);
      _log.debug(
        'chunk decrypt done',
        fields: {
          'file_id': file.id,
          'duration_ms': decryptDuration.inMilliseconds,
        },
      );

      if (decryptItem != null) {
        _transferManager?.completeTransfer(decryptItem.id);
      }
    } catch (e) {
      if (decryptItem != null) {
        _transferManager?.failTransfer(
          decryptItem.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }

    await onComplete?.call();
  }

  void _logDownloadTiming({
    required String fileId,
    required int totalBytes,
    required DateTime started,
  }) {
    final duration = DateTime.now().difference(started);
    final mbps = totalBytes > 0 && duration.inMicroseconds > 0
        ? (totalBytes * 8 / duration.inMicroseconds).toStringAsFixed(1)
        : '?';
    _log.debug(
      'chunk download done',
      fields: {
        'file_id': fileId,
        'duration_ms': duration.inMilliseconds,
        'size_kb': totalBytes ~/ 1024,
        'mbps': mbps,
      },
    );
  }
}
