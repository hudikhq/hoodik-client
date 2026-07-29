import 'package:drift/drift.dart';

import 'database.dart';

/// Data-access helpers for the [McpAuditLog] table.
///
/// Kept in its own extension so `database.dart` doesn't have to grow every
/// time a table adds CRUD. Mirrors [PendingUploadsDao] in shape.
extension McpAuditDao on AppDatabase {
  /// Record one MCP tool invocation. Returns the persisted row ID.
  Future<int> insertMcpAuditEntry({
    required DateTime timestamp,
    required String sessionId,
    String? accountId,
    required String toolName,
    required String paramsHash,
    required String resultStatus,
    String? errorMessage,
    required int durationMs,
  }) {
    return into(mcpAuditLog).insert(
      McpAuditLogCompanion.insert(
        timestamp: timestamp,
        sessionId: sessionId,
        accountId: Value(accountId),
        toolName: toolName,
        paramsHash: paramsHash,
        resultStatus: resultStatus,
        errorMessage: Value(errorMessage),
        durationMs: durationMs,
      ),
    );
  }

  /// Page through audit entries, newest first. Used by the settings screen.
  ///
  /// Sort is `(timestamp DESC, id DESC)` so entries that land in the same
  /// millisecond still come back in insertion order. Without the `id` tiebreaker
  /// the UI jitters whenever a burst of audits share a timestamp, and tests
  /// that assert ordering would be flaky.
  Future<List<McpAuditLogData>> getMcpAuditEntries({
    int limit = 100,
    int offset = 0,
    String? toolName,
    String? resultStatus,
  }) {
    final query = select(mcpAuditLog)
      ..orderBy([
        (e) => OrderingTerm.desc(e.timestamp),
        (e) => OrderingTerm.desc(e.id),
      ])
      ..limit(limit, offset: offset);
    if (toolName != null && toolName.isNotEmpty) {
      query.where((e) => e.toolName.equals(toolName));
    }
    if (resultStatus != null && resultStatus.isNotEmpty) {
      query.where((e) => e.resultStatus.equals(resultStatus));
    }
    return query.get();
  }

  /// All entries for a given session (by hashed session ID), oldest first
  /// so the UI can render a chronological trace.
  Future<List<McpAuditLogData>> getMcpAuditEntriesBySession(String sessionId) {
    return (select(mcpAuditLog)
          ..where((e) => e.sessionId.equals(sessionId))
          ..orderBy([(e) => OrderingTerm.asc(e.timestamp)]))
        .get();
  }

  /// Reactive watcher for the settings screen: emits whenever the audit
  /// log changes so the list stays current without manual polling. Sort
  /// matches [getMcpAuditEntries] so paginated and watched views agree.
  Stream<List<McpAuditLogData>> watchMcpAuditEntries({
    int limit = 100,
    String? toolName,
    String? resultStatus,
  }) {
    final query = select(mcpAuditLog)
      ..orderBy([
        (e) => OrderingTerm.desc(e.timestamp),
        (e) => OrderingTerm.desc(e.id),
      ])
      ..limit(limit);
    if (toolName != null && toolName.isNotEmpty) {
      query.where((e) => e.toolName.equals(toolName));
    }
    if (resultStatus != null && resultStatus.isNotEmpty) {
      query.where((e) => e.resultStatus.equals(resultStatus));
    }
    return query.watch();
  }

  /// Distinct tool names that appear in the log. Powers the filter dropdown.
  Future<List<String>> getDistinctMcpAuditToolNames() async {
    final rows = await customSelect(
      'SELECT DISTINCT tool_name FROM mcp_audit_log ORDER BY tool_name ASC',
      readsFrom: {mcpAuditLog},
    ).get();
    return rows.map((r) => r.read<String>('tool_name')).toList();
  }

  /// Retention helper: drop entries older than the given age. Callers choose
  /// the policy (we don't enforce one here).
  Future<int> deleteOldMcpAuditEntries(Duration olderThan) {
    final cutoff = DateTime.now().subtract(olderThan);
    return (delete(
      mcpAuditLog,
    )..where((e) => e.timestamp.isSmallerThanValue(cutoff))).go();
  }

  /// Wipe the full audit log. Surfaced to the user via "Clear log" in the
  /// settings screen.
  Future<int> clearMcpAuditLog() => delete(mcpAuditLog).go();

  /// Count rows for the settings header / diagnostics.
  Future<int> countMcpAuditEntries() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM mcp_audit_log',
      readsFrom: {mcpAuditLog},
    ).getSingle();
    return row.read<int>('c');
  }
}
