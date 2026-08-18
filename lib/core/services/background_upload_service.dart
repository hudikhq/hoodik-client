import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import '../utils/l10n_lookup.dart';
import '../utils/logger.dart';
import '../workers/worker_messages.dart';
import 'file_downloader_config.dart';
import 'transfer_manager.dart';

const _log = Logger('BackgroundUploadService');

/// Uploads pre-encrypted `.enc` chunks via the OS-native background transfer
/// system (`background_downloader`).
///
/// Each chunk is dispatched as a separate [UploadTask] with `post: 'binary'`.
/// The holding queue limits concurrency to 6 per group so only 6 chunks fly
/// at once — the rest wait automatically. On iOS this uses URLSession, on
/// Android WorkManager, so uploads survive app suspension.
class BackgroundUploadService {
  static const String group = 'chunk-uploads';
  static const String _taskPrefix = '$group|';

  final String baseUrl;

  /// Owner stamped into every task id. The OS hands tasks back after a
  /// restart with nothing but the id to go on, so a task that does not carry
  /// its account cannot be told from another account's leftovers — see
  /// [transferTaskId].
  final String accountId;

  /// Per-file upload state keyed by file ID.
  final Map<String, _FileUploadInfo> _active = {};

  /// Completers resolved when all chunks for a file finish (or fail).
  final Map<String, Completer<void>> _completers = {};

  /// Maps fileId → transferId for pushing progress to [TransferManager].
  final Map<String, String> _fileIdToTransferId = {};

  /// File IDs whose upload has been cancelled.
  final Set<String> _cancelledFileIds = {};

  TransferManager? _transferManager;

  BackgroundUploadService({required this.baseUrl, required this.accountId});

  void setTransferManager(TransferManager tm) {
    _transferManager = tm;
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Upload all encrypted chunks for a file. Returns when every chunk has
  /// been uploaded (or throws on failure).
  Future<void> uploadChunks({
    required UploadChunksCommand cmd,
    String? transferId,
  }) async {
    final completer = Completer<void>();
    _completers[cmd.fileId] = completer;
    if (transferId != null) {
      _fileIdToTransferId[cmd.fileId] = transferId;
    }
    _enqueueChunkUploads(cmd: cmd);
    return completer.future;
  }

  /// Cancel an in-progress upload. All pending/active tasks for the file
  /// are cancelled and the completer completes with an error.
  void cancelUpload(String fileId) {
    _cancelledFileIds.add(fileId);

    final info = _active[fileId];
    if (info != null) {
      for (var i = 0; i < info.totalChunks; i++) {
        FileDownloader().cancelTaskWithId(_taskId(fileId, i));
      }
    }

    final completer = _completers.remove(fileId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception(ambientL10n.serviceUploadCancelled));
    }

    _cleanup(fileId);
  }

  /// Replay buffered OS events after app resumes from background.
  Future<void> resumeFromBackground() async {
    await FileDownloader().resumeFromBackground();
  }

  void dispose() {
    FileDownloader().cancelAll(group: group);
    FileDownloader().database.deleteAllRecords(group: group);
    unregisterTaskUpdateHandler(_taskPrefix);

    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Service disposed'));
      }
    }

    _active.clear();
    _completers.clear();
    _fileIdToTransferId.clear();
    _cancelledFileIds.clear();
  }

  // ── Internals ───────────────────────────────────────────────────────────

  void _enqueueChunkUploads({required UploadChunksCommand cmd}) {
    () async {
      try {
        await ensureFileDownloaderConfigured();
        registerTaskUpdateHandler(_taskPrefix, _handleUpdate);

        final info = _FileUploadInfo(
          fileId: cmd.fileId,
          totalChunks: cmd.totalChunks,
          fileSize: cmd.fileSize,
          chunksDir: cmd.chunksDir,
        );
        _active[cmd.fileId] = info;

        for (var i = 0; i < cmd.totalChunks; i++) {
          if (_cancelledFileIds.contains(cmd.fileId)) break;

          final checksum = cmd.checksums[i] ?? '';
          final chunkFilename = '${i.toString().padLeft(6, '0')}.enc';

          final task = UploadTask(
            taskId: _taskId(cmd.fileId, i),
            post: 'binary',
            url: '$baseUrl/api/storage/${cmd.fileId}',
            urlQueryParameters: {
              'chunk': '$i',
              'checksum': checksum,
              'checksum_function': 'crc16',
            },
            filename: chunkFilename,
            directory: cmd.chunksDir,
            baseDirectory: BaseDirectory.root,
            headers: {'Authorization': 'Bearer ${cmd.transferToken}'},
            mimeType: 'application/octet-stream',
            group: group,
            updates: Updates.statusAndProgress,
            retries: 3,
          );

          final ok = await FileDownloader().enqueue(task);
          if (!ok) {
            _onFileError(cmd.fileId, 'Failed to enqueue chunk $i');
            return;
          }
        }

        _log.debug(
          'chunks enqueued',
          fields: {
            'file_id': cmd.fileId,
            'chunks': cmd.totalChunks,
            'size_kb': cmd.fileSize ~/ 1024,
          },
        );
      } catch (e) {
        _onFileError(cmd.fileId, 'Failed to start upload: $e');
      }
    }();
  }

  void _handleUpdate(TaskUpdate update) {
    final parsed = _parseTaskId(update.task.taskId);
    if (parsed == null) return;
    final (fileId, chunkIndex) = parsed;

    if (_cancelledFileIds.contains(fileId)) return;

    final info = _active[fileId];
    if (info == null) return;

    if (update is TaskProgressUpdate) {
      _handleProgress(fileId, chunkIndex, info, update);
    } else if (update is TaskStatusUpdate) {
      _handleStatus(fileId, chunkIndex, info, update);
    }
  }

  void _handleProgress(
    String fileId,
    int chunkIndex,
    _FileUploadInfo info,
    TaskProgressUpdate update,
  ) {
    final progress = update.progress.clamp(0.0, 1.0);
    info.inProgressFractions[chunkIndex] = progress;

    final transferId = _fileIdToTransferId[fileId];
    if (transferId != null) {
      _transferManager?.updateProgress(
        transferId,
        completedChunks: info.completedChunks.length,
        transferredBytes: info.transferredBytes,
      );
    }
  }

  void _handleStatus(
    String fileId,
    int chunkIndex,
    _FileUploadInfo info,
    TaskStatusUpdate update,
  ) {
    switch (update.status) {
      case TaskStatus.complete:
        _onChunkComplete(fileId, chunkIndex, info);

      case TaskStatus.failed || TaskStatus.notFound:
        // The server returns 422 when a chunk was already uploaded.
        // background_downloader treats non-2xx as failure, but for us
        // this is an idempotent success.
        if (update.responseStatusCode == 422) {
          _log.debug(
            'chunk already exists — treating as success',
            fields: {'file_id': fileId, 'chunk': chunkIndex},
          );
          _onChunkComplete(fileId, chunkIndex, info);
          return;
        }

        final error =
            update.exception?.description ?? ambientL10n.serviceUploadFailed;
        _log.warn(
          'chunk upload failed',
          fields: {
            'file_id': fileId,
            'chunk': chunkIndex,
            'status': update.responseStatusCode,
          },
        );
        _onFileError(fileId, 'Chunk $chunkIndex failed: $error');

      case TaskStatus.canceled:
        break;

      default:
        break;
    }
  }

  void _onChunkComplete(String fileId, int chunkIndex, _FileUploadInfo info) {
    info.completedChunks.add(chunkIndex);
    info.inProgressFractions.remove(chunkIndex);

    final transferId = _fileIdToTransferId[fileId];
    if (transferId != null) {
      _transferManager?.updateProgress(
        transferId,
        completedChunks: info.completedChunks.length,
        transferredBytes: info.transferredBytes,
      );
    }

    if (info.completedChunks.length == info.totalChunks) {
      _log.info(
        'all chunks uploaded',
        fields: {'file_id': fileId, 'chunks': info.totalChunks},
      );

      final completer = _completers.remove(fileId);
      _cleanup(fileId);
      completer?.complete();
    }
  }

  void _onFileError(String fileId, String error) {
    _log.warn(
      'upload failed',
      fields: {'file_id': fileId, 'error_message': error},
    );

    // Cancel all remaining chunk tasks for this file.
    final info = _active[fileId];
    if (info != null) {
      for (var i = 0; i < info.totalChunks; i++) {
        FileDownloader().cancelTaskWithId(_taskId(fileId, i));
      }
    }

    final transferId = _fileIdToTransferId[fileId];
    final completer = _completers.remove(fileId);
    _cleanup(fileId);

    if (transferId != null) {
      _transferManager?.failTransfer(transferId, error);
    }
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception(error));
    }
  }

  void _cleanup(String fileId) {
    _active.remove(fileId);
    _fileIdToTransferId.remove(fileId);
    _cancelledFileIds.remove(fileId);
  }

  // ── Task ID helpers ─────────────────────────────────────────────────────

  String _taskId(String fileId, int chunkIndex) => transferTaskId(
    prefix: group,
    accountId: accountId,
    fileId: fileId,
    chunk: chunkIndex,
  );

  /// Parse task ID back to (fileId, chunkIndex). Returns null for
  /// task IDs that don't belong to this service.
  static (String, int)? _parseTaskId(String taskId) {
    final fileId = fileIdFromTaskId(taskId);
    final chunkIndex = chunkFromTaskId(taskId);
    if (fileId == null || chunkIndex == null) return null;
    return (fileId, chunkIndex);
  }
}

/// Per-file upload tracking.
class _FileUploadInfo {
  final String fileId;
  final int totalChunks;
  final int fileSize;
  final String chunksDir;

  /// Chunk indices that have been successfully uploaded.
  final Set<int> completedChunks = {};

  /// Per-chunk upload progress (0.0–1.0) for in-flight chunks.
  final Map<int, double> inProgressFractions = {};

  _FileUploadInfo({
    required this.fileId,
    required this.totalChunks,
    required this.fileSize,
    required this.chunksDir,
  });

  /// Estimated bytes uploaded so far, combining completed chunks and
  /// partial progress of in-flight chunks.
  int get transferredBytes {
    if (fileSize <= 0 || totalChunks <= 0) return 0;
    final bytesPerChunk = fileSize / totalChunks;
    final completedBytes = completedChunks.length * bytesPerChunk;
    final inProgressBytes = inProgressFractions.values.fold(
      0.0,
      (sum, frac) => sum + frac * bytesPerChunk,
    );
    return (completedBytes + inProgressBytes).round();
  }
}
