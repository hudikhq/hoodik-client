import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/background_upload_service.dart';
import 'package:hoodik_app/core/services/file_downloader_config.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/core/services/pending_upload_status.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_uploads_dao.dart';

import '../../helpers/fakes.dart';

class _StubApiClient extends Fake implements ApiClient {}

/// Reports what the pending-uploads table looked like at the moment the
/// upload was in flight — the state a kill would freeze in place.
class _ObservingFileOperations extends Fake implements FileOperations {
  _ObservingFileOperations(this._db);

  final AppDatabase _db;

  List<PendingUpload> rowsDuringUpload = [];
  bool fail = false;

  @override
  Future<void> uploadFile(
    String localPath, {
    String? parentDirId,
    void Function(double progress)? onProgress,
  }) async {
    rowsDuringUpload = await _db.getPendingUploads('acct');
    if (fail) throw Exception('upload blew up');
  }
}

void main() {
  late AppDatabase db;
  late SyncService sync;
  late _ObservingFileOperations ops;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ops = _ObservingFileOperations(db);
    sync = SyncService(
      db: db,
      connectivity: FakeConnectivityService(fakeOnline: true),
      clock: () => DateTime(2026, 8, 18, 12),
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

  group('an upload records itself before it starts', () {
    // A process killed mid-upload never gets to report a failure. If the row
    // were only written on the way out, the transfer would leave nothing
    // behind: its encrypted chunks would sit in staging forever and the file
    // would simply never arrive.
    test('so a kill mid-transfer leaves something to resume', () async {
      await sync.uploadFileOrQueue(localPath: '/tmp/a.jpg');

      expect(ops.rowsDuringUpload, hasLength(1));
      expect(ops.rowsDuringUpload.single.localPath, '/tmp/a.jpg');
      expect(ops.rowsDuringUpload.single.status, PendingUploadStatus.uploading);
    });

    test('and the row is gone once the upload lands', () async {
      await sync.uploadFileOrQueue(localPath: '/tmp/a.jpg');

      expect(await db.getPendingUploads('acct'), isEmpty);
    });

    // The failure path used to insert a second row. With the row already
    // there, a failure has to update it or every retry would double the queue.
    test('a failure updates that row rather than adding another', () async {
      ops.fail = true;

      await sync.uploadFileOrQueue(localPath: '/tmp/a.jpg');

      final rows = await db.getPendingUploads('acct');
      expect(rows, hasLength(1));
      expect(rows.single.retryCount, 1);
      expect(rows.single.status, PendingUploadStatus.pending);
      expect(rows.single.nextRetryAt, isNotNull);
    });
  });

  group('reviveInterruptedUploads', () {
    // Nothing else clears the in-flight state, and the retry pass skips those
    // rows for as long as it stands — so an interrupted upload would sit
    // there untouched forever.
    test('hands an interrupted upload back to the retry queue', () async {
      final row = await db.insertPendingUpload(
        PendingUploadsCompanion.insert(
          accountId: 'acct',
          localPath: '/tmp/killed.jpg',
          status: const Value(PendingUploadStatus.uploading),
          nextRetryAt: Value(DateTime(2030)),
        ),
      );

      expect(await db.reviveInterruptedUploads('acct'), 1);

      final revived = (await db.getPendingUploads('acct')).single;
      expect(revived.id, row.id);
      expect(revived.status, PendingUploadStatus.pending);
      // The stale cooldown goes too, or the revived row waits out a backoff
      // that belonged to the session that died.
      expect(revived.nextRetryAt, isNull);
    });

    // activate() runs again on every provider rebuild, including ones that
    // happen mid-upload. Reviving a row whose transfer is still running would
    // start a second upload of the same file and land it in the drive twice.
    test('leaves a row this process is still uploading alone', () async {
      final live = await db.insertPendingUpload(
        PendingUploadsCompanion.insert(
          accountId: 'acct',
          localPath: '/tmp/inflight.jpg',
          status: const Value(PendingUploadStatus.uploading),
        ),
      );

      expect(
        await db.reviveInterruptedUploads(
          'acct',
          startedByThisProcess: {live.id},
        ),
        0,
      );
      expect(
        (await db.getPendingUploads('acct')).single.status,
        PendingUploadStatus.uploading,
      );
    });

    test('leaves other accounts and settled rows alone', () async {
      await db.insertPendingUpload(
        PendingUploadsCompanion.insert(
          accountId: 'other',
          localPath: '/tmp/theirs.jpg',
          status: const Value(PendingUploadStatus.uploading),
        ),
      );
      await db.insertPendingUpload(
        PendingUploadsCompanion.insert(
          accountId: 'acct',
          localPath: '/tmp/gaveup.jpg',
          status: const Value(PendingUploadStatus.failedPermanent),
        ),
      );

      expect(await db.reviveInterruptedUploads('acct'), 0);
      expect(
        (await db.getPendingUploads('acct')).single.status,
        PendingUploadStatus.failedPermanent,
      );
    });
  });

  group('upload task ids', () {
    // Uploads used to be tagged `upload:{fileId}:{chunk}`, which carries no
    // owner. Once task tracking went live, adoptTransfersForAccount could not
    // tell those from another account's leftovers.
    test('carry the account so a cold start can attribute them', () {
      final service = BackgroundUploadService(
        baseUrl: 'https://drive.example.com',
        accountId: 'acct-7',
      );
      final id = transferTaskId(
        prefix: BackgroundUploadService.group,
        accountId: service.accountId,
        fileId: 'file-3',
        chunk: 11,
      );

      expect(accountIdFromTaskId(id), 'acct-7');
      expect(fileIdFromTaskId(id), 'file-3');
      expect(chunkFromTaskId(id), 11);
    });
  });
}
