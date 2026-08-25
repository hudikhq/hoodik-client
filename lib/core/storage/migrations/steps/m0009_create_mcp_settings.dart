import '../migration.dart';

/// The MCP server settings, at this point a single row for the whole app.
class CreateMcpSettings extends Migration {
  const CreateMcpSettings();

  @override
  int get version => 9;

  @override
  String get name => 'create_mcp_settings';

  @override
  Future<void> up(MigrationContext db) => db.execute('''
        CREATE TABLE IF NOT EXISTS mcp_settings (
          account_id TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
          port INTEGER NOT NULL DEFAULT 19548,
          bearer_token TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
        )
      ''');
}
