import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/l10n_lookup.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('FileDownloaderConfig');

Future<void>? _configuring;
Future<void>? _startupCleanup;
StreamSubscription<TaskUpdate>? _sharedSub;

/// Registered update handlers keyed by task-ID prefix.
///
/// `FileDownloader().updates` is a single-subscription stream — only one
/// `.listen()` call is allowed. We subscribe once and dispatch each update
/// to every registered handler whose prefix matches the task ID.
final Map<String, void Function(TaskUpdate)> _handlers = {};

/// Register a handler for all task updates whose task ID starts with
/// [prefix]. Call this instead of `FileDownloader().updates.listen()`.
void registerTaskUpdateHandler(
  String prefix,
  void Function(TaskUpdate) handler,
) {
  _handlers[prefix] = handler;
  _ensureListening();
}

/// Remove a previously registered handler.
void unregisterTaskUpdateHandler(String prefix) {
  _handlers.remove(prefix);
}

/// Shared one-time configuration for the [FileDownloader] singleton.
///
/// Both [BackgroundDownloadService] and [BackgroundUploadService] call this
/// before enqueuing tasks. Returns the same future on repeated calls so
/// the setup runs exactly once.
Future<void> ensureFileDownloaderConfigured() {
  return _configuring ??= _doConfigure();
}

/// Cancel every task the app owns and purge the [FileDownloader] database.
///
/// Correct on account switch and on logout, where nothing in flight belongs to
/// the session that comes next.
///
/// Not on cold start. The OS keeps transfers running across a kill, and
/// throwing them away at launch means a large download can never survive being
/// backgrounded out of memory — it starts over every time. Cold start goes
/// through [adoptTransfersForAccount] instead, which keeps this account's work
/// and cancels only what belongs elsewhere.
Future<void> cleanUpFileDownloader() {
  return _startupCleanup ??= _doCleanUp();
}

Future<void> _doCleanUp() async {
  for (final group in _managedGroups) {
    await FileDownloader().cancelAll(group: group);
    await FileDownloader().database.deleteAllRecords(group: group);
  }
}

/// Keep the transfers belonging to [accountId] and cancel the rest.
///
/// The OS transfer queue is process-wide and outlives any single session, so a
/// cold start can be holding work from whichever account was last signed in.
/// Task ids carry their owner (see [transferTaskId]), which is what makes them
/// separable without asking the server anything.
///
/// Returns the file ids this account still has in flight, so the caller can
/// avoid re-queuing what the OS is already carrying.
Future<Set<String>> adoptTransfersForAccount(String accountId) async {
  await ensureFileDownloaderConfigured();

  final mine = <String>{};
  final foreign = <String>[];

  for (final group in _managedGroups) {
    for (final record in await FileDownloader().database.allRecords(
      group: group,
    )) {
      final owner = accountIdFromTaskId(record.task.taskId);
      if (owner == accountId) {
        final fileId = fileIdFromTaskId(record.task.taskId);
        if (fileId != null) mine.add(fileId);
      } else {
        foreign.add(record.task.taskId);
      }
    }
  }

  if (foreign.isNotEmpty) {
    await FileDownloader().cancelTasksWithIds(foreign);
    for (final id in foreign) {
      await FileDownloader().database.deleteRecordWithId(id);
    }
  }

  return mine;
}

/// Task id encoding: `{group-prefix}:{accountId}:{fileId}[:{chunk}]`.
///
/// The owner has to travel with the task because the OS hands these back after
/// a restart with no context beyond the id itself.
String transferTaskId({
  required String prefix,
  required String accountId,
  required String fileId,
  int? chunk,
}) {
  final base = '$prefix:$accountId:$fileId';
  return chunk == null ? base : '$base:$chunk';
}

String? accountIdFromTaskId(String taskId) {
  final parts = taskId.split(':');
  return parts.length >= 3 ? parts[1] : null;
}

String? fileIdFromTaskId(String taskId) {
  final parts = taskId.split(':');
  return parts.length >= 3 ? parts[2] : null;
}

/// Groups the app owns. Any new `background_downloader` task must register
/// its group here so cleanup and notification wiring cover it.
const List<String> _managedGroups = [
  'chunk-downloads',
  'chunk-uploads',
  'tar-downloads',
  'tar-uploads',
];

/// Reset module-level state so the next [ensureFileDownloaderConfigured]
/// re-runs full setup. Call on account switch / logout so the new session
/// starts clean.
void resetFileDownloaderState() {
  _configuring = null;
  _startupCleanup = null;
}

void _ensureListening() {
  if (_sharedSub != null) return;
  _sharedSub = FileDownloader().updates.listen(
    _dispatch,
    onError: (e) {
      _log.warn(
        'file downloader stream error',
        fields: {'error': describeError(e)},
      );
    },
  );
}

void _dispatch(TaskUpdate update) {
  final taskId = update.task.taskId;
  for (final entry in _handlers.entries) {
    if (taskId.startsWith(entry.key)) {
      entry.value(update);
      return;
    }
  }
}

/// Concurrent transfers permitted per group.
///
/// Direct downloads hand the OS one task per chunk, so this decides how much
/// of a file is in flight at once. It is a knob rather than a constant because
/// how a real device copes with a few thousand queued background tasks is not
/// something the simulator can answer — that comes back from TestFlight and
/// Play internal testing, and a bad answer should be a value change here
/// rather than a redesign.
///
/// Raising it does not make transfers unbounded: URLSession and WorkManager
/// impose their own ceilings underneath.
const int kMaxConcurrentTransfersPerGroup = 6;

Future<void> _doConfigure() async {
  final configs = <(String, dynamic)>[
    // (maxConcurrent, maxConcurrentByHost, maxConcurrentByGroup)
    //
    // Anything held back here lives in the plugin's own queue, which the OS
    // does keep running while the app is suspended but which dies with the
    // process if the app is killed — unlike tasks already handed to
    // URLSession or WorkManager, which survive. So this cap is also the line
    // between "resumes by itself" and "needs re-queuing on next launch".
    (
      Config.holdingQueue,
      (null, null, kMaxConcurrentTransfersPerGroup),
    ),
  ];

  if (Platform.isAndroid) {
    configs.add((Config.runInForeground, Config.always));
  }

  await FileDownloader().configure(globalConfig: configs);

  if (Platform.isAndroid) {
    // Android 13+ requires runtime permission for notifications.
    await Permission.notification.request();

    for (final group in const ['chunk-downloads', 'tar-downloads']) {
      FileDownloader().configureNotificationForGroup(
        group,
        running: TaskNotification(
          ambientL10n.serviceTransferDownloading,
          '{progress} — {networkSpeed}',
        ),
        complete: TaskNotification(
          ambientL10n.serviceNotificationDownloadComplete,
          ambientL10n.serviceNotificationReady,
        ),
        progressBar: true,
      );
    }
    for (final group in const ['chunk-uploads', 'tar-uploads']) {
      FileDownloader().configureNotificationForGroup(
        group,
        running: TaskNotification(
          ambientL10n.serviceTransferUploading,
          '{progress}',
        ),
        complete: TaskNotification(
          ambientL10n.serviceNotificationUploadComplete,
          ambientL10n.serviceNotificationReady,
        ),
        progressBar: true,
      );
    }
  }

  // Cancel orphaned tasks and purge stale database records left over from
  // a previous app session (or account switch).
  await cleanUpFileDownloader();
}
