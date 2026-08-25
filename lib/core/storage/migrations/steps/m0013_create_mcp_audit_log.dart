import '../migration.dart';

/// Every tool call the local MCP server serves.
class CreateMcpAuditLog extends Migration {
  const CreateMcpAuditLog();

  @override
  int get version => 13;

  @override
  String get name => 'create_mcp_audit_log';

  @override
  Future<void> up(MigrationContext db) => db.execute('''
        CREATE TABLE IF NOT EXISTS mcp_audit_log (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          session_id TEXT NOT NULL,
          account_id TEXT NULL,
          tool_name TEXT NOT NULL,
          params_hash TEXT NOT NULL,
          result_status TEXT NOT NULL,
          error_message TEXT NULL,
          duration_ms INTEGER NOT NULL
        )
      ''');
}
