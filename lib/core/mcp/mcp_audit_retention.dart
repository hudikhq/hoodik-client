import 'package:drift/drift.dart' show Value;

import '../storage/database.dart';
import '../storage/mcp_audit_dao.dart';
import '../utils/logger.dart';

/// Minimum gap between two retention passes. Foregrounding the app repeatedly
/// is cheap; hammering SQLite with delete-scans is not — 24h matches the
/// observable audit granularity and keeps the cleanup off the hot path.
const Duration kMcpRetentionDebounce = Duration(hours: 24);

/// Sentinel meaning "keep audit entries forever". Stored as `0` in the
/// database so the type system keeps it dense with the real day counts.
const int kMcpRetentionForever = 0;

const Logger _log = Logger('mcp.retention');

/// Drops audit-log rows whose timestamp is older than the configured window.
///
/// The policy lives per-account on [McpSettings.auditRetentionDays]; this
/// helper is the single place that reads it, decides whether the debounce
/// has elapsed, runs the delete, and records the cleanup wall-clock on the
/// same row. Keeping it out of widget code means the cleanup can run from
/// lifecycle listeners (app foreground) and from server start without
/// duplicating logic in either caller.
class McpAuditRetention {
  final AppDatabase _db;

  McpAuditRetention(this._db);

  /// Run the retention pass for [accountId] if it is due. Returns the number
  /// of rows deleted (`0` on "skipped" as well as "nothing to remove" — the
  /// two are indistinguishable to the caller and don't need to be).
  Future<int> maybeRun(
    String accountId, {
    DateTime Function() now = _defaultNow,
  }) async {
    final settings = await _db.getMcpSettings(accountId);
    if (settings == null) return 0;

    final days = settings.auditRetentionDays;
    if (days <= kMcpRetentionForever) return 0;

    final wall = now();
    final last = settings.lastAuditCleanupAt;
    if (last != null && wall.difference(last) < kMcpRetentionDebounce) {
      return 0;
    }

    final removed = await _db.deleteOldMcpAuditEntries(Duration(days: days));
    await _db.upsertMcpSettings(
      accountId,
      McpSettingsCompanion(lastAuditCleanupAt: Value(wall)),
    );

    if (removed > 0) {
      _log.info(
        'audit retention pass complete',
        fields: {'removed': removed, 'days': days},
      );
    }
    return removed;
  }

  /// Force a retention pass, bypassing the 24h debounce. Used when the user
  /// changes the retention window: the new policy should take effect
  /// immediately rather than wait for the next foreground.
  Future<int> runNow(
    String accountId, {
    DateTime Function() now = _defaultNow,
  }) async {
    final settings = await _db.getMcpSettings(accountId);
    if (settings == null) return 0;

    final days = settings.auditRetentionDays;
    if (days <= kMcpRetentionForever) {
      await _db.upsertMcpSettings(
        accountId,
        McpSettingsCompanion(lastAuditCleanupAt: Value(now())),
      );
      return 0;
    }

    final removed = await _db.deleteOldMcpAuditEntries(Duration(days: days));
    await _db.upsertMcpSettings(
      accountId,
      McpSettingsCompanion(lastAuditCleanupAt: Value(now())),
    );
    return removed;
  }
}

DateTime _defaultNow() => DateTime.now();
