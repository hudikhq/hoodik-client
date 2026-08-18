import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_downloads_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.insertServer(
      ServersCompanion(
        id: const Value('s1'),
        url: const Value('https://drive.test'),
        name: const Value('Test'),
      ),
    );
    for (final id in ['a1', 'a2']) {
      await db.insertAccount(
        AccountsCompanion(
          id: Value(id),
          serverId: const Value('s1'),
          userId: Value('u-$id'),
          email: Value('$id@test.io'),
        ),
      );
    }
  });

  tearDown(() async => await db.close());

  test('records a download and reads it back for that account only', () async {
    await db.recordPendingDownload(
      accountId: 'a1',
      fileId: 'f1',
      chunkCount: 3,
      outputDir: '/tmp/a1/f1',
    );
    await db.recordPendingDownload(
      accountId: 'a2',
      fileId: 'f2',
      chunkCount: 5,
      outputDir: '/tmp/a2/f2',
    );

    final mine = await db.getPendingDownloads('a1');
    expect(mine, hasLength(1));
    expect(mine.single.fileId, 'f1');
    expect(mine.single.chunkCount, 3);
  });

  // Tapping download twice on a running transfer must not race two rows into
  // the same output directory.
  test('recording the same file twice updates rather than duplicates', () async {
    await db.recordPendingDownload(
      accountId: 'a1',
      fileId: 'f1',
      chunkCount: 3,
      outputDir: '/tmp/old',
    );
    await db.recordPendingDownload(
      accountId: 'a1',
      fileId: 'f1',
      chunkCount: 7,
      outputDir: '/tmp/new',
    );

    final rows = await db.getPendingDownloads('a1');
    expect(rows, hasLength(1));
    expect(rows.single.chunkCount, 7);
    expect(rows.single.outputDir, '/tmp/new');
  });

  test('clearing removes only that file', () async {
    await db.recordPendingDownload(
      accountId: 'a1', fileId: 'f1', chunkCount: 1, outputDir: '/tmp/1');
    await db.recordPendingDownload(
      accountId: 'a1', fileId: 'f2', chunkCount: 1, outputDir: '/tmp/2');

    await db.clearPendingDownload(accountId: 'a1', fileId: 'f1');

    final rows = await db.getPendingDownloads('a1');
    expect(rows.map((r) => r.fileId), ['f2']);
  });

  // Deleting an account must not leave its unfinished transfers behind for
  // whoever signs in next.
  test('deleting an account drops its pending downloads', () async {
    await db.recordPendingDownload(
      accountId: 'a1', fileId: 'f1', chunkCount: 1, outputDir: '/tmp/1');
    await db.recordPendingDownload(
      accountId: 'a2', fileId: 'f2', chunkCount: 1, outputDir: '/tmp/2');

    await db.deleteAccount('a1');

    expect(await db.getPendingDownloads('a1'), isEmpty);
    expect(await db.getPendingDownloads('a2'), hasLength(1));
  });

  test('other-account rows are cleared wholesale on sign-in', () async {
    await db.recordPendingDownload(
      accountId: 'a1', fileId: 'f1', chunkCount: 1, outputDir: '/tmp/1');
    await db.recordPendingDownload(
      accountId: 'a2', fileId: 'f2', chunkCount: 1, outputDir: '/tmp/2');

    await db.clearPendingDownloadsForOtherAccounts('a1');

    expect(await db.getPendingDownloads('a1'), hasLength(1));
    expect(await db.getPendingDownloads('a2'), isEmpty);
  });
}
