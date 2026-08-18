import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/chunk_download_runner.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';

import '../../helpers/fakes.dart';

void main() {
  const baseUrl = 'https://drive.example.com';
  const cookie = 'hoodik_session=abcdef';
  const fileId = 'file-123';
  const fileSize = 4194304;
  const chunkCount = 1;
  const outputDir = '/tmp/chunks/file-123';

  Future<void> runOnce(ChunkDownloadRunner runner) => runner.run(
    baseUrl: baseUrl,
    cookie: cookie,
    fileId: fileId,
    fileSize: fileSize,
    chunkCount: chunkCount,
    outputDir: outputDir,
    alreadyDownloaded: const [],
      accountId: 'acct-test',
  );

  test('happy path: tar succeeds, capability cache records the win', () async {
    final transport = FakeChunkDownloadTransport();
    final cache = TarCapabilityCache();
    final runner = ChunkDownloadRunner(
      transport: transport,
      tarCapabilityCache: cache,
    );

    await runOnce(runner);

    expect(transport.tarCalls, hasLength(1));
    expect(transport.perChunkCalls, isEmpty);
    expect(cache.lookup(baseUrl), isTrue);
  });

  test('tar returns malformed_tar error — per-chunk fallback engages and the '
      'second attempt succeeds', () async {
    final transport = FakeChunkDownloadTransport()
      ..tarError = Exception('malformed_tar: unexpected stream end');
    final cache = TarCapabilityCache();
    final runner = ChunkDownloadRunner(
      transport: transport,
      tarCapabilityCache: cache,
    );

    await runOnce(runner);

    expect(transport.tarCalls, hasLength(1));
    expect(transport.perChunkCalls, hasLength(1));
    expect(cache.lookup(baseUrl), isFalse);
  });

  test('tar returns a timeout — error bubbles up and neither tar nor per-chunk '
      'is marked in the cache', () async {
    final transport = FakeChunkDownloadTransport()
      ..tarError = Exception('Connection timed out after 30 seconds');
    final cache = TarCapabilityCache();
    final runner = ChunkDownloadRunner(
      transport: transport,
      tarCapabilityCache: cache,
    );

    expect(() => runOnce(runner), throwsA(isA<Exception>()));

    await pumpEventQueue();
    expect(transport.tarCalls, hasLength(1));
    expect(transport.perChunkCalls, isEmpty);
    expect(cache.lookup(baseUrl), isNull);
  });

  test(
    'capability known-unsupported: skip tar, go straight to per-chunk',
    () async {
      final transport = FakeChunkDownloadTransport();
      final cache = TarCapabilityCache()..markUnsupported(baseUrl);
      final runner = ChunkDownloadRunner(
        transport: transport,
        tarCapabilityCache: cache,
      );

      await runOnce(runner);

      expect(transport.tarCalls, isEmpty);
      expect(transport.perChunkCalls, hasLength(1));
      expect(cache.lookup(baseUrl), isFalse);
    },
  );
}
