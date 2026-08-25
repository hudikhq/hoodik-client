import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/offline_cache_lru.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_downloads_dao.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _account(AppDatabase db, {int? limit}) async {
  await db.insertAccount(
    AccountsCompanion(
      id: const Value('a1'),
      serverId: const Value('s1'),
      userId: const Value('u1'),
      email: const Value('t@t.com'),
      cacheLimitBytes: Value(limit),
    ),
  );
}

Future<void> _file(
  AppDatabase db, {
  required String id,
  required int size,
  required DateTime accessed,
  bool pinned = false,
}) {
  return db.insertOfflineFile(
    OfflineFilesCompanion(
      accountId: const Value('a1'),
      fileId: Value(id),
      localPath: Value('/cache/$id'),
      sizeOnDisk: Value(size),
      pinned: Value(pinned),
      lastAccessedAt: Value(accessed),
    ),
  );
}

void main() {
  late AppDatabase db;
  final removed = <String>[];

  setUp(() {
    db = _db();
    removed.clear();
  });

  tearDown(() => db.close());

  Future<void> evict({
    Set<String> keep = const {},
    Set<String> Function()? active,
    Future<Set<String>> Function()? osInFlight,
  }) {
    return enforceOfflineCacheLimit(
      db: db,
      accountId: 'a1',
      keep: keep,
      activeTransferIds: active,
      osInFlightIds: osInFlight ?? () async => {},
      remove: (accountId, fileId) async {
        removed.add(fileId);
        await db.deleteOfflineFile(accountId, fileId);
      },
    );
  }

  test('unpinned over the cap: oldest lastAccessedAt first', () async {
    await _account(db, limit: 1000);
    final t0 = DateTime(2026, 1, 1);
    await _file(db, id: 'old', size: 400, accessed: t0);
    await _file(
      db,
      id: 'mid',
      size: 400,
      accessed: t0.add(const Duration(days: 1)),
    );
    await _file(
      db,
      id: 'new',
      size: 400,
      accessed: t0.add(const Duration(days: 2)),
    );

    await evict();

    expect(removed, ['old']);
    expect(await db.getOfflineCacheSize('a1'), 800);
  });

  test('pinned files are never chosen', () async {
    await _account(db, limit: 100);
    final t0 = DateTime(2026, 1, 1);
    await _file(db, id: 'pin', size: 500, accessed: t0, pinned: true);
    await _file(
      db,
      id: 'loose',
      size: 500,
      accessed: t0.add(const Duration(days: 1)),
    );

    await evict();

    expect(removed, ['loose']);
    expect(await db.getOfflineFile('a1', 'pin'), isNotNull);
  });

  test('the file just registered is in keep and survives', () async {
    await _account(db, limit: 100);
    final t0 = DateTime(2026, 1, 1);
    await _file(db, id: 'keep', size: 80, accessed: t0);
    await _file(
      db,
      id: 'other',
      size: 80,
      accessed: t0.add(const Duration(days: 1)),
    );

    await evict(keep: {'keep'});

    expect(removed, ['other']);
    expect(await db.getOfflineFile('a1', 'keep'), isNotNull);
  });

  test('a pendingDownloads file ID in keep survives', () async {
    await _account(db, limit: 100);
    final t0 = DateTime(2026, 1, 1);
    await _file(db, id: 'pending', size: 80, accessed: t0);
    await _file(
      db,
      id: 'other',
      size: 80,
      accessed: t0.add(const Duration(days: 1)),
    );
    await db.recordPendingDownload(
      accountId: 'a1',
      fileId: 'pending',
      chunkCount: 1,
      fileSize: 80,
      outputDir: '/tmp',
    );

    await evict();

    expect(removed, ['other']);
    expect(await db.getOfflineFile('a1', 'pending'), isNotNull);
  });

  test('a file id in the OS task queue survives', () async {
    await _account(db, limit: 100);
    final t0 = DateTime(2026, 1, 1);
    await _file(db, id: 'os', size: 80, accessed: t0);
    await _file(
      db,
      id: 'other',
      size: 80,
      accessed: t0.add(const Duration(days: 1)),
    );

    await evict(osInFlight: () async => {'os'});

    expect(removed, ['other']);
    expect(await db.getOfflineFile('a1', 'os'), isNotNull);
  });

  test('an active transfer fileId survives', () async {
    await _account(db, limit: 100);
    final t0 = DateTime(2026, 1, 1);
    await _file(db, id: 'xfer', size: 80, accessed: t0);
    await _file(
      db,
      id: 'other',
      size: 80,
      accessed: t0.add(const Duration(days: 1)),
    );

    await evict(active: () => {'xfer'});

    expect(removed, ['other']);
    expect(await db.getOfflineFile('a1', 'xfer'), isNotNull);
  });

  test('cacheLimitBytes == 0 deletes nothing', () async {
    await _account(db, limit: 0);
    await _file(
      db,
      id: 'huge',
      size: kDefaultCacheLimitBytes + 1,
      accessed: DateTime(2026, 1, 1),
    );

    await evict();

    expect(removed, isEmpty);
  });

  test('cacheLimitBytes == null uses 8 GB', () async {
    await _account(db);
    await _file(
      db,
      id: 'over',
      size: kDefaultCacheLimitBytes + 1,
      accessed: DateTime(2026, 1, 1),
    );

    await evict();

    expect(removed, ['over']);
  });

  test('lowering the limit evicts immediately', () async {
    await _account(db, limit: 1000);
    await _file(db, id: 'a', size: 400, accessed: DateTime(2026, 1, 1));
    expect(await db.getOfflineCacheSize('a1'), 400);

    await db.setCacheLimitBytes('a1', 100);
    await evict();

    expect(removed, ['a']);
  });

  test('resolvedCacheLimitBytes: null is 8 GB, 0 is unlimited', () {
    expect(resolvedCacheLimitBytes(null), kDefaultCacheLimitBytes);
    expect(resolvedCacheLimitBytes(0), isNull);
    expect(resolvedCacheLimitBytes(123), 123);
  });
}
