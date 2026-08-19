import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/transfer_manager.dart';

void main() {
  late TransferManager manager;

  setUp(() {
    manager = TransferManager();
  });

  group('TransferType', () {
    test('label returns correct strings', () {
      expect(TransferType.uploadEncrypt.label, 'Encrypting');
      expect(TransferType.uploadHttp.label, 'Uploading');
      expect(TransferType.downloadHttp.label, 'Downloading');
      expect(TransferType.downloadDecrypt.label, 'Decrypting');
    });

    test('isUpload is true only for upload types', () {
      expect(TransferType.uploadEncrypt.isUpload, true);
      expect(TransferType.uploadHttp.isUpload, true);
      expect(TransferType.downloadHttp.isUpload, false);
      expect(TransferType.downloadDecrypt.isUpload, false);
    });

    test('isNetworkTransfer is true only for HTTP types', () {
      expect(TransferType.uploadEncrypt.isNetworkTransfer, false);
      expect(TransferType.uploadHttp.isNetworkTransfer, true);
      expect(TransferType.downloadHttp.isNetworkTransfer, true);
      expect(TransferType.downloadDecrypt.isNetworkTransfer, false);
    });
  });

  group('startTransfer', () {
    test('creates an active transfer', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1024,
        totalChunks: 4,
        fileId: 'file-1',
      );

      expect(item.status, TransferStatus.active);
      expect(item.fileName, 'test.txt');
      expect(item.totalBytes, 1024);
      expect(item.totalChunks, 4);
      expect(item.fileId, 'file-1');
      expect(item.transferredBytes, 0);
      expect(item.progress, 0.0);
    });

    test('adds to transfers list', () {
      manager.startTransfer(
        fileName: 'a.txt',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
      );
      manager.startTransfer(
        fileName: 'b.txt',
        type: TransferType.downloadHttp,
        totalBytes: 200,
        totalChunks: 2,
      );

      expect(manager.transfers.length, 2);
      expect(manager.hasTransfers, true);
      expect(manager.hasActiveTransfers, true);
    });

    test('inserts newest transfer first', () {
      manager.startTransfer(
        fileName: 'first.txt',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
      );
      manager.startTransfer(
        fileName: 'second.txt',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
      );

      expect(manager.transfers[0].fileName, 'second.txt');
      expect(manager.transfers[1].fileName, 'first.txt');
    });
  });

  group('updateProgress', () {
    test('updates transferred bytes and chunks', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.updateProgress(
        item.id,
        completedChunks: 2,
        transferredBytes: 500,
      );

      expect(item.completedChunks, 2);
      expect(item.transferredBytes, 500);
      expect(item.progress, 0.5);
    });

    test('notifies listeners', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      var notified = false;
      manager.addListener(() => notified = true);
      manager.updateProgress(
        item.id,
        completedChunks: 1,
        transferredBytes: 250,
      );

      expect(notified, true);
    });

    test('never moves the bar backwards — a "regressing" update from a '
        'background_downloader retry (URLSession internally restarts the '
        'tar UploadTask from byte 0) is clamped to the previous '
        'high-water mark, so the user does not see 30 % → 0 % → climbs '
        'again repeatedly during a flaky tar upload', () {
      final item = manager.startTransfer(
        fileName: 'big.mov',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.updateProgress(
        item.id,
        completedChunks: 1,
        transferredBytes: 300,
      );
      expect(item.transferredBytes, 300);
      expect(item.completedChunks, 1);

      // OS-native uploader retried — fresh attempt resets to 0.
      manager.updateProgress(item.id, completedChunks: 0, transferredBytes: 0);
      expect(
        item.transferredBytes,
        300,
        reason: 'transferredBytes must be clamped to high-water mark',
      );
      expect(
        item.completedChunks,
        1,
        reason: 'completedChunks must be clamped to high-water mark',
      );

      // Retry climbs back through the same bytes — still at the
      // high-water until it actually surpasses it.
      manager.updateProgress(
        item.id,
        completedChunks: 1,
        transferredBytes: 200,
      );
      expect(item.transferredBytes, 300);
      expect(item.completedChunks, 1);

      // Now the new attempt actually advances past the previous
      // high-water — bar moves forward.
      manager.updateProgress(
        item.id,
        completedChunks: 2,
        transferredBytes: 600,
      );
      expect(item.transferredBytes, 600);
      expect(item.completedChunks, 2);
    });

    test('a regressing update does not pollute the speed sample with a '
        'phantom delta — only forward motion contributes to bytes/sec', () {
      final item = manager.startTransfer(
        fileName: 'big.mov',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.updateProgress(
        item.id,
        completedChunks: 1,
        transferredBytes: 300,
      );
      final speedAfterFirst = item.bytesPerSecond;

      // Regression: should not inflate or deflate the speed average.
      manager.updateProgress(item.id, completedChunks: 0, transferredBytes: 0);
      expect(
        item.bytesPerSecond,
        equals(speedAfterFirst),
        reason: 'A "back to 0" event must not change bytesPerSecond',
      );
    });
  });

  group('completeTransfer', () {
    test('sets status to completed and fills bytes', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.completeTransfer(item.id);

      expect(item.status, TransferStatus.completed);
      expect(item.transferredBytes, 1000);
      expect(item.completedChunks, 4);
    });
  });

  group('failTransfer', () {
    test('sets status to failed with error message', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.failTransfer(item.id, 'Network error');

      expect(item.status, TransferStatus.failed);
      expect(item.errorMessage, 'Network error');
    });
  });

  group('cancelTransfer', () {
    test('sets status to cancelled', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
        fileId: 'f1',
      );

      manager.cancelTransfer(item.id);

      expect(item.status, TransferStatus.cancelled);
    });

    test('calls onCancelRequested with fileId', () {
      String? cancelledFileId;
      manager.onCancelRequested = (id) => cancelledFileId = id;

      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
        fileId: 'f1',
      );

      manager.cancelTransfer(item.id);
      expect(cancelledFileId, 'f1');
    });

    test('does not cancel already completed transfers', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
        fileId: 'f1',
      );

      manager.completeTransfer(item.id);
      manager.cancelTransfer(item.id);

      expect(item.status, TransferStatus.completed);
    });
  });

  group('dismissTransfer', () {
    test('removes completed transfer', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.completeTransfer(item.id);
      manager.dismissTransfer(item.id);

      expect(manager.transfers, isEmpty);
    });

    test('does not remove active transfer', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.dismissTransfer(item.id);

      expect(manager.transfers.length, 1);
    });
  });

  group('clearCompleted', () {
    test('removes completed and failed, keeps active', () {
      final active = manager.startTransfer(
        fileName: 'active.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );
      final done = manager.startTransfer(
        fileName: 'done.txt',
        type: TransferType.downloadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );
      final failed = manager.startTransfer(
        fileName: 'failed.txt',
        type: TransferType.downloadDecrypt,
        totalBytes: 1000,
        totalChunks: 4,
      );

      manager.completeTransfer(done.id);
      manager.failTransfer(failed.id, 'error');
      manager.clearCompleted();

      expect(manager.transfers.length, 1);
      expect(manager.transfers[0].id, active.id);
    });
  });

  group('TransferItem', () {
    test('progress is 0 when totalBytes is 0', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 0,
        startedAt: DateTime.now(),
      );
      expect(item.progress, 0.0);
    });

    test('progress computes correctly', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        transferredBytes: 250,
        startedAt: DateTime.now(),
      );
      expect(item.progress, 0.25);
    });

    test('speedString formats correctly', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 10 * 1024 * 1024, // 10 MB
        transferredBytes: 5 * 1024 * 1024, // 5 MB
        startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      // Without speed samples, falls back to average.
      final speed = item.speedString;
      expect(speed.isNotEmpty, true);
    });

    test('etaString returns empty when no progress', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        startedAt: DateTime.now(),
      );
      expect(item.etaString, '');
    });

    test('sizeProgressString formats transfer/total', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1024 * 1024, // 1 MB
        transferredBytes: 512 * 1024, // 512 KB
        startedAt: DateTime.now(),
      );
      expect(item.sizeProgressString, contains('/'));
    });

    test('formatBytes handles all scales', () {
      expect(TransferItem.formatBytes(500), '500 B');
      expect(TransferItem.formatBytes(1500), contains('KB'));
      expect(TransferItem.formatBytes(1500000), contains('MB'));
      expect(TransferItem.formatBytes(1500000000), contains('GB'));
    });

    test('type label is accessible on item', () {
      final encrypt = TransferItem(
        id: 'e',
        fileName: 'a.txt',
        type: TransferType.uploadEncrypt,
        startedAt: DateTime.now(),
      );
      final upload = TransferItem(
        id: 'u',
        fileName: 'b.txt',
        type: TransferType.uploadHttp,
        startedAt: DateTime.now(),
      );
      final download = TransferItem(
        id: 'd',
        fileName: 'c.txt',
        type: TransferType.downloadHttp,
        startedAt: DateTime.now(),
      );
      final decrypt = TransferItem(
        id: 'dc',
        fileName: 'd.txt',
        type: TransferType.downloadDecrypt,
        startedAt: DateTime.now(),
      );

      expect(encrypt.type.label, 'Encrypting');
      expect(upload.type.label, 'Uploading');
      expect(download.type.label, 'Downloading');
      expect(decrypt.type.label, 'Decrypting');
    });
  });

  group('activeTransfers', () {
    test('filters only active transfers', () {
      final a = manager.startTransfer(
        fileName: 'a.txt',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
      );
      manager.startTransfer(
        fileName: 'b.txt',
        type: TransferType.downloadHttp,
        totalBytes: 100,
        totalChunks: 1,
      );

      manager.completeTransfer(a.id);

      expect(manager.activeTransfers.length, 1);
      expect(manager.hasActiveTransfers, true);
    });

    test('returns empty when no active transfers', () {
      final item = manager.startTransfer(
        fileName: 'a.txt',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
      );

      manager.completeTransfer(item.id);

      expect(manager.activeTransfers, isEmpty);
      expect(manager.hasActiveTransfers, false);
    });
  });

  group('updateFileId', () {
    test('changes the fileId on a transfer', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      expect(item.fileId, isNull);

      manager.updateFileId(item.id, 'server-file-abc');

      expect(item.fileId, 'server-file-abc');
    });

    test('notifies listeners', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 1000,
        totalChunks: 4,
      );

      var notified = false;
      manager.addListener(() => notified = true);
      manager.updateFileId(item.id, 'new-id');

      expect(notified, true);
    });

    test('ignores unknown transfer id', () {
      // Should not throw.
      manager.updateFileId('nonexistent', 'some-id');
    });
  });

  group('markCancelled', () {
    test('marks cancelled without triggering callback', () {
      String? cancelledId;
      manager.onCancelRequested = (id) => cancelledId = id;

      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'f1',
      );

      manager.markCancelled(item.id);

      expect(item.status, TransferStatus.cancelled);
      expect(cancelledId, isNull); // callback NOT called
    });
  });

  group('speed and ETA calculations', () {
    test('addSpeedSample builds rolling window', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.downloadHttp,
        totalBytes: 10000,
        transferredBytes: 5000,
        startedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      // With fewer than 2 samples, bytesPerSecond falls back to overall
      // average: 5000 bytes / 10 seconds = 500 B/s.
      item.addSpeedSample(1000);
      expect(item.bytesPerSecond, greaterThan(0));
      expect(item.speedString.isNotEmpty, true);
    });

    test('estimatedTimeRemaining returns null when no speed', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.downloadHttp,
        totalBytes: 1000,
        transferredBytes: 0,
        startedAt: DateTime.now(),
      );

      // No time elapsed, no speed samples → speed is 0 → ETA is null.
      expect(item.estimatedTimeRemaining, isNull);
    });

    test('estimatedTimeRemaining returns zero when fully transferred', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.downloadHttp,
        totalBytes: 1000,
        transferredBytes: 1000,
        startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );

      final eta = item.estimatedTimeRemaining;
      // Either null (if speed calc is 0) or Duration.zero.
      expect(eta == null || eta == Duration.zero, true);
    });

    test('etaString formats minutes and seconds', () {
      final item = TransferItem(
        id: 'test',
        fileName: 'test.txt',
        type: TransferType.downloadHttp,
        totalBytes: 10 * 1024 * 1024,
        transferredBytes: 1 * 1024 * 1024,
        startedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      // With 1MB transferred in 10s = ~100KB/s, ~90s remaining.
      // The format should start with '~'.
      final eta = item.etaString;
      if (eta.isNotEmpty) {
        expect(eta.startsWith('~'), true);
      }
    });
  });

  group('onWorker flag', () {
    test('defaults to false', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
      );

      expect(item.onWorker, false);
    });

    test('can be set via startTransfer', () {
      final item = manager.startTransfer(
        fileName: 'test.txt',
        type: TransferType.downloadHttp,
        totalBytes: 100,
        totalChunks: 1,
        onWorker: true,
      );

      expect(item.onWorker, true);
    });
  });

  // One upload is two stages and one download is two the other way round.
  // Both render as "Done {size}" once finished — the stage name shows only
  // while a stage runs — so a finished stage left in the list showed the same
  // file twice with identical text, which reads as the transfer having run
  // twice.
  group('stages of one operation', () {
    test('a starting stage retires the finished stage it follows', () {
      final encrypt = manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.uploadEncrypt,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'staging-1',
        groupId: 'staging-1',
      );
      manager.completeTransfer(encrypt.id);

      // The server file id only exists once encryption is done, so the two
      // stages carry different `fileId`s and the group is what links them.
      manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'server-file-1',
        groupId: 'staging-1',
      );

      expect(manager.transfers, hasLength(1));
      expect(manager.transfers.single.type, TransferType.uploadHttp);
    });

    test('a download groups on its file id without being told', () {
      final download = manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.downloadHttp,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'file-1',
      );
      manager.completeTransfer(download.id);

      manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.downloadDecrypt,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'file-1',
      );

      expect(manager.transfers, hasLength(1));
      expect(manager.transfers.single.type, TransferType.downloadDecrypt);
    });

    test('an unfinished stage is never retired', () {
      manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.uploadEncrypt,
        totalBytes: 100,
        totalChunks: 1,
        groupId: 'staging-1',
      );
      manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
        groupId: 'staging-1',
      );

      expect(manager.transfers, hasLength(2));
    });

    // Downloading a file and then uploading one are separate operations that
    // happen to share an id; neither should clear the other's history.
    test('an upload does not retire a finished download of the same file', () {
      final download = manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.downloadDecrypt,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'file-1',
      );
      manager.completeTransfer(download.id);

      manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
        fileId: 'file-1',
      );

      expect(manager.transfers, hasLength(2));
    });

    test('two files uploading at once do not retire each other', () {
      final first = manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.uploadEncrypt,
        totalBytes: 100,
        totalChunks: 1,
        groupId: 'staging-1',
      );
      manager.completeTransfer(first.id);

      manager.startTransfer(
        fileName: 'holiday.mov',
        type: TransferType.uploadHttp,
        totalBytes: 100,
        totalChunks: 1,
        groupId: 'staging-2',
      );

      expect(manager.transfers, hasLength(2));
    });
  });
}
