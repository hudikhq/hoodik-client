import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/offline_manager.dart';
import 'package:hoodik_app/core/storage/database.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<Directory> _chunks(int bytes) async {
  final dir = await Directory.systemTemp.createTemp('hoodik_pin_');
  await File('${dir.path}/000000.enc').writeAsBytes(List.filled(bytes, 1));
  return dir;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _db();
  });

  tearDown(() => db.close());

  Future<void> account({int? limit}) {
    return db.insertAccount(
      AccountsCompanion(
        id: const Value('a1'),
        serverId: const Value('s1'),
        userId: const Value('u1'),
        email: const Value('t@t.com'),
        cacheLimitBytes: Value(limit),
      ),
    );
  }

  test('re-registering with pinned: false does not unpin', () async {
    await account(limit: 0);
    final dir = await _chunks(3);
    addTearDown(() => dir.delete(recursive: true));
    final om = OfflineManager(db);

    await om.registerChunks(
      accountId: 'a1',
      fileId: 'f1',
      chunksDir: dir.path,
      chunkCount: 1,
      pinned: true,
    );
    await om.registerChunks(
      accountId: 'a1',
      fileId: 'f1',
      chunksDir: dir.path,
      chunkCount: 1,
    );

    final row = await db.getOfflineFile('a1', 'f1');
    expect(row?.pinned, isTrue);
  });

  test('two overlapping enforceLimit calls do not double-delete', () async {
    await account(limit: 1000);
    final t0 = DateTime(2026, 1, 1);
    for (var i = 0; i < 4; i++) {
      await db.insertOfflineFile(
        OfflineFilesCompanion(
          accountId: const Value('a1'),
          fileId: Value('f$i'),
          localPath: Value('/cache/f$i'),
          sizeOnDisk: const Value(400),
          pinned: const Value(false),
          lastAccessedAt: Value(t0.add(Duration(days: i))),
        ),
      );
    }

    final hold = Completer<void>();
    final om = _GatedOfflineManager(db, hold);
    Future<Set<String>> none() async => {};
    final first = om.enforceLimit('a1', osInFlightIds: none);
    final second = om.enforceLimit('a1', osInFlightIds: none);
    hold.complete();
    await Future.wait([first, second]);

    expect(om.removed.toSet().length, om.removed.length);
    expect(await db.getOfflineCacheSize('a1'), lessThanOrEqualTo(1000));
    expect(om.removed.length, 2);
  });
}

class _GatedOfflineManager extends OfflineManager {
  _GatedOfflineManager(super.db, this._hold);

  final Completer<void> _hold;
  final removed = <String>[];

  @override
  Future<void> removeCachedFile(String accountId, String fileId) async {
    if (!_hold.isCompleted) await _hold.future;
    removed.add(fileId);
    await super.removeCachedFile(accountId, fileId);
  }
}
