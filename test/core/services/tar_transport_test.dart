import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/binary_upload_transport.dart';
import 'package:hoodik_app/core/services/chunk_download_transport.dart';
import 'package:path/path.dart' as p;

/// Regression coverage for the fix that moves tar HTTP out of Rust and
/// into `background_downloader`. These tests would have failed against
/// the old wiring where the tar leg flowed through reqwest inside the
/// FFI — both transports now land the archive on disk and hand the path
/// off to Dart + the Rust pack/unpack FFI rather than initiating the
/// HTTP round-trip inside Rust.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hoodik_tar_transport_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> stagingPath(String filename) async {
    return p.join(tmp.path, 'staging', filename);
  }

  group('BackgroundDownloaderChunkTransport', () {
    test('happy path: fetch lands the tar on disk, unpack is called with '
        'that path, and the tar is deleted after success', () async {
      final backend = _FakeDownloadBackend();
      final transport = BackgroundDownloaderChunkTransport.forTesting(
        backend: backend,
        stagingTarPath: stagingPath,
      );

      await transport.downloadAsTar(
        baseUrl: 'https://drive.example.com',
        cookie: 'session=abc',
        fileId: 'file-123',
        fileSize: 4194304,
        chunkCount: 1,
        outputDir: p.join(tmp.path, 'chunks'),
        alreadyDownloaded: const [],
      );

      expect(backend.fetchCalls, hasLength(1));
      final fetchCall = backend.fetchCalls.single;
      expect(fetchCall.taskId, equals('file-123'));
      expect(
        fetchCall.url,
        equals('https://drive.example.com/api/storage/file-123?format=tar'),
      );
      expect(fetchCall.headers, equals({'Cookie': 'session=abc'}));
      expect(
        fetchCall.outputPath,
        equals(p.join(tmp.path, 'staging', 'download_file-123.tar')),
      );

      expect(backend.unpackCalls, hasLength(1));
      expect(
        backend.unpackCalls.single.tarPath,
        equals(fetchCall.outputPath),
        reason: 'The path landed on disk by fetch must be the unpack input',
      );
      expect(
        backend.unpackCalls.single.outputDir,
        equals(p.join(tmp.path, 'chunks')),
      );

      expect(
        await File(fetchCall.outputPath).exists(),
        isFalse,
        reason: 'Tar file must be removed after successful unpack',
      );
    });

    test('fetch fails: the tar file (if any) is removed before the error '
        'surfaces to the caller', () async {
      final backend = _FakeDownloadBackend()
        ..fetchError = Exception('Connection reset');
      final transport = BackgroundDownloaderChunkTransport.forTesting(
        backend: backend,
        stagingTarPath: stagingPath,
      );

      await expectLater(
        transport.downloadAsTar(
          baseUrl: 'https://drive.example.com',
          cookie: '',
          fileId: 'file-xyz',
          fileSize: 100,
          chunkCount: 1,
          outputDir: p.join(tmp.path, 'chunks'),
          alreadyDownloaded: const [],
        ),
        throwsA(isA<Exception>()),
      );

      expect(backend.unpackCalls, isEmpty);
      expect(
        await File(
          p.join(tmp.path, 'staging', 'download_file-xyz.tar'),
        ).exists(),
        isFalse,
      );
    });

    test('empty cookie: no Cookie header is sent (matches transfer crate '
        'auth semantics where an empty value means "no header")', () async {
      final backend = _FakeDownloadBackend();
      final transport = BackgroundDownloaderChunkTransport.forTesting(
        backend: backend,
        stagingTarPath: stagingPath,
      );

      await transport.downloadAsTar(
        baseUrl: 'https://drive.example.com',
        cookie: '',
        fileId: 'file-9',
        fileSize: 1,
        chunkCount: 1,
        outputDir: p.join(tmp.path, 'chunks'),
        alreadyDownloaded: const [],
      );

      expect(backend.fetchCalls.single.headers, isEmpty);
    });
  });

  group('BackgroundDownloaderUploadTarTransport', () {
    test('happy path: pack writes the tar, send uploads it, the body is '
        'parsed into an UploadTarResult, and the tar is deleted', () async {
      final backend = _FakeUploadBackend()
        ..sendResponse = jsonEncode({
          'chunks_stored': 3,
          'finished_upload_at': 1700000000,
        });
      final transport = BackgroundDownloaderUploadTarTransport.forTesting(
        backend: backend,
        stagingTarPath: stagingPath,
      );

      final result = await transport.uploadAsTar(
        baseUrl: 'https://drive.example.com',
        transferToken: 'transfer-jwt-1',
        fileId: 'file-up-1',
        chunksDir: p.join(tmp.path, 'encrypted'),
        chunkCount: 3,
      );

      expect(result.chunksStored, equals(3));
      expect(result.finishedUploadAt, equals(1700000000));
      expect(result.finished, isTrue);

      expect(backend.packCalls, hasLength(1));
      final pack = backend.packCalls.single;
      expect(pack.chunksDir, equals(p.join(tmp.path, 'encrypted')));
      expect(pack.chunkCount, equals(3));
      expect(
        pack.tarPath,
        equals(p.join(tmp.path, 'staging', 'upload_file-up-1.tar')),
      );

      expect(backend.sendCalls, hasLength(1));
      final send = backend.sendCalls.single;
      expect(send.taskId, equals('file-up-1'));
      expect(
        send.url,
        equals('https://drive.example.com/api/storage/file-up-1?format=tar'),
      );
      expect(send.headers, equals({'Authorization': 'Bearer transfer-jwt-1'}));
      expect(send.tarPath, equals(pack.tarPath));

      expect(
        await File(pack.tarPath).exists(),
        isFalse,
        reason: 'Tar file must be removed after successful upload',
      );
    });

    test(
      'send fails: the tar file is removed before the error surfaces',
      () async {
        final backend = _FakeUploadBackend()..sendError = Exception('HTTP 500');
        final transport = BackgroundDownloaderUploadTarTransport.forTesting(
          backend: backend,
          stagingTarPath: stagingPath,
        );

        await expectLater(
          transport.uploadAsTar(
            baseUrl: 'https://drive.example.com',
            transferToken: 'transfer-jwt-2',
            fileId: 'file-up-2',
            chunksDir: p.join(tmp.path, 'encrypted'),
            chunkCount: 1,
          ),
          throwsA(isA<Exception>()),
        );

        expect(
          await File(
            p.join(tmp.path, 'staging', 'upload_file-up-2.tar'),
          ).exists(),
          isFalse,
          reason: 'Failure path must still clean up the staged tar',
        );
      },
    );

    test('empty response body decodes to an in-progress result', () async {
      final backend = _FakeUploadBackend()..sendResponse = '';
      final transport = BackgroundDownloaderUploadTarTransport.forTesting(
        backend: backend,
        stagingTarPath: stagingPath,
      );

      final result = await transport.uploadAsTar(
        baseUrl: 'https://drive.example.com',
        transferToken: 'transfer-jwt-empty',
        fileId: 'file-up-empty',
        chunksDir: p.join(tmp.path, 'encrypted'),
        chunkCount: 1,
      );

      expect(result.chunksStored, equals(0));
      expect(result.finishedUploadAt, isNull);
      expect(result.finished, isFalse);
    });

    test('onProgress events are forwarded through the transport so the '
        'pipeline can drive the UI bar — without this wire a 300 MB '
        'upload sat at 0 % until completion', () async {
      final backend = _FakeUploadBackend()
        ..progressEvents = const [(0, 200), (100, 200), (200, 200)];
      final transport = BackgroundDownloaderUploadTarTransport.forTesting(
        backend: backend,
        stagingTarPath: stagingPath,
      );
      final captured = <(int, int)>[];

      await transport.uploadAsTar(
        baseUrl: 'https://drive.example.com',
        transferToken: 'transfer-jwt-progress',
        fileId: 'file-up-progress',
        chunksDir: p.join(tmp.path, 'encrypted'),
        chunkCount: 1,
        onProgress: (sent, total) => captured.add((sent, total)),
      );

      expect(captured, equals(const [(0, 200), (100, 200), (200, 200)]));
    });
  });
}

class _FetchCall {
  final String taskId;
  final String url;
  final Map<String, String> headers;
  final String outputPath;
  final int totalBytes;

  _FetchCall({
    required this.taskId,
    required this.url,
    required this.headers,
    required this.outputPath,
    required this.totalBytes,
  });
}

class _UnpackCall {
  final String tarPath;
  final String outputDir;
  _UnpackCall(this.tarPath, this.outputDir);
}

class _FakeDownloadBackend implements TarDownloadBackend {
  final List<_FetchCall> fetchCalls = [];
  final List<_UnpackCall> unpackCalls = [];
  Object? fetchError;
  Object? unpackError;

  @override
  Future<void> fetch({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String outputPath,
    required int totalBytes,
  }) async {
    fetchCalls.add(
      _FetchCall(
        taskId: taskId,
        url: url,
        headers: Map.unmodifiable(headers),
        outputPath: outputPath,
        totalBytes: totalBytes,
      ),
    );

    final err = fetchError;
    if (err != null) {
      fetchError = null;
      throw err;
    }

    await Directory(p.dirname(outputPath)).create(recursive: true);
    await File(outputPath).writeAsBytes(List<int>.filled(128, 0));
  }

  @override
  void unpack({required String tarPath, required String outputDir}) {
    unpackCalls.add(_UnpackCall(tarPath, outputDir));
    final err = unpackError;
    if (err != null) {
      unpackError = null;
      throw err;
    }
  }
}

class _PackCall {
  final String chunksDir;
  final int chunkCount;
  final String tarPath;
  _PackCall(this.chunksDir, this.chunkCount, this.tarPath);
}

class _SendCall {
  final String taskId;
  final String url;
  final Map<String, String> headers;
  final String tarPath;
  _SendCall(this.taskId, this.url, this.headers, this.tarPath);
}

class _FakeUploadBackend implements TarUploadBackend {
  final List<_PackCall> packCalls = [];
  final List<_SendCall> sendCalls = [];
  Object? packError;
  Object? sendError;
  String sendResponse = '{"chunks_stored":1,"finished_upload_at":1}';

  /// Progress events the next [send] should replay. Each entry is
  /// `(transferred, total)`.
  List<(int, int)> progressEvents = const [];

  @override
  void pack({
    required String chunksDir,
    required int chunkCount,
    required String tarPath,
  }) {
    packCalls.add(_PackCall(chunksDir, chunkCount, tarPath));
    final err = packError;
    if (err != null) {
      packError = null;
      throw err;
    }
    Directory(p.dirname(tarPath)).createSync(recursive: true);
    File(tarPath).writeAsBytesSync(List<int>.filled(256, 0));
  }

  @override
  Future<String> send({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String tarPath,
    void Function(int transferred, int total)? onProgress,
  }) async {
    sendCalls.add(_SendCall(taskId, url, Map.unmodifiable(headers), tarPath));
    if (onProgress != null) {
      for (final (t, total) in progressEvents) {
        onProgress(t, total);
      }
    }
    final err = sendError;
    if (err != null) {
      sendError = null;
      throw err;
    }
    return sendResponse;
  }
}
