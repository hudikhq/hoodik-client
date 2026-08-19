import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/mcp_audit_dao.dart';

AppDatabase _createTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

Future<int> _insert(
  AppDatabase db, {
  DateTime? timestamp,
  String sessionId = 'sess',
  String? accountId,
  String toolName = 'list_files',
  String paramsHash = '',
  String resultStatus = 'ok',
  String? errorMessage,
  int durationMs = 5,
}) {
  return db.insertMcpAuditEntry(
    timestamp: timestamp ?? DateTime.now(),
    sessionId: sessionId,
    accountId: accountId,
    toolName: toolName,
    paramsHash: paramsHash,
    resultStatus: resultStatus,
    errorMessage: errorMessage,
    durationMs: durationMs,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('McpAuditDao insert + retrieve', () {
    test('round-trips every column', () async {
      // Drift stores DateTime as unix seconds and reads back local time,
      // so use a local DateTime rounded to the second to dodge both the
      // tz shift and sub-second drift.
      final ts = DateTime(2026, 4, 19, 12, 30, 15);
      await _insert(
        db,
        timestamp: ts,
        sessionId: 'abcdef0123456789',
        accountId: 'acct-42',
        toolName: 'read_file',
        paramsHash: 'a' * 64,
        resultStatus: 'ok',
        errorMessage: null,
        durationMs: 42,
      );

      final entries = await db.getMcpAuditEntries();
      expect(entries, hasLength(1));
      final row = entries.single;
      expect(row.timestamp, ts);
      expect(row.sessionId, 'abcdef0123456789');
      expect(row.accountId, 'acct-42');
      expect(row.toolName, 'read_file');
      expect(row.paramsHash, 'a' * 64);
      expect(row.resultStatus, 'ok');
      expect(row.errorMessage, isNull);
      expect(row.durationMs, 42);
      expect(row.id, isNonZero);
    });

    test('stores nullable error message when an error is recorded', () async {
      await _insert(
        db,
        resultStatus: 'error',
        errorMessage: 'Not authenticated',
      );

      final entry = (await db.getMcpAuditEntries()).single;
      expect(entry.resultStatus, 'error');
      expect(entry.errorMessage, 'Not authenticated');
    });
  });

  group('McpAuditDao pagination', () {
    test('returns 150 entries across pages of 100 then 50', () async {
      final base = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 150; i++) {
        await _insert(
          db,
          timestamp: base.add(Duration(minutes: i)),
          toolName: 'list_files',
          durationMs: i,
        );
      }

      final page1 = await db.getMcpAuditEntries(limit: 100, offset: 0);
      final page2 = await db.getMcpAuditEntries(limit: 100, offset: 100);

      expect(page1, hasLength(100));
      expect(page2, hasLength(50));

      expect(page1.first.durationMs, 149);
      expect(page1.last.durationMs, 50);
      expect(page2.first.durationMs, 49);
      expect(page2.last.durationMs, 0);
    });

    test('newest entries surface first without an explicit limit', () async {
      final base = DateTime.utc(2026, 1, 1);
      await _insert(db, timestamp: base, toolName: 'older');
      await _insert(
        db,
        timestamp: base.add(const Duration(hours: 1)),
        toolName: 'newer',
      );

      final entries = await db.getMcpAuditEntries();
      expect(entries.first.toolName, 'newer');
      expect(entries.last.toolName, 'older');
    });
  });

  group('McpAuditDao filtering', () {
    test('by session returns only rows that match', () async {
      await _insert(db, sessionId: 'sess-a', toolName: 'list_files');
      await _insert(db, sessionId: 'sess-a', toolName: 'read_file');
      await _insert(db, sessionId: 'sess-b', toolName: 'write_file');

      final a = await db.getMcpAuditEntriesBySession('sess-a');
      final b = await db.getMcpAuditEntriesBySession('sess-b');

      expect(a, hasLength(2));
      expect(a.every((r) => r.sessionId == 'sess-a'), isTrue);
      expect(b, hasLength(1));
      expect(b.single.sessionId, 'sess-b');
    });

    test('by tool + status narrows the paginated query', () async {
      await _insert(db, toolName: 'list_files', resultStatus: 'ok');
      await _insert(db, toolName: 'list_files', resultStatus: 'error');
      await _insert(db, toolName: 'read_file', resultStatus: 'ok');

      final errors = await db.getMcpAuditEntries(resultStatus: 'error');
      expect(errors, hasLength(1));
      expect(errors.single.toolName, 'list_files');

      final reads = await db.getMcpAuditEntries(toolName: 'read_file');
      expect(reads, hasLength(1));
      expect(reads.single.resultStatus, 'ok');
    });

    test('distinct tool names returns a sorted, de-duplicated list', () async {
      await _insert(db, toolName: 'read_file');
      await _insert(db, toolName: 'read_file');
      await _insert(db, toolName: 'list_files');
      await _insert(db, toolName: 'write_file');

      final names = await db.getDistinctMcpAuditToolNames();
      expect(names, ['list_files', 'read_file', 'write_file']);
    });
  });

  group('McpAuditDao retention', () {
    test('deleteOldMcpAuditEntries drops rows older than the cutoff', () async {
      final old = DateTime.now().subtract(const Duration(days: 10));
      final fresh = DateTime.now().subtract(const Duration(hours: 1));

      await _insert(db, timestamp: old, toolName: 'stale');
      await _insert(db, timestamp: fresh, toolName: 'recent');

      final removed = await db.deleteOldMcpAuditEntries(
        const Duration(days: 7),
      );
      expect(removed, 1);

      final remaining = await db.getMcpAuditEntries();
      expect(remaining, hasLength(1));
      expect(remaining.single.toolName, 'recent');
    });

    test('clearMcpAuditLog empties the table', () async {
      for (var i = 0; i < 5; i++) {
        await _insert(db, toolName: 'tool-$i');
      }
      final before = await db.countMcpAuditEntries();
      expect(before, 5);

      await db.clearMcpAuditLog();

      final after = await db.countMcpAuditEntries();
      expect(after, 0);
      expect(await db.getMcpAuditEntries(), isEmpty);
    });
  });

  // v13 recreates the mcp_audit_log table on top of a v12 shape. Verify
  // that an app upgrading from v12 ends up with a queryable audit table
  // and that pre-existing rows on other tables survive the migration.
  group('Schema v13 migration', () {
    test('creates mcp_audit_log table when upgrading v12 -> v13', () async {
      final silenceWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = silenceWarning;
      });

      final migrationDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(migrationDb.close);

      // The ledger, not the version number, decides what runs. `forTesting`
      // builds the current schema and records every migration as applied, so
      // reproducing a v12 device means dropping the ledger it never had.
      await migrationDb.customStatement('DROP TABLE schema_migrations');
      await migrationDb.customStatement('DROP TABLE mcp_audit_log');

      const presenceCheckSql =
          'SELECT name FROM sqlite_master '
          "WHERE type='table' AND name='mcp_audit_log'";

      // Sanity: table is truly gone, so the migration has something to do.
      final before = await migrationDb.customSelect(presenceCheckSql).get();
      expect(before, isEmpty);

      final migrator = Migrator(migrationDb);
      await migrationDb.migration.onUpgrade(
        migrator,
        12,
        AppDatabase.currentSchemaVersion,
      );

      final after = await migrationDb.customSelect(presenceCheckSql).get();
      expect(after, hasLength(1));

      // Table is usable after the migration — not just present.
      await migrationDb.insertMcpAuditEntry(
        timestamp: DateTime(2026, 4, 19),
        sessionId: 'sess',
        toolName: 'list_files',
        paramsHash: '',
        resultStatus: 'ok',
        durationMs: 1,
      );
      final rows = await migrationDb.getMcpAuditEntries();
      expect(rows, hasLength(1));
    });
  });
}
