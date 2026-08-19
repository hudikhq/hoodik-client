import 'package:drift/drift.dart';

import 'migration.dart';

/// Applies every registered migration a database has not recorded yet.
///
/// The ledger, not `user_version`, decides what runs. Sqlite's version is a
/// single integer: it says where a database is, never how it got there, and
/// drift only writes it once the whole upgrade has finished. An upgrade that
/// died halfway therefore leaves a version describing a schema that no longer
/// exists, and the next launch replays steps against their own finished work.
/// A row per applied migration survives that, so a resumed upgrade picks up
/// exactly where it stopped.
class MigrationRunner {
  const MigrationRunner(this.migrations);

  final List<Migration> migrations;

  /// Marks every migration as applied without running one, for a database
  /// drift has just built whole from the current definitions.
  Future<void> adoptFresh(DatabaseConnectionUser db) async {
    await _createLedger(db);
    await _record(db, migrations);
  }

  /// Runs what [db] is missing, where [installedVersion] is the schema version
  /// it last completed an upgrade at.
  Future<void> upgrade(DatabaseConnectionUser db, int installedVersion) async {
    final hadLedger = await _ledgerExists(db);
    await _createLedger(db);

    if (!hadLedger) {
      // Adopting the ledger onto a database that predates it. Everything the
      // installed version implies has run, whether or not anything recorded
      // it at the time.
      await _record(db, migrations.where((m) => m.version <= installedVersion));
    }

    final applied = await _appliedNames(db);
    final context = MigrationContext(db);

    for (final migration in migrations) {
      if (applied.contains(migration.name)) continue;
      // The row lands with the statements it describes. Sqlite makes DDL
      // transactional, so a migration either applies and is recorded or does
      // neither, and the next launch retries exactly it.
      await db.transaction(() async {
        await migration.up(context);
        await _record(db, [migration]);
      });
    }
  }

  Future<bool> _ledgerExists(DatabaseConnectionUser db) async {
    final rows = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'schema_migrations'",
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _createLedger(DatabaseConnectionUser db) {
    return db.customStatement('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name TEXT NOT NULL PRIMARY KEY,
        version INTEGER NOT NULL,
        applied_at INTEGER NOT NULL
      )
    ''');
  }

  Future<Set<String>> _appliedNames(DatabaseConnectionUser db) async {
    final rows = await db
        .customSelect('SELECT name FROM schema_migrations')
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<void> _record(
    DatabaseConnectionUser db,
    Iterable<Migration> applied,
  ) async {
    final rows = applied.toList();
    if (rows.isEmpty) return;

    final placeholders = List.filled(
      rows.length,
      "(?, ?, strftime('%s', 'now'))",
    ).join(', ');
    await db.customStatement(
      'INSERT OR REPLACE INTO schema_migrations (name, version, applied_at) '
      'VALUES $placeholders',
      [
        for (final m in rows) ...[m.name, m.version],
      ],
    );
  }
}
