import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import '../utils/l10n_lookup.dart';
import '../utils/logger.dart';
import 'background_tar_transfer.dart' show TransferFailure;
import 'direct_chunk_download.dart' show ChunkProgress;
import 'file_downloader_config.dart';

const _log = Logger('DirectChunkUpload');

/// The OS-native task that writes one encrypted chunk straight into the
/// bucket.
///
/// A free function so a test can assert the wire shape without a platform
/// channel. As on the read side, the header map is the part that matters: the
/// presigned URL carries its own signature over the method, key and content
/// length, and adding an `Authorization` header alongside it is refused by
/// several S3 implementations. Nothing about the session may reach the bucket.
@visibleForTesting
UploadTask directChunkUploadTask({
  required String accountId,
  required String fileId,
  required int chunk,
  required String url,
  required String stagingDir,
}) {
  return UploadTask(
    taskId: transferTaskId(
      prefix: DirectChunkUploadService.group,
      accountId: accountId,
      fileId: fileId,
      chunk: chunk,
    ),
    url: url,
    httpRequestMethod: 'PUT',
    post: 'binary',
    headers: const {},
    baseDirectory: BaseDirectory.root,
    directory: stagingDir,
    filename: '${chunk.toString().padLeft(6, '0')}.enc',
    mimeType: 'application/octet-stream',
    group: DirectChunkUploadService.group,
    updates: Updates.statusAndProgress,
    retries: 3,
  );
}

/// Writes a file's encrypted chunks straight into object storage, one
/// `background_downloader` task per chunk.
///
/// The mirror of [DirectChunkDownloadService], and it exists for the same
/// reason: the OS keeps these running while the app is suspended, and on iOS
/// and Android they are handed to URLSession and WorkManager, which outlive
/// the process. It also skips the tenant's own instance entirely, which is the
/// metered hop this whole path exists to avoid.
///
/// Takes no base URL and no cookie. The presigned URL is the whole credential.
class DirectChunkUploadService {
  static const String group = 'direct-chunk-uploads';
  static const String _taskPrefix = '$group|';

  final Map<String, _FileUpload> _active = {};

  Future<void>? _configuring;

  Future<void> _configure() => _configuring ??= _doConfigure();

  Future<void> _doConfigure() async {
    await ensureFileDownloaderConfigured();
    registerTaskUpdateHandler(_taskPrefix, _handleUpdate);
  }

  /// Push every chunk in [urls] from [stagingDir] into the bucket, completing
  /// once all of them have landed. Throws if any chunk fails or the transfer
  /// is cancelled.
  ///
  /// [urls] is indexed by chunk number and must cover every chunk being
  /// written; the caller checks that before routing here. Nothing is skipped:
  /// unlike a download, the caller cannot tell from disk what the bucket
  /// already holds, and a repeated PUT of the same key is harmless.
  Future<void> upload({
    required String accountId,
    required String fileId,
    required List<String> urls,
    required String stagingDir,
    required int fileSize,
    void Function(int completedChunks, int transferredBytes)? onProgress,
  }) async {
    await _configure();

    final state = _FileUpload(
      accountId: accountId,
      completer: Completer<void>(),
      progress: ChunkProgress(
        chunkCount: urls.length,
        fileSize: fileSize,
        completed: <int>{},
        onProgress: onProgress,
      ),
    );
    _active[fileId] = state;

    for (var i = 0; i < urls.length; i++) {
      if (urls[i].isEmpty) continue;
      // Cancellation and enqueue failures both drop the entry; stop pushing
      // tasks nobody is waiting for.
      if (_active[fileId] != state) break;

      final ok = await FileDownloader().enqueue(
        directChunkUploadTask(
          accountId: accountId,
          fileId: fileId,
          chunk: i,
          url: urls[i],
          stagingDir: stagingDir,
        ),
      );
      if (!ok) {
        _stop(fileId, Exception('Failed to enqueue chunk $i of $fileId'));
        break;
      }
    }

    _log.debug(
      'direct chunk uploads enqueued',
      fields: {'file_id': fileId, 'chunks': urls.length},
    );

    return state.completer.future;
  }

  /// Cancel every outstanding chunk task for [fileId] and fail its future.
  /// Safe to call for a file that is not uploading.
  void cancel(String fileId) {
    _stop(fileId, Exception(ambientL10n.serviceUploadCancelled));
  }

  /// Cancel everything this service owns and release its update handler.
  Future<void> dispose() async {
    for (final fileId in _active.keys.toList()) {
      _stop(fileId, Exception('Service disposed'));
    }
    await FileDownloader().cancelAll(group: group);
    await FileDownloader().database.deleteAllRecords(group: group);
    unregisterTaskUpdateHandler(_taskPrefix);
    _configuring = null;
  }

  void _handleUpdate(TaskUpdate update) {
    final taskId = update.task.taskId;
    final fileId = fileIdFromTaskId(taskId);
    final chunk = chunkFromTaskId(taskId);
    if (fileId == null || chunk == null) return;

    final state = _active[fileId];
    if (state == null) return;

    if (update is TaskProgressUpdate) {
      state.progress.advance(chunk, update.progress);
      return;
    }
    if (update is! TaskStatusUpdate) return;

    switch (update.status) {
      case TaskStatus.complete:
        state.progress.complete(chunk);
        // The server is told the upload is done only once every chunk is in
        // the bucket, and it re-checks by listing before it commits anything.
        if (state.progress.isDone) {
          _active.remove(fileId);
          unawaited(
            forgetTaskRecords(
              group: group,
              accountId: state.accountId,
              fileId: fileId,
              chunkCount: state.progress.chunkCount,
            ),
          );
          if (!state.completer.isCompleted) state.completer.complete();
        }

      case TaskStatus.failed || TaskStatus.notFound:
        final failure = TransferFailure.fromTaskStatusUpdate(update);
        _log.warn(
          'direct chunk upload failed',
          fields: {...failure.asLogFields(taskId), 'chunk': chunk},
        );
        _stop(fileId, Exception(failure.message));

      case TaskStatus.canceled:
        break;

      default:
        break;
    }
  }

  void _stop(String fileId, Object error) {
    final state = _active.remove(fileId);
    if (state == null) return;

    final outstanding = [
      for (final chunk in state.progress.outstanding)
        transferTaskId(
          prefix: group,
          accountId: state.accountId,
          fileId: fileId,
          chunk: chunk,
        ),
    ];
    if (outstanding.isNotEmpty) {
      unawaited(
        FileDownloader()
            .cancelTasksWithIds(outstanding)
            .then(
              (_) => forgetTaskRecords(
                group: group,
                accountId: state.accountId,
                fileId: fileId,
                chunkCount: state.progress.chunkCount,
              ),
            ),
      );
    }

    if (!state.completer.isCompleted) state.completer.completeError(error);
  }
}

/// Ciphertext sizes of the staged chunks, keyed by chunk index.
///
/// The server signs each declared length into its URL, so these have to be the
/// exact on-disk sizes rather than the plaintext chunk size: every chunk
/// carries its AEAD tag on top of the payload.
Future<Map<int, int>> stagedChunkSizes(
  String stagingDir,
  int chunkCount,
) async {
  final sizes = <int, int>{};
  for (var chunk = 0; chunk < chunkCount; chunk++) {
    final file = File(
      p.join(stagingDir, '${chunk.toString().padLeft(6, '0')}.enc'),
    );
    if (await file.exists()) sizes[chunk] = await file.length();
  }
  return sizes;
}

class _FileUpload {
  final String accountId;
  final Completer<void> completer;
  final ChunkProgress progress;

  _FileUpload({
    required this.accountId,
    required this.completer,
    required this.progress,
  });
}
