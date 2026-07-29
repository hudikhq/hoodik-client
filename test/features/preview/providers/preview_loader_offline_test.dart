import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/core/services/offline_manager.dart';
import 'package:hoodik_app/core/services/transfer_manager.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/preview/providers/preview_loader.dart';

/// Counts [downloadAndPinOffline] calls and records the `pinned` flag
/// per invocation. [onComplete] fires synchronously so test code can
/// `await ensureFileDownloaded` without plumbing a fake transfer.
class _CountingFileOperations extends Fake implements FileOperations {
  int downloadCallCount = 0;
  final List<bool> pinnedArgs = [];
  bool shouldComplete = true;

  @override
  void downloadAndPinOffline(
    FileItem file, {
    String? displayName,
    bool pinned = true,
    void Function()? onComplete,
    void Function(String error)? onError,
  }) {
    downloadCallCount++;
    pinnedArgs.add(pinned);
    if (shouldComplete) {
      onComplete?.call();
    } else {
      onError?.call('test-failure');
    }
  }
}

FileItem _file(String id, {int? finishedUploadAt}) {
  return FileItem(
    id: id,
    encryptedName: 'enc-$id',
    mime: 'text/plain',
    size: 4096,
    chunks: 1,
    finishedUploadAt: finishedUploadAt,
  );
}

void main() {
  const accountId = 'account-1';

  late AppDatabase db;
  late OfflineManager offlineManager;
  late TransferManager transferManager;
  late _CountingFileOperations ops;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    offlineManager = OfflineManager(db);
    transferManager = TransferManager();
    ops = _CountingFileOperations();
  });

  tearDown(() async {
    await db.close();
  });

  /// Record an offline cache entry by going straight at the DB so the
  /// tests don't have to lay down real encrypted chunks on disk.
  Future<void> seedOffline(
    String fileId, {
    bool pinned = false,
    DateTime? downloadedAt,
  }) async {
    await db.insertOfflineFile(
      OfflineFilesCompanion(
        accountId: const Value(accountId),
        fileId: Value(fileId),
        localPath: Value('/tmp/offline_cache/$accountId/$fileId'),
        sizeOnDisk: const Value(4096),
        pinned: Value(pinned),
        downloadedAt: Value(downloadedAt ?? DateTime.now()),
        lastAccessedAt: Value(downloadedAt ?? DateTime.now()),
      ),
    );
  }

  group('ensureFileDownloaded — cache-hit short-circuit', () {
    test(
      'does not re-download when chunks are already cached offline',
      () async {
        final file = _file('file-1');
        await seedOffline(file.id, pinned: true);

        await ensureFileDownloaded(
          offlineManager: offlineManager,
          transferManager: transferManager,
          ops: ops,
          accountId: accountId,
          file: file,
        );

        expect(
          ops.downloadCallCount,
          0,
          reason:
              'Preview must not kick off a download when the file is already '
              'pinned offline — that completely defeats the cache.',
        );
      },
    );

    test(
      'bumps lastAccessedAt so the cache hit slides up in LRU order',
      () async {
        final file = _file('file-1');
        final oldTime = DateTime(2020, 1, 1);
        await seedOffline(file.id, downloadedAt: oldTime);

        await ensureFileDownloaded(
          offlineManager: offlineManager,
          transferManager: transferManager,
          ops: ops,
          accountId: accountId,
          file: file,
        );

        final entry = await db.getOfflineFile(accountId, file.id);
        expect(entry, isNotNull);
        expect(
          entry!.lastAccessedAt.isAfter(oldTime),
          isTrue,
          reason: 'Cache hit should refresh lastAccessedAt for LRU fairness.',
        );
      },
    );
  });

  group('ensureFileDownloaded — cold cache', () {
    test('downloads exactly once when nothing is cached', () async {
      final file = _file('file-new');

      await ensureFileDownloaded(
        offlineManager: offlineManager,
        transferManager: transferManager,
        ops: ops,
        accountId: accountId,
        file: file,
      );

      expect(ops.downloadCallCount, 1);
    });

    test('a brand-new file defaults to pinned=false so preview-triggered '
        'downloads stay evictable by LRU', () async {
      final file = _file('file-fresh');

      await ensureFileDownloaded(
        offlineManager: offlineManager,
        transferManager: transferManager,
        ops: ops,
        accountId: accountId,
        file: file,
      );

      expect(ops.pinnedArgs, [false]);
    });
  });

  group('ensureFileDownloaded — in-progress transfer', () {
    test(
      'waits for an active download instead of starting a duplicate',
      () async {
        final file = _file('file-downloading');

        final transferItem = transferManager.startTransfer(
          fileName: 'preview',
          type: TransferType.downloadHttp,
          totalBytes: 4096,
          totalChunks: 1,
          fileId: file.id,
        );

        // Fire-and-forget the ensureFileDownloaded future.
        final future = ensureFileDownloaded(
          offlineManager: offlineManager,
          transferManager: transferManager,
          ops: ops,
          accountId: accountId,
          file: file,
        );

        // Give the listener a chance to attach.
        await Future<void>.delayed(Duration.zero);

        expect(
          ops.downloadCallCount,
          0,
          reason:
              'An existing active transfer should be joined, not duplicated.',
        );

        transferManager.completeTransfer(transferItem.id);
        await future;

        expect(ops.downloadCallCount, 0);
      },
    );
  });
}
