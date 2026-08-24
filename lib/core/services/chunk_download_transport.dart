import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show Uint64List;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../src/rust/api.dart' as rust;
import 'background_tar_transfer.dart';
import 'direct_chunk_download.dart';
import 'file_downloader_config.dart';

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
    required String accountId,
    void Function(int completedChunks, int transferredBytes)? onProgress,
  });

  Future<void> downloadPerChunk({
    required String baseUrl,
    required String cookie,
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String outputDir,
    required List<int> alreadyDownloaded,
    required String accountId,
  });

  /// Fetch the chunks straight from object storage using the presigned
  /// [urls], one OS-native task each, so the transfer keeps running while the
  /// app is suspended and picks up where it left off after a kill.
  ///
  /// Takes no base URL and no cookie on purpose: the presigned URL is the
  /// whole credential, and a leg with no session material in scope cannot
  /// attach any to a bucket request.
  Future<void> downloadDirectChunks({
    required String fileId,
    required List<String> urls,
    required int fileSize,
    required String outputDir,
    required List<int> alreadyDownloaded,
    required String accountId,
    void Function(int completedChunks, int transferredBytes)? onProgress,
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
    void Function(int transferred, int total)? onProgress,
  });

  void unpack({required String tarPath, required String outputDir});
}

/// Production adapter: runs the tar leg via `background_downloader` (iOS
/// URLSession / Android WorkManager) so the transfer survives app
/// suspension, then invokes the Rust FFI to unpack the archive into
/// individual chunk files. Direct transfers hand every chunk to
/// [DirectChunkDownloadService], which is background-durable for the same
/// reason. The per-chunk fallback still goes through the Rust HTTP pipeline
/// because its concurrent downloader is well tuned and only runs when the
/// server speaks neither `?format=tar` nor presigned URLs.
class BackgroundDownloaderChunkTransport implements ChunkDownloadTransport {
  final TarDownloadBackend _backend;
  final Future<String> Function(String) _stagingTarPath;

  final DirectChunkDownloadService _direct;

  BackgroundDownloaderChunkTransport({
    required BackgroundTarTransfer tarTransfer,
    required DirectChunkDownloadService directChunks,
  }) : _backend = _BackgroundTarDownloadBackend(tarTransfer),
       _direct = directChunks,
       _stagingTarPath = _defaultStagingTarPath;

  @visibleForTesting
  BackgroundDownloaderChunkTransport.forTesting({
    required TarDownloadBackend backend,
    required Future<String> Function(String) stagingTarPath,
    required DirectChunkDownloadService directChunks,
  }) : _backend = backend,
       _direct = directChunks,
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
    required String accountId,
    void Function(int completedChunks, int transferredBytes)? onProgress,
  }) async {
    final tarPath = await _stagingTarPath('download_$fileId.tar');
    await _ensureParent(tarPath);

    try {
      await _backend.fetch(
        taskId: transferTaskId(
          prefix: 'tar-downloads',
          accountId: accountId,
          fileId: fileId,
        ),
        url: '$baseUrl/api/storage/$fileId?format=tar',
        headers: cookie.isEmpty ? const {} : {'Cookie': cookie},
        outputPath: tarPath,
        totalBytes: fileSize,
        // The archive arrives as one transfer and the chunks only exist once
        // it is unpacked, so there are no completed chunks to count on the
        // way. Scaling the bytes gives the chunk-shaped display something
        // that moves, and the byte count beside it is exact.
        onProgress: onProgress == null
            ? null
            : (transferred, total) => onProgress(
                total <= 0 ? 0 : (transferred * chunkCount) ~/ total,
                transferred,
              ),
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
    required String accountId,
  }) {
    return rust.downloadEncryptedChunks(
      baseUrl: baseUrl,
      cookie: cookie,
      fileId: fileId,
      fileSize: BigInt.from(fileSize),
      chunkCount: BigInt.from(chunkCount),
      outputDir: outputDir,
      alreadyDownloaded: Uint64List.fromList(alreadyDownloaded),
      // Chunks that come from the bucket never take this path — they go
      // through [downloadDirectChunks], which the OS keeps running while the
      // app is suspended. This leg only ever talks to the server.
      directUrls: const [],
    );
  }

  @override
  Future<void> downloadDirectChunks({
    required String fileId,
    required List<String> urls,
    required int fileSize,
    required String outputDir,
    required List<int> alreadyDownloaded,
    required String accountId,
    void Function(int completedChunks, int transferredBytes)? onProgress,
  }) {
    return _direct.download(
      accountId: accountId,
      fileId: fileId,
      urls: urls,
      outputDir: outputDir,
      fileSize: fileSize,
      alreadyDownloaded: alreadyDownloaded,
      onProgress: onProgress,
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
    void Function(int transferred, int total)? onProgress,
  }) {
    return _tarTransfer.downloadTarToFile(
      taskId: taskId,
      url: url,
      headers: headers,
      outputPath: outputPath,
      totalBytes: totalBytes,
      onProgress: onProgress,
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
