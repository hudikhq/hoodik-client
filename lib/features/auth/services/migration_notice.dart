import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the post-migration "save your recovery key" notice was
/// already shown for an account on this device. Mirrors the web client's
/// localStorage flag: per device, cleared never — one reminder is enough.
const _keyPrefix = 'migrationNotice.seen.';

Future<bool> isMigrationNoticeSeen(String accountId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('$_keyPrefix$accountId') ?? false;
}

Future<void> markMigrationNoticeSeen(String accountId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('$_keyPrefix$accountId', true);
}
