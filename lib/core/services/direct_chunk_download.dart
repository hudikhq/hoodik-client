import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import '../utils/logger.dart';
import 'background_tar_transfer.dart' show TransferFailure;
import 'file_downloader_config.dart';
import 'transfer_errors.dart';

const _log = Logger('DirectChunkDownload');

/// On-disk name of chunk [index] — the layout `decrypt_chunks_to_file` and
/// the offline cache both read.
String _chunkFileName(int index) => '${index.toString().padLeft(6, '0')}.enc';

/// The OS-native task that fetches one encrypted chunk straight from the
/// bucket.
///
/// A free function so a test can assert the wire shape without a platform
/// channel. The empty header map is the part that matters: a presigned URL
/// carries its own signature, and several S3 implementations reject a request
/// that also has an `Authorization` header. Nothing about the session may
/// travel to the bucket — no cookie, no bearer token, no refresh hint.
@visibleForTesting
DownloadTask directChunkTask({
  required String accountId,
  required String fileId,
  required int chunk,
  required String url,
  required String outputDir,
}) {
  return DownloadTask(
    taskId: transferTaskId(
      prefix: DirectChunkDownloadService.group,
      accountId: accountId,
      fileId: fileId,
      chunk: chunk,
    ),
    url: url,
    headers: const {},
    baseDirectory: BaseDirectory.root,
    directory: outputDir,
    filename: _chunkFileName(chunk),
    group: DirectChunkDownloadService.group,
    updates: Updates.statusAndProgress,
    retries: 3,
    allowPause: false,
  );
}

/// Downloads a file's encrypted chunks straight from object storage, one
/// `background_downloader` task per chunk.
///
/// This is what lets a direct transfer outlive the app. On iOS and Android the
/// chunks are handed to URLSession and WorkManager, which keep moving bytes
/// with no Dart isolate alive; on desktop the plugin runs them in its own
/// isolates, so they survive backgrounding but not a quit, and the records it
/// keeps on disk are what [FileDownloader.rescheduleKilledTasks] resumes from
/// at the next launch. The in-process Rust downloader offers neither — it
/// dies with the process leaving nothing behind — which is why the direct
/// path routes here instead.
///
/// Deliberately takes no base URL and no cookie. The presigned URL is the
/// entire credential, and a leg with no session material in scope cannot leak
/// any — the same property `ChunkTarget::Direct` has on the Rust side.
class DirectChunkDownloadService {
  static const String group = 'direct-chunks';
  static const String _taskPrefix = '$group|';

  final Map<String, _FileDownload> _active = {};

  Future<void>? _configuring;

  Future<void> _configure() => _configuring ??= _doConfigure();

  Future<void> _doConfigure() async {
    await ensureFileDownloaderConfigured();
    registerTaskUpdateHandler(_taskPrefix, _handleUpdate);
  }

  /// Fetch every chunk of [fileId] into [outputDir], completing once all of
  /// them are on disk. Throws if any chunk fails or the transfer is cancelled.
  ///
  /// [urls] is indexed by chunk number and must cover the whole file — the
  /// caller checks that before routing here. Chunks already on disk are
  /// skipped, which is what makes a relaunch resume instead of restart.
  Future<void> download({
    required String accountId,
    required String fileId,
    required List<String> urls,
    required String outputDir,
    required int fileSize,
    required List<int> alreadyDownloaded,
    void Function(int completedChunks, int transferredBytes)? onProgress,
  }) async {
    // Already downloading. Wait on the driver that is running rather than
    // registering a second one: the map holds one state per file, so the
    // overwrite orphaned the first caller's completer and its future never
    // finished — hanging whatever was waiting on it, the sequential resume
    // loop included, for the rest of the session.
    final running = _active[fileId];
    if (running != null) return running.completer.future;

    final state = _FileDownload(
      accountId: accountId,
      completer: Completer<void>(),
      progress: ChunkProgress(
        chunkCount: urls.length,
        fileSize: fileSize,
        completed: {},
        onProgress: onProgress,
      ),
    );

    // Registered synchronously, in the same turn as the check above — an
    // await in between would open a window where two drivers both pass the
    // null check and the second overwrite orphans the first completer, the
    // exact hang the guard exists to prevent. Registering before disk is
    // read also matters on its own: a task the OS is still carrying can land
    // in between, and an update with nowhere to go is a chunk this transfer
    // would then wait for forever.
    _active[fileId] = state;

    try {
      await _configure();

      final dir = Directory(outputDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      // Disk decides what is missing, not the caller's list. The offline
      // cache only learns about a file once every chunk has landed, so a
      // download picked back up after a kill has chunks on disk that no
      // bookkeeping knows about yet — and refetching those is the one cost
      // this feature exists to avoid.
      final present = await chunksOnDisk(dir, urls.length);
      present.addAll(alreadyDownloaded.where((i) => i >= 0 && i < urls.length));
      state.progress.completed.addAll(present);
      state.progress.report();

      if (state.progress.isDone) {
        // Joiners picked up during the awaits above hold this completer, so
        // it has to resolve — a bare return would leave them waiting on a
        // download that already happened.
        _active.remove(fileId);
        if (!state.completer.isCompleted) state.completer.complete();
        return state.completer.future;
      }

      final live = await tasksInFlight(group);
      var adopted = 0;

      for (var i = 0; i < urls.length; i++) {
        if (state.progress.completed.contains(i)) continue;
        // Cancellation and enqueue failures both drop the entry; stop pushing
        // tasks nobody is waiting for.
        if (_active[fileId] != state) break;

        final task = directChunkTask(
          accountId: accountId,
          fileId: fileId,
          chunk: i,
          url: urls[i],
          outputDir: outputDir,
        );

        // Already moving. Its updates reach the state registered above, so
        // the bar covers it without a second task fighting it for the same
        // file.
        if (live.contains(task.taskId)) {
          adopted++;
          continue;
        }

        if (!await FileDownloader().enqueue(task)) {
          _stop(fileId, Exception('Failed to enqueue chunk $i of $fileId'));
          break;
        }
      }

      _log.debug(
        'direct chunks enqueued',
        fields: {
          'file_id': fileId,
          'chunks': urls.length,
          'skipped': present.length,
          'adopted': adopted,
        },
      );
    } catch (e) {
      _stop(fileId, e);
      rethrow;
    }

    return state.completer.future;
  }

  /// Cancel every outstanding chunk task for [fileId] and fail its future.
  /// Safe to call for a file that is not downloading.
  void cancel(String fileId) {
    // The typed exception is load-bearing: the pipeline's cancel handler
    // clears the pending-download row only for this type, and the runner's
    // manifest-refresh retry rethrows it instead of restarting the transfer
    // the user just stopped. A plain Exception here once did both — the
    // cancel restarted the download and the row resurrected it at next
    // launch.
    _stop(fileId, TransferCancelledException(fileId));
  }

  /// Register a download as running without touching the OS queue, so a test
  /// can drive the "already downloading" path without a platform channel.
  @visibleForTesting
  Future<void> seedInFlight(String fileId, {int chunkCount = 2}) {
    final completer = Completer<void>();
    _active[fileId] = _FileDownload(
      accountId: 'test',
      completer: completer,
      progress: ChunkProgress(
        chunkCount: chunkCount,
        fileSize: chunkCount * 1024,
        completed: {},
      ),
    );
    return completer.future;
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
        // Decrypt only ever runs behind a full set of chunks; a file is done
        // when every index has landed, not when the last task reports.
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
          'direct chunk download failed',
          fields: {...failure.asLogFields(taskId), 'chunk': chunk},
        );
        _stop(fileId, Exception(failure.message));

      case TaskStatus.canceled:
        // A cancel this service issued removes the state first, so its own
        // updates never reach here. One that does belongs to a task someone
        // else cancelled — a stale cancel racing a restarted download, the
        // OS reclaiming the queue — and swallowing it would leave the state
        // active and the completer waiting on a chunk that is never coming.
        _stop(fileId, TransferCancelledException(fileId));

      default:
        break;
    }
  }

  /// Drop [fileId]'s transfer: cancel the chunks still outstanding, then fail
  /// the awaited future. Used for both cancellation and chunk failure — the
  /// remaining tasks are worthless either way, and leaving a few hundred of
  /// them queued in the OS is not.
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

/// Chunk indices already sitting in [dir].
///
/// Disk is the source of truth for what a resumed transfer still needs. The
/// offline cache only records a file once every chunk has landed, so mid-flight
/// it knows nothing, and `background_downloader` moves each chunk into place
/// only after it completes — a name here means those bytes are done.
Future<Set<int>> chunksOnDisk(Directory dir, int chunkCount) async {
  final present = <int>{};
  // The tar leg only creates the chunk directory at unpack time, so a
  // transfer killed mid-fetch legitimately has no directory yet. That is
  // zero chunks on disk, not an error — throwing here made every resume of
  // such a row fail forever.
  if (!await dir.exists()) return present;
  await for (final entity in dir.list()) {
    if (entity is! File || !entity.path.endsWith('.enc')) continue;
    final index = int.tryParse(p.basenameWithoutExtension(entity.path));
    if (index != null && index >= 0 && index < chunkCount) present.add(index);
  }
  return present;
}

class _FileDownload {
  final String accountId;
  final Completer<void> completer;
  final ChunkProgress progress;

  _FileDownload({
    required this.accountId,
    required this.completer,
    required this.progress,
  });
}

/// How much of a file has arrived, across the many tasks carrying it.
///
/// One transfer used to be one task and one bar; a direct transfer is one bar
/// over hundreds of tasks, so the arithmetic that used to be implicit lives
/// here. Holds no plugin state, which also makes it the piece worth testing
/// directly: it decides both what the user sees and when decrypt is allowed
/// to start.
class ChunkProgress {
  final int chunkCount;
  final int fileSize;

  /// Indices already on disk, including the ones a previous session left.
  final Set<int> completed;

  final void Function(int completedChunks, int transferredBytes)? onProgress;

  /// Progress of the chunks currently in flight, so the bar moves between
  /// completions instead of stepping once per 4 MB.
  final Map<int, double> _fractions = {};

  ChunkProgress({
    required this.chunkCount,
    required this.fileSize,
    required this.completed,
    this.onProgress,
  });

  /// True only once every index has landed. Nothing downstream may run before
  /// then — a decrypt over a partial set produces a corrupt file, not an error.
  bool get isDone => completed.length >= chunkCount;

  /// Indices still missing, in order.
  Iterable<int> get outstanding sync* {
    for (var i = 0; i < chunkCount; i++) {
      if (!completed.contains(i)) yield i;
    }
  }

  void advance(int chunk, double fraction) {
    if (completed.contains(chunk)) return;
    _fractions[chunk] = fraction.clamp(0.0, 1.0);
    report();
  }

  void complete(int chunk) {
    _fractions.remove(chunk);
    completed.add(chunk);
    report();
  }

  void report() {
    final callback = onProgress;
    if (callback == null || chunkCount == 0) return;
    final perChunk = fileSize / chunkCount;
    final bytes =
        completed.length * perChunk +
        _fractions.values.fold(0.0, (sum, f) => sum + f * perChunk);
    callback(completed.length, bytes.round().clamp(0, fileSize));
  }
}
