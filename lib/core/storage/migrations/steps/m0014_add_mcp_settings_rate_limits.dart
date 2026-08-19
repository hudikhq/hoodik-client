import '../migration.dart';

/// Read-only access while locked, and the request rate the server allows.
class AddMcpSettingsRateLimits extends Migration {
  const AddMcpSettingsRateLimits();

  @override
  int get version => 14;

  @override
  String get name => 'add_mcp_settings_rate_limits';

  @override
  Future<void> up(MigrationContext db) => () async {
    await db.addColumn(
      'mcp_settings',
      'allow_read_only_while_locked',
      'INTEGER NOT NULL DEFAULT 0 '
          'CHECK (allow_read_only_while_locked IN (0, 1))',
    );
    await db.addColumn(
      'mcp_settings',
      'rate_limit_rps',
      'INTEGER NOT NULL DEFAULT 5',
    );
    await db.addColumn(
      'mcp_settings',
      'rate_limit_burst',
      'INTEGER NOT NULL DEFAULT 20',
    );
  }();
}
