import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/database.dart';
import '../storage/pending_downloads_dao.dart';
import '../utils/l10n_lookup.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('FileDownloaderConfig');

Future<void>? _configuring;
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
/// Call this on logout, where nothing in flight belongs to the session that
/// comes next.
///
/// Never on cold start, and never from [ensureFileDownloaderConfigured] — the
/// OS keeps transfers running across a kill, and throwing them away the first
/// time anything touches the downloader means a large download can never
/// survive being backgrounded out of memory. It starts over every launch
/// instead. Cold start goes through [adoptTransfersForAccount], which keeps
/// this account's work and cancels only what belongs elsewhere; an account
/// switch goes through the same path, so the incoming account's own transfers
/// survive it.
Future<void> cleanUpFileDownloader() async {
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

  // Replay whatever the OS buffered while the app was gone, so the sweep
  // below sees finished tasks as finished rather than as still in flight.
  await FileDownloader().resumeFromBackground();

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
      } else if (owner != null) {
        foreign.add(record.task.taskId);
      }
      // An id with no owner in it was written by a version of the app that
      // predates this encoding, and survives an upgrade in the OS queue. It
      // cannot be attributed, so it is left running rather than cancelled:
      // guessing wrong kills a transfer the user is watching, and everything
      // these tasks write is ciphertext under their own account's directory
      // either way. Nothing the app creates now lands here.
    }
  }

  if (foreign.isNotEmpty) {
    await FileDownloader().cancelTasksWithIds(foreign);
    for (final id in foreign) {
      await FileDownloader().database.deleteRecordWithId(id);
    }
  }

  // Tasks the OS never took, or dropped when the process died — anything
  // recorded as still running but absent from the native queue. Chunks held
  // back by [kMaxConcurrentTransfersPerGroup] land here after a kill, which is
  // most of a large file. Re-enqueued from the record, so the presigned URL
  // rides along and no manifest has to be fetched to resume.
  //
  // Runs after the sweep above so a foreign account's work is cancelled rather
  // than rescheduled.
  final (rescheduled, failed) = await FileDownloader().rescheduleKilledTasks();
  if (rescheduled.isNotEmpty || failed.isNotEmpty) {
    _log.info(
      'transfers re-queued after an interrupted session',
      fields: {'rescheduled': rescheduled.length, 'failed': failed.length},
    );
  }

  return mine;
}

/// Settle the OS transfer queue against the account that just signed in.
///
/// The queue outlives the process, so at sign-in it may be carrying work for
/// whoever was signed in last. This account's transfers keep running,
/// everyone else's are cancelled, and the bookkeeping rows are pruned in the
/// same pass so the two cannot disagree about what is still expected to
/// finish.
Future<void> reconcileTransfersForAccount({
  required AppDatabase db,
  required String accountId,
}) async {
  final adopted = await adoptTransfersForAccount(accountId);
  await db.clearPendingDownloadsForOtherAccounts(accountId);

  // Rows this account still has, minus whatever the OS is already carrying,
  // are the transfers that died with the previous process and that
  // [FileDownloader.rescheduleKilledTasks] could not revive either — their
  // records went with them. They stay recorded so the drive can offer to
  // resume them; nothing is re-fetched behind the user's back on a metered
  // connection, and the chunks already on disk mean a resume only pays for
  // what is missing.
  final stranded = (await db.getPendingDownloads(
    accountId,
  )).where((row) => !adopted.contains(row.fileId)).toList();
  if (stranded.isNotEmpty) {
    _log.info(
      'downloads interrupted by a previous session',
      fields: {'count': stranded.length},
    );
  }
}

/// Task id encoding: `{prefix}|{accountId}|{fileId}[|{chunk}]`.
///
/// The owner has to travel with the task because the OS hands these back after
/// a restart with nothing but the id to go on.
///
/// `|` rather than `:` because [BackgroundTarTransfer] prepends its own prefix
/// to whatever it is given, so the leading segment is not always what the
/// caller passed. Reading the account and file from fixed positions *after*
/// the first separator is stable under that double-prefixing; splitting on
/// `:` and trusting position zero was not.
String transferTaskId({
  required String prefix,
  required String accountId,
  required String fileId,
  int? chunk,
}) {
  final base = '$prefix|$accountId|$fileId';
  return chunk == null ? base : '$base|$chunk';
}

/// The account a task belongs to, or null for an id that predates this
/// encoding — which is treated as "not mine" rather than guessed at.
String? accountIdFromTaskId(String taskId) {
  final parts = taskId.split('|');
  return parts.length >= 3 ? parts[1] : null;
}

String? fileIdFromTaskId(String taskId) {
  final parts = taskId.split('|');
  return parts.length >= 3 ? parts[2] : null;
}

/// The chunk a task carries, or null for a whole-file task like the tar leg.
int? chunkFromTaskId(String taskId) {
  final parts = taskId.split('|');
  return parts.length >= 4 ? int.tryParse(parts[3]) : null;
}

/// Groups the app owns. Any new `background_downloader` task must register
/// its group here so cleanup and notification wiring cover it.
const List<String> _managedGroups = [
  'chunk-downloads',
  'chunk-uploads',
  'direct-chunks',
  'tar-downloads',
  'tar-uploads',
];

/// Reset module-level state so the next [ensureFileDownloaderConfigured]
/// re-runs full setup. Call on account switch / logout so the new session
/// starts clean.
void resetFileDownloaderState() {
  _configuring = null;
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
    // Anything held back here lives in the plugin's own queue, which keeps
    // running while the app is suspended but dies with the process if the app
    // is killed — unlike tasks already handed to URLSession or WorkManager on
    // iOS and Android, which survive it. So on mobile this cap is the line
    // between "resumes by itself" and "needs re-queuing on next launch"; on
    // desktop, where the plugin runs every task in its own isolates, nothing
    // survives a quit and everything comes back through
    // [FileDownloader.rescheduleKilledTasks].
    (Config.holdingQueue, (null, null, kMaxConcurrentTransfersPerGroup)),
  ];

  if (Platform.isAndroid) {
    configs.add((Config.runInForeground, Config.always));
  }

  await FileDownloader().configure(globalConfig: configs);

  // Subscribe before tracking starts: `trackTasks` replays the tasks that
  // finished while the app was suspended, and those updates are only useful
  // if something is already listening.
  _ensureListening();

  // Persist every task to the plugin's own database. Without this the
  // database is empty, [adoptTransfersForAccount] sees no records and adopts
  // nothing, and [FileDownloader.rescheduleKilledTasks] is a no-op — which
  // makes surviving a kill impossible however durable the OS queue is.
  await FileDownloader().trackTasks();

  if (Platform.isAndroid) {
    // Android 13+ requires runtime permission for notifications.
    await Permission.notification.request();

    for (final group in const [
      'chunk-downloads',
      'direct-chunks',
      'tar-downloads',
    ]) {
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
}
