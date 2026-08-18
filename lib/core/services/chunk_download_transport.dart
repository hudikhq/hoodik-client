import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show Uint64List;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../src/rust/api.dart' as rust;
import 'background_tar_transfer.dart';

/// Seam around the two chunk-download paths so unit tests can run the
/// pipeline without booting the Rust runtime or spinning up the OS
/// downloader. Production wires [BackgroundDownloaderChunkTransport]
/// through [ChunkDownloadPipeline]'s default constructor; tests substitute
/// an in-process fake.
abstract class ChunkDownloadTransport {
  Future<void> downloadAsTar({
    required String baseUrl,
    required String cookie,
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String outputDir,
    required List<int> alreadyDownloaded,
  });

  Future<void> downloadPerChunk({
    required String baseUrl,
    required String cookie,
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String outputDir,
    required List<int> alreadyDownloaded,
    List<String> directUrls,
  });
}

/// Moves the tar archive off the network and calls the unpacker after it
/// lands on disk. Lets [BackgroundDownloaderChunkTransport] swap the
/// HTTP-and-unpack pair for in-process fakes during tests.
abstract class TarDownloadBackend {
  Future<void> fetch({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String outputPath,
    required int totalBytes,
  });

  void unpack({required String tarPath, required String outputDir});
}

/// Production adapter: runs the tar leg via `background_downloader` (iOS
/// URLSession / Android WorkManager) so the transfer survives app
/// suspension, then invokes the Rust FFI to unpack the archive into
/// individual chunk files. The per-chunk fallback still goes through the
/// Rust HTTP pipeline because its concurrent downloader is well tuned and
/// only runs when the server doesn't speak `?format=tar`.
class BackgroundDownloaderChunkTransport implements ChunkDownloadTransport {
  final TarDownloadBackend _backend;
  final Future<String> Function(String) _stagingTarPath;

  BackgroundDownloaderChunkTransport({
    required BackgroundTarTransfer tarTransfer,
  }) : _backend = _BackgroundTarDownloadBackend(tarTransfer),
       _stagingTarPath = _defaultStagingTarPath;

  @visibleForTesting
  BackgroundDownloaderChunkTransport.forTesting({
    required TarDownloadBackend backend,
    required Future<String> Function(String) stagingTarPath,
  }) : _backend = backend,
       _stagingTarPath = stagingTarPath;

  @override
  Future<void> downloadAsTar({
    required String baseUrl,
    required String cookie,
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String outputDir,
    required List<int> alreadyDownloaded,
  }) async {
    final tarPath = await _stagingTarPath('download_$fileId.tar');
    await _ensureParent(tarPath);

    try {
      await _backend.fetch(
        taskId: fileId,
        url: '$baseUrl/api/storage/$fileId?format=tar',
        headers: cookie.isEmpty ? const {} : {'Cookie': cookie},
        outputPath: tarPath,
        totalBytes: fileSize,
      );

      _backend.unpack(tarPath: tarPath, outputDir: outputDir);
    } finally {
      await _deleteIfExists(tarPath);
    }
  }

  @override
  Future<void> downloadPerChunk({
    required String baseUrl,
    required String cookie,
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String outputDir,
    required List<int> alreadyDownloaded,
    List<String> directUrls = const [],
  }) {
    return rust.downloadEncryptedChunks(
      baseUrl: baseUrl,
      cookie: cookie,
      fileId: fileId,
      fileSize: BigInt.from(fileSize),
      chunkCount: BigInt.from(chunkCount),
      outputDir: outputDir,
      alreadyDownloaded: Uint64List.fromList(alreadyDownloaded),
      directUrls: directUrls,
    );
  }
}

class _BackgroundTarDownloadBackend implements TarDownloadBackend {
  final BackgroundTarTransfer _tarTransfer;

  _BackgroundTarDownloadBackend(this._tarTransfer);

  @override
  Future<void> fetch({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String outputPath,
    required int totalBytes,
  }) {
    return _tarTransfer.downloadTarToFile(
      taskId: taskId,
      url: url,
      headers: headers,
      outputPath: outputPath,
      totalBytes: totalBytes,
    );
  }

  @override
  void unpack({required String tarPath, required String outputDir}) {
    rust.unpackTarToChunks(tarPath: tarPath, outputDir: outputDir);
  }
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
