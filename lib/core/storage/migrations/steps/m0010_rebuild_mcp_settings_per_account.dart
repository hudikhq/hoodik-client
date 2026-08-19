import '../migration.dart';

/// Settings become per-account, keyed by the account they belong to.
///
/// Rebuilt rather than altered: the table is one version old and holds only a
/// disabled server's defaults, so there is nothing to carry over, and starting
/// from a drop is what lets a failed attempt simply run again.
class RebuildMcpSettingsPerAccount extends Migration {
  const RebuildMcpSettingsPerAccount();

  @override
  int get version => 10;

  @override
  String get name => 'rebuild_mcp_settings_per_account';

  @override
  Future<void> up(MigrationContext db) => db.rebuild('mcp_settings', '''
          CREATE TABLE mcp_settings (
            account_id TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
            port INTEGER NOT NULL DEFAULT 19548,
            bearer_token TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            PRIMARY KEY (account_id)
          )
        ''');
}
