import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_uploads_dao.dart';

/// Creates an in-memory [AppDatabase] for testing.
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Server operations ──────────────────────────────────────────────

  group('Server CRUD', () {
    test('insert and retrieve server', () async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test Server'),
        ),
      );

      final servers = await db.getAllServers();
      expect(servers.length, 1);
      expect(servers[0].name, 'Test Server');
      expect(servers[0].url, 'https://example.com');
    });

    test('getServerByUrl finds matching server', () async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );

      final found = await db.getServerByUrl('https://example.com');
      expect(found, isNotNull);
      expect(found!.id, 's1');
    });

    test('getServerByUrl returns null for unknown', () async {
      final found = await db.getServerByUrl('https://nope.com');
      expect(found, isNull);
    });

    test('deleteServer removes server and accounts', () async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('test@test.com'),
        ),
      );

      await db.deleteServer('s1');

      final servers = await db.getAllServers();
      final accounts = await db.getAllAccounts();
      expect(servers, isEmpty);
      expect(accounts, isEmpty);
    });
  });

  // ── Account operations ─────────────────────────────────────────────

  group('Account CRUD', () {
    setUp(() async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );
    });

    test('upsert and retrieve account', () async {
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('alice@test.com'),
        ),
      );

      final accounts = await db.getAllAccounts();
      expect(accounts.length, 1);
      expect(accounts[0].email, 'alice@test.com');
    });

    test('getActiveAccount returns active account', () async {
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('alice@test.com'),
          isActive: const Value(true),
        ),
      );

      final active = await db.getActiveAccount();
      expect(active, isNotNull);
      expect(active!.id, 'a1');
    });

    test('getActiveAccount returns null when none active', () async {
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('alice@test.com'),
          isActive: const Value(false),
        ),
      );

      final active = await db.getActiveAccount();
      expect(active, isNull);
    });

    test('setActiveAccount switches active flag', () async {
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('alice@test.com'),
          isActive: const Value(true),
        ),
      );
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a2'),
          serverId: const Value('s1'),
          userId: const Value('u2'),
          email: const Value('bob@test.com'),
          isActive: const Value(false),
        ),
      );

      await db.setActiveAccount('a2');

      final a1 = await db.getAccountById('a1');
      final a2 = await db.getAccountById('a2');
      expect(a1!.isActive, false);
      expect(a2!.isActive, true);
    });

    test(
      'updateAccountQuota writes through and can clear to unlimited',
      () async {
        await db.insertAccount(
          AccountsCompanion(
            id: const Value('a1'),
            serverId: const Value('s1'),
            userId: const Value('u1'),
            email: const Value('test@test.com'),
            quota: const Value(1000),
          ),
        );

        await db.updateAccountQuota('a1', 5000);
        expect((await db.getAccountById('a1'))!.quota, 5000);

        await db.updateAccountQuota('a1', null);
        expect((await db.getAccountById('a1'))!.quota, isNull);
      },
    );
  });

  // ── CachedFiles operations ─────────────────────────────────────────

  group('CachedFiles', () {
    setUp(() async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('alice@test.com'),
        ),
      );
    });

    test('upsert and query files in directory', () async {
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('f1'),
          dirId: const Value('dir1'),
          encryptedName: const Value('enc_name'),
          mime: const Value('application/pdf'),
          size: const Value(1024),
        ),
      );

      final files = await db.getFilesInDir('a1', 'dir1');
      expect(files.length, 1);
      expect(files[0].id, 'f1');
      expect(files[0].mime, 'application/pdf');
    });

    test('upsert updates existing entry', () async {
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('f1'),
          encryptedName: const Value('old_name'),
          mime: const Value('text/plain'),
        ),
      );
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('f1'),
          encryptedName: const Value('new_name'),
          mime: const Value('text/plain'),
        ),
      );

      final files = await db.getFilesInDir('a1', null);
      expect(files.length, 1);
      expect(files[0].encryptedName, 'new_name');
    });

    test('getFilesInDir returns root files for null dirId', () async {
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('f1'),
          dirId: const Value.absent(),
          encryptedName: const Value('root_file'),
          mime: const Value('text/plain'),
        ),
      );
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('f2'),
          dirId: const Value('some-dir'),
          encryptedName: const Value('child_file'),
          mime: const Value('text/plain'),
        ),
      );

      final root = await db.getFilesInDir('a1', null);
      expect(root.length, 1);
      expect(root[0].id, 'f1');
    });

    test('removeStaleCachedFiles prunes deleted entries', () async {
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('keep'),
          dirId: const Value('d1'),
          encryptedName: const Value('a'),
          mime: const Value('text/plain'),
        ),
      );
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('stale'),
          dirId: const Value('d1'),
          encryptedName: const Value('b'),
          mime: const Value('text/plain'),
        ),
      );

      await db.removeStaleCachedFiles('a1', 'd1', {'keep'});

      final remaining = await db.getFilesInDir('a1', 'd1');
      expect(remaining.length, 1);
      expect(remaining[0].id, 'keep');
    });

    test('clearCacheForAccount removes all cached files', () async {
      await db.upsertCachedFile(
        CachedFilesCompanion(
          accountId: const Value('a1'),
          id: const Value('f1'),
          encryptedName: const Value('a'),
          mime: const Value('text/plain'),
        ),
      );

      await db.clearCacheForAccount('a1');

      final files = await db.getFilesInDir('a1', null);
      expect(files, isEmpty);
    });
  });

  // ── PendingUploads CRUD ────────────────────────────────────────────

  group('PendingUploads', () {
    test('insert and retrieve', () async {
      final upload = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/photo.jpg'),
          targetDirId: const Value('dir1'),
        ),
      );

      expect(upload.accountId, 'a1');
      expect(upload.localPath, '/tmp/photo.jpg');
      expect(upload.targetDirId, 'dir1');
      expect(upload.status, 'pending');
    });

    test('getPendingUploads returns ordered by date', () async {
      await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/first.jpg'),
        ),
      );
      await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/second.jpg'),
        ),
      );

      final uploads = await db.getPendingUploads('a1');
      expect(uploads.length, 2);
      // Oldest first
      expect(uploads[0].localPath, '/tmp/first.jpg');
      expect(uploads[1].localPath, '/tmp/second.jpg');
    });

    test('getPendingUploadsByStatus filters correctly', () async {
      final u = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/file.jpg'),
        ),
      );

      await db.updatePendingUploadStatus(u.id, 'failed');

      final pending = await db.getPendingUploadsByStatus('a1', 'pending');
      final failed = await db.getPendingUploadsByStatus('a1', 'failed');
      expect(pending, isEmpty);
      expect(failed.length, 1);
    });

    test('getPendingUploadCount counts pending and failed', () async {
      await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/a.jpg'),
        ),
      );
      final u2 = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/b.jpg'),
        ),
      );
      final u3 = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/c.jpg'),
        ),
      );

      await db.updatePendingUploadStatus(u2.id, 'failed');
      await db.updatePendingUploadStatus(u3.id, 'completed');

      final count = await db.getPendingUploadCount('a1');
      // pending=1, failed=1, completed=0 (not counted)
      expect(count, 2);
    });

    test('deletePendingUpload removes by id', () async {
      final u = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/file.jpg'),
        ),
      );

      await db.deletePendingUpload(u.id);

      final uploads = await db.getPendingUploads('a1');
      expect(uploads, isEmpty);
    });

    test('clearCompletedPendingUploads only removes completed', () async {
      await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/pending.jpg'),
        ),
      );
      final u2 = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/done.jpg'),
        ),
      );

      await db.updatePendingUploadStatus(u2.id, 'completed');
      await db.clearCompletedPendingUploads('a1');

      final uploads = await db.getPendingUploads('a1');
      expect(uploads.length, 1);
      expect(uploads[0].localPath, '/tmp/pending.jpg');
    });

    test('uploads scoped to account', () async {
      await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/a1.jpg'),
        ),
      );
      await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a2'),
          localPath: const Value('/tmp/a2.jpg'),
        ),
      );

      final a1Uploads = await db.getPendingUploads('a1');
      final a2Uploads = await db.getPendingUploads('a2');
      expect(a1Uploads.length, 1);
      expect(a2Uploads.length, 1);
    });

    test('retry columns default to 0 and null', () async {
      final upload = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/fresh.jpg'),
        ),
      );

      expect(upload.retryCount, 0);
      expect(upload.nextRetryAt, isNull);
    });

    test('scheduleNextUploadRetry persists backoff state', () async {
      final u = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/a.jpg'),
        ),
      );
      final due = DateTime(2026, 5, 1, 8);

      await db.scheduleNextUploadRetry(u.id, retryCount: 2, nextRetryAt: due);

      final row = await db.getPendingUploads('a1').then((r) => r.single);
      expect(row.retryCount, 2);
      expect(row.nextRetryAt, due);
      expect(row.status, 'pending');
    });

    test('getPendingUploadsEligibleForRetry skips cooling-down rows', () async {
      final u1 = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/hot.jpg'),
        ),
      );
      final u2 = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/cold.jpg'),
        ),
      );

      final now = DateTime(2026, 5, 1, 12);
      await db.scheduleNextUploadRetry(
        u1.id,
        retryCount: 1,
        nextRetryAt: now.subtract(const Duration(seconds: 10)),
      );
      await db.scheduleNextUploadRetry(
        u2.id,
        retryCount: 1,
        nextRetryAt: now.add(const Duration(seconds: 10)),
      );

      final eligible = await db.getPendingUploadsEligibleForRetry('a1', now);
      expect(eligible.map((r) => r.id).toList(), [u1.id]);
    });

    test('markPendingUploadPermanentlyFailed clears nextRetryAt', () async {
      final u = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/a.jpg'),
        ),
      );
      await db.scheduleNextUploadRetry(
        u.id,
        retryCount: 4,
        nextRetryAt: DateTime(2026, 5, 1, 12),
      );

      await db.markPendingUploadPermanentlyFailed(u.id, 5);

      final row = await db.getPendingUploads('a1').then((r) => r.single);
      expect(row.status, 'failed_permanent');
      expect(row.retryCount, 5);
      expect(row.nextRetryAt, isNull);
    });

    test('resetPendingUploadForRetry restarts the retry budget', () async {
      final u = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/a.jpg'),
        ),
      );
      await db.markPendingUploadPermanentlyFailed(u.id, 5);

      await db.resetPendingUploadForRetry(u.id);

      final row = await db.getPendingUploads('a1').then((r) => r.single);
      expect(row.status, 'pending');
      expect(row.retryCount, 0);
      expect(row.nextRetryAt, isNull);
    });

    test('getPermanentlyFailedUploads filters to failed_permanent', () async {
      final pending = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/pending.jpg'),
        ),
      );
      final dead = await db.insertPendingUpload(
        PendingUploadsCompanion(
          accountId: const Value('a1'),
          localPath: const Value('/tmp/dead.jpg'),
        ),
      );
      await db.markPendingUploadPermanentlyFailed(dead.id, 5);

      final failed = await db.getPermanentlyFailedUploads('a1');
      expect(failed.map((r) => r.id).toList(), [dead.id]);
      expect(failed.any((r) => r.id == pending.id), isFalse);
    });
  });

  // ── OfflineFiles operations ────────────────────────────────────────

  group('OfflineFiles', () {
    test('insert and query offline file', () async {
      await db.insertOfflineFile(
        OfflineFilesCompanion(
          accountId: const Value('a1'),
          fileId: const Value('f1'),
          localPath: const Value('/cache/f1.enc'),
          sizeOnDisk: const Value(5000),
          pinned: const Value(true),
        ),
      );

      final file = await db.getOfflineFile('a1', 'f1');
      expect(file, isNotNull);
      expect(file!.localPath, '/cache/f1.enc');
      expect(file.pinned, true);
      expect(file.sizeOnDisk, 5000);
    });

    test('getOfflineFile returns entry or null', () async {
      await db.insertOfflineFile(
        OfflineFilesCompanion(
          accountId: const Value('a1'),
          fileId: const Value('f1'),
          localPath: const Value('/cache/f1.enc'),
        ),
      );

      expect(await db.getOfflineFile('a1', 'f1'), isNotNull);
      expect(await db.getOfflineFile('a1', 'f2'), isNull);
    });

    test('deleteOfflineFile removes entry', () async {
      await db.insertOfflineFile(
        OfflineFilesCompanion(
          accountId: const Value('a1'),
          fileId: const Value('f1'),
          localPath: const Value('/cache/f1.enc'),
        ),
      );

      await db.deleteOfflineFile('a1', 'f1');

      final file = await db.getOfflineFile('a1', 'f1');
      expect(file, isNull);
    });

    test('deleteAllOfflineFiles clears account', () async {
      await db.insertOfflineFile(
        OfflineFilesCompanion(
          accountId: const Value('a1'),
          fileId: const Value('f1'),
          localPath: const Value('/cache/f1.enc'),
        ),
      );
      await db.insertOfflineFile(
        OfflineFilesCompanion(
          accountId: const Value('a1'),
          fileId: const Value('f2'),
          localPath: const Value('/cache/f2.enc'),
        ),
      );

      await db.deleteAllOfflineFiles('a1');

      expect(await db.getOfflineFile('a1', 'f1'), isNull);
      expect(await db.getOfflineFile('a1', 'f2'), isNull);
    });

    test(
      'getEvictableFiles returns non-pinned ordered by lastAccess',
      () async {
        await db.insertOfflineFile(
          OfflineFilesCompanion(
            accountId: const Value('a1'),
            fileId: const Value('pinned'),
            localPath: const Value('/cache/p.enc'),
            pinned: const Value(true),
          ),
        );
        await db.insertOfflineFile(
          OfflineFilesCompanion(
            accountId: const Value('a1'),
            fileId: const Value('auto'),
            localPath: const Value('/cache/a.enc'),
            pinned: const Value(false),
          ),
        );

        final evictable = await db.getEvictableFiles('a1');
        expect(evictable.length, 1);
        expect(evictable[0].fileId, 'auto');
      },
    );
  });

  // ── PendingUploads schema v12 migration ────────────────────────────
  //
  // Recreate the pre-v12 pending_uploads shape (no retry_count /
  // next_retry_at columns), replay the v11 -> v12 step of the real
  // migration strategy, and check both that the new columns exist and
  // that an existing row carries forward with expected defaults.
  //
  // Lives in its own group so the outer [setUp] that opens a full v12
  // schema doesn't race the bespoke v11 shape built inside the test.
  group('PendingUploads v12 migration', () {
    test('adds retry_count + next_retry_at columns to v11 database', () async {
      final silenceWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = silenceWarning;
      });

      final migrationDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(migrationDb.close);

      await migrationDb.customStatement('DROP TABLE pending_uploads');
      await migrationDb.customStatement('''
        CREATE TABLE pending_uploads (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          account_id TEXT NOT NULL,
          local_path TEXT NOT NULL,
          target_dir_id TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      await migrationDb.customStatement(
        'INSERT INTO pending_uploads(account_id, local_path) '
        "VALUES ('a1', '/tmp/pre_migration.jpg')",
      );

      final migrator = Migrator(migrationDb);
      await migrationDb.migration.onUpgrade(migrator, 11, 12);

      final rows = await migrationDb
          .customSelect(
            'SELECT id, retry_count, next_retry_at '
            'FROM pending_uploads WHERE account_id = ?',
            variables: [Variable<String>('a1')],
          )
          .get();
      expect(rows.length, 1);
      expect(rows.single.read<int>('retry_count'), 0);
      expect(rows.single.readNullable<DateTime>('next_retry_at'), isNull);
    });
  });

  // ── Free-pivot v18 migration ───────────────────────────────────────
  //
  // v18 drops the subscriptions table left behind by the paid era. Two
  // paths matter: a database that has the table loses it, and a database
  // that never had it (pre-v5 installs) upgrades without error.
  group('subscriptions v18 migration', () {
    Future<bool> subscriptionsTableExists(AppDatabase target) async {
      final rows = await target
          .customSelect(
            'SELECT name FROM sqlite_master '
            "WHERE type = 'table' AND name = 'subscriptions'",
          )
          .get();
      return rows.isNotEmpty;
    }

    test('drops the subscriptions table from a v17 database', () async {
      final silenceWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = silenceWarning;
      });

      final migrationDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(migrationDb.close);

      await migrationDb.customStatement('''
        CREATE TABLE subscriptions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          trial_started_at INTEGER,
          cached_status TEXT NOT NULL DEFAULT 'unknown'
        );
      ''');
      expect(await subscriptionsTableExists(migrationDb), isTrue);

      final migrator = Migrator(migrationDb);
      await migrationDb.migration.onUpgrade(migrator, 17, 18);

      expect(await subscriptionsTableExists(migrationDb), isFalse);
    });

    test('upgrading a database that never had the table succeeds', () async {
      final silenceWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = silenceWarning;
      });

      final migrationDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(migrationDb.close);

      final migrator = Migrator(migrationDb);
      await migrationDb.migration.onUpgrade(migrator, 17, 18);

      expect(await subscriptionsTableExists(migrationDb), isFalse);
    });
  });

  // ── Create-then-extend migration steps ─────────────────────────────
  //
  // A step that creates a table must build the shape that table had at that
  // version, not the shape it has today. `m.createTable` does the latter, so
  // an old step silently changes meaning every time a column is added — and
  // then the step that adds the column runs against a table that already has
  // it and the whole upgrade throws.
  //
  // This is what shipped: v21 added `output_path` to a `pending_downloads`
  // that v20 had just created complete, so any install older than v20 could
  // not open its database at all. Only devices that had already run a v20
  // build escaped, which is why every simulator here was fine and a phone
  // was not.
  group('create-then-extend steps', () {
    // `forTesting` builds today's schema, so replaying an older range would
    // re-add columns that are already there. Clearing what the intervening
    // steps add puts the database back in the shape that range expects.
    Future<AppDatabase> upgradedFrom(
      int from, {
      required List<String> drop,
      List<String> dropColumns = const [],
      int to = 21,
    }) async {
      final silence = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = silence;
      });

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // An install from before the creating step has no such table.
      for (final table in drop) {
        await db.customStatement('DROP TABLE IF EXISTS $table');
      }
      for (final column in dropColumns) {
        await db.customStatement('ALTER TABLE $column');
      }
      await db.migration.onUpgrade(Migrator(db), from, to);
      return db;
    }

    Future<List<String>> columnsOf(AppDatabase db, String table) async {
      final rows =
          await db.customSelect("SELECT name FROM pragma_table_info('$table')").get();
      return rows.map((r) => r.read<String>('name')).toList();
    }

    test('pending_downloads: created at v20, extended at v21', () async {
      final db = await upgradedFrom(19, drop: ['pending_downloads']);
      final columns = await columnsOf(db, 'pending_downloads');
      expect(columns.where((c) => c == 'output_path'), hasLength(1));
      expect(columns, containsAll(['account_id', 'file_id', 'output_dir']));
    });

    test('trusted_fingerprints: created at v16, extended at v19', () async {
      final db = await upgradedFrom(
        15,
        drop: ['trusted_fingerprints'],
        // v17 adds this to accounts; the current table already has it.
        dropColumns: ['accounts DROP COLUMN wrapping_public_key'],
        to: 19,
      );
      final columns = await columnsOf(db, 'trusted_fingerprints');
      expect(columns.where((c) => c == 'email'), hasLength(1));
      expect(columns, containsAll(['owner_user_id', 'user_id', 'fingerprint']));
    });

    test('mcp_settings: created at v10, extended at v14 and v15', () async {
      final db = await upgradedFrom(
        9,
        drop: ['mcp_settings', 'mcp_audit_log'],
        // v12 adds these to pending_uploads; the current table has them.
        dropColumns: [
          'pending_uploads DROP COLUMN retry_count',
          'pending_uploads DROP COLUMN next_retry_at',
        ],
        to: 15,
      );
      final columns = await columnsOf(db, 'mcp_settings');
      for (final added in const [
        'allow_read_only_while_locked',
        'rate_limit_rps',
        'rate_limit_burst',
        'audit_retention_days',
        'last_audit_cleanup_at',
      ]) {
        expect(columns.where((c) => c == added), hasLength(1), reason: added);
      }
    });

    // The guard against regression: a step may neither build a table from the
    // live Dart definition, because that is the thing that goes stale, nor add
    // a column unguarded, because a retried step meets its own finished work.
    test('every step freezes its DDL and guards its columns', () {
      final source = File('lib/core/storage/database.dart').readAsStringSync();
      final steps = source.substring(
        source.indexOf('Future<int> _upgradeStep('),
        source.indexOf('static Future<void> _addColumn('),
      );
      expect(
        steps.contains('m.createTable('),
        isFalse,
        reason: 'freeze the DDL at the version the step belongs to instead',
      );
      expect(
        steps.contains('m.addColumn('),
        isFalse,
        reason: 'go through _addColumn so a retried step skips its own work',
      );
    });
  });

  // ── Interrupted upgrades ───────────────────────────────────────────
  //
  // Drift runs `onUpgrade` outside a transaction, so a step that throws leaves
  // everything it had already issued committed in the file. Two properties
  // keep that survivable, and both are checked here: the version advances one
  // step at a time so a retry resumes where it stopped, and every step is
  // idempotent so the retry gets past its own leftovers.
  group('interrupted upgrades', () {
    Future<AppDatabase> memoryDb() async {
      final silence = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = silence;
      });

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      return db;
    }

    Future<int> userVersion(AppDatabase db) async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      return row.read<int>('user_version');
    }

    Future<Map<String, List<String>>> schemaOf(AppDatabase db) async {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .get();
      final schema = <String, List<String>>{};
      for (final table in tables.map((r) => r.read<String>('name'))) {
        final columns = await db
            .customSelect(
              "SELECT name FROM pragma_table_info('$table') ORDER BY name",
            )
            .get();
        schema[table] = columns.map((r) => r.read<String>('name')).toList();
      }
      return schema;
    }

    // The failure that shipped. An older build created `pending_downloads`
    // from the live definition at v20, complete with `output_path`, and then
    // threw adding that column at v21 — leaving the table behind at version
    // 19. Every launch after that met its own table again.
    test('resumes past a table an aborted run already created', () async {
      final db = await memoryDb();

      await db.customStatement('DROP TABLE pending_downloads');
      await db.customStatement('''
        CREATE TABLE pending_downloads (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          account_id TEXT NOT NULL,
          file_id TEXT NOT NULL,
          chunk_count INTEGER NOT NULL,
          output_dir TEXT NOT NULL,
          output_path TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
          UNIQUE (account_id, file_id)
        )
      ''');
      await db.customStatement('PRAGMA user_version = 19');

      await db.migration.onUpgrade(Migrator(db), 19, 21);

      final columns = await db
          .customSelect("SELECT name FROM pragma_table_info('pending_downloads')")
          .get();
      expect(
        columns.map((r) => r.read<String>('name')).where((c) => c == 'output_path'),
        hasLength(1),
      );
      expect(await userVersion(db), 21);
    });

    test('replaying every step over a current database changes nothing', () async {
      final db = await memoryDb();
      final before = await schemaOf(db);

      await db.migration.onUpgrade(Migrator(db), 1, 21);

      expect(await schemaOf(db), before);
    });

    test('a failing step leaves the version at the last one that finished',
        () async {
      final db = await memoryDb();

      // v7 is the first step to touch `servers`; without the table its
      // `ALTER TABLE` throws the way any genuinely broken step would.
      await db.customStatement('DROP TABLE servers');
      await db.customStatement('PRAGMA user_version = 1');

      await expectLater(
        db.migration.onUpgrade(Migrator(db), 1, 21),
        throwsA(isA<SqliteException>()),
      );

      // Steps 1 through 5 finished; the run stopped upgrading 6 to 7.
      expect(await userVersion(db), 6);
    });
  });
}
