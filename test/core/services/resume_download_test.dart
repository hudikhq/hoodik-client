import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/chunk_urls_models.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/chunk_download_pipeline.dart';
import 'package:hoodik_app/core/services/offline_manager.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';
import 'package:hoodik_app/core/services/transfer_manager.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_downloads_dao.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late AppDatabase db;
  late OfflineManager offline;
  late FakeChunkDownloadTransport transport;
  late TransferManager transfers;
  late FileCrypto fileCrypto;
  late String publicKeyPem;
  late Directory chunks;

  ChunkDownloadPipeline build() => ChunkDownloadPipeline(
    client: _FakeApiClient(),
    offlineManager: offline,
    tarCapabilityCache: TarCapabilityCache(),
    accountId: 'acct',
    transport: transport,
    database: db,
    fileCrypto: fileCrypto,
    transferManager: transfers,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    offline = OfflineManager(db);
    transport = FakeChunkDownloadTransport();
    transfers = TransferManager();
    final keypair = rust.generateRsaKeypair();
    fileCrypto = FileCrypto(privateKeyPem: keypair.privateKeyPem);
    publicKeyPem = keypair.publicKeyPem;
    chunks = Directory.systemTemp.createTempSync('resume_chunks');
  });

  tearDown(() async {
    if (chunks.existsSync()) chunks.deleteSync(recursive: true);
    await db.close();
  });

  Future<PendingDownload> strand({required int chunkCount}) async {
    await db.recordPendingDownload(
      accountId: 'acct',
      fileId: 'file-0001',
      chunkCount: chunkCount,
      fileSize: chunkCount * 1024,
      outputDir: chunks.path,
    );
    return (await db.getPendingDownloads('acct')).single;
  }

  /// The metadata-cache row a directory listing would have left behind before
  /// the app was killed.
  Future<void> cacheMetadata({required int size, required String name}) async {
    final fileKey = fileCrypto.generateFileKey();
    await db.upsertCachedFile(
      CachedFilesCompanion.insert(
        accountId: 'acct',
        id: 'file-0001',
        encryptedName: fileCrypto.encryptFileName(
          name: name,
          fileKey: fileKey,
          cipher: 'aegis128l',
        ),
        encryptedKey: Value(
          fileCrypto.encryptFileKey(
            fileKey: fileKey,
            publicKeyPem: publicKeyPem,
          ),
        ),
        mime: 'application/octet-stream',
        size: Value(size),
      ),
    );
  }

  /// Resume the row and stop inside the download, where the overlay entry the
  /// user sees is at the state the resume gave it.
  Future<TransferItem> resumeAndHold(PendingDownload row) async {
    final gate = Completer<void>();
    transport.hold = gate.future;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    unawaited(build().resumeInterrupted([row]));

    // The resume reads disk and the metadata cache before it registers
    // anything, so yield until the entry shows up rather than guessing how
    // many turns of the loop that takes.
    for (var i = 0; transfers.visibleTransfers.isEmpty && i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    return transfers.visibleTransfers.single;
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
      expect(await offline.hasCachedFile('acct', 'file-0001'), isTrue);
    },
  );

  test('a download stopped partway is picked back up', () async {
    final row = await strand(chunkCount: 3);
    writeChunk(0);

    await build().resumeInterrupted([row]);

    expect(transport.tarCalls, hasLength(1));
    expect(transport.tarCalls.single.fileId, 'file-0001');
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
      fileSize: 2048,
      outputDir: chunks.path,
    );
    await db.recordPendingDownload(
      accountId: 'acct',
      fileId: 'file-okay',
      chunkCount: 2,
      fileSize: 2048,
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

  // Nothing in this session started these transfers, so nothing in it would
  // draw them either: the pipeline that owned the bar died with the previous
  // process. Without an item in the manager the overlay never mounts, and the
  // download the user is waiting on runs invisibly.
  group('the transfer a resume shows', () {
    test('opens at the fraction already on disk', () async {
      final row = await strand(chunkCount: 4);
      writeChunk(0);
      writeChunk(1);

      final item = await resumeAndHold(row);

      expect(item.fileId, 'file-0001');
      expect(item.type, TransferType.downloadHttp);
      expect(item.totalBytes, 4096);
      expect(item.totalChunks, 4);
      expect(item.completedChunks, 2);
      expect(item.transferredBytes, 2048);
      expect(item.progress, 0.5);
    });

    // The size used to be read off the metadata cache, which holds only what
    // the user has browsed to recently. A miss left totalBytes at zero, and a
    // bar with no total sits at 0 % with no speed and no ETA for the whole run
    // however many bytes arrive.
    test('knows how big the file is without the metadata cache', () async {
      final row = await strand(chunkCount: 2);
      writeChunk(0);

      final item = await resumeAndHold(row);

      expect(item.totalBytes, 2048);
    });

    // Bytes a previous session fetched arrive at once. Counted as throughput
    // they read as several GB/s and an ETA of nothing — wrong in the direction
    // that makes the estimate useless.
    test('does not count the resumed bytes as speed', () async {
      final row = await strand(chunkCount: 4);
      writeChunk(0);
      writeChunk(1);
      writeChunk(2);

      final item = await resumeAndHold(row);

      expect(item.bytesPerSecond, 0);
      expect(item.speedString, isEmpty);
      expect(item.etaString, isEmpty);
    });

    test('reports what this session moves', () async {
      final row = await strand(chunkCount: 4);
      writeChunk(0);

      final item = await resumeAndHold(row);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      transfers.updateProgress(
        item.id,
        completedChunks: 2,
        transferredBytes: 2048,
      );

      // 1024 bytes over ~20 ms is tens of KB/s. Counting the chunk the
      // previous session left would put it in the megabytes.
      expect(item.bytesPerSecond, greaterThan(0));
      expect(item.bytesPerSecond, lessThan(1024 * 1024));
    });

    test('carries the file name rather than its id', () async {
      await cacheMetadata(size: 3072, name: 'quarterly-report.pdf');
      final row = await strand(chunkCount: 3);
      writeChunk(0);

      final item = await resumeAndHold(row);

      expect(item.fileName, 'quarterly-report.pdf');
    });

    // An account that lost access to the file between the two sessions cannot
    // read its name back. That is not a reason to drop the transfer.
    test('falls back to the id when the name cannot be read', () async {
      final row = await strand(chunkCount: 3);
      writeChunk(0);

      final item = await resumeAndHold(row);

      expect(item.fileName, 'file-000');
    });
  });
}
