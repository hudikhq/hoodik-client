import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/core/services/pending_upload_status.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_uploads_dao.dart';

import '../../helpers/fakes.dart';

/// FileOperations test double whose [uploadFile] outcome is scripted
/// per invocation. Anything outside of [SyncService]'s retry path is
/// bypassed — upload() just succeeds or throws as configured.
class _ScriptedFileOperations extends Fake implements FileOperations {
  /// Per-localPath queues of outcomes: true = succeed, false = throw.
  /// Consumed from the front on each [uploadFile] call.
  final Map<String, List<bool>> outcomes = {};

  /// Records each upload attempt in order (for assertions on retry count).
  final List<String> attemptLog = [];

  void scriptFailure(String localPath, {int times = 1}) {
    outcomes.putIfAbsent(localPath, () => []).addAll(List.filled(times, false));
  }

  void scriptSuccess(String localPath, {int times = 1}) {
    outcomes.putIfAbsent(localPath, () => []).addAll(List.filled(times, true));
  }

  @override
  Future<void> uploadFile(
    String localPath, {
    String? parentDirId,
    void Function(double progress)? onProgress,
    String? stagingId,
  }) async {
    attemptLog.add(localPath);
    final queue = outcomes[localPath];
    if (queue == null || queue.isEmpty) {
      throw StateError('No scripted outcome for $localPath');
    }
    final shouldSucceed = queue.removeAt(0);
    if (!shouldSucceed) {
      throw Exception('Scripted upload failure for $localPath');
    }
  }
}

void main() {
  late AppDatabase db;
  late FakeConnectivityService connectivity;
  late _ScriptedFileOperations ops;
  late SyncService sync;
  late DateTime fakeNow;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    connectivity = FakeConnectivityService(fakeOnline: true);
    ops = _ScriptedFileOperations();
    fakeNow = DateTime(2026, 4, 19, 12);
    sync = SyncService(
      db: db,
      connectivity: connectivity,
      clock: () => fakeNow,
    );
    sync.accountId = 'acct';
    sync.apiClient = _StubApiClient();
    sync.fileOperations = ops;
  });

  tearDown(() async {
    sync.deactivate();
    sync.dispose();
    await db.close();
  });

  Future<PendingUpload> queue(String path) async {
    // The retry pass drops rows whose source file is gone before it ever
    // calls FileOperations, so a queued path has to exist on disk.
    File(path).writeAsBytesSync([1]);
    addTearDown(() => File(path).deleteSync());
    final row = await db.insertPendingUpload(
      PendingUploadsCompanion.insert(accountId: 'acct', localPath: path),
    );
    return row;
  }

  Future<PendingUpload> reload(int id) async {
    return (db.select(
      db.pendingUploads,
    )..where((u) => u.id.equals(id))).getSingle();
  }

  group('exponential backoff schedule', () {
    test('first failure sets next_retry_at 30s in the future', () async {
      final row = await queue('/tmp/a.jpg');
      ops.scriptFailure(row.localPath);

      await sync.processPendingUploads();

      final updated = await reload(row.id);
      expect(updated.retryCount, 1);
      expect(updated.status, PendingUploadStatus.pending);
      expect(updated.nextRetryAt, fakeNow.add(const Duration(seconds: 30)));
    });

    test('second failure sets 60s backoff', () async {
      final row = await queue('/tmp/b.jpg');
      ops.scriptFailure(row.localPath, times: 2);

      await sync.processPendingUploads();
      // Advance past the 30s cooldown so the second attempt runs.
      fakeNow = fakeNow.add(const Duration(seconds: 31));
      await sync.processPendingUploads();

      final updated = await reload(row.id);
      expect(updated.retryCount, 2);
      expect(updated.status, PendingUploadStatus.pending);
      // nextRetryAt = now + 60s. `now` here is the advanced fakeNow.
      expect(updated.nextRetryAt, fakeNow.add(const Duration(seconds: 60)));
    });

    test(
      'fifth failure marks failed_permanent and clears next_retry_at',
      () async {
        final row = await queue('/tmp/c.jpg');
        ops.scriptFailure(row.localPath, times: 5);

        // Run 5 attempts back-to-back, advancing the clock past each cooldown.
        final delays = [30, 60, 120, 240];
        await sync.processPendingUploads();
        for (final seconds in delays) {
          fakeNow = fakeNow.add(Duration(seconds: seconds + 1));
          await sync.processPendingUploads();
        }

        final updated = await reload(row.id);
        expect(updated.retryCount, 5);
        expect(updated.status, PendingUploadStatus.failedPermanent);
        expect(updated.nextRetryAt, isNull);
      },
    );
  });

  group('eligibility filter', () {
    test('rows with next_retry_at in the future are skipped', () async {
      final row = await queue('/tmp/cold.jpg');
      ops.scriptFailure(row.localPath);

      await sync.processPendingUploads();

      // One attempt recorded so far; nextRetryAt is 30s out.
      expect(ops.attemptLog.length, 1);

      // Re-run while still within the cooldown — must not attempt again.
      await sync.processPendingUploads();
      expect(ops.attemptLog.length, 1);
    });

    test('rows with next_retry_at in the past are retried', () async {
      final row = await queue('/tmp/hot.jpg');
      ops.scriptFailure(row.localPath);
      ops.scriptSuccess(row.localPath);

      await sync.processPendingUploads();
      expect(ops.attemptLog.length, 1);

      fakeNow = fakeNow.add(const Duration(seconds: 31));
      await sync.processPendingUploads();

      expect(ops.attemptLog.length, 2);
      // Success deleted the row.
      expect(
        await (db.select(
          db.pendingUploads,
        )..where((u) => u.id.equals(row.id))).getSingleOrNull(),
        isNull,
      );
    });
  });

  group('success path', () {
    test('successful upload after retries deletes the row', () async {
      final row = await queue('/tmp/eventual.jpg');
      ops.scriptFailure(row.localPath, times: 2);
      ops.scriptSuccess(row.localPath);

      await sync.processPendingUploads();
      fakeNow = fakeNow.add(const Duration(seconds: 31));
      await sync.processPendingUploads();
      fakeNow = fakeNow.add(const Duration(seconds: 61));
      await sync.processPendingUploads();

      expect(
        await (db.select(
          db.pendingUploads,
        )..where((u) => u.id.equals(row.id))).getSingleOrNull(),
        isNull,
      );
      expect(ops.attemptLog.length, 3);
    });

    test(
      'first-try success deletes the row with retry_count untouched',
      () async {
        final row = await queue('/tmp/easy.jpg');
        ops.scriptSuccess(row.localPath);

        await sync.processPendingUploads();

        expect(
          await (db.select(
            db.pendingUploads,
          )..where((u) => u.id.equals(row.id))).getSingleOrNull(),
          isNull,
        );
      },
    );
  });

  group('retryPermanentlyFailed', () {
    test('resets retry_count, status, and next_retry_at', () async {
      final row = await queue('/tmp/dead.jpg');
      ops.scriptFailure(row.localPath, times: 5);

      final delays = [0, 30, 60, 120, 240];
      for (final seconds in delays) {
        fakeNow = fakeNow.add(Duration(seconds: seconds + 1));
        await sync.processPendingUploads();
      }

      var updated = await reload(row.id);
      expect(updated.status, PendingUploadStatus.failedPermanent);

      // User taps "Retry" — script a success and reset.
      ops.scriptSuccess(row.localPath);
      await sync.retryPermanentlyFailed(row.id);

      // The reset-then-process should have uploaded and deleted the row.
      final gone = await (db.select(
        db.pendingUploads,
      )..where((u) => u.id.equals(row.id))).getSingleOrNull();
      expect(gone, isNull);
    });

    test(
      'reset without server trip: state is pending with retryCount=0',
      () async {
        final row = await queue('/tmp/reset.jpg');
        ops.scriptFailure(row.localPath, times: 5);

        final delays = [0, 30, 60, 120, 240];
        for (final seconds in delays) {
          fakeNow = fakeNow.add(Duration(seconds: seconds + 1));
          await sync.processPendingUploads();
        }

        // Go offline so retry reset doesn't immediately reprocess.
        connectivity.fakeOnline = false;
        await sync.retryPermanentlyFailed(row.id);

        final updated = await reload(row.id);
        expect(updated.status, PendingUploadStatus.pending);
        expect(updated.retryCount, 0);
        expect(updated.nextRetryAt, isNull);
      },
    );
  });

  group('self-DDoS regression', () {
    test(
      'repeated process calls on a failing upload do not spam the server',
      () async {
        // Before the fix, every processPendingUploads call re-attempted
        // a failed upload with no backoff. After the fix, a single
        // failure gates the row for 30s.
        final row = await queue('/tmp/failing.jpg');
        ops.scriptFailure(row.localPath, times: 10);

        for (var i = 0; i < 10; i++) {
          await sync.processPendingUploads();
        }

        // Only the first call should have attempted the upload; the
        // remaining 9 calls must respect the cooldown window.
        expect(ops.attemptLog.length, 1);
      },
    );
  });
}

/// Trivial ApiClient stub — SyncService only needs it to be non-null for
/// the retry path; none of these tests exercise listFiles.
class _StubApiClient extends Fake implements ApiClient {}
