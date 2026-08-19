import '../migration.dart';

/// How long audit rows are kept, and when they were last swept.
class AddMcpSettingsAuditRetention extends Migration {
  const AddMcpSettingsAuditRetention();

  @override
  int get version => 15;

  @override
  String get name => 'add_mcp_settings_audit_retention';

  @override
  Future<void> up(MigrationContext db) => () async {
    await db.addColumn(
      'mcp_settings',
      'audit_retention_days',
      'INTEGER NOT NULL DEFAULT 30',
    );
    await db.addColumn('mcp_settings', 'last_audit_cleanup_at', 'INTEGER NULL');
  }();
}
