import 'dart:io';
import 'dart:typed_data';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../storage/database.dart';
import '../utils/l10n_lookup.dart';
import '../utils/logger.dart';
import 'chunk_download_pipeline.dart';
import 'chunk_download_transport.dart';
import 'file_downloader_pin.dart';
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
  final TarCapabilityCache? _tarCapabilityCache;
  final ChunkDownloadTransport? _chunkDownloadTransport;
  final AppDatabase? _database;
  final String? _accountId;

  /// Passed to the chunk pipeline, which skips asking for a bucket manifest
  /// on a server that does not serve them.
  final bool _directTransfer;

  /// File IDs with pending cancellation (for main-thread fallback loops).
  final Set<String> _cancelledFileIds = {};

  FileDownloader({
    required ApiClient client,
    required FileCrypto fileCrypto,
    TransferManager? transferManager,
    OfflineManager? offlineManager,
    TarCapabilityCache? tarCapabilityCache,
    ChunkDownloadTransport? chunkDownloadTransport,
    AppDatabase? database,
    String? accountId,
    bool directTransfer = true,
  }) : _client = client,
       _database = database,
       _fileCrypto = fileCrypto,
       _transferManager = transferManager,
       _offlineManager = offlineManager,
       _tarCapabilityCache = tarCapabilityCache,
       _chunkDownloadTransport = chunkDownloadTransport,
       _directTransfer = directTransfer,
       _accountId = accountId {
    _offlineManager?.activeTransferIds = () {
      final ids = <String>{};
      for (final t in _transferManager?.activeTransfers ?? const []) {
        final id = t.fileId;
        if (id != null) ids.add(id);
      }
      return ids;
    };
  }

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

  /// Pick up the chunk downloads a previous session left unfinished.
  ///
  /// Called at sign-in with every row this account still has, whether or not
  /// the OS is carrying the transfer: what died with the previous process is
  /// the owner, and without one nothing draws the progress, decrypts the
  /// result or clears the row. A no-op on a build that cannot run the chunk
  /// pipeline, which is also the only place those rows are ever written.
  Future<void> resumeInterruptedDownloads(List<PendingDownload> rows) async {
    if (rows.isEmpty || !_useChunkPipeline) return;
    await _pipeline().resumeInterrupted(rows);
  }

  ChunkDownloadPipeline _pipeline() => ChunkDownloadPipeline(
    client: _client,
    offlineManager: _offlineManager!,
    tarCapabilityCache: _tarCapabilityCache!,
    accountId: _accountId!,
    transport: _chunkDownloadTransport!,
    database: _database,
    fileCrypto: _fileCrypto,
    transferManager: _transferManager,
    directTransfer: _directTransfer,
  );

  /// Request cancellation of the main-thread transfer loop for [fileId].
  /// The loop checks between chunks and throws [TransferCancelledException]
  /// at the next boundary. No-op for pipeline transfers — the OS-native tasks
  /// behind those are cancelled through the services that own them.
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
    final totalChunks = file.chunks ?? 1;
    final totalBytes = file.size ?? 0;
    final name = displayName ?? file.id.substring(0, 8);

    if (_useChunkPipeline) {
      return _pipeline().fetchAndDecrypt(
        file,
        fileKey: fileKey,
        displayName: name,
        totalChunks: totalChunks,
        totalBytes: totalBytes,
        silent: !showInTransfers,
        onProgress: onProgress,
      );
    }

    await _client.ensureFreshSession();

    final builder = BytesBuilder(copy: false);

    final transferItem = showInTransfers
        ? _transferManager?.startTransfer(
            fileName: name,
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
    void Function(String error)? onError,
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
      _pipeline().run(
        file,
        fileKey: fileKey,
        outputPath: outputPath,
        displayName: name,
        totalChunks: totalChunks,
        totalBytes: totalBytes,
        onComplete: onComplete,
        onError: onError,
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
      onError: onError,
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
    final totalChunks = file.chunks ?? 1;
    final totalBytes = file.size ?? 0;
    final name = displayName ?? file.id.substring(0, 8);

    () async {
      try {
        if (_useChunkPipeline) {
          await _pipeline().fetchChunks(
            file,
            displayName: name,
            totalChunks: totalChunks,
            totalBytes: totalBytes,
            pinned: pinned,
            silent: silent,
          );
          onComplete?.call();
          return;
        }

        if (_offlineManager == null || _accountId == null) {
          onError?.call(ambientL10n.serviceOfflineManagerUnavailable);
          return;
        }

        await pinOfflineOnMainThread(
          client: _client,
          offlineManager: _offlineManager,
          accountId: _accountId,
          transferManager: _transferManager,
          file: file,
          chunksPath: await _offlineManager.chunksDir(_accountId, file.id),
          totalChunks: totalChunks,
          totalBytes: totalBytes,
          pinned: pinned,
          transferItem: _transferManager?.startTransfer(
            fileName: name,
            type: TransferType.downloadHttp,
            totalBytes: totalBytes,
            totalChunks: totalChunks,
            fileId: file.id,
            silent: silent,
          ),
          onComplete: onComplete,
          onError: onError,
        );
      } catch (e) {
        onError?.call(e.toString());
      }
    }();
  }

  Future<void> _downloadOnMainThread(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    String? displayName,
    TransferItem? transferItem,
    Future<void> Function()? onComplete,
    void Function(String error)? onError,
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
      onError?.call(e.toString());
    }
  }
}
