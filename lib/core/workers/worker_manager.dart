import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../services/transfer_manager.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'worker_messages.dart';
import 'decrypt_worker.dart' as decrypt_worker;
import 'encrypt_worker.dart' as encrypt_worker;

const _log = Logger('WorkerManager');

/// Manages the lifecycle of worker isolates (decrypt, encrypt) and
/// routes messages between them and the main isolate.
///
/// Uploads and downloads are handled by [BackgroundUploadService] and the
/// services behind [ChunkDownloadPipeline], using OS-native URLSession (iOS) /
/// WorkManager (Android) for background-safe transfers.
class WorkerManager {
  final TransferManager transferManager;
  final ApiClient apiClient;

  // Isolate references.
  Isolate? _decryptIsolate;
  Isolate? _encryptIsolate;

  // SendPorts for sending commands TO workers.
  SendPort? _decryptSendPort;
  SendPort? _encryptSendPort;

  // ReceivePorts for getting responses FROM workers.
  ReceivePort? _decryptReceivePort;
  ReceivePort? _encryptReceivePort;

  // Track in-progress transfer IDs to map responses to TransferManager items.
  final Map<String, String> _fileIdToTransferId = {};

  // Stored from init() so dead workers can be respawned.
  String? _baseUrl;

  // Health check completers — fulfilled when a PongResponse arrives.
  Completer<bool>? _decryptHealthCompleter;
  Completer<bool>? _encryptHealthCompleter;

  // Completers for encrypt operations — resolved with the encrypt result
  // so FileOperations can await the sha256 + checksums.
  final Map<String, Completer<EncryptCompleteResponse>> _encryptCompleters = {};

  // Callbacks.
  void Function(Map<String, String> names, Map<String, Uint8List> keys)?
  onNamesDecrypted;

  /// Whether each worker is available (initialized and not crashed).
  bool get decryptWorkerActive => _decryptSendPort != null;
  bool get encryptWorkerActive => _encryptSendPort != null;

  WorkerManager({required this.transferManager, required this.apiClient});

  /// Initialize all worker isolates. Call once after login.
  ///
  /// Each isolate is spawned inside try/catch — if any fails, its SendPort
  /// stays null and operations fall back to the main thread.
  Future<void> init({required String baseUrl}) async {
    _baseUrl = baseUrl;

    await Future.wait([
      _spawnWorker(
        name: 'decrypt',
        entryPoint: decrypt_worker.decryptWorkerEntryPoint,
        baseUrl: baseUrl,
        onReady: (isolate, sendPort, receivePort) {
          _decryptIsolate = isolate;
          _decryptSendPort = sendPort;
          _decryptReceivePort = receivePort;
        },
        onMessage: _handleDecryptResponse,
      ),
      _spawnWorker(
        name: 'encrypt',
        entryPoint: encrypt_worker.encryptWorkerEntryPoint,
        baseUrl: baseUrl,
        onReady: (isolate, sendPort, receivePort) {
          _encryptIsolate = isolate;
          _encryptSendPort = sendPort;
          _encryptReceivePort = receivePort;
        },
        onMessage: _handleEncryptResponse,
      ),
    ]);

    _log.info(
      'workers initialized',
      fields: {
        'decrypt_active': decryptWorkerActive,
        'encrypt_active': encryptWorkerActive,
      },
    );
  }

  // ── Public operations ──────────────────────────────────────────────────

  /// Dispatch batch name decryption to the decrypt worker.
  void decryptNames(DecryptNamesCommand cmd) {
    _decryptSendPort?.send(cmd);
  }

  /// Dispatch file encryption to the encrypt worker.
  ///
  /// Returns a [Future] that completes with the encryption result (sha256
  /// hash + per-chunk CRC-16 checksums) when the worker finishes.
  Future<EncryptCompleteResponse> encryptFile(
    EncryptFileCommand cmd, {
    String? transferId,
  }) {
    if (transferId != null) {
      _fileIdToTransferId[cmd.tempFileId] = transferId;
    }
    final completer = Completer<EncryptCompleteResponse>();
    _encryptCompleters[cmd.tempFileId] = completer;
    _encryptSendPort?.send(cmd);
    return completer.future;
  }

  /// Cancel an in-progress encryption.
  void cancelEncryption(String fileId) {
    _encryptSendPort?.send(CancelCommand(fileId: fileId));
  }

  /// Kill all isolates and clean up. Call on logout.
  void dispose() {
    _decryptIsolate?.kill(priority: Isolate.immediate);
    _encryptIsolate?.kill(priority: Isolate.immediate);

    _decryptReceivePort?.close();
    _encryptReceivePort?.close();

    _decryptIsolate = null;
    _encryptIsolate = null;

    _decryptSendPort = null;
    _encryptSendPort = null;

    _fileIdToTransferId.clear();
    _encryptCompleters.clear();

    _log.info('all workers disposed');
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Notify workers that the app has resumed from background.
  ///
  /// Checks worker health and restarts any that have crashed.
  Future<void> notifyResumed() async {
    try {
      await restartDeadWorkers();
    } catch (e) {
      _log.warn(
        'worker health check failed',
        fields: {'error': redactException(e)},
      );
    }
  }

  /// Check if workers are responsive via ping/pong with a 5-second timeout.
  Future<Map<String, bool>> checkWorkerHealth() async {
    final results = await Future.wait([
      _pingWorker(
        'decrypt',
        _decryptSendPort,
        (c) => _decryptHealthCompleter = c,
      ),
      _pingWorker(
        'encrypt',
        _encryptSendPort,
        (c) => _encryptHealthCompleter = c,
      ),
    ]);
    return {'decrypt': results[0], 'encrypt': results[1]};
  }

  Future<bool> _pingWorker(
    String name,
    SendPort? port,
    void Function(Completer<bool>?) setCompleter,
  ) async {
    if (port == null) return false;
    final completer = Completer<bool>();
    setCompleter(completer);
    port.send(PingCommand());
    try {
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log.warn('worker did not respond to ping', fields: {'worker': name});
          return false;
        },
      );
    } finally {
      setCompleter(null);
    }
  }

  /// Restart any workers that are unresponsive or have crashed.
  Future<void> restartDeadWorkers() async {
    if (_baseUrl == null) return;

    final health = await checkWorkerHealth();

    if (health['decrypt'] == false) {
      _log.info('restarting dead worker', fields: {'worker': 'decrypt'});
      _decryptIsolate?.kill(priority: Isolate.immediate);
      _decryptReceivePort?.close();
      _decryptIsolate = null;
      _decryptSendPort = null;
      await _spawnWorker(
        name: 'decrypt',
        entryPoint: decrypt_worker.decryptWorkerEntryPoint,
        baseUrl: _baseUrl!,
        onReady: (isolate, sendPort, receivePort) {
          _decryptIsolate = isolate;
          _decryptSendPort = sendPort;
          _decryptReceivePort = receivePort;
        },
        onMessage: _handleDecryptResponse,
      );
    }

    if (health['encrypt'] == false) {
      _log.info('restarting dead worker', fields: {'worker': 'encrypt'});
      _encryptIsolate?.kill(priority: Isolate.immediate);
      _encryptReceivePort?.close();
      _encryptIsolate = null;
      _encryptSendPort = null;
      await _spawnWorker(
        name: 'encrypt',
        entryPoint: encrypt_worker.encryptWorkerEntryPoint,
        baseUrl: _baseUrl!,
        onReady: (isolate, sendPort, receivePort) {
          _encryptIsolate = isolate;
          _encryptSendPort = sendPort;
          _encryptReceivePort = receivePort;
        },
        onMessage: _handleEncryptResponse,
      );
    }
  }

  // ── Response handlers ──────────────────────────────────────────────────

  void _handleDecryptResponse(dynamic message) {
    if (message is PongResponse) {
      _decryptHealthCompleter?.complete(true);
      return;
    }

    if (message is DecryptedNamesResponse) {
      onNamesDecrypted?.call(message.names, message.keys);
    } else if (message is WorkerErrorResponse) {
      _log.warn(
        'decrypt worker error',
        fields: {'error_message': message.error},
      );
    }
  }

  void _handleEncryptResponse(dynamic message) {
    if (message is PongResponse) {
      _encryptHealthCompleter?.complete(true);
      return;
    }

    if (message is TransferProgressResponse) {
      final transferId = _fileIdToTransferId[message.fileId];
      if (transferId != null) {
        final item = transferManager.transfers
            .where((t) => t.id == transferId)
            .firstOrNull;
        final totalBytes = item?.totalBytes ?? 0;
        final transferredBytes = message.total > 0
            ? (totalBytes * message.transferred / message.total).round()
            : 0;
        transferManager.updateProgress(
          transferId,
          completedChunks: message.transferred,
          transferredBytes: transferredBytes,
        );
      }
      return;
    }

    if (message is EncryptCompleteResponse) {
      _fileIdToTransferId.remove(message.tempFileId);
      final completer = _encryptCompleters.remove(message.tempFileId);
      completer?.complete(message);
    } else if (message is WorkerErrorResponse && message.fileId != null) {
      _fileIdToTransferId.remove(message.fileId!);
      final completer = _encryptCompleters.remove(message.fileId!);
      if (completer != null) {
        completer.completeError(Exception(message.error));
      } else {
        _log.warn(
          'encrypt worker error',
          fields: {'file_id': message.fileId, 'error_message': message.error},
        );
      }
    }
  }

  /// Null out a worker's send port and isolate reference after a crash.
  void _clearWorker(String name) {
    switch (name) {
      case 'decrypt':
        _decryptSendPort = null;
        _decryptIsolate = null;
      case 'encrypt':
        _encryptSendPort = null;
        _encryptIsolate = null;
    }
  }

  // ── Isolate spawn helper ───────────────────────────────────────────────

  Future<void> _spawnWorker({
    required String name,
    required void Function(SendPort) entryPoint,
    required String baseUrl,
    required void Function(Isolate, SendPort, ReceivePort) onReady,
    required void Function(dynamic) onMessage,
  }) async {
    try {
      final receivePort = ReceivePort();
      final completer = Completer<SendPort>();

      receivePort.listen((message) {
        if (message is SendPort) {
          completer.complete(message);
        } else if (message is List) {
          // Isolate error: [error.toString(), stackTrace.toString()].
          // Null out the send port so we know the worker is dead.
          _log.warn(
            'worker crashed',
            fields: {
              'worker': name,
              'error_message': message.isNotEmpty
                  ? message[0].toString()
                  : null,
            },
          );
          _clearWorker(name);
        } else {
          onMessage(message);
        }
      });

      final isolate = await Isolate.spawn(
        entryPoint,
        receivePort.sendPort,
        debugName: 'hoodik-$name-worker',
        onError: receivePort.sendPort,
      );

      final workerSendPort = await completer.future.timeout(
        const Duration(seconds: 10),
      );

      final initCompleter = Completer<void>();
      final initReplyPort = ReceivePort();

      initReplyPort.listen((message) {
        if (message is InitReadyResponse) {
          initCompleter.complete();
        } else if (message is WorkerErrorResponse) {
          initCompleter.completeError(Exception(message.error));
        }
        initReplyPort.close();
      });

      workerSendPort.send(
        InitCommand(replyPort: initReplyPort.sendPort, baseUrl: baseUrl),
      );

      await initCompleter.future.timeout(const Duration(seconds: 10));

      onReady(isolate, workerSendPort, receivePort);
      _log.info('worker ready', fields: {'worker': name});
    } catch (e) {
      _log.error(
        'failed to spawn worker',
        fields: {'worker': name, 'error': redactException(e)},
      );
    }
  }
}
