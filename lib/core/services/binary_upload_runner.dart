import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'binary_upload_transport.dart';
import 'tar_fallback.dart';

const _log = Logger('BinaryUploadRunner');

/// Signature for the per-chunk upload leg. Implementations hand the
/// already-encrypted staging chunks off to the OS-native uploader (in
/// production) or a mock (in tests).
typedef PerChunkUploadFn = Future<void> Function();

/// Decides between the tar upload FFI and the per-chunk fallback for one
/// upload attempt.
///
/// Tar is tried on every run — a self-hosted server can be upgraded between
/// uploads, so caching a "no tar here" verdict for the rest of the session
/// would mean every upload after the first failure stays on per-chunk even
/// after the operator deploys a tar-capable build. The cost of always
/// probing is a single failed POST per legacy server per upload, in
/// exchange for transparent recovery the moment the server gains support.
///
/// A server that says outright it will not serve archives is the exception:
/// [tarSupported] is read fresh from the capability on every run, so it
/// withholds the probe without caching anything, and the moment the operator
/// turns archives back on the next upload uses one again.
class BinaryUploadRunner {
  final UploadTarTransport _tarTransport;

  const BinaryUploadRunner({required UploadTarTransport tarTransport})
    : _tarTransport = tarTransport;

  /// Try the tar upload path and return `true` when it succeeded. Returns
  /// `false` and runs [perChunk] when the tar attempt raises a
  /// [shouldFallbackToPerChunk] error. Non-capability errors bubble up
  /// unchanged.
  ///
  /// [onTarResult] fires with the summary returned by the tar endpoint so
  /// the caller can update progress / register chunks stored. Only called
  /// on the tar-success path.
  ///
  /// [onTarProgress] receives `(transferred, total)` byte counts as the
  /// OS-native uploader streams the tar to the server. Forwarded to the
  /// transport — the per-chunk path emits its own progress through
  /// [BackgroundUploadService] and doesn't go through this callback.
  Future<bool> run({
    required String baseUrl,
    required String transferToken,
    required String fileId,
    required String stagingDir,
    required int chunkCount,
    required PerChunkUploadFn perChunk,
    void Function(UploadTarResult)? onTarResult,
    void Function(int transferred, int total)? onTarProgress,
    bool tarSupported = true,
  }) async {
    if (!tarSupported) {
      await perChunk();
      return false;
    }

    try {
      _log.info(
        'upload transport',
        fields: {
          'file_id': fileId,
          'transport': 'relay-tar',
          'chunks': chunkCount,
        },
      );
      final result = await _tarTransport.uploadAsTar(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        chunksDir: stagingDir,
        chunkCount: chunkCount,
        onProgress: onTarProgress,
      );
      onTarResult?.call(result);
      return true;
    } catch (e) {
      if (!shouldFallbackToPerChunk(e)) rethrow;
      _log.info(
        'tar upload rejected — falling back to per-chunk for this upload',
        fields: {'base_url': baseUrl, 'error': describeError(e)},
      );
      await perChunk();
      return false;
    }
  }
}
