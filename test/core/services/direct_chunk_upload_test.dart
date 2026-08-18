import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/direct_chunk_upload.dart';
import 'package:hoodik_app/core/services/file_downloader_config.dart';

void main() {
  group('directChunkUploadTask', () {
    UploadTask build({int chunk = 4}) => directChunkUploadTask(
      accountId: 'acct-1',
      fileId: 'file-9',
      chunk: chunk,
      url: 'https://bucket.example.com/obj?X-Amz-Signature=deadbeef',
      stagingDir: '/var/staging/file-9',
    );

    // The presigned URL signs the method, the key and the content length, and
    // an Authorization header alongside it is refused outright by several S3
    // implementations. The session must not reach the bucket on the write path
    // any more than on the read path.
    test('carries no session material to the bucket', () {
      expect(build().headers, isEmpty);
    });

    // A presigned PUT is signed for PUT. background_downloader defaults an
    // upload to POST, which the bucket would reject as a signature mismatch.
    test('is a PUT, not the default POST', () {
      expect(build().httpRequestMethod, 'PUT');
      expect(build().post, 'binary');
    });

    test('encodes its owner so a cold start can attribute it', () {
      final task = build();

      expect(accountIdFromTaskId(task.taskId), 'acct-1');
      expect(fileIdFromTaskId(task.taskId), 'file-9');
      expect(chunkFromTaskId(task.taskId), 4);
    });

    test('reads the chunk the encrypt phase staged', () async {
      final task = build(chunk: 12);

      expect(task.filename, '000012.enc');
      expect(await task.filePath(), '/var/staging/file-9/000012.enc');
    });
  });

  group('stagedChunkSizes', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('staged'));
    tearDown(() => dir.deleteSync(recursive: true));

    // The server signs each declared length into its URL, so these have to be
    // the on-disk ciphertext sizes. Sending the plaintext chunk size would
    // have every upload rejected by the bucket for a length mismatch, since
    // each chunk carries an AEAD tag on top of its payload.
    test('reports the ciphertext length of each staged chunk', () async {
      File('${dir.path}/000000.enc').writeAsBytesSync(List.filled(1024, 7));
      File('${dir.path}/000001.enc').writeAsBytesSync(List.filled(512, 7));

      expect(await stagedChunkSizes(dir.path, 2), {0: 1024, 1: 512});
    });

    // A gap means the encrypt phase did not finish. The caller reads the short
    // map as "not ready" and falls back rather than asking the server to sign
    // a partial set.
    test('leaves out a chunk that was never staged', () async {
      File('${dir.path}/000000.enc').writeAsBytesSync(List.filled(8, 1));

      final sizes = await stagedChunkSizes(dir.path, 3);

      expect(sizes.keys, [0]);
      expect(sizes.length, isNot(3));
    });
  });
}
