import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/migrations/registry.dart';
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
  // ── Migrations ─────────────────────────────────────────────────────
  //
  // What runs is decided by the `schema_migrations` ledger, so a test database
  // cannot be aged by version number alone: `forTesting` builds the current
  // schema through `onCreate`, which records every migration as applied. A
  // device that predates the ledger has no such table, and dropping it is what
  // actually reproduces one.
  group('migrations', () {
    Future<AppDatabase> deviceAt(
      int version, {
      List<String> drop = const [],
      List<String> alter = const [],
    }) async {
      final silence = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = silence;
      });

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement('DROP TABLE schema_migrations');
      for (final table in drop) {
        await db.customStatement('DROP TABLE IF EXISTS $table');
      }
      for (final statement in alter) {
        await db.customStatement('ALTER TABLE $statement');
      }
      await db.customStatement('PRAGMA user_version = $version');
      return db;
    }

    Future<List<String>> columnsOf(AppDatabase db, String table) async {
      final rows = await db
          .customSelect("SELECT name FROM pragma_table_info('$table')")
          .get();
      return rows.map((r) => r.read<String>('name')).toList();
    }

    Future<List<String>> appliedNames(AppDatabase db) async {
      final rows = await db
          .customSelect('SELECT name FROM schema_migrations ORDER BY version')
          .get();
      return rows.map((r) => r.read<String>('name')).toList();
    }

    Future<void> upgrade(AppDatabase db, int from) => db.migration.onUpgrade(
      Migrator(db),
      from,
      AppDatabase.currentSchemaVersion,
    );

    test(
      'a database that predates the ledger keeps what it already has',
      () async {
        final db = await deviceAt(19);

        await upgrade(db, 19);

        // Everything up to the installed version is adopted rather than re-run;
        // only what is genuinely missing applies.
        final applied = await appliedNames(db);
        expect(applied, contains('add_accounts_biometric_pin'));
        expect(applied.last, 'rebuild_pending_downloads_file_size');
        expect(applied.toSet(), hasLength(applied.length));
      },
    );

    // The failure that shipped. An earlier build created `pending_downloads`
    // from the live definition, complete with `output_path`, then threw adding
    // that column — leaving the table behind at version 19. Every launch after
    // met its own table again and the app could not open its database at all.
    test('heals a table an aborted upgrade already created', () async {
      final db = await deviceAt(19);
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

      await upgrade(db, 19);

      final columns = await columnsOf(db, 'pending_downloads');
      expect(columns.where((c) => c == 'output_path'), hasLength(1));
    });

    test('adds the retry columns to a database that predates them', () async {
      final db = await deviceAt(
        11,
        alter: const [
          'pending_uploads DROP COLUMN retry_count',
          'pending_uploads DROP COLUMN next_retry_at',
        ],
      );
      await db.customStatement(
        'INSERT INTO pending_uploads(account_id, local_path) '
        "VALUES ('a1', '/tmp/pre_migration.jpg')",
      );

      await upgrade(db, 11);

      final row = await db
          .customSelect(
            'SELECT retry_count, next_retry_at FROM pending_uploads '
            'WHERE account_id = ?',
            variables: [Variable<String>('a1')],
          )
          .getSingle();
      expect(row.read<int>('retry_count'), 0);
      expect(row.readNullable<DateTime>('next_retry_at'), isNull);
    });

    test('drops the subscriptions table the paid app left behind', () async {
      final db = await deviceAt(17);
      await db.customStatement('''
        CREATE TABLE subscriptions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          trial_started_at INTEGER,
          cached_status TEXT NOT NULL DEFAULT 'unknown'
        )
      ''');

      await upgrade(db, 17);

      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = 'subscriptions'",
          )
          .get();
      expect(rows, isEmpty);
    });

    test('upgrades a database that never had subscriptions', () async {
      final db = await deviceAt(17);
      await expectLater(upgrade(db, 17), completes);
    });

    // Sqlite will not add a NOT NULL column with an expression default to a
    // table that has rows, and `last_accessed_at` defaults to the current
    // time. Adding it works on an empty table and fails on exactly the devices
    // that have offline files, so v4 carries the rows across instead.
    test('carries offline files across the v4 rebuild', () async {
      final db = await deviceAt(
        3,
        alter: const [
          'offline_files DROP COLUMN size_on_disk',
          'offline_files DROP COLUMN pinned',
          'offline_files DROP COLUMN last_accessed_at',
        ],
      );
      await db.customStatement(
        'INSERT INTO offline_files(account_id, file_id, local_path) '
        "VALUES ('a1', 'f1', '/tmp/kept.bin')",
      );

      await upgrade(db, 3);

      final row = await db
          .customSelect(
            'SELECT local_path, size_on_disk, pinned, last_accessed_at '
            "FROM offline_files WHERE file_id = 'f1'",
          )
          .getSingle();
      expect(row.read<String>('local_path'), '/tmp/kept.bin');
      expect(row.read<int>('size_on_disk'), 0);
      expect(row.read<int>('last_accessed_at'), greaterThan(0));
    });

    test('reaches every table a later migration extends', () async {
      const extended = {
        'trusted_fingerprints': ['email', 'owner_user_id', 'fingerprint'],
        'mcp_settings': [
          'allow_read_only_while_locked',
          'rate_limit_rps',
          'audit_retention_days',
          'last_audit_cleanup_at',
        ],
        'pending_downloads': ['output_path', 'output_dir', 'chunk_count'],
      };
      for (final table in extended.entries) {
        final db = await deviceAt(1, drop: [table.key]);
        await upgrade(db, 1);
        expect(
          await columnsOf(db, table.key),
          containsAll(table.value),
          reason: table.key,
        );
      }
    });

    test('running the whole registry again changes nothing', () async {
      final db = await deviceAt(1);
      await upgrade(db, 1);

      Future<Map<String, List<String>>> shape() async {
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name NOT LIKE 'sqlite_%' ORDER BY name",
            )
            .get();
        return {
          for (final t in tables.map((r) => r.read<String>('name')))
            t: await columnsOf(db, t),
        };
      }

      final before = await shape();
      await db.customStatement('DELETE FROM schema_migrations');
      await upgrade(db, 1);

      expect(await shape(), before);
    });

    test(
      'a failing migration records neither itself nor what follows',
      () async {
        // v7 is the first migration to touch `servers`; without the table its
        // ALTER throws the way any genuinely broken migration would.
        final db = await deviceAt(1, drop: ['servers']);

        await expectLater(upgrade(db, 1), throwsA(isA<SqliteException>()));

        final applied = await appliedNames(db);
        expect(applied, contains('rebuild_offline_files_cache_columns'));
        expect(applied, isNot(contains('add_servers_trust_self_signed_certs')));
        expect(applied, isNot(contains('create_mcp_settings')));
      },
    );
  });

  // ── Registry invariants ────────────────────────────────────────────
  group('migration registry', () {
    const steps = 'lib/core/storage/migrations/steps';

    test('versions strictly increase and names are unique', () {
      final versions = [for (final m in migrations) m.version];
      expect(versions, orderedEquals(versions.toList()..sort()));
      expect(versions.toSet(), hasLength(versions.length));
      expect({
        for (final m in migrations) m.name,
      }, hasLength(migrations.length));
    });

    test('the schema version is the last migration', () {
      expect(AppDatabase.currentSchemaVersion, migrations.last.version);
    });

    test('each file is named for the migration it holds', () {
      for (final m in migrations) {
        final padded = m.version.toString().padLeft(4, '0');
        expect(
          File('$steps/m${padded}_${m.name}.dart').existsSync(),
          isTrue,
          reason: m.name,
        );
      }
    });

    // A migration that could reach the current table definitions would go
    // stale every time one changed, which is how a step creating a table
    // complete ended up followed by a step adding a column it already had.
    test('no migration can see the current schema', () {
      for (final file in Directory(steps).listSync().whereType<File>()) {
        expect(
          file.readAsStringSync(),
          isNot(contains('database.dart')),
          reason: file.path,
        );
      }
    });

    // Dropping any of these is not a recoverable annoyance: accounts hold the
    // encrypted private keys, and trusted fingerprints are the record that
    // makes a changed key visible instead of silently re-trusted.
    test('nothing rebuilds a table that cannot be rebuilt', () {
      for (final file in Directory(steps).listSync().whereType<File>()) {
        final source = file.readAsStringSync();
        for (final durable in const [
          'servers',
          'accounts',
          'trusted_fingerprints',
        ]) {
          expect(
            source,
            isNot(matches(RegExp('(DROP TABLE|rebuild)[^;]*$durable'))),
            reason: '${file.path} must not drop $durable',
          );
        }
      }
    });
  });
}
