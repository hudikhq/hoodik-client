import '../migration.dart';

/// Per-account ceiling on the offline cache.
class AddAccountsCacheLimitBytes extends Migration {
  const AddAccountsCacheLimitBytes();

  @override
  int get version => 6;

  @override
  String get name => 'add_accounts_cache_limit_bytes';

  @override
  Future<void> up(MigrationContext db) =>
      db.addColumn('accounts', 'cache_limit_bytes', 'INTEGER NULL');
}
