import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'chunk_download_transport.dart';
import 'tar_fallback.dart';
import 'transfer_errors.dart';

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
    required String accountId,
    List<String> directUrls = const [],
    Future<List<String>?> Function()? refreshDirectUrls,
    void Function(int completedChunks, int transferredBytes)? onProgress,
  }) async {
    // Direct transfer wins over tar when the server offers it. The tar exists
    // to spare the server N requests; when the chunks aren't coming from the
    // server at all, bundling them through it is the one thing worth avoiding.
    if (_coversEveryChunk(directUrls, chunkCount)) {
      Future<void> fetch(List<String> urls) => _transport.downloadDirectChunks(
        fileId: fileId,
        urls: urls,
        fileSize: fileSize,
        outputDir: outputDir,
        alreadyDownloaded: alreadyDownloaded,
        accountId: accountId,
        onProgress: onProgress,
      );

      try {
        await fetch(directUrls);
      } on TransferCancelledException {
        // A cancel is an answer, not a failure — retrying it with a fresh
        // manifest would restart the transfer the user just stopped.
        rethrow;
      } catch (e) {
        // Signed URLs are long-lived but not eternal, and a transfer the OS
        // carried across several launches can outlive them. One fresh manifest
        // is cheap — the chunks already on disk are skipped, so the retry only
        // refetches what is genuinely missing — and anything that fails twice
        // is a real failure.
        final refreshed = await refreshDirectUrls?.call();
        if (refreshed == null || !_coversEveryChunk(refreshed, chunkCount)) {
          rethrow;
        }
        _log.info(
          'retrying direct download with a fresh manifest',
          fields: {'file_id': fileId, 'error': describeError(e)},
        );
        await fetch(refreshed);
      }
      return;
    }

    if (directUrls.isNotEmpty) {
      _log.info(
        'manifest does not cover every chunk — downloading through the server',
        fields: {
          'file_id': fileId,
          'urls': directUrls.length,
          'chunks': chunkCount,
        },
      );
    }

    if (_tarCapabilityCache.lookup(baseUrl) == false) {
      _log.info(
        'downloading per chunk — the server does not offer the archive',
        fields: {'file_id': fileId, 'chunks': chunkCount},
      );
      await _transport.downloadPerChunk(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: alreadyDownloaded,
        accountId: accountId,
        onProgress: onProgress,
      );
      return;
    }

    try {
      _log.info(
        'downloading as one archive',
        fields: {'file_id': fileId, 'chunks': chunkCount},
      );
      await _transport.downloadAsTar(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: alreadyDownloaded,
        accountId: accountId,
        onProgress: onProgress,
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
        accountId: accountId,
        onProgress: onProgress,
      );
    }
  }
}

/// Whether the manifest can carry the whole transfer on its own.
///
/// A partial manifest is not worth splitting the file across two transports:
/// the bucket leg would survive suspension and the server leg would not, so
/// the transfer as a whole still would not. Better to take one path that
/// works for every chunk.
bool _coversEveryChunk(List<String> urls, int chunkCount) =>
    urls.length == chunkCount &&
    chunkCount > 0 &&
    urls.every((url) => url.isNotEmpty);
