import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/file_downloader.dart';
import 'package:hoodik_app/core/services/offline_manager.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';
import 'package:hoodik_app/core/storage/database.dart';

import '../../helpers/fakes.dart';

/// Every way the app acquires a file's bytes, asserted separately.
///
/// Export went direct for weeks while pinning a file for offline use still
/// pulled a tar through the server and previews still asked for one chunk at a
/// time — and nothing caught it, because each tail had grown its own transport
/// and only one of them was ever tested. There is one transport now; these
/// tests are what keeps it that way, one per tail rather than one per feature.
class _FakeFilesClient extends Fake implements FilesClient {
  int manifestRequests = 0;
  int relayedChunkRequests = 0;

  @override
  Future<ChunkUrlsResponse?> fetchChunkUrls(String fileId) async {
    manifestRequests++;
    return ChunkUrlsResponse(
      urls: const [
        'https://bucket.example.com/obj/000000.chunk?X-Amz-Signature=deadbeef',
        'https://bucket.example.com/obj/000001.chunk?X-Amz-Signature=deadbeef',
      ],
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
    );
  }

  @override
  Future<Uint8List> downloadChunk({
    required String fileId,
    required int chunk,
  }) async {
    relayedChunkRequests++;
    return Uint8List.fromList(const [1, 2, 3]);
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this.files);

  @override
  final _FakeFilesClient files;

  @override
  String get baseUrl => 'https://drive.example.com';

  @override
  Future<void> ensureFreshSession() async {}

  @override
  Future<String> getCookieHeader() async => 'session=abc';
}

void main() {
  late AppDatabase db;
  late OfflineManager offline;
  late FakeChunkDownloadTransport transport;
  late _FakeFilesClient filesClient;
  late Directory support;

  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  final file = FileItem(
    id: '3f7c1a58-9d2e-4b60-8a11-6c5d0e2f4b93',
    encryptedName: 'holiday.mov',
    mime: 'video/quicktime',
    size: 8388608,
    chunks: 2,
    cipher: 'aegis128l',
  );

  FileDownloader build() => FileDownloader(
    client: _FakeApiClient(filesClient),
    fileCrypto: FileCrypto(),
    offlineManager: offline,
    tarCapabilityCache: TarCapabilityCache(),
    chunkDownloadTransport: transport,
    database: db,
    accountId: 'acct',
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    offline = OfflineManager(db);
    transport = FakeChunkDownloadTransport();
    filesClient = _FakeFilesClient();
    support = Directory.systemTemp.createTempSync('download_tails');
    // The offline cache lives under the app support directory, which is a
    // platform channel this harness has no host for.
    for (final channel in const [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_macos',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => support.path,
      );
    }
  });

  tearDown(() async {
    if (support.existsSync()) support.deleteSync(recursive: true);
    await db.close();
  });

  void expectWentDirect() {
    expect(
      transport.directCalls,
      hasLength(1),
      reason: 'chunks should have come from the bucket',
    );
    expect(transport.tarCalls, isEmpty);
    expect(transport.perChunkCalls, isEmpty);
    expect(
      filesClient.relayedChunkRequests,
      0,
      reason: 'no chunk should have been relayed through the server',
    );
    expect(
      filesClient.manifestRequests,
      1,
      reason: 'one manifest covers the whole file',
    );
  }

  test('pinning a file for offline use fetches its chunks from the '
      'bucket', () async {
    final done = Completer<void>();
    build().downloadAndPinOffline(
      file,
      onComplete: done.complete,
      onError: (e) => done.completeError(e),
    );
    await done.future;

    expectWentDirect();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'an in-memory read fetches its chunks from the bucket',
    () async {
      // The decrypt half needs the Rust runtime, which `flutter test` has no way
      // to boot, so it throws after the transfer. Where the bytes came from is
      // the half that regressed and the half this asserts.
      await expectLater(
        build().downloadFile(file, fileKey: Uint8List(32)),
        throwsA(anything),
      );

      expectWentDirect();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a second read of the same file refetches nothing',
    () async {
      final first = Completer<void>();
      final downloader = build();
      downloader.downloadAndPinOffline(
        file,
        onComplete: first.complete,
        onError: (e) => first.completeError(e),
      );
      await first.future;

      final second = Completer<void>();
      downloader.downloadAndPinOffline(
        file,
        onComplete: second.complete,
        onError: (e) => second.completeError(e),
      );
      await second.future;

      expect(
        transport.directCalls,
        hasLength(1),
        reason: 'the cache should have answered the second read',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
