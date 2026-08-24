import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/chunk_download_runner.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';

import '../../helpers/fakes.dart';

/// A file's bytes can reach the device three ways, and which one runs is the
/// server's choice, not the user's: straight from the bucket over presigned
/// URLs, as one archive through the server, or a request per chunk. The bar
/// the user watches is drawn from whichever leg runs, so every one of them has
/// to be handed the progress hook.
///
/// Each leg lost it at some point, separately, and each time the symptom was
/// identical and silent — a transfer that sits at zero for its whole life and
/// then jumps to done, which reads as a stall rather than a missing wire. The
/// tar upload was fixed first, the tar download months later, the per-chunk
/// leg later still. Nothing failed in between, because the tests exercised
/// each leg's own behaviour and nothing checked that the runner still handed
/// the callback down.
///
/// So this asserts the wiring rather than the behaviour: whichever leg the
/// runner picks, it receives a live hook, and calling it reaches the caller.
void main() {
  const baseUrl = 'https://drive.example.com';
  const fileId = 'file-123';
  const chunkCount = 4;

  ({
    FakeChunkDownloadTransport transport,
    TarCapabilityCache cache,
    List<(int, int)> seen,
  })
  setup() {
    return (
      transport: FakeChunkDownloadTransport(),
      cache: TarCapabilityCache(),
      seen: <(int, int)>[],
    );
  }

  Future<void> run(
    FakeChunkDownloadTransport transport,
    TarCapabilityCache cache,
    List<(int, int)> seen, {
    List<String> directUrls = const [],
  }) {
    return ChunkDownloadRunner(
      transport: transport,
      tarCapabilityCache: cache,
    ).run(
      baseUrl: baseUrl,
      cookie: 'session=abc',
      fileId: fileId,
      fileSize: 4000,
      chunkCount: chunkCount,
      outputDir: '/tmp/chunks',
      alreadyDownloaded: const [],
      accountId: 'acct-test',
      directUrls: directUrls,
      onProgress: (chunks, bytes) => seen.add((chunks, bytes)),
    );
  }

  test('the direct leg is handed a live progress hook', () async {
    final (:transport, :cache, :seen) = setup();

    await run(
      transport,
      cache,
      seen,
      directUrls: List.generate(chunkCount, (i) => 'https://bucket/$i'),
    );

    expect(transport.directCalls, hasLength(1));
    final hook = transport.directCalls.single.onProgress;
    expect(hook, isNotNull, reason: 'the direct leg draws the bar too');
    final before = seen.length;
    hook!(2, 2000);
    expect(seen.skip(before), equals([(2, 2000)]));
  });

  test('the tar leg is handed a live progress hook', () async {
    final (:transport, :cache, :seen) = setup();

    // Nothing known about this server, so the runner tries the archive.
    await run(transport, cache, seen);

    expect(transport.tarCalls, hasLength(1));
    final hook = transport.tarCalls.single.onProgress;
    expect(hook, isNotNull, reason: 'the archive leg draws the bar too');
    final before = seen.length;
    hook!(1, 1000);
    expect(seen.skip(before), equals([(1, 1000)]));
  });

  test('the per-chunk leg is handed a live progress hook', () async {
    final (:transport, :cache, :seen) = setup();
    cache.markUnsupported(baseUrl);

    await run(transport, cache, seen);

    expect(transport.perChunkCalls, hasLength(1));
    expect(transport.tarCalls, isEmpty, reason: 'the archive is known absent');
    final hook = transport.perChunkCalls.single.onProgress;
    expect(hook, isNotNull, reason: 'the per-chunk leg draws the bar too');
    final before = seen.length;
    hook!(3, 3000);
    expect(seen.skip(before), equals([(3, 3000)]));
  });

  test(
    'the per-chunk leg keeps the hook when it is reached by fallback',
    () async {
      // The other way into per-chunk: the archive was tried and refused. A
      // server that turns the archive off mid-transfer lands here, and so does
      // every client too old to have read the capability.
      final (:transport, :cache, :seen) = setup();
      transport.tarError = Exception(
        'HTTP 501 tar_transfer_disabled for ?format=tar',
      );

      await run(transport, cache, seen);

      expect(transport.tarCalls, hasLength(1));
      expect(transport.perChunkCalls, hasLength(1));
      final hook = transport.perChunkCalls.single.onProgress;
      expect(
        hook,
        isNotNull,
        reason: 'the fallback path drops it just as easily',
      );
      final before = seen.length;
      hook!(4, 4000);
      expect(seen.skip(before), equals([(4, 4000)]));
    },
  );

  test('every leg the runner can choose is covered above', () {
    // A fourth leg added without a hook would otherwise ship silently. This
    // fails when ChunkDownloadTransport grows one, which is the moment to add
    // the matching case rather than the release someone notices a dead bar.
    expect(
      FakeChunkDownloadTransport().legNames,
      unorderedEquals(const ['tar', 'perChunk', 'direct']),
    );
  });
}
