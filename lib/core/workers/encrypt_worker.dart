import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../../src/rust/api.dart' as rust;
import '../../src/rust/frb_generated.dart';
import 'worker_messages.dart';

/// Chunk size: 4 MiB — must match the server and other workers.
const int _kChunkSize = 4 * 1024 * 1024;

/// Entry point for the encrypt worker isolate.
///
/// Reads a local file, hashes it with SHA-256 (streaming Dart crypto), encrypts
/// each chunk via sync Rust FFI, computes CRC-16, and writes encrypted chunks
/// to disk. Hashing and encryption happen in a single pass for efficiency.
void encryptWorkerEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  bool initialized = false;

  final cancelledIds = <String>{};

  /// File IDs currently being encrypted. Prevents duplicate concurrent
  /// encryptions for the same file (ReceivePort.listen doesn't await async
  /// callbacks, so two commands can run concurrently).
  final activeIds = <String>{};

  receivePort.listen((message) async {
    if (message is InitCommand) {
      try {
        await RustLib.init();
        initialized = true;
        message.replyPort.send(InitReadyResponse());
      } catch (e) {
        message.replyPort.send(
          WorkerErrorResponse(error: 'Encrypt worker init failed: $e'),
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
      cancelledIds.add(message.fileId);
      return;
    }

    if (message is EncryptFileCommand) {
      if (activeIds.contains(message.tempFileId)) {
        mainSendPort.send(
          WorkerErrorResponse(
            fileId: message.tempFileId,
            error: 'Encryption already in progress for this file',
          ),
        );
        return;
      }
      activeIds.add(message.tempFileId);

      try {
        await _handleEncrypt(
          cmd: message,
          replyPort: mainSendPort,
          cancelledIds: cancelledIds,
        );
      } finally {
        activeIds.remove(message.tempFileId);
      }
    }
  });

  mainSendPort.send(receivePort.sendPort);
}

/// Single-pass hash + encrypt pipeline.
///
/// For each 4 MiB chunk:
///   1. Read plaintext from disk
///   2. Feed to SHA-256 hasher (Dart `crypto` — constant memory)
///   3. Encrypt via sync Rust FFI (`cipherEncryptChunk`, per-chunk nonce)
///   4. Compute CRC-16 via sync Rust FFI (`crc16Digest`)
///   5. Write encrypted chunk to `{outputDir}/{index:06}.enc`
///   6. Report progress
Future<void> _handleEncrypt({
  required EncryptFileCommand cmd,
  required SendPort replyPort,
  required Set<String> cancelledIds,
}) async {
  try {
    final file = File(cmd.localPath);
    final raf = await file.open(mode: FileMode.read);
    final outputDir = Directory(cmd.outputDir);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final sha256Sink = AccumulatorSink<Digest>();
    final sha256Hasher = sha256.startChunkedConversion(sha256Sink);
    final checksums = <int, String>{};

    int chunksCompleted = 0;

    final progressTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
      replyPort.send(
        TransferProgressResponse(
          fileId: cmd.tempFileId,
          transferred: chunksCompleted,
          total: cmd.totalChunks,
        ),
      );
    });

    try {
      for (var i = 0; i < cmd.totalChunks; i++) {
        if (cancelledIds.remove(cmd.tempFileId)) {
          throw Exception('Encryption cancelled');
        }

        final start = i * _kChunkSize;
        final end = (start + _kChunkSize).clamp(0, cmd.fileSize);
        final chunkLen = end - start;
        if (chunkLen <= 0) break;

        await raf.setPosition(start);
        final plaintext = await raf.read(chunkLen);

        // Feed plaintext to streaming SHA-256 hasher.
        sha256Hasher.add(plaintext);

        // Encrypt via sync Rust FFI with a per-chunk nonce derived from the
        // index — a fixed nonce across chunks would void the AEAD guarantees.
        final encrypted = rust.cipherEncryptChunk(
          cipher: cmd.cipher,
          key: cmd.fileKey,
          chunkIndex: BigInt.from(i),
          plaintext: plaintext,
        );

        // CRC-16 of encrypted chunk — sync Rust FFI.
        final crc = rust.crc16Digest(data: encrypted);
        checksums[i] = crc;

        // Write encrypted chunk to disk.
        final chunkFile = File(
          '${cmd.outputDir}/${i.toString().padLeft(6, '0')}.enc',
        );
        await chunkFile.writeAsBytes(encrypted, flush: true);

        chunksCompleted++;
      }
    } finally {
      progressTimer.cancel();
      await raf.close();
    }

    // Finalize SHA-256.
    sha256Hasher.close();
    final hash = sha256Sink.events.single.toString();

    // Final progress.
    replyPort.send(
      TransferProgressResponse(
        fileId: cmd.tempFileId,
        transferred: cmd.totalChunks,
        total: cmd.totalChunks,
      ),
    );

    replyPort.send(
      EncryptCompleteResponse(
        tempFileId: cmd.tempFileId,
        sha256: hash,
        checksums: checksums,
      ),
    );
  } catch (e) {
    replyPort.send(
      WorkerErrorResponse(
        fileId: cmd.tempFileId,
        error: 'Encryption failed: $e',
      ),
    );
  }
}

/// Accumulator that collects a single [Digest] result from a chunked
/// conversion sink. Used with `sha256.startChunkedConversion()`.
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
