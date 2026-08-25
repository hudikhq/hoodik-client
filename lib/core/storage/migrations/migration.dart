import 'package:drift/drift.dart';

/// One schema change, applied once and recorded by name.
///
/// Migrations speak raw SQL and never import the database class. That is the
/// point rather than an inconvenience: a migration that cannot reach today's
/// table definitions cannot drift out of step with the schema it was written
/// against, which is how a step that created `pending_downloads` complete
/// ended up followed by a step adding a column it already had.
abstract class Migration {
  const Migration();

  /// The schema version this migration produces. Strictly increasing across
  /// the registry, and what tells an existing install which migrations its
  /// `user_version` already implies.
  int get version;

  /// Identity in `schema_migrations`. Never change one after it has shipped —
  /// a renamed migration reads as a new one and runs again.
  String get name;

  Future<void> up(MigrationContext db);
}

/// What a migration is allowed to do.
class MigrationContext {
  const MigrationContext(this._db);

  final DatabaseConnectionUser _db;

  Future<void> execute(String sql) => _db.customStatement(sql);

  Future<bool> hasColumn(String table, String column) async {
    final rows = await _db
        .customSelect(
          "SELECT 1 FROM pragma_table_info('$table') WHERE name = ?",
          variables: [Variable<String>(column)],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Adds a column unless the live schema already has it.
  ///
  /// Drift runs migrations outside a transaction on the way in, so a run that
  /// died leaves its finished statements behind and retries the rest. Reading
  /// the schema rather than trusting a version number is what lets that retry
  /// get past its own work.
  Future<void> addColumn(String table, String column, String definition) async {
    if (await hasColumn(table, column)) return;
    await execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  /// Drops a table and builds it again from [ddl], discarding its rows.
  ///
  /// For a table holding cache or resume state there is nothing worth keeping,
  /// and a change written as a rebuild cannot be stopped by whatever state a
  /// previous attempt left behind. Identity, keys and trusted fingerprints are
  /// never rebuilt — see the durable list in the migration tests.
  Future<void> rebuild(String table, String ddl) async {
    await execute('DROP TABLE IF EXISTS $table');
    await execute(ddl);
  }

  /// Replaces a table with [ddl], carrying the [carry] columns over.
  ///
  /// The way to change a table whose rows matter but whose new shape an
  /// `ALTER TABLE` cannot reach — sqlite refuses to add a `NOT NULL` column
  /// with an expression default to a table that has rows, and cannot change a
  /// constraint at all. Every migration runs in a transaction, so the window
  /// where the old table is gone and the new one is not yet in place does not
  /// outlive a crash.
  Future<void> rebuildPreserving(
    String table,
    String ddl, {
    required List<String> carry,
  }) async {
    final staging = '${table}_migrating';
    final columns = carry.join(', ');

    await execute('DROP TABLE IF EXISTS $staging');
    await execute(ddl.replaceFirst(table, staging));
    await execute(
      'INSERT INTO $staging ($columns) SELECT $columns FROM $table',
    );
    await execute('DROP TABLE $table');
    await execute('ALTER TABLE $staging RENAME TO $table');
  }
}
