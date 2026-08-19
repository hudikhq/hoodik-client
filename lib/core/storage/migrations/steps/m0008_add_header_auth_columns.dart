import '../migration.dart';

/// Header-based auth, for servers running with `USE_HEADERS_FOR_AUTH`.
class AddHeaderAuthColumns extends Migration {
  const AddHeaderAuthColumns();

  @override
  int get version => 8;

  @override
  String get name => 'add_header_auth_columns';

  @override
  Future<void> up(MigrationContext db) => () async {
    await db.addColumn(
      'servers',
      'use_header_auth',
      'INTEGER NOT NULL DEFAULT 0 CHECK (use_header_auth IN (0, 1))',
    );
    await db.addColumn('accounts', 'header_jwt', 'TEXT NULL');
    await db.addColumn('accounts', 'header_refresh_token', 'TEXT NULL');
  }();
}
