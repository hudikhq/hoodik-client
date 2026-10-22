import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/offline_manager.dart';
import 'package:hoodik_app/core/storage/database.dart';

void main() {
  const accountId = 'account-1';

  late AppDatabase db;
  late OfflineManager manager;
  late Directory chunksDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    manager = OfflineManager(db);
    chunksDir = await Directory.systemTemp.createTemp('hoodik-chunks-');
  });

  tearDown(() async {
    await db.close();
    if (await chunksDir.exists()) await chunksDir.delete(recursive: true);
  });

  Future<void> cacheFile(String fileId) async {
    await db.insertOfflineFile(
      OfflineFilesCompanion(
        accountId: const Value(accountId),
        fileId: Value(fileId),
        localPath: Value(chunksDir.path),
        sizeOnDisk: const Value(0),
        pinned: const Value(false),
        downloadedAt: Value(DateTime.now()),
        lastAccessedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> writeChunk(int index, List<int> bytes) async {
    await File(
      '${chunksDir.path}/${index.toString().padLeft(6, '0')}.enc',
    ).writeAsBytes(bytes);
  }

  Uint8List identity(Uint8List encrypted, int index) => encrypted;

  test('concatenates decrypted chunks in order', () async {
    await cacheFile('file-1');
    await writeChunk(0, [1, 2, 3]);
    await writeChunk(1, [4, 5]);

    final bytes = await manager.decryptToMemory(
      accountId: accountId,
      fileId: 'file-1',
      chunkCount: 2,
      decryptChunk: identity,
    );

    expect(bytes, [1, 2, 3, 4, 5]);
  });

  test('passes each chunk index to the decryptor', () async {
    await cacheFile('file-2');
    await writeChunk(0, [10]);
    await writeChunk(1, [20]);

    final seen = <int>[];
    await manager.decryptToMemory(
      accountId: accountId,
      fileId: 'file-2',
      chunkCount: 2,
      decryptChunk: (encrypted, index) {
        seen.add(index);
        return encrypted;
      },
    );

    expect(seen, [0, 1]);
  });

  test('returns null and evicts an incomplete cache', () async {
    await cacheFile('file-3');
    await writeChunk(0, [1]);

    final bytes = await manager.decryptToMemory(
      accountId: accountId,
      fileId: 'file-3',
      chunkCount: 2,
      decryptChunk: identity,
    );

    expect(bytes, isNull);
    expect(await db.getOfflineFile(accountId, 'file-3'), isNull);
  });

  test('returns null and evicts when decryption fails', () async {
    await cacheFile('file-4');
    await writeChunk(0, [1]);

    final bytes = await manager.decryptToMemory(
      accountId: accountId,
      fileId: 'file-4',
      chunkCount: 1,
      decryptChunk: (encrypted, index) => throw StateError('bad tag'),
    );

    expect(bytes, isNull);
    expect(await db.getOfflineFile(accountId, 'file-4'), isNull);
  });

  test('returns null when nothing is cached', () async {
    final bytes = await manager.decryptToMemory(
      accountId: accountId,
      fileId: 'missing',
      chunkCount: 1,
      decryptChunk: identity,
    );

    expect(bytes, isNull);
  });
}
