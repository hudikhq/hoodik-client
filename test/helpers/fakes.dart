import 'package:hoodik_app/core/services/binary_upload_transport.dart';
import 'package:hoodik_app/core/services/chunk_download_transport.dart';
import 'package:hoodik_app/core/services/connectivity_service.dart';

/// A minimal ConnectivityService substitute for testing.
///
/// Doesn't call `connectivity_plus` — online/offline state is set manually.
class FakeConnectivityService extends ConnectivityService {
  bool fakeOnline;

  FakeConnectivityService({this.fakeOnline = true});

  @override
  bool get isOnline => fakeOnline;

  /// Do NOT call `super.init()` which starts the real connectivity listener.
  @override
  void init() {}

  /// Simulate a reconnection event.
  void simulateReconnect() {
    fakeOnline = true;
    onReconnected?.call();
  }
}

/// Records every call to the two chunk-download paths so a test can
/// assert on whether tar or per-chunk was picked, and scripts errors to
/// exercise the fallback branch. Never touches disk or Rust.
class FakeChunkDownloadTransport implements ChunkDownloadTransport {
  /// Arguments supplied to each successful or attempted tar call.
  final List<ChunkDownloadInvocation> tarCalls = [];

  /// Arguments supplied to each per-chunk call.
  final List<ChunkDownloadInvocation> perChunkCalls = [];

  /// Arguments supplied to each direct (presigned-URL) call.
  final List<ChunkDownloadInvocation> directCalls = [];

  /// Throw this on the next [downloadDirectChunks]. Clears itself after one
  /// throw so the manifest-refresh retry runs its normal flow.
  Object? directError;

  /// Throw this when [downloadAsTar] is called. Clears itself after one
  /// throw so a fallback attempt through the per-chunk path still runs
  /// its normal flow.
  Object? tarError;

  /// Throw this when [downloadPerChunk] is called. Persists across calls
  /// unless the test explicitly clears it.
  Object? perChunkError;

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
  }) async {
    tarCalls.add(
      ChunkDownloadInvocation(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: List.unmodifiable(alreadyDownloaded),
      ),
    );
    final err = tarError;
    if (err != null) {
      tarError = null;
      throw err;
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
  }) async {
    perChunkCalls.add(
      ChunkDownloadInvocation(
        baseUrl: baseUrl,
        cookie: cookie,
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: chunkCount,
        outputDir: outputDir,
        alreadyDownloaded: List.unmodifiable(alreadyDownloaded),
      ),
    );
    final err = perChunkError;
    if (err != null) throw err;
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
  }) async {
    directCalls.add(
      ChunkDownloadInvocation(
        baseUrl: '',
        cookie: '',
        fileId: fileId,
        fileSize: fileSize,
        chunkCount: urls.length,
        outputDir: outputDir,
        alreadyDownloaded: List.unmodifiable(alreadyDownloaded),
        directUrls: List.unmodifiable(urls),
      ),
    );
    final err = directError;
    if (err != null) {
      directError = null;
      throw err;
    }
    onProgress?.call(urls.length, fileSize);
  }
}

/// Snapshot of the arguments the pipeline forwarded to the transport.
class ChunkDownloadInvocation {
  final String baseUrl;
  final String cookie;
  final String fileId;
  final int fileSize;
  final int chunkCount;
  final String outputDir;
  final List<int> alreadyDownloaded;

  /// Presigned bucket URLs handed to this call, empty when the transfer went
  /// through the server. Lets a test assert which path was taken.
  final List<String> directUrls;

  ChunkDownloadInvocation({
    required this.baseUrl,
    required this.cookie,
    required this.fileId,
    required this.fileSize,
    required this.chunkCount,
    required this.outputDir,
    required this.alreadyDownloaded,
    this.directUrls = const [],
  });
}

/// Records tar upload calls so the pipeline tests can verify which
/// path the pipeline took and scripts errors to exercise fallback.
class FakeUploadTarTransport implements UploadTarTransport {
  final List<UploadTarInvocation> calls = [];

  /// Throw this on the next [uploadAsTar]. Clears itself after firing
  /// so a follow-up attempt succeeds.
  Object? error;

  /// Result returned when [error] is null. Defaults to a fully-finished
  /// summary — tests can overwrite it to simulate partial completion.
  UploadTarResult result = const UploadTarResult(
    chunksStored: 1,
    finishedUploadAt: 1000,
  );

  /// Progress events the next [uploadAsTar] should replay synchronously
  /// before returning. Each entry is `(transferred, total)`. Tests use
  /// this to assert the pipeline plumbs the OS-native uploader's bytes
  /// through to [TransferManager].
  List<(int, int)> progressEvents = const [];

  @override
  Future<UploadTarResult> uploadAsTar({
    required String baseUrl,
    required String transferToken,
    required String fileId,
    required String chunksDir,
    required int chunkCount,
    void Function(int transferred, int total)? onProgress,
  }) async {
    calls.add(
      UploadTarInvocation(
        baseUrl: baseUrl,
        transferToken: transferToken,
        fileId: fileId,
        chunksDir: chunksDir,
        chunkCount: chunkCount,
      ),
    );
    if (onProgress != null) {
      for (final (transferred, total) in progressEvents) {
        onProgress(transferred, total);
      }
    }
    final err = error;
    if (err != null) {
      error = null;
      throw err;
    }
    return result;
  }
}

/// Snapshot of a tar upload call.
class UploadTarInvocation {
  final String baseUrl;
  final String transferToken;
  final String fileId;
  final String chunksDir;
  final int chunkCount;

  UploadTarInvocation({
    required this.baseUrl,
    required this.transferToken,
    required this.fileId,
    required this.chunksDir,
    required this.chunkCount,
  });
}
