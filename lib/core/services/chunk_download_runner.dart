import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'chunk_download_transport.dart';
import 'tar_fallback.dart';

const _log = Logger('ChunkDownloadRunner');

/// Selects between tar and per-chunk downloads and feeds the chosen
/// [ChunkDownloadTransport] method its arguments. Kept separate from
/// [ChunkDownloadPipeline] so the fallback logic can be unit-tested
/// without the surrounding orchestration (offline cache, transfer
/// manager, decrypt step).
class ChunkDownloadRunner {
  final ChunkDownloadTransport _transport;
  final TarCapabilityCache _tarCapabilityCache;

  const ChunkDownloadRunner({
    required ChunkDownloadTransport transport,
    required TarCapabilityCache tarCapabilityCache,
  }) : _transport = transport,
       _tarCapabilityCache = tarCapabilityCache;

  /// Run the download, preferring the tar endpoint. Drops back to
  /// per-chunk when the cache says the server doesn't speak tar or when
  /// a tar attempt raises a [shouldFallbackToPerChunk] error.
  Future<void> run({
    required String baseUrl,
    required String cookie,
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String outputDir,
    required List<int> alreadyDownloaded,
    List<String> directUrls = const [],
  }) async {
    // Direct transfer wins over tar when the server offers it. The tar exists
    // to spare the server N requests; when the chunks aren't coming from the
    // server at all, bundling them through it is the one thing worth avoiding.
    if (directUrls.isNotEmpty) {
      await _transport.downloadPerChunk(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: alreadyDownloaded,
        directUrls: directUrls,
      );
      return;
    }

    if (_tarCapabilityCache.lookup(baseUrl) == false) {
      await _transport.downloadPerChunk(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: alreadyDownloaded,
      );
      return;
    }

    try {
      await _transport.downloadAsTar(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: alreadyDownloaded,
      );
      _tarCapabilityCache.markSupported(baseUrl);
    } catch (e) {
      if (!shouldFallbackToPerChunk(e)) rethrow;
      _log.info(
        'tar download rejected — falling back to per-chunk',
        fields: {'base_url': baseUrl, 'error': describeError(e)},
      );
      _tarCapabilityCache.markUnsupported(baseUrl);
      await _transport.downloadPerChunk(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: alreadyDownloaded,
      );
    }
  }
}
