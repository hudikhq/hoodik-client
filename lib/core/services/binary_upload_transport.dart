import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../src/rust/api.dart' as rust;
import 'background_tar_transfer.dart';

/// Seam around the tar upload path so [BinaryUploadPipeline] can be unit-
/// tested without spinning up Rust or the OS-native uploader. Per-chunk
/// uploads still go through [BackgroundUploadService] in production; the
/// transport's tar method is shaped to let a test stub track which
/// encrypted bytes the pipeline would have sent.
abstract class UploadTarTransport {
  /// POST the chunks under [chunksDir] to the server as one tar stream.
  /// Returns the `chunks_stored` / `finished_upload_at` summary so the
  /// pipeline can tell whether the upload fully completed on this attempt.
  ///
  /// [transferToken] is the short-lived JWT scoped to this `(fileId,
  /// upload)` pair — sent as `Authorization: Bearer …` to match the
  /// per-chunk path. The transport intentionally does not see the session
  /// cookie: the tar endpoint accepts narrow-scope tokens, so we don't
  /// hand it broader credentials than it needs.
  ///
  /// [onProgress] receives `(transferred, total)` byte counts derived
  /// from the OS-native uploader's progress events as the tar streams
  /// to the server. Without this the UI sits at 0 % until the final
  /// response lands — fine for a 5 MB upload, brutal for a 300 MB one.
  Future<UploadTarResult> uploadAsTar({
    required String baseUrl,
    required String transferToken,
    required String fileId,
    required String chunksDir,
    required int chunkCount,
    void Function(int transferred, int total)? onProgress,
  });
}

/// Packs staging chunks into a tar file and uploads the archive. Lets
/// [BackgroundDownloaderUploadTarTransport] swap the pack+upload pair for
/// in-process fakes during tests.
abstract class TarUploadBackend {
  void pack({
    required String chunksDir,
    required int chunkCount,
    required String tarPath,
  });

  Future<String> send({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String tarPath,
    void Function(int transferred, int total)? onProgress,
  });
}

/// Production adapter: packs the encrypted staging chunks into a tar file
/// via Rust FFI, then uploads the archive through `background_downloader`
/// (iOS URLSession / Android WorkManager) so the transfer survives app
/// suspension. The pack step is pure local I/O; the network leg is entirely
/// Dart-side so the OS can keep moving bytes while the app is backgrounded.
class BackgroundDownloaderUploadTarTransport implements UploadTarTransport {
  final TarUploadBackend _backend;
  final Future<String> Function(String) _stagingTarPath;

  BackgroundDownloaderUploadTarTransport({
    required BackgroundTarTransfer tarTransfer,
  }) : _backend = _BackgroundTarUploadBackend(tarTransfer),
       _stagingTarPath = _defaultStagingTarPath;

  @visibleForTesting
  BackgroundDownloaderUploadTarTransport.forTesting({
    required TarUploadBackend backend,
    required Future<String> Function(String) stagingTarPath,
  }) : _backend = backend,
       _stagingTarPath = stagingTarPath;

  @override
  Future<UploadTarResult> uploadAsTar({
    required String baseUrl,
    required String transferToken,
    required String fileId,
    required String chunksDir,
    required int chunkCount,
    void Function(int transferred, int total)? onProgress,
  }) async {
    final tarPath = await _stagingTarPath('upload_$fileId.tar');
    await _ensureParent(tarPath);

    try {
      _backend.pack(
        chunksDir: chunksDir,
        chunkCount: chunkCount,
        tarPath: tarPath,
      );

      final responseBody = await _backend.send(
        taskId: fileId,
        url: '$baseUrl/api/storage/$fileId?format=tar',
        headers: {'Authorization': 'Bearer $transferToken'},
        tarPath: tarPath,
        onProgress: onProgress,
      );

      return _parseResponse(responseBody);
    } finally {
      await _deleteIfExists(tarPath);
    }
  }

  /// The server's upload-complete response mirrors `ChunkResponse` —
  /// `chunks_stored` + `finished_upload_at` are the only fields the pipeline
  /// consumes. We accept an empty body defensively so a misconfigured
  /// server still returns a valid partial-progress signal instead of
  /// throwing from the pipeline's response handler.
  UploadTarResult _parseResponse(String body) {
    if (body.isEmpty) {
      return const UploadTarResult(chunksStored: 0, finishedUploadAt: null);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Tar upload response was not a JSON object: $body');
    }
    return UploadTarResult(
      chunksStored: (decoded['chunks_stored'] as num?)?.toInt() ?? 0,
      finishedUploadAt: (decoded['finished_upload_at'] as num?)?.toInt(),
    );
  }
}

class _BackgroundTarUploadBackend implements TarUploadBackend {
  final BackgroundTarTransfer _tarTransfer;

  _BackgroundTarUploadBackend(this._tarTransfer);

  @override
  void pack({
    required String chunksDir,
    required int chunkCount,
    required String tarPath,
  }) {
    rust.packChunksToTar(
      chunksDir: chunksDir,
      chunkCount: BigInt.from(chunkCount),
      tarPath: tarPath,
    );
  }

  @override
  Future<String> send({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String tarPath,
    void Function(int transferred, int total)? onProgress,
  }) {
    return _tarTransfer.uploadTarFromFile(
      taskId: taskId,
      url: url,
      headers: headers,
      tarPath: tarPath,
      onProgress: onProgress,
    );
  }
}

/// Plain-Dart subset of the server's upload-complete response we surface
/// to the pipeline. Matches [rust.UploadCompleteSummary] without the FRB
/// [PlatformInt64] type so unit tests don't need to depend on FRB.
class UploadTarResult {
  final int chunksStored;
  final int? finishedUploadAt;

  const UploadTarResult({
    required this.chunksStored,
    required this.finishedUploadAt,
  });

  bool get finished => finishedUploadAt != null;
}

Future<String> _defaultStagingTarPath(String filename) async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'tar_staging', filename);
}

Future<void> _ensureParent(String path) async {
  final dir = Directory(p.dirname(path));
  if (!await dir.exists()) await dir.create(recursive: true);
}

Future<void> _deleteIfExists(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
