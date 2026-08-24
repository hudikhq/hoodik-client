import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/binary_upload_runner.dart';
import 'package:hoodik_app/core/services/upload_staging.dart';
import 'package:path/path.dart' as p;

import '../../helpers/fakes.dart';

void main() {
  const baseUrl = 'https://drive.example.com';
  const transferToken = 'transfer-jwt-abc';
  const fileId = 'file-abc123';
  const stagingDir = '/tmp/upload_staging/acct/file-abc123';
  const chunkCount = 3;

  group('BinaryUploadRunner', () {
    /// A server with the archive switched off answers `?format=tar` with 501.
    /// Reading that from the capability and withholding the probe is what
    /// keeps an upload from spending a refused request on every file — and
    /// what kept the refusal off the user's screen, back when the fallback
    /// could not recognise it.
    test('a server that will not serve archives is never probed', () async {
      final transport = FakeUploadTarTransport();
      var perChunkInvocations = 0;

      final usedTar = await BinaryUploadRunner(tarTransport: transport).run(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        stagingDir: stagingDir,
        chunkCount: chunkCount,
        tarSupported: false,
        perChunk: () async => perChunkInvocations++,
      );

      expect(usedTar, isFalse);
      expect(transport.calls, isEmpty, reason: 'no archive is packed or sent');
      expect(perChunkInvocations, equals(1));
    });

    /// The default stays a probe. A server that advertises nothing either way
    /// is the common case, and one upgraded between uploads has to be picked
    /// up without a restart — which is why this leg caches no verdict.
    test('a server that says nothing is still probed', () async {
      final transport = FakeUploadTarTransport();

      await BinaryUploadRunner(tarTransport: transport).run(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        stagingDir: stagingDir,
        chunkCount: chunkCount,
        perChunk: () async => fail('per-chunk must not run on tar success'),
      );

      expect(transport.calls, hasLength(1));
    });

    test('happy path: tar succeeds and per-chunk is not invoked', () async {
      final transport = FakeUploadTarTransport();
      var perChunkInvocations = 0;

      final runner = BinaryUploadRunner(tarTransport: transport);

      final usedTar = await runner.run(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        stagingDir: stagingDir,
        chunkCount: chunkCount,
        perChunk: () async => perChunkInvocations++,
      );

      expect(usedTar, isTrue);
      expect(transport.calls, hasLength(1));
      expect(transport.calls.single.chunksDir, equals(stagingDir));
      expect(transport.calls.single.chunkCount, equals(chunkCount));
      expect(transport.calls.single.transferToken, equals(transferToken));
      expect(perChunkInvocations, equals(0));
    });

    test('byte-level progress events from the OS-native uploader are '
        'forwarded through to the caller via onTarProgress — without '
        'this wire the UI sat at 0 % until the upload completed, which '
        'broke the 300 MB upload UX entirely', () async {
      final transport = FakeUploadTarTransport()
        ..progressEvents = const [(0, 100), (50, 100), (100, 100)];
      final captured = <(int, int)>[];

      final runner = BinaryUploadRunner(tarTransport: transport);

      final usedTar = await runner.run(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        stagingDir: stagingDir,
        chunkCount: chunkCount,
        perChunk: () async => fail('per-chunk must not run on tar success'),
        onTarProgress: (sent, total) => captured.add((sent, total)),
      );

      expect(usedTar, isTrue);
      expect(
        captured,
        equals(const [(0, 100), (50, 100), (100, 100)]),
        reason:
            'Every progress tick the transport emits must reach the '
            'pipeline so TransferManager can drive the UI bar',
      );
    });

    test('tar fails with 405 — per-chunk fallback runs exactly once', () async {
      final transport = FakeUploadTarTransport()
        ..error = Exception('HTTP 405 Method Not Allowed');
      var perChunkInvocations = 0;

      final runner = BinaryUploadRunner(tarTransport: transport);

      final usedTar = await runner.run(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        stagingDir: stagingDir,
        chunkCount: chunkCount,
        perChunk: () async => perChunkInvocations++,
      );

      expect(usedTar, isFalse);
      expect(transport.calls, hasLength(1));
      expect(perChunkInvocations, equals(1));
    });

    test('every upload re-probes tar — a previous fallback does not poison '
        'the next attempt against the same base URL, so a self-hoster who '
        'upgrades mid-session recovers automatically', () async {
      final transport = FakeUploadTarTransport()
        ..error = Exception('HTTP 405 Method Not Allowed');

      final runner = BinaryUploadRunner(tarTransport: transport);

      final firstUsedTar = await runner.run(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        stagingDir: stagingDir,
        chunkCount: chunkCount,
        perChunk: () async {},
      );
      expect(firstUsedTar, isFalse);
      expect(transport.calls, hasLength(1));

      // The fake's `error` is one-shot; the next attempt finds tar healthy
      // — exactly what happens when the operator deploys a tar-capable
      // build between two uploads. A cache-based runner would still skip
      // tar here.
      final secondUsedTar = await runner.run(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        stagingDir: stagingDir,
        chunkCount: chunkCount,
        perChunk: () async => fail('per-chunk must not run when tar succeeds'),
      );
      expect(secondUsedTar, isTrue);
      expect(transport.calls, hasLength(2));
    });

    test('tar raises a non-capability error — bubbles up without touching '
        'the per-chunk path', () async {
      final transport = FakeUploadTarTransport()
        ..error = Exception('Internal Server Error status 500');
      var perChunkInvocations = 0;

      final runner = BinaryUploadRunner(tarTransport: transport);

      await expectLater(
        runner.run(
          baseUrl: baseUrl,
          transferToken: transferToken,
          fileId: fileId,
          stagingDir: stagingDir,
          chunkCount: chunkCount,
          perChunk: () async => perChunkInvocations++,
        ),
        throwsA(isA<Exception>()),
      );
      expect(perChunkInvocations, equals(0));
    });
  });

  group('UploadStaging', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('hoodik_upload_staging_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    UploadStaging newStaging() => UploadStaging(
      accountId: 'acct',
      supportDirOverride: () async => tmp.path,
    );

    test('resume: a staging dir pre-populated with some chunks reports the '
        'indices so the pipeline can skip re-encrypting them', () async {
      final staging = newStaging();
      final path = await staging.stagingDir('stage-1');

      await File(p.join(path, '000000.enc')).writeAsBytes([0x01, 0x02]);
      await File(p.join(path, '000002.enc')).writeAsBytes([0x03]);
      // A stray non-.enc file must not derail the scan.
      await File(p.join(path, 'ignore.txt')).writeAsString('ignored');

      final indices = await staging.listExistingChunkIndices(path);
      expect(indices, equals([0, 2]));
    });

    test('cancellation mid-encrypt: clear is opt-in so the pipeline can leave '
        'staging intact for a follow-up attempt', () async {
      final staging = newStaging();
      final path = await staging.stagingDir('stage-cancel');
      await File(p.join(path, '000000.enc')).writeAsBytes([0xA5]);

      expect(await Directory(path).exists(), isTrue);
      // The pipeline's error path deliberately does NOT call clear, so
      // the chunks survive until the next retry explicitly kicks them.
      expect(await File(p.join(path, '000000.enc')).exists(), isTrue);

      // A successful run — or explicit cleanup — does clear.
      await staging.clear('stage-cancel');
      expect(await Directory(path).exists(), isFalse);
    });

    test('moveTo: a successful upload can promote the encrypted staging dir '
        'into the offline cache without re-reading any bytes', () async {
      final staging = newStaging();
      final path = await staging.stagingDir('stage-move');
      await File(p.join(path, '000000.enc')).writeAsBytes([1, 2, 3]);

      final destination = p.join(tmp.path, 'offline', 'acct', 'file-42');
      await staging.moveTo(path, destination);

      expect(await Directory(path).exists(), isFalse);
      expect(
        await File(p.join(destination, '000000.enc')).readAsBytes(),
        equals([1, 2, 3]),
      );
    });
  });
}
