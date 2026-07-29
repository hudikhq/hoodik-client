import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_uploads_dao.dart';

import '../../helpers/fakes.dart';

/// A fake [FilesClient] that returns controllable file lists.
///
/// Only [listFiles] is implemented since that's all [SyncService] uses.
class _FakeFilesClient extends Fake implements FilesClient {
  List<FileItem> filesToReturn = [];
  bool shouldThrow = false;

  @override
  Future<StorageResponse> listFiles({
    String? dirId,
    bool? editable,
    String? orderBy,
    String? order,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return StorageResponse(children: filesToReturn);
  }
}

/// A fake [ApiClient] that exposes a fake [FilesClient] through its
/// sub-client coordinator getter. Matches the real coordinator shape
/// without pulling in a Dio instance.
class FakeApiClient extends Fake implements ApiClient {
  final _FakeFilesClient _files = _FakeFilesClient();

  @override
  FilesClient get files => _files;

  List<FileItem> get filesToReturn => _files.filesToReturn;
  set filesToReturn(List<FileItem> v) => _files.filesToReturn = v;

  bool get shouldThrow => _files.shouldThrow;
  set shouldThrow(bool v) => _files.shouldThrow = v;
}

void main() {
  late AppDatabase db;
  late FakeConnectivityService connectivity;
  late SyncService syncService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    connectivity = FakeConnectivityService(fakeOnline: true);
    syncService = SyncService(db: db, connectivity: connectivity);
    // Set fields directly — avoids needing a real ApiClient for queue tests.
    syncService.accountId = 'test-account';
  });

  tearDown(() async {
    syncService.deactivate();
    await db.close();
  });

  group('fetchFiles', () {
    test('returns empty list with isFromCache when no client', () async {
      // apiClient is null — should return empty cache result
      final result = await syncService.fetchFiles(dirId: null);

      expect(result.files, isEmpty);
      expect(result.isFromCache, true);
    });

    test('returns cached data when deactivated', () async {
      syncService.deactivate();

      final result = await syncService.fetchFiles(dirId: null);
      expect(result.files, isEmpty);
      expect(result.isFromCache, true);
    });
  });

  group('queueUpload', () {
    test('inserts pending upload into database', () async {
      await syncService.queueUpload(
        localPath: '/tmp/photo.jpg',
        targetDirId: 'dir1',
      );

      final uploads = await db.getPendingUploads('test-account');
      expect(uploads.length, 1);
      expect(uploads[0].localPath, '/tmp/photo.jpg');
      expect(uploads[0].targetDirId, 'dir1');
      expect(uploads[0].status, 'pending');
    });

    test('increments pendingUploadCount', () async {
      expect(syncService.pendingUploadCount, 0);

      await syncService.queueUpload(localPath: '/tmp/a.jpg');
      expect(syncService.pendingUploadCount, 1);

      await syncService.queueUpload(localPath: '/tmp/b.jpg');
      expect(syncService.pendingUploadCount, 2);
    });

    test('does nothing when deactivated', () async {
      syncService.deactivate();

      await syncService.queueUpload(localPath: '/tmp/photo.jpg');

      // Can't query for null account, but count should be 0
      expect(syncService.pendingUploadCount, 0);
    });
  });

  group('uploadFileOrQueue', () {
    test('queues when offline', () async {
      connectivity.fakeOnline = false;

      await syncService.uploadFileOrQueue(
        localPath: '/tmp/photo.jpg',
        parentDirId: 'dir1',
      );

      expect(syncService.pendingUploadCount, 1);
    });

    test('queues when no fileOperations', () async {
      // fileOperations is null — should queue instead of upload
      await syncService.uploadFileOrQueue(localPath: '/tmp/photo.jpg');

      expect(syncService.pendingUploadCount, 1);
    });
  });

  group('processPendingUploads', () {
    test('does nothing when offline', () async {
      await syncService.queueUpload(localPath: '/tmp/photo.jpg');
      connectivity.fakeOnline = false;

      await syncService.processPendingUploads();

      // Upload should still be pending
      expect(syncService.pendingUploadCount, 1);
    });

    test('does nothing when no fileOperations', () async {
      await syncService.queueUpload(localPath: '/tmp/photo.jpg');

      await syncService.processPendingUploads();

      // No fileOperations = no processing
      expect(syncService.pendingUploadCount, 1);
    });

    test('does not process concurrently', () async {
      await syncService.queueUpload(localPath: '/tmp/photo.jpg');

      // Process twice simultaneously
      final f1 = syncService.processPendingUploads();
      final f2 = syncService.processPendingUploads();
      await Future.wait([f1, f2]);

      // Should not throw or double-process
      expect(syncService.processingQueue, false);
    });
  });

  group('activate / deactivate', () {
    test('setting accountId and refreshing count', () async {
      // Queue something first
      await syncService.queueUpload(localPath: '/tmp/a.jpg');
      expect(syncService.pendingUploadCount, 1);

      // Deactivate clears state
      syncService.deactivate();
      expect(syncService.pendingUploadCount, 0);
      expect(syncService.processingQueue, false);

      // Re-set accountId and manually refresh
      syncService.accountId = 'test-account';
    });

    test('deactivate resets all state', () async {
      syncService.deactivate();

      expect(syncService.pendingUploadCount, 0);
      expect(syncService.processingQueue, false);
    });
  });

  group('isOnline', () {
    test('reflects connectivity state', () {
      connectivity.fakeOnline = true;
      expect(syncService.isOnline, true);

      connectivity.fakeOnline = false;
      expect(syncService.isOnline, false);
    });
  });

  group('DirectoryListingResult', () {
    test('stores files and isFromCache flag', () {
      final result = DirectoryListingResult(
        files: [FileItem(id: 'f1', encryptedName: 'enc', mime: 'text/plain')],
        isFromCache: true,
      );

      expect(result.files.length, 1);
      expect(result.isFromCache, true);
    });

    test('empty result', () {
      const result = DirectoryListingResult(files: [], isFromCache: false);
      expect(result.files, isEmpty);
      expect(result.isFromCache, false);
    });
  });

  // ── Disposal / lifecycle tests (Bug 1) ──────────────────────────────

  group('dispose / lifecycle', () {
    test('dispose clears onReconnected callback', () {
      syncService.dispose();

      // Reconnect should be safe — callback was cleared.
      expect(() => connectivity.simulateReconnect(), returnsNormally);
    });

    test('notifyListeners is not called after dispose', () async {
      var notified = false;
      syncService.addListener(() => notified = true);

      syncService.dispose();

      // Queue an upload — internally calls _refreshPendingCount → notifyListeners
      // but the disposed guard should prevent it.
      // (accountId is still set from setUp, so the DB write succeeds;
      //  only the notification should be suppressed.)
      await syncService.queueUpload(localPath: '/tmp/a.jpg');

      expect(notified, false);
    });

    test('reconnect after dispose does not throw', () {
      syncService.dispose();

      // Even if something externally triggers simulateReconnect on the
      // connectivity service, the disposed SyncService ignores it.
      expect(() => connectivity.simulateReconnect(), returnsNormally);
    });

    test('processPendingUploads is a no-op after dispose', () async {
      await syncService.queueUpload(localPath: '/tmp/a.jpg');

      syncService.dispose();

      // Should complete without throwing.
      await expectLater(syncService.processPendingUploads(), completes);
    });
  });

  // ── Cache consistency tests (Bug 3) ──────────────────────────────────

  group('cache consistency', () {
    late FakeApiClient fakeClient;

    final file1 = FileItem(id: 'f1', encryptedName: 'enc1', mime: 'text/plain');
    final file2 = FileItem(id: 'f2', encryptedName: 'enc2', mime: 'image/png');

    setUp(() {
      fakeClient = FakeApiClient();
      syncService.apiClient = fakeClient;
    });

    test('fetchFiles caches results and returns from cache on error', () async {
      fakeClient.filesToReturn = [file1, file2];

      // First fetch — server returns data, caches it.
      final result = await syncService.fetchFiles(dirId: null);
      expect(result.files.length, 2);
      expect(result.isFromCache, false);

      // Simulate network failure.
      fakeClient.shouldThrow = true;

      // Second fetch — falls back to cache.
      final cached = await syncService.fetchFiles(dirId: null);
      expect(cached.files.length, 2);
      expect(cached.isFromCache, true);
      expect(cached.files.map((f) => f.id).toSet(), {'f1', 'f2'});
    });

    test('stale files are removed from cache after server fetch', () async {
      // First: server has both files.
      fakeClient.filesToReturn = [file1, file2];
      await syncService.fetchFiles(dirId: null);

      // Second: file2 was deleted on the server.
      fakeClient.filesToReturn = [file1];
      await syncService.fetchFiles(dirId: null);

      // Now go offline — cache should only have file1.
      fakeClient.shouldThrow = true;
      final cached = await syncService.fetchFiles(dirId: null);
      expect(cached.files.length, 1);
      expect(cached.files.first.id, 'f1');
    });

    test('cache is consistent immediately after fetchFiles returns', () async {
      fakeClient.filesToReturn = [file1];
      await syncService.fetchFiles(dirId: null);

      // Verify cache directly — the await guarantees consistency.
      final cachedRows = await db.getFilesInDir('test-account', null);
      expect(cachedRows.length, 1);
      expect(cachedRows.first.id, 'f1');
    });
  });
}
