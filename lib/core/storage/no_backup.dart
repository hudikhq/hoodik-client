import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _channel = MethodChannel('io.hoodik.app/backup');
const _log = Logger('NoBackup');

/// Marks the local database with `NSURLIsExcludedFromBackupKey` so the sealed
/// key material and session tokens it holds never ride along into an
/// unencrypted iCloud or iTunes/Finder backup. iOS and macOS only — Android
/// covers this declaratively with `allowBackup="false"`.
///
/// Idempotent and best-effort: re-applied on every launch (the flag lives on
/// the file, so re-setting it is a no-op) and never fatal. Call it after the
/// database file exists.
Future<void> excludeDatabaseFromBackup() async {
  if (!Platform.isIOS && !Platform.isMacOS) return;
  final dir = await getApplicationDocumentsDirectory();
  final base = p.join(dir.path, 'hoodik.db');
  // The WAL/SHM sidecars carry recent writes — including the sealed private-key
  // and token columns — so exclude them too whenever SQLite has them open.
  for (final path in [base, '$base-wal', '$base-shm']) {
    if (!await File(path).exists()) continue;
    try {
      await _channel.invokeMethod('excludeFromBackup', {'path': path});
    } catch (e) {
      _log.warn(
        'exclude-from-backup failed',
        fields: {'error': redactException(e)},
      );
    }
  }
}
