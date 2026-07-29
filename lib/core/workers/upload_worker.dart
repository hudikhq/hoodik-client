import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'worker_messages.dart';

/// Maximum concurrent chunk uploads in flight.
const int _kUploadPoolLimit = 8;

/// Maximum retries per chunk (CRC mismatch, transient error).
const int _kMaxRetries = 3;

/// Per-chunk timeout. Safety net for hung connections after app suspension.
/// Uploads are less prone to stalling than downloads (writes to a dead socket
/// fail fast with EPIPE/ECONNRESET), but this catches edge cases. Set
/// generously so slow connections aren't affected.
const Duration _kChunkTimeout = Duration(seconds: 180);

/// Entry point for the upload worker isolate.
///
/// Reads pre-encrypted `.enc` files from disk and uploads them via pure Dart
/// HTTP with Bearer token auth. No encryption logic — the encrypt worker
/// handles that beforehand.
void uploadWorkerEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  bool initialized = false;
  String? baseUrl;

  /// File IDs that have been cancelled.
  final cancelledFileIds = <String>{};

  /// File IDs currently being uploaded. Prevents duplicate concurrent
  /// uploads for the same file (ReceivePort.listen doesn't await async
  /// callbacks, so two commands can run concurrently).
  final activeFileIds = <String>{};

  receivePort.listen((message) async {
    if (message is InitCommand) {
      try {
        baseUrl = message.baseUrl;
        initialized = true;
        message.replyPort.send(InitReadyResponse());
      } catch (e) {
        message.replyPort.send(
          WorkerErrorResponse(error: 'Upload worker init failed: $e'),
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

    if (message is UploadChunksCommand) {
      if (activeFileIds.contains(message.fileId)) {
        mainSendPort.send(
          WorkerErrorResponse(
            fileId: message.fileId,
            error: 'Upload already in progress for this file',
          ),
        );
        return;
      }
      activeFileIds.add(message.fileId);

      try {
        await _handleUploadChunks(
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

/// Upload pre-encrypted `.enc` chunks from disk using a Bearer transfer token.
///
/// Pure HTTP — no encryption, no hashing, no session refresh dance.
/// Transfer tokens are valid for 30 days, so 401s should be extremely rare.
Future<void> _handleUploadChunks({
  required UploadChunksCommand cmd,
  required SendPort replyPort,
  required String baseUrl,
  required Set<String> cancelledFileIds,
}) async {
  final client = HttpClient()
    // Catch stale connection-pool entries after app suspension.
    ..connectionTimeout = const Duration(seconds: 15);

  int chunksCompleted = 0;

  final progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
    replyPort.send(
      TransferProgressResponse(
        fileId: cmd.fileId,
        transferred: chunksCompleted,
        total: cmd.totalChunks,
      ),
    );
  });

  try {
    final alreadyUploaded = cmd.alreadyUploaded.toSet();
    var active = 0;
    final done = Completer<void>();

    // Queue of chunk indices still to upload.
    final remaining = <int>[];
    for (var i = 0; i < cmd.totalChunks; i++) {
      if (!alreadyUploaded.contains(i)) remaining.add(i);
    }

    void scheduleMore() {
      if (done.isCompleted) return;

      if (cancelledFileIds.remove(cmd.fileId)) {
        client.close(force: true);
        done.completeError(Exception('Upload cancelled'));
        return;
      }

      while (active < _kUploadPoolLimit && remaining.isNotEmpty) {
        final chunkIndex = remaining.removeAt(0);
        active++;

        _uploadEncChunkWithRetry(
              client: client,
              baseUrl: baseUrl,
              token: cmd.transferToken,
              fileId: cmd.fileId,
              chunkIndex: chunkIndex,
              chunksDir: cmd.chunksDir,
              checksum: cmd.checksums[chunkIndex],
            )
            .then((_) {
              chunksCompleted++;
              active--;
              scheduleMore();
            })
            .catchError((Object e) {
              active--;
              if (!done.isCompleted) {
                client.close(force: true);
                done.completeError(e);
              }
            });
      }

      if (remaining.isEmpty && active == 0 && !done.isCompleted) {
        done.complete();
      }
    }

    scheduleMore();
    await done.future;

    progressTimer.cancel();

    // Final progress.
    replyPort.send(
      TransferProgressResponse(
        fileId: cmd.fileId,
        transferred: cmd.totalChunks,
        total: cmd.totalChunks,
      ),
    );

    replyPort.send(UploadChunksCompleteResponse(fileId: cmd.fileId));
  } catch (e) {
    progressTimer.cancel();
    replyPort.send(
      WorkerErrorResponse(fileId: cmd.fileId, error: 'Chunk upload failed: $e'),
    );
  } finally {
    client.close();
  }
}

/// Upload a single pre-encrypted .enc chunk with retry and Bearer auth.
Future<void> _uploadEncChunkWithRetry({
  required HttpClient client,
  required String baseUrl,
  required String token,
  required String fileId,
  required int chunkIndex,
  required String chunksDir,
  required String? checksum,
}) async {
  final chunkFile = File(
    '$chunksDir/${chunkIndex.toString().padLeft(6, '0')}.enc',
  );
  final data = await chunkFile.readAsBytes();

  for (var attempt = 0; attempt <= _kMaxRetries; attempt++) {
    try {
      return await _doUploadChunk(
        client: client,
        baseUrl: baseUrl,
        token: token,
        fileId: fileId,
        chunkIndex: chunkIndex,
        data: data,
        checksum: checksum,
      ).timeout(_kChunkTimeout);
    } on HttpException {
      rethrow;
    } catch (e) {
      if (attempt < _kMaxRetries) {
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        continue;
      }
      rethrow;
    }
  }
  throw StateError('Unreachable');
}

/// Single HTTP POST attempt for one chunk with Bearer auth.
Future<void> _doUploadChunk({
  required HttpClient client,
  required String baseUrl,
  required String token,
  required String fileId,
  required int chunkIndex,
  required Uint8List data,
  required String? checksum,
}) async {
  var path =
      '$baseUrl/api/storage/$fileId'
      '?chunk=$chunkIndex';
  if (checksum != null) {
    path += '&checksum=$checksum&checksum_function=crc16';
  }
  final uri = Uri.parse(path);

  final request = await client.postUrl(uri);
  request.headers.set('Authorization', 'Bearer $token');
  request.headers.set('Content-Type', 'application/octet-stream');
  request.headers.set('Content-Length', data.length.toString());
  request.add(data);
  final response = await request.close();

  if (response.statusCode >= 400) {
    // Hoodik server responses are always UTF-8; SystemEncoding would mangle
    // multi-byte characters on Windows where the default is legacy cp1252.
    final body = await response.transform(utf8.decoder).join();
    // 422 with "chunk_already_exists" is idempotent — treat as success.
    if (response.statusCode == 422 && body.contains('chunk_already_exists')) {
      return;
    }
    throw _HttpStatusException(response.statusCode, chunkIndex, body);
  }

  await response.drain<void>();
}

/// Typed exception for HTTP error status codes.
class _HttpStatusException implements Exception {
  final int statusCode;
  final int chunk;
  final String body;

  _HttpStatusException(this.statusCode, this.chunk, this.body);

  @override
  String toString() => 'HTTP $statusCode on chunk $chunk: $body';
}
