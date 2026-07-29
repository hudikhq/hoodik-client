import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../utils/tar_extractor.dart';
import 'worker_messages.dart';

/// Maximum retries for the tar download request.
const int _kMaxRetries = 3;

/// Idle timeout for response body streaming. If no bytes are received for
/// this duration, the connection is considered dead (e.g. after app
/// suspension breaks TCP sockets).
const Duration _kIdleTimeout = Duration(seconds: 30);

/// Fixed timeout for getting response headers after sending a request.
const Duration _kResponseTimeout = Duration(seconds: 30);

/// Entry point for the download worker isolate.
///
/// Downloads all encrypted chunks as a single tar archive using the server's
/// `?format=tar` endpoint with Bearer token auth, then extracts individual
/// chunk files to disk. No Rust FFI — avoids the FRB limitation where async
/// Rust calls hang from spawned Dart isolates.
void downloadWorkerEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  bool initialized = false;
  String? baseUrl;

  final cancelledFileIds = <String>{};
  final activeFileIds = <String>{};

  receivePort.listen((message) async {
    if (message is InitCommand) {
      try {
        baseUrl = message.baseUrl;
        initialized = true;
        message.replyPort.send(InitReadyResponse());
      } catch (e) {
        message.replyPort.send(
          WorkerErrorResponse(error: 'Download worker init failed: $e'),
        );
      }
      return;
    }

    if (!initialized) return;

    if (message is PingCommand) {
      mainSendPort.send(PongResponse());
      return;
    }

    if (message is CancelCommand) {
      cancelledFileIds.add(message.fileId);
      return;
    }

    if (message is DownloadChunksCommand) {
      if (activeFileIds.contains(message.fileId)) {
        mainSendPort.send(
          WorkerErrorResponse(
            fileId: message.fileId,
            error: 'Download already in progress for this file',
          ),
        );
        return;
      }
      activeFileIds.add(message.fileId);

      try {
        await _handleTarDownload(
          cmd: message,
          replyPort: mainSendPort,
          baseUrl: baseUrl!,
          cancelledFileIds: cancelledFileIds,
        );
      } finally {
        activeFileIds.remove(message.fileId);
      }
    }
  });

  mainSendPort.send(receivePort.sendPort);
}

/// Download a tar archive of all chunks using Bearer token auth,
/// extract chunks to disk, and report completion.
Future<void> _handleTarDownload({
  required DownloadChunksCommand cmd,
  required SendPort replyPort,
  required String baseUrl,
  required Set<String> cancelledFileIds,
}) async {
  try {
    await Directory(cmd.outputDir).create(recursive: true);

    final tarPath = '${cmd.outputDir}/${cmd.fileId}.tar';
    int bytesDownloaded = 0;

    final progressTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
      replyPort.send(
        TransferProgressResponse(
          fileId: cmd.fileId,
          transferred: bytesDownloaded,
          total: cmd.fileSize,
        ),
      );
    });

    try {
      for (var attempt = 0; attempt <= _kMaxRetries; attempt++) {
        if (cancelledFileIds.remove(cmd.fileId)) {
          throw Exception('Transfer cancelled');
        }

        try {
          bytesDownloaded = 0;
          bytesDownloaded = await _fetchTar(
            baseUrl: baseUrl,
            token: cmd.transferToken,
            fileId: cmd.fileId,
            tarPath: tarPath,
            onBytesReceived: (bytes) => bytesDownloaded = bytes,
          );
          break;
        } on HttpException {
          rethrow;
        } catch (e) {
          if (attempt < _kMaxRetries) {
            await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)),
            );
            continue;
          }
          rethrow;
        }
      }

      await extractTarFile(tarPath, cmd.outputDir);

      try {
        await File(tarPath).delete();
      } catch (_) {}
    } finally {
      progressTimer.cancel();
    }

    replyPort.send(
      TransferProgressResponse(
        fileId: cmd.fileId,
        transferred: bytesDownloaded,
        total: cmd.fileSize,
      ),
    );

    replyPort.send(
      DownloadChunksCompleteResponse(
        fileId: cmd.fileId,
        chunksDir: cmd.outputDir,
      ),
    );
  } catch (e) {
    _cleanupDir(cmd.outputDir);
    replyPort.send(
      WorkerErrorResponse(fileId: cmd.fileId, error: 'Tar download failed: $e'),
    );
  }
}

/// Fetch the tar archive with Bearer token auth, streaming to a file.
/// Returns total bytes written.
Future<int> _fetchTar({
  required String baseUrl,
  required String token,
  required String fileId,
  required String tarPath,
  required void Function(int bytesReceived) onBytesReceived,
}) async {
  final client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15);

  try {
    final uri = Uri.parse('$baseUrl/api/storage/$fileId?format=tar');
    final request = await client.getUrl(uri);
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.removeAll('Accept-Encoding');
    final response = await request.close().timeout(_kResponseTimeout);

    if (response.statusCode >= 400) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}');
    }

    return _streamToFile(response, tarPath, onBytesReceived);
  } finally {
    client.close();
  }
}

/// Stream an HTTP response body to a file with idle timeout.
/// Returns total bytes written.
Future<int> _streamToFile(
  HttpClientResponse response,
  String filePath,
  void Function(int bytesReceived) onBytesReceived,
) async {
  final file = File(filePath);
  final sink = file.openWrite();
  final completer = Completer<int>();
  var totalBytes = 0;
  Timer? timer;

  void resetTimer() {
    timer?.cancel();
    timer = Timer(_kIdleTimeout, () {
      if (!completer.isCompleted) {
        sink.close().catchError((_) {});
        completer.completeError(
          TimeoutException('No data received', _kIdleTimeout),
        );
      }
    });
  }

  resetTimer();

  response.listen(
    (bytes) {
      sink.add(bytes);
      totalBytes += bytes.length;
      onBytesReceived(totalBytes);
      resetTimer();
    },
    onDone: () async {
      timer?.cancel();
      await sink.close();
      if (!completer.isCompleted) {
        completer.complete(totalBytes);
      }
    },
    onError: (Object e) {
      timer?.cancel();
      sink.close().catchError((_) {});
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    },
  );

  return completer.future;
}

/// Delete a directory and its contents. Ignores errors.
void _cleanupDir(String path) {
  () async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }();
}
