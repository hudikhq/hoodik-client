import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/direct_chunk_download.dart';
import 'package:hoodik_app/core/services/file_downloader_config.dart';

void main() {
  group('directChunkTask', () {
    DownloadTask build({int chunk = 3}) => directChunkTask(
      accountId: 'acct-1',
      fileId: 'file-9',
      chunk: chunk,
      url: 'https://bucket.example.com/obj?X-Amz-Signature=deadbeef',
      outputDir: '/var/chunks/file-9',
    );

    // The whole point of a presigned URL is that it authenticates itself.
    // Sending a session cookie or a bearer token to the bucket alongside it is
    // rejected outright by some S3 implementations, and hands the storage
    // provider a credential it has no business holding. The web side asserts
    // the same thing against the wire in `web/e2e/direct-transfer.spec.ts`.
    test('carries no session material to the bucket', () {
      final task = build();

      expect(task.headers, isEmpty);
      expect(
        task.headers.keys.map((k) => k.toLowerCase()),
        isNot(anyOf(contains('cookie'), contains('authorization'))),
      );
    });

    // An id built any other way is invisible to adoptTransfersForAccount,
    // which then reads it as another account's work and cancels it on the
    // next sign-in.
    test('encodes its owner so a cold start can adopt it', () {
      final task = build();

      expect(accountIdFromTaskId(task.taskId), 'acct-1');
      expect(fileIdFromTaskId(task.taskId), 'file-9');
    });

    // decrypt_chunks_to_file and the offline cache both read this layout;
    // a chunk under any other name is a chunk that silently went missing.
    test('lands the chunk where the decrypt step looks for it', () async {
      final task = build(chunk: 12);

      expect(task.filename, '000012.enc');
      expect(task.group, DirectChunkDownloadService.group);
      expect(await task.filePath(), '/var/chunks/file-9/000012.enc');
    });
  });

  group('ChunkProgress', () {
    late List<(int, int)> reported;

    ChunkProgress build({Set<int> completed = const {}}) => ChunkProgress(
      chunkCount: 4,
      fileSize: 400,
      completed: {...completed},
      onProgress: (chunks, bytes) => reported.add((chunks, bytes)),
    );

    setUp(() => reported = []);

    // Decrypting a partial set produces a corrupt file rather than an error,
    // so "every task reported" is not the same question as "every chunk is
    // here" — the last task can complete while an earlier one failed.
    test('is only done once every index has landed', () {
      final progress = build();

      progress.complete(0);
      progress.complete(2);
      progress.complete(3);
      expect(progress.isDone, isFalse);

      progress.complete(1);
      expect(progress.isDone, isTrue);
    });

    test('counts in-flight chunks toward the bar without completing them', () {
      final progress = build();

      progress.complete(0);
      progress.advance(1, 0.5);

      expect(reported.last, (1, 150));
      expect(progress.isDone, isFalse);
    });

    // A resumed transfer starts from what is already on disk. Reporting zero
    // first would drag the bar back to the start of a download that is
    // three-quarters done.
    test('starts from the chunks a previous session left behind', () {
      final progress = build(completed: {0, 1});

      progress.report();

      expect(reported.single, (2, 200));
    });

    test('lists only the chunks still missing, in order', () {
      expect(build(completed: {1, 3}).outstanding, [0, 2]);
    });

    test('never reports more bytes than the file holds', () {
      final progress = build(completed: {0, 1, 2, 3});
      progress.advance(3, 1.0);
      progress.report();

      expect(reported.last, (4, 400));
    });
  });

  group('chunksOnDisk', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('direct_chunks'));
    tearDown(() => dir.deleteSync(recursive: true));

    // This is what makes a relaunch resume instead of restart: the offline
    // cache does not know a file exists until every chunk has landed, so
    // mid-transfer the only record of progress is the directory itself.
    test('finds the chunks a killed session already fetched', () async {
      File('${dir.path}/000000.enc').writeAsStringSync('a');
      File('${dir.path}/000002.enc').writeAsStringSync('c');

      expect(await chunksOnDisk(dir, 4), {0, 2});
    });

    test('ignores anything that is not a chunk of this file', () async {
      File('${dir.path}/000000.enc').writeAsStringSync('a');
      File('${dir.path}/000009.enc').writeAsStringSync('past the end');
      File('${dir.path}/notes.txt').writeAsStringSync('x');
      File('${dir.path}/partial.enc').writeAsStringSync('unparseable index');

      expect(await chunksOnDisk(dir, 4), {0});
    });
  });

  // Tapping a file that a resume is already downloading used to overwrite the
  // in-memory state for it, orphaning the first driver's completer: its future
  // never finished, so the sequential resume loop behind it stalled for the
  // rest of the session.
  group('a second download of the same file', () {
    test('joins the one already running instead of replacing it', () async {
      final service = DirectChunkDownloadService();
      final first = service.seedInFlight('file-9');

      final second = service.download(
        accountId: 'acct-1',
        fileId: 'file-9',
        urls: const ['https://bucket.example.com/obj/000000.enc'],
        outputDir: '/var/chunks/file-9',
        fileSize: 1024,
        alreadyDownloaded: const [],
      );

      // Both callers now wait on one transfer: completing it finishes both,
      // and no platform channel was touched to find that out.
      service.cancel('file-9');

      await expectLater(first, throwsA(isA<Exception>()));
      await expectLater(second, throwsA(isA<Exception>()));
    });
  });
}
