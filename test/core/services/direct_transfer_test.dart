import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/services/chunk_download_runner.dart';
import 'package:hoodik_app/core/services/file_downloader_config.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';

import '../../helpers/fakes.dart';

void main() {
  group('ChunkUrlsResponse', () {
    // Order in the response is not a contract; the chunk index is. Reading
    // positionally would decrypt chunks in the wrong order, which surfaces as
    // a corrupt file rather than an error.
    test('orders urls by chunk index, not by response order', () {
      final parsed = ChunkUrlsResponse.fromJson({
        'urls': [
          {'chunk': 2, 'url': 'https://bucket/2'},
          {'chunk': 0, 'url': 'https://bucket/0'},
          {'chunk': 1, 'url': 'https://bucket/1'},
        ],
        'expires_at': 1234,
      });

      expect(parsed.urls, [
        'https://bucket/0',
        'https://bucket/1',
        'https://bucket/2',
      ]);
      expect(parsed.expiresAt, 1234);
    });

    // A gap must stay a gap. Collapsing it would shift every later chunk down
    // one and hand the wrong bytes to the decryptor.
    test('leaves an uncovered index empty rather than shifting the rest', () {
      final parsed = ChunkUrlsResponse.fromJson({
        'urls': [
          {'chunk': 0, 'url': 'https://bucket/0'},
          {'chunk': 2, 'url': 'https://bucket/2'},
        ],
        'expires_at': 1,
      });

      expect(parsed.urls, ['https://bucket/0', '', 'https://bucket/2']);
    });

    test('an empty payload reads as no manifest', () {
      expect(
        ChunkUrlsResponse.fromJson({'urls': [], 'expires_at': 0}).isEmpty,
        isTrue,
      );
      expect(ChunkUrlsResponse.fromJson(const {}).isEmpty, isTrue);
    });

    test('skips malformed entries instead of throwing', () {
      final parsed = ChunkUrlsResponse.fromJson({
        'urls': [
          {'chunk': 0, 'url': 'https://bucket/0'},
          {'chunk': null, 'url': 'https://bucket/x'},
          {'chunk': 1},
          'nonsense',
        ],
        'expires_at': 5,
      });

      expect(parsed.urls, ['https://bucket/0']);
    });
  });

  group('Capabilities.directTransfer', () {
    // Absent has to read as false: a server that predates the feature omits
    // the field entirely, and guessing true would send every download at a
    // bucket that will refuse it.
    test('defaults to false when the server omits the field', () {
      final caps = Capabilities.fromJson({
        'sharing': {'enabled': true, 'roles': <String>[]},
        'editable_folders': true,
        'share_groups': true,
        'audit_log': true,
        'fork': true,
      });

      expect(caps.directTransfer, isFalse);
    });

    test('is read when the server advertises it', () {
      final caps = Capabilities.fromJson({
        'sharing': {'enabled': true, 'roles': <String>[]},
        'editable_folders': true,
        'share_groups': true,
        'audit_log': true,
        'fork': true,
        'direct_transfer': true,
      });

      expect(caps.directTransfer, isTrue);
    });

    test('the fail-closed sentinel has it off', () {
      expect(const Capabilities.disabled().directTransfer, isFalse);
    });
  });

  group('ChunkDownloadRunner routing', () {
    late FakeChunkDownloadTransport transport;
    late TarCapabilityCache cache;
    late ChunkDownloadRunner runner;

    setUp(() {
      transport = FakeChunkDownloadTransport();
      cache = TarCapabilityCache();
      runner = ChunkDownloadRunner(
        transport: transport,
        tarCapabilityCache: cache,
      );
    });

    Future<void> run({
      List<String> directUrls = const [],
      Future<List<String>?> Function()? refreshDirectUrls,
    }) => runner.run(
      baseUrl: 'https://drive.example.com',
      cookie: 'session=abc',
      fileId: 'file-1',
      fileSize: 1024,
      chunkCount: 2,
      outputDir: '/tmp/chunks',
      alreadyDownloaded: const [],
      accountId: 'acct-test',
      directUrls: directUrls,
      refreshDirectUrls: refreshDirectUrls,
    );

    // The tar exists to spare the server N requests. When the chunks are not
    // coming from the server at all, routing them through it is the one thing
    // worth avoiding — and the bucket leg is the only one the OS keeps
    // running while the app is suspended.
    test('a manifest goes straight at the bucket, skipping tar and the '
        'in-process pipeline', () async {
      await run(directUrls: ['https://bucket/0', 'https://bucket/1']);

      expect(transport.tarCalls, isEmpty);
      expect(transport.perChunkCalls, isEmpty);
      expect(transport.directCalls.single.directUrls, [
        'https://bucket/0',
        'https://bucket/1',
      ]);
    });

    test('without a manifest it still prefers tar', () async {
      await run();

      expect(transport.tarCalls, hasLength(1));
      expect(transport.directCalls, isEmpty);
    });

    // Half a manifest would split one file across two transports, only one of
    // which survives suspension — so the transfer as a whole still would not.
    test('a manifest missing a chunk falls back rather than splitting the '
        'file across transports', () async {
      await run(directUrls: const ['https://bucket/0', '']);

      expect(transport.directCalls, isEmpty);
      expect(transport.tarCalls, hasLength(1));
    });

    test('a manifest shorter than the file falls back too', () async {
      await run(directUrls: const ['https://bucket/0']);

      expect(transport.directCalls, isEmpty);
      expect(transport.tarCalls, hasLength(1));
    });

    // Presigned URLs outlive the transfer they were minted for, but not
    // forever, and a download the OS carried across several launches can come
    // back to a 403.
    test(
      'an expired manifest is refetched once and the transfer continues',
      () async {
        transport.directError = Exception('403 Forbidden (status 403)');

        await run(
          directUrls: const ['https://bucket/0', 'https://bucket/1'],
          refreshDirectUrls: () async => const [
            'https://bucket/0?fresh',
            'https://bucket/1?fresh',
          ],
        );

        expect(transport.directCalls, hasLength(2));
        expect(transport.directCalls.last.directUrls, [
          'https://bucket/0?fresh',
          'https://bucket/1?fresh',
        ]);
        expect(transport.tarCalls, isEmpty);
      },
    );

    // A second failure is a real failure. Falling back to the server here
    // would quietly put the bytes back on the metered path this feature
    // exists to avoid.
    test(
      'a server that can no longer sign gives up instead of relaying',
      () async {
        transport.directError = Exception('403 Forbidden');

        await expectLater(
          run(
            directUrls: const ['https://bucket/0', 'https://bucket/1'],
            refreshDirectUrls: () async => null,
          ),
          throwsA(isA<Exception>()),
        );
        expect(transport.tarCalls, isEmpty);
        expect(transport.perChunkCalls, isEmpty);
      },
    );
  });

  group('transfer task ids', () {
    // The OS hands tasks back after a restart with nothing but the id, so the
    // owning account has to travel inside it or a cold start cannot tell this
    // account's work from the previous session's.
    test('round-trip the account and file they belong to', () {
      final id = transferTaskId(
        prefix: 'chunk-downloads',
        accountId: 'acct-1',
        fileId: 'file-9',
        chunk: 3,
      );

      expect(accountIdFromTaskId(id), 'acct-1');
      expect(fileIdFromTaskId(id), 'file-9');
    });

    test('work without a chunk suffix', () {
      final id = transferTaskId(
        prefix: 'tar-downloads',
        accountId: 'acct-2',
        fileId: 'file-4',
      );

      expect(accountIdFromTaskId(id), 'acct-2');
      expect(fileIdFromTaskId(id), 'file-4');
    });

    // Chunk uploads and tar downloads still use their own id schemes, which
    // carry no owner. adoptTransfersForAccount leaves those running rather
    // than cancelling them on sign-in, so the answer has to be "unknown"
    // rather than a guess.
    test('an unrecognised id yields no owner rather than a wrong one', () {
      expect(accountIdFromTaskId('legacy-task-id'), isNull);
      expect(fileIdFromTaskId('legacy-task-id'), isNull);
      expect(accountIdFromTaskId('upload:file-1:3'), isNull);
      expect(accountIdFromTaskId('tar:file-1'), isNull);
    });
  });
}
