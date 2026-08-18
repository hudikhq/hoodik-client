import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import '../utils/l10n_lookup.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import '../utils/tar_extractor.dart';
import '../workers/worker_messages.dart';
import 'file_downloader_config.dart';
import 'transfer_manager.dart';

const _log = Logger('BackgroundDownloadService');

/// Delegates file downloads to the OS via `background_downloader`.
///
/// Downloads all encrypted chunks as a single tar archive using the server's
/// `?format=tar` endpoint. The tar is fetched as one [DownloadTask] that iOS
/// URLSession or Android WorkManager handles natively — downloads continue
/// even when the app is suspended or killed.
///
/// After the tar completes, chunks are extracted to individual `.enc` files
/// for subsequent decryption via Rust FFI.
class BackgroundDownloadService {
  static const String group = 'chunk-downloads';
  static const String _taskPrefix = '$group|';

  final String baseUrl;

  /// Owner stamped into every task id, so a later sign-in can tell this
  /// account's transfers from another's — see [transferTaskId].
  final String accountId;

  Future<void>? _configuring;

  /// Per-file download state.
  final Map<String, _FileDownloadInfo> _active = {};

  // Fire-and-forget callbacks.
  final Map<String, Future<void> Function()> _onComplete = {};
  final Map<String, void Function(String)> _onError = {};

  // Awaitable completion (preview pipeline).
  final Map<String, Completer<void>> _completers = {};
  final Map<String, void Function(int, int)> _progressCallbacks = {};

  // TransferManager bridge.
  TransferManager? _transferManager;
  final Map<String, String> _fileIdToTransferId = {};
  final Set<String> _cancelledFileIds = {};

  BackgroundDownloadService({required this.baseUrl, required this.accountId});

  /// Wire to TransferManager for UI progress updates.
  void setTransferManager(TransferManager tm) {
    _transferManager = tm;
  }

  /// One-time configuration. Returns the same future on repeated calls so
  /// callers can safely `await configure()` without double-init.
  Future<void> configure() => _configuring ??= _doConfigure();

  Future<void> _doConfigure() async {
    await ensureFileDownloaderConfigured();
    registerTaskUpdateHandler(_taskPrefix, _handleUpdate);
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Queue a tar download for a file. Returns immediately.
  ///
  /// Progress and completion are reported via [onComplete] / [onError]
  /// callbacks. If [transferId] is set, progress is also pushed to
  /// [TransferManager].
  void downloadChunks({
    required DownloadChunksCommand cmd,
    String? transferId,
    Future<void> Function()? onComplete,
    void Function(String error)? onError,
  }) {
    _enqueueTarDownload(
      cmd: cmd,
      transferId: transferId,
      onComplete: onComplete,
      onError: onError,
    );
  }

  /// Queue a tar download and return a [Future] that completes when done.
  ///
  /// Used by the preview pipeline where the caller needs to `await` before
  /// proceeding to decryption.
  Future<void> downloadChunksAsync({
    required DownloadChunksCommand cmd,
    void Function(int transferred, int total)? onProgress,
  }) {
    final completer = Completer<void>();
    _completers[cmd.fileId] = completer;
    if (onProgress != null) {
      _progressCallbacks[cmd.fileId] = onProgress;
    }
    _enqueueTarDownload(cmd: cmd);
    return completer.future;
  }

  /// Cancel the pending/active download for a file.
  ///
  /// Stops the OS-native task, deletes partial files (tar + extracted chunks),
  /// and removes the stale record from the [FileDownloader] persistent
  /// database so it doesn't accumulate across sessions.
  void cancelDownload(String fileId) {
    _cancelledFileIds.add(fileId);

    final info = _active[fileId];
    if (info != null) {
      FileDownloader().cancelTaskWithId(info.taskId);
      // Remove partial tar + extracted chunks from disk.
      _cleanupOutputDir(info.outputDir);
      // Purge the task record from the persistent database so it doesn't
      // accumulate and slow down future operations.
      FileDownloader().database.deleteRecordWithId(info.taskId);
    }

    final completer = _completers.remove(fileId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception(ambientL10n.serviceDownloadCancelled));
    }

    _cleanup(fileId);
  }

  /// Replay buffered OS events after app resumes from background.
  Future<void> resumeFromBackground() async {
    await FileDownloader().resumeFromBackground();
  }

  /// Cancel all active tasks and clean up.
  ///
  /// Called on logout and account switch (via provider disposal). Resets
  /// the module-level [FileDownloader] config state so the next session
  /// re-runs full setup including orphan cleanup.
  void dispose() {
    // Clean up partial files for every active download.
    for (final info in _active.values) {
      _cleanupOutputDir(info.outputDir);
    }

    FileDownloader().cancelAll(group: group);
    FileDownloader().database.deleteAllRecords(group: group);
    unregisterTaskUpdateHandler(_taskPrefix);

    // Reset module-level state so the next BackgroundDownloadService
    // re-runs configure() from scratch.
    resetFileDownloaderState();

    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Service disposed'));
      }
    }

    _active.clear();
    _onComplete.clear();
    _onError.clear();
    _completers.clear();
    _progressCallbacks.clear();
    _fileIdToTransferId.clear();
    _cancelledFileIds.clear();
    _configuring = null;
  }

  // ── Internals ───────────────────────────────────────────────────────────

  void _enqueueTarDownload({
    required DownloadChunksCommand cmd,
    String? transferId,
    Future<void> Function()? onComplete,
    void Function(String error)? onError,
  }) {
    () async {
      try {
        // Ensure one-time setup (stream subscription, orphan cleanup) is
        // complete before enqueuing. Without this, a concurrent configure()
        // call could cancelAll() after we enqueue.
        await configure();

        final taskId = transferTaskId(
          prefix: group,
          accountId: accountId,
          fileId: cmd.fileId,
        );

        _active[cmd.fileId] = _FileDownloadInfo(
          fileId: cmd.fileId,
          fileSize: cmd.fileSize,
          totalChunks: cmd.totalChunks,
          outputDir: cmd.outputDir,
          taskId: taskId,
        );

        if (transferId != null) {
          _fileIdToTransferId[cmd.fileId] = transferId;
        }
        if (onComplete != null) _onComplete[cmd.fileId] = onComplete;
        if (onError != null) _onError[cmd.fileId] = onError;

        // Ensure output directory exists.
        await Directory(cmd.outputDir).create(recursive: true);

        // Single download task: tar of all chunks.
        final task = DownloadTask(
          taskId: taskId,
          url: '$baseUrl/api/storage/${cmd.fileId}?format=tar',
          headers: {
            'Authorization': 'Bearer ${cmd.transferToken}',
            'Known-Content-Length': '${cmd.fileSize}',
          },
          baseDirectory: BaseDirectory.root,
          directory: cmd.outputDir,
          filename: '${cmd.fileId}.tar',
          group: group,
          updates: Updates.statusAndProgress,
          retries: 3,
          allowPause: false,
        );

        final ok = await FileDownloader().enqueue(task);
        if (!ok) {
          _onFileError(cmd.fileId, 'Failed to enqueue tar download');
          return;
        }

        await task.filePath();
        _log.debug(
          'tar download enqueued',
          fields: {'file_id': cmd.fileId, 'size_kb': cmd.fileSize ~/ 1024},
        );
      } catch (e) {
        _onFileError(cmd.fileId, 'Failed to start tar download: $e');
      }
    }();
  }

  void _handleUpdate(TaskUpdate update) {
    if (update is TaskStatusUpdate) {
      final exception = update.exception;
      _log.debug(
        'status update',
        fields: {
          'status': update.status.toString(),
          'task_id': update.task.taskId,
          if (exception != null) 'exception': redactException(exception),
        },
      );
    }

    final fileId = _parseFileId(update.task.taskId);
    if (fileId == null) return;
    if (_cancelledFileIds.contains(fileId)) return;

    final info = _active[fileId];
    if (info == null) return;

    if (update is TaskProgressUpdate) {
      _handleProgress(fileId, info, update);
    } else if (update is TaskStatusUpdate) {
      _handleStatus(fileId, info, update);
    }
  }

  void _handleProgress(
    String fileId,
    _FileDownloadInfo info,
    TaskProgressUpdate update,
  ) {
    final progress = update.progress.clamp(0.0, 1.0);
    final bytesDownloaded = (progress * info.fileSize).round();

    _log.debug(
      'progress',
      fields: {
        'file_id': fileId,
        'percent': (progress * 100).toStringAsFixed(1),
        'bytes_downloaded': bytesDownloaded,
        'total_bytes': info.fileSize,
      },
    );

    _progressCallbacks[fileId]?.call(bytesDownloaded, info.fileSize);

    final transferId = _fileIdToTransferId[fileId];
    if (transferId != null) {
      _transferManager?.updateProgress(
        transferId,
        completedChunks: 0,
        transferredBytes: bytesDownloaded,
      );
    }
  }

  void _handleStatus(
    String fileId,
    _FileDownloadInfo info,
    TaskStatusUpdate update,
  ) {
    switch (update.status) {
      case TaskStatus.complete:
        _onTarDownloadComplete(fileId, info);

      case TaskStatus.failed || TaskStatus.notFound:
        final error =
            update.exception?.description ?? ambientL10n.serviceDownloadFailed;
        _onFileError(fileId, error);

      case TaskStatus.canceled:
        break;

      default:
        // enqueued, running, waitingToRetry, paused — no action needed.
        break;
    }
  }

  /// Tar download finished — extract chunks and fire completion.
  void _onTarDownloadComplete(String fileId, _FileDownloadInfo info) {
    () async {
      try {
        final tarPath = '${info.outputDir}/$fileId.tar';
        final tarFile = File(tarPath);
        final tarSize = await tarFile.length();

        _log.debug(
          'tar file received',
          fields: {
            'file_id': fileId,
            'tar_size': tarSize,
            'expected_size': info.fileSize,
            'total_chunks': info.totalChunks,
          },
        );

        // Sanity check: the tar should be at least as large as the file
        // data. A tiny tar for a large file means the download was
        // truncated or the server returned an error body.
        if (tarSize < info.fileSize * 0.9) {
          _onFileError(
            fileId,
            'Tar file too small: $tarSize bytes for a '
            '${info.fileSize} byte file — download likely truncated',
          );
          return;
        }

        final entriesExtracted = await extractTarFile(tarPath, info.outputDir);

        if (entriesExtracted != info.totalChunks) {
          _onFileError(
            fileId,
            'Expected ${info.totalChunks} chunks but extracted '
            '$entriesExtracted from tar',
          );
          return;
        }

        // Remove the tar file — only keep extracted chunks.
        try {
          await File(tarPath).delete();
        } catch (_) {}

        _log.info(
          'tar extracted',
          fields: {
            'file_id': fileId,
            'chunks': entriesExtracted,
            'tar_size': tarSize,
          },
        );

        final onComplete = _onComplete.remove(fileId);
        final completer = _completers.remove(fileId);
        _cleanup(fileId);

        await onComplete?.call();
        completer?.complete();
      } catch (e) {
        _onFileError(fileId, 'Tar extraction failed: $e');
      }
    }();
  }

  void _onFileError(String fileId, String error) {
    _log.warn(
      'download failed',
      fields: {'file_id': fileId, 'error_message': error},
    );

    // Cancel any in-flight task.
    final info = _active[fileId];
    if (info != null) {
      FileDownloader().cancelTaskWithId(info.taskId);
    }

    // Clean up any partial files in the output directory.
    if (info != null) {
      _cleanupOutputDir(info.outputDir);
    }

    final onError = _onError.remove(fileId);
    final completer = _completers.remove(fileId);
    final transferId = _fileIdToTransferId[fileId];

    _cleanup(fileId);

    if (transferId != null) {
      _transferManager?.failTransfer(transferId, error);
    }
    onError?.call(error);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception(error));
    }
  }

  /// Delete all files in the output directory on failure.
  void _cleanupOutputDir(String dirPath) {
    () async {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }();
  }

  void _cleanup(String fileId) {
    _active.remove(fileId);
    _onComplete.remove(fileId);
    _onError.remove(fileId);
    _progressCallbacks.remove(fileId);
    _fileIdToTransferId.remove(fileId);
    _cancelledFileIds.remove(fileId);
  }

  // ── Task ID helpers ─────────────────────────────────────────────────────

  /// Extract fileId from task ID format `tar:{fileId}`.
  static String? _parseFileId(String taskId) => fileIdFromTaskId(taskId);
}

/// Per-file download metadata.
class _FileDownloadInfo {
  final String fileId;
  final int fileSize;
  final int totalChunks;
  final String outputDir;
  final String taskId;

  _FileDownloadInfo({
    required this.fileId,
    required this.fileSize,
    required this.totalChunks,
    required this.outputDir,
    required this.taskId,
  });
}
