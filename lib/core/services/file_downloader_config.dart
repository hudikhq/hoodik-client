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

/// Cancel all orphaned tasks and purge stale records from the
/// [FileDownloader] persistent database.
///
/// Call on cold start (before any downloads are enqueued) and on account
/// switch (via [resetFileDownloaderState]) to prevent ghost downloads from
/// consuming bandwidth.
Future<void> cleanUpFileDownloader() {
  return _startupCleanup ??= _doCleanUp();
}

Future<void> _doCleanUp() async {
  for (final group in _managedGroups) {
    await FileDownloader().cancelAll(group: group);
    await FileDownloader().database.deleteAllRecords(group: group);
  }
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

Future<void> _doConfigure() async {
  final configs = <(String, dynamic)>[
    // (maxConcurrent, maxConcurrentByHost, maxConcurrentByGroup)
    // Unlimited total / per-host, 6 per group.
    // Downloads (group 'chunk-downloads'): 1 tar task, well under 6.
    // Uploads  (group 'chunk-uploads'):    6 concurrent chunk uploads.
    (Config.holdingQueue, (null, null, 6)),
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
