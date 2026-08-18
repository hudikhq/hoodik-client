import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/services/chunk_download_pipeline.dart';
import 'package:hoodik_app/core/services/offline_manager.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_downloads_dao.dart';

import '../../helpers/fakes.dart';

class _FakeFilesClient extends Fake implements FilesClient {
  @override
  Future<ChunkUrlsResponse?> fetchChunkUrls(String fileId) async => null;
}

class _FakeApiClient extends Fake implements ApiClient {
  @override
  String get baseUrl => 'https://drive.example.com';

  @override
  FilesClient get files => _FakeFilesClient();

  @override
  Future<void> ensureFreshSession() async {}

  @override
  Future<String> getCookieHeader() async => 'session=abc';
}

void main() {
  late AppDatabase db;
  late OfflineManager offline;
  late FakeChunkDownloadTransport transport;
  late Directory chunks;

  ChunkDownloadPipeline build() => ChunkDownloadPipeline(
    client: _FakeApiClient(),
    offlineManager: offline,
    tarCapabilityCache: TarCapabilityCache(),
    accountId: 'acct',
    transport: transport,
    database: db,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    offline = OfflineManager(db);
    transport = FakeChunkDownloadTransport();
    chunks = Directory.systemTemp.createTempSync('resume_chunks');
  });

  tearDown(() async {
    if (chunks.existsSync()) chunks.deleteSync(recursive: true);
    await db.close();
  });

  Future<PendingDownload> strand({required int chunkCount}) async {
    await db.recordPendingDownload(
      accountId: 'acct',
      fileId: 'file-1',
      chunkCount: chunkCount,
      outputDir: chunks.path,
    );
    return (await db.getPendingDownloads('acct')).single;
  }

  void writeChunk(int index) {
    File(
      '${chunks.path}/${index.toString().padLeft(6, '0')}.enc',
    ).writeAsStringSync('x');
  }

  // The OS carries a transfer on after the app is gone, and on iOS may finish
  // it entirely. The row outlives that, so a relaunch has to tell "already
  // done" from "stopped partway" before it fetches anything.
  test(
    'a download the OS finished while the app was gone is just recorded',
    () async {
      final row = await strand(chunkCount: 3);
      writeChunk(0);
      writeChunk(1);
      writeChunk(2);

      await build().resumeInterrupted([row]);

      expect(transport.tarCalls, isEmpty);
      expect(transport.perChunkCalls, isEmpty);
      expect(transport.directCalls, isEmpty);
      expect(await db.getPendingDownloads('acct'), isEmpty);
      expect(await offline.hasCachedFile('acct', 'file-1'), isTrue);
    },
  );

  test('a download stopped partway is picked back up', () async {
    final row = await strand(chunkCount: 3);
    writeChunk(0);

    await build().resumeInterrupted([row]);

    expect(transport.tarCalls, hasLength(1));
    expect(transport.tarCalls.single.fileId, 'file-1');
    expect(transport.tarCalls.single.outputDir, chunks.path);
  });

  // A file whose manifest has gone, or whose server is down, says nothing
  // about the next file in the list. Stopping on the first one would leave
  // every later download stranded for another session.
  test('one that cannot be resumed does not strand the others', () async {
    await db.recordPendingDownload(
      accountId: 'acct',
      fileId: 'file-broken',
      chunkCount: 2,
      outputDir: chunks.path,
    );
    await db.recordPendingDownload(
      accountId: 'acct',
      fileId: 'file-ok',
      chunkCount: 2,
      outputDir: chunks.path,
    );
    final rows = await db.getPendingDownloads('acct');
    transport.tarError = Exception('manifest gone');
    transport.perChunkError = Exception('manifest gone');

    await build().resumeInterrupted(rows);

    // The failing one keeps its row so a later session can try again; the
    // other is finished and cleared.
    final left = await db.getPendingDownloads('acct');
    expect(left.map((r) => r.fileId), ['file-broken']);
  });
}
