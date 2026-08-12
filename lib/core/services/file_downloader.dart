import 'dart:io';
import 'dart:typed_data';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../utils/l10n_lookup.dart';
import '../utils/logger.dart';
import '../workers/worker_messages.dart';
import 'background_download_service.dart';
import 'chunk_download_pipeline.dart';
import 'chunk_download_transport.dart';
import 'offline_manager.dart';
import 'tar_fallback.dart';
import 'transfer_errors.dart';
import 'transfer_manager.dart';

const _log = Logger('FileDownloader');

/// Download + decrypt orchestration. Three entry points:
///
/// * [downloadFile] — in-memory decrypted bytes (previews, MCP tool calls).
///   Always main-thread because callers want the plaintext directly.
/// * [downloadFileToDisk] — staged chunk download, then decrypt to an
///   output path. Delegates to [ChunkDownloadPipeline] on platforms where
///   the OS-native downloader is available so transfers survive app
///   suspension; otherwise falls back to a main-thread sequential loop.
/// * [downloadAndPinOffline] — fetches encrypted chunks into the offline
///   cache without decrypting. Feeds "Make Available Offline" and the
///   preview pipeline (which decrypts separately from the cache).
class FileDownloader {
  final ApiClient _client;
  final FileCrypto _fileCrypto;
  final TransferManager? _transferManager;
  final OfflineManager? _offlineManager;
  final BackgroundDownloadService? _backgroundDownloadService;
  final TarCapabilityCache? _tarCapabilityCache;
  final ChunkDownloadTransport? _chunkDownloadTransport;
  final String? _accountId;

  /// File IDs with pending cancellation (for main-thread fallback loops).
  final Set<String> _cancelledFileIds = {};

  FileDownloader({
    required ApiClient client,
    required FileCrypto fileCrypto,
    TransferManager? transferManager,
    OfflineManager? offlineManager,
    BackgroundDownloadService? backgroundDownloadService,
    TarCapabilityCache? tarCapabilityCache,
    ChunkDownloadTransport? chunkDownloadTransport,
    String? accountId,
  }) : _client = client,
       _fileCrypto = fileCrypto,
       _transferManager = transferManager,
       _offlineManager = offlineManager,
       _backgroundDownloadService = backgroundDownloadService,
       _tarCapabilityCache = tarCapabilityCache,
       _chunkDownloadTransport = chunkDownloadTransport,
       _accountId = accountId;

  /// Prefer the OS-native downloader when the platform supports it and the
  /// wiring is in place. Used for [downloadAndPinOffline] which still goes
  /// through [BackgroundDownloadService] so the download survives app
  /// suspension on iOS/Android. [downloadFileToDisk] uses the Rust FFI
  /// pipeline on all platforms (see [_useChunkPipeline]).
  bool get _useBackgroundDownloader =>
      _backgroundDownloadService != null &&
      _offlineManager != null &&
      _accountId != null &&
      (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  /// Whether [ChunkDownloadPipeline] can run — requires the offline store
  /// for chunk placement, the capability cache for tar fallback, and a
  /// chunk-download transport. The tar leg pushes HTTP through
  /// `background_downloader` (iOS URLSession / Android WorkManager) so
  /// the transfer survives app suspension; the per-chunk fallback runs
  /// through the Rust HTTP pipeline when the server doesn't speak tar.
  bool get _useChunkPipeline =>
      _offlineManager != null &&
      _accountId != null &&
      _tarCapabilityCache != null &&
      _chunkDownloadTransport != null;

  /// Request cancellation of the main-thread transfer loop for [fileId].
  /// The loop checks between chunks and throws [TransferCancelledException]
  /// at the next boundary. No-op for background downloader transfers —
  /// those are cancelled directly through [BackgroundDownloadService].
  void requestCancel(String fileId) {
    _cancelledFileIds.add(fileId);
  }

  /// Download, decrypt, and return the plaintext bytes for [file]. Progress
  /// is reported through [onProgress] (0.0 to 1.0) and optionally surfaced
  /// in the transfer overlay.
  ///
  /// Set [showInTransfers] to false for background loads that already own
  /// a transfer item — e.g. preview prefetches or the main-thread fallback
  /// path invoked from [downloadFileToDisk].
  Future<Uint8List> downloadFile(
    FileItem file, {
    required Uint8List fileKey,
    void Function(double progress)? onProgress,
    String? displayName,
    bool showInTransfers = true,
  }) async {
    await _client.ensureFreshSession();

    final totalChunks = file.chunks ?? 1;
    final totalBytes = file.size ?? 0;
    final builder = BytesBuilder(copy: false);

    final transferItem = showInTransfers
        ? _transferManager?.startTransfer(
            fileName: displayName ?? file.id.substring(0, 8),
            type: TransferType.downloadHttp,
            totalBytes: totalBytes,
            totalChunks: totalChunks,
            fileId: file.id,
          )
        : null;

    try {
      for (var i = 0; i < totalChunks; i++) {
        if (_cancelledFileIds.remove(file.id)) {
          if (transferItem != null) {
            _transferManager?.markCancelled(transferItem.id);
          }
          throw TransferCancelledException(file.id);
        }

        final encryptedChunk = await _client.files.downloadChunk(
          fileId: file.id,
          chunk: i,
        );

        final decrypted = _fileCrypto.decryptChunk(
          data: encryptedChunk,
          fileKey: fileKey,
          cipher: file.cipher,
          chunkIndex: i,
        );

        builder.add(decrypted);

        final completedChunks = i + 1;
        final transferredBytes = totalBytes > 0
            ? (totalBytes * completedChunks / totalChunks).round()
            : 0;

        onProgress?.call(completedChunks / totalChunks);

        if (transferItem != null) {
          _transferManager?.updateProgress(
            transferItem.id,
            completedChunks: completedChunks,
            transferredBytes: transferredBytes,
          );
        }
      }

      if (transferItem != null) {
        _transferManager?.completeTransfer(transferItem.id);
      }

      return builder.toBytes();
    } catch (e) {
      // Cancellation already marked the transfer at the cancel point — only
      // real failures get surfaced as `failTransfer`.
      if (transferItem != null && e is! TransferCancelledException) {
        _transferManager?.failTransfer(
          transferItem.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }
  }

  /// Download [file] and write the decrypted bytes to [outputPath]. Runs
  /// fire-and-forget (the caller gets control back immediately); progress
  /// is tracked through the transfer overlay and [onComplete] fires after
  /// the file is on disk.
  void downloadFileToDisk(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    String? displayName,
    Future<void> Function()? onComplete,
  }) {
    final totalChunks = file.chunks ?? 1;
    final totalBytes = file.size ?? 0;
    final name = displayName ?? file.id.substring(0, 8);

    if (_useChunkPipeline) {
      _log.debug(
        'using chunk pipeline (tar-first)',
        fields: {
          'file_id': file.id,
          'chunks': totalChunks,
          'size_kb': totalBytes ~/ 1024,
        },
      );
      ChunkDownloadPipeline(
        client: _client,
        offlineManager: _offlineManager!,
        tarCapabilityCache: _tarCapabilityCache!,
        accountId: _accountId!,
        transport: _chunkDownloadTransport!,
        transferManager: _transferManager,
      ).run(
        file,
        fileKey: fileKey,
        outputPath: outputPath,
        displayName: name,
        totalChunks: totalChunks,
        totalBytes: totalBytes,
        onComplete: onComplete,
      );
      return;
    }

    // Main-thread fallback: single overlay entry covering download + decrypt.
    final transferItem = _transferManager?.startTransfer(
      fileName: name,
      type: TransferType.downloadHttp,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
      fileId: file.id,
    );
    _downloadOnMainThread(
      file,
      fileKey: fileKey,
      outputPath: outputPath,
      displayName: name,
      transferItem: transferItem,
      onComplete: onComplete,
    );
  }

  /// Download encrypted chunks and register them in the offline cache,
  /// without decrypting. Feeds "Make Available Offline" and the preview
  /// pipeline.
  ///
  /// [pinned] (default true) marks the file as pinned so automatic LRU
  /// eviction won't reclaim it. Preview passes false so previewed files
  /// can be evicted when space is needed.
  void downloadAndPinOffline(
    FileItem file, {
    String? displayName,
    bool pinned = true,
    bool silent = false,
    void Function()? onComplete,
    void Function(String error)? onError,
  }) {
    if (_offlineManager == null || _accountId == null) {
      onError?.call(ambientL10n.serviceOfflineManagerUnavailable);
      return;
    }

    final totalChunks = file.chunks ?? 1;
    final totalBytes = file.size ?? 0;
    final useBg = _useBackgroundDownloader;
    final name = displayName ?? file.id.substring(0, 8);

    final transferItem = _transferManager?.startTransfer(
      fileName: name,
      type: TransferType.downloadHttp,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
      fileId: file.id,
      onWorker: useBg,
      silent: silent,
    );

    () async {
      try {
        final chunksPath = await _offlineManager.chunksDir(_accountId, file.id);

        if (useBg) {
          final transferToken = await _requestTransferToken(file.id);

          _backgroundDownloadService!.downloadChunks(
            cmd: DownloadChunksCommand(
              fileId: file.id,
              totalChunks: totalChunks,
              fileSize: totalBytes,
              outputDir: chunksPath,
              transferToken: transferToken,
            ),
            transferId: transferItem?.id,
            onComplete: () async {
              if (transferItem != null) {
                _transferManager?.completeTransfer(transferItem.id);
              }
              await _offlineManager.registerChunks(
                accountId: _accountId,
                fileId: file.id,
                chunksDir: chunksPath,
                chunkCount: totalChunks,
                pinned: pinned,
              );
              onComplete?.call();
            },
            onError: (error) {
              if (transferItem != null) {
                _transferManager?.failTransfer(transferItem.id, error);
              }
              onError?.call(error);
            },
          );
        } else {
          await _pinOfflineMainThread(
            file,
            chunksPath: chunksPath,
            totalChunks: totalChunks,
            totalBytes: totalBytes,
            pinned: pinned,
            transferItem: transferItem,
            onComplete: onComplete,
            onError: onError,
          );
        }
      } catch (e) {
        if (transferItem != null) {
          _transferManager?.failTransfer(transferItem.id, e.toString());
        }
        onError?.call(e.toString());
      }
    }();
  }

  /// Bearer token for direct transfer uploads/downloads. Refreshes the
  /// session first so callers (including the background download service)
  /// don't have to.
  Future<String> _requestTransferToken(String fileId) async {
    await _client.ensureFreshSession();
    final token = await _client.auth.requestTransferToken(
      fileId: fileId,
      action: 'download',
    );
    return token.token;
  }

  Future<void> _downloadOnMainThread(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    String? displayName,
    TransferItem? transferItem,
    Future<void> Function()? onComplete,
  }) async {
    final totalChunks = file.chunks ?? 1;
    final totalBytes = file.size ?? 0;

    try {
      // Parent transfer item already exists — the in-memory download below
      // skips creating its own and writes progress back to ours instead.
      final bytes = await downloadFile(
        file,
        fileKey: fileKey,
        displayName: displayName,
        showInTransfers: false,
        onProgress: transferItem != null
            ? (progress) {
                _transferManager?.updateProgress(
                  transferItem.id,
                  completedChunks: (totalChunks * progress).round(),
                  transferredBytes: (totalBytes * progress).round(),
                );
              }
            : null,
      );
      await File(outputPath).writeAsBytes(bytes);

      if (transferItem != null) {
        _transferManager?.completeTransfer(transferItem.id);
      }

      await onComplete?.call();
    } on TransferCancelledException {
      // The cancel point already called markCancelled — nothing more to do.
    } catch (e) {
      if (transferItem != null) {
        _transferManager?.failTransfer(
          transferItem.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _pinOfflineMainThread(
    FileItem file, {
    required String chunksPath,
    required int totalChunks,
    required int totalBytes,
    bool pinned = true,
    TransferItem? transferItem,
    void Function()? onComplete,
    void Function(String error)? onError,
  }) async {
    try {
      await _client.ensureFreshSession();
      for (var i = 0; i < totalChunks; i++) {
        final encryptedChunk = await _client.files.downloadChunk(
          fileId: file.id,
          chunk: i,
        );
        final dir = Directory(chunksPath);
        if (!await dir.exists()) await dir.create(recursive: true);
        final chunkPath = '$chunksPath/${i.toString().padLeft(6, '0')}.enc';
        await File(chunkPath).writeAsBytes(encryptedChunk);

        if (transferItem != null) {
          final transferred = (totalBytes * (i + 1) / totalChunks).round();
          _transferManager?.updateProgress(
            transferItem.id,
            completedChunks: i + 1,
            transferredBytes: transferred,
          );
        }
      }

      await _offlineManager!.registerChunks(
        accountId: _accountId!,
        fileId: file.id,
        chunksDir: chunksPath,
        chunkCount: totalChunks,
        pinned: pinned,
      );

      if (transferItem != null) {
        _transferManager?.completeTransfer(transferItem.id);
      }

      onComplete?.call();
    } catch (e) {
      if (transferItem != null) {
        _transferManager?.failTransfer(transferItem.id, e.toString());
      }
      onError?.call(e.toString());
    }
  }
}
