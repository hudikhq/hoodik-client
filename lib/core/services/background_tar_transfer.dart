import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:path/path.dart' as p;

import '../utils/logger.dart';
import 'file_downloader_config.dart';

const _log = Logger('BackgroundTarTransfer');

/// Wraps `background_downloader` to move tar archives on and off the device
/// as single [DownloadTask] / [UploadTask] transfers so iOS URLSession and
/// Android WorkManager can keep them running while the app is suspended.
///
/// Used by [ChunkDownloadPipeline] (tar-based download leg) and
/// [BinaryUploadPipeline] (tar-based upload leg). The Rust FFI packs and
/// unpacks the archive locally; this class owns the network round-trip.
class BackgroundTarTransfer {
  static const String downloadGroup = 'tar-downloads';
  static const String uploadGroup = 'tar-uploads';

  final String baseUrl;

  final Map<String, _PendingDownload> _downloads = {};
  final Map<String, _PendingUpload> _uploads = {};

  Future<void>? _configuring;

  BackgroundTarTransfer({required this.baseUrl});

  Future<void> _configure() => _configuring ??= _doConfigure();

  Future<void> _doConfigure() async {
    await ensureFileDownloaderConfigured();
    registerTaskUpdateHandler(_downloadTaskPrefix, _handleDownloadUpdate);
    registerTaskUpdateHandler(_uploadTaskPrefix, _handleUploadUpdate);
  }

  /// Download [url] to [outputPath] via an OS-native [DownloadTask].
  ///
  /// Completes when the tar is on disk, or throws if the transfer failed or
  /// was cancelled through [cancel]. [onProgress] receives values in
  /// `[0, totalBytes]`. Use [taskId] to cancel the same transfer later.
  Future<void> downloadTarToFile({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String outputPath,
    required int totalBytes,
    void Function(int transferred, int total)? onProgress,
  }) async {
    await _configure();

    final completer = Completer<void>();
    _downloads[taskId] = _PendingDownload(
      totalBytes: totalBytes,
      outputPath: outputPath,
      completer: completer,
      onProgress: onProgress,
    );

    final parent = Directory(p.dirname(outputPath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    final task = DownloadTask(
      taskId: '$_downloadTaskPrefix$taskId',
      url: url,
      headers: headers,
      baseDirectory: BaseDirectory.root,
      directory: p.dirname(outputPath),
      filename: p.basename(outputPath),
      group: downloadGroup,
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: false,
    );

    final ok = await FileDownloader().enqueue(task);
    if (!ok) {
      _downloads.remove(taskId);
      throw Exception('Failed to enqueue tar download for $taskId');
    }

    return completer.future;
  }

  /// Upload the tar archive at [tarPath] via an OS-native [UploadTask].
  ///
  /// Completes with the server's response body once the upload finishes, or
  /// throws on failure / cancellation. Progress is reported in bytes derived
  /// from the on-disk file size so the overlay can show a fractional bar
  /// even when the upload streams in a single HTTP request.
  Future<String> uploadTarFromFile({
    required String taskId,
    required String url,
    required Map<String, String> headers,
    required String tarPath,
    void Function(int transferred, int total)? onProgress,
  }) async {
    await _configure();

    final tarFile = File(tarPath);
    final totalBytes = await tarFile.length();

    final completer = Completer<String>();
    _uploads[taskId] = _PendingUpload(
      totalBytes: totalBytes,
      completer: completer,
      onProgress: onProgress,
    );

    final task = UploadTask(
      taskId: '$_uploadTaskPrefix$taskId',
      url: url,
      headers: {...headers, 'Content-Type': 'application/x-tar'},
      post: 'binary',
      filename: p.basename(tarPath),
      directory: p.dirname(tarPath),
      baseDirectory: BaseDirectory.root,
      mimeType: 'application/x-tar',
      group: uploadGroup,
      updates: Updates.statusAndProgress,
      retries: 3,
    );

    final ok = await FileDownloader().enqueue(task);
    if (!ok) {
      _uploads.remove(taskId);
      throw Exception('Failed to enqueue tar upload for $taskId');
    }

    return completer.future;
  }

  /// Cancel an in-flight tar transfer previously started with [taskId].
  ///
  /// Cancels the OS-native task and fails the awaited future so the caller
  /// can propagate the cancellation. Safe to call when no transfer with the
  /// given ID is active.
  Future<void> cancel(String taskId) async {
    final download = _downloads.remove(taskId);
    final upload = _uploads.remove(taskId);

    if (download != null) {
      await FileDownloader().cancelTaskWithId('$_downloadTaskPrefix$taskId');
      if (!download.completer.isCompleted) {
        download.completer.completeError(Exception('Tar download cancelled'));
      }
    }
    if (upload != null) {
      await FileDownloader().cancelTaskWithId('$_uploadTaskPrefix$taskId');
      if (!upload.completer.isCompleted) {
        upload.completer.completeError(Exception('Tar upload cancelled'));
      }
    }
  }

  /// Replay buffered OS events after the app resumes from background.
  Future<void> resumeFromBackground() =>
      FileDownloader().resumeFromBackground();

  /// Cancel all pending transfers, remove their database records, and
  /// release the shared update handlers. Safe to call multiple times.
  Future<void> dispose() async {
    for (final pending in _downloads.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(Exception('Service disposed'));
      }
    }
    for (final pending in _uploads.values) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(Exception('Service disposed'));
      }
    }
    _downloads.clear();
    _uploads.clear();

    await FileDownloader().cancelAll(group: downloadGroup);
    await FileDownloader().cancelAll(group: uploadGroup);
    await FileDownloader().database.deleteAllRecords(group: downloadGroup);
    await FileDownloader().database.deleteAllRecords(group: uploadGroup);
    unregisterTaskUpdateHandler(_downloadTaskPrefix);
    unregisterTaskUpdateHandler(_uploadTaskPrefix);
    _configuring = null;
  }

  void _handleDownloadUpdate(TaskUpdate update) {
    final taskId = _stripPrefix(update.task.taskId, _downloadTaskPrefix);
    if (taskId == null) return;

    final pending = _downloads[taskId];
    if (pending == null) return;

    if (update is TaskProgressUpdate) {
      final fraction = update.progress.clamp(0.0, 1.0);
      pending.onProgress?.call(
        (fraction * pending.totalBytes).round(),
        pending.totalBytes,
      );
      return;
    }

    if (update is! TaskStatusUpdate) return;

    switch (update.status) {
      case TaskStatus.complete:
        _downloads.remove(taskId);
        if (!pending.completer.isCompleted) {
          pending.completer.complete();
        }
      case TaskStatus.failed || TaskStatus.notFound:
        _downloads.remove(taskId);
        _deleteIfExists(pending.outputPath);
        final failure = _describeFailure(update);
        _log.warn('tar download failed', fields: failure.asLogFields(taskId));
        if (!pending.completer.isCompleted) {
          pending.completer.completeError(Exception(failure.message));
        }
      case TaskStatus.canceled:
        _downloads.remove(taskId);
        _deleteIfExists(pending.outputPath);
        if (!pending.completer.isCompleted) {
          pending.completer.completeError(Exception('Tar download cancelled'));
        }
      default:
        break;
    }
  }

  void _handleUploadUpdate(TaskUpdate update) {
    final taskId = _stripPrefix(update.task.taskId, _uploadTaskPrefix);
    if (taskId == null) return;

    final pending = _uploads[taskId];
    if (pending == null) return;

    if (update is TaskProgressUpdate) {
      final fraction = update.progress.clamp(0.0, 1.0);
      pending.onProgress?.call(
        (fraction * pending.totalBytes).round(),
        pending.totalBytes,
      );
      return;
    }

    if (update is! TaskStatusUpdate) return;

    switch (update.status) {
      case TaskStatus.complete:
        _uploads.remove(taskId);
        if (!pending.completer.isCompleted) {
          pending.completer.complete(update.responseBody ?? '');
        }
      case TaskStatus.failed || TaskStatus.notFound:
        _uploads.remove(taskId);
        final failure = _describeFailure(update);
        _log.warn('tar upload failed', fields: failure.asLogFields(taskId));
        if (!pending.completer.isCompleted) {
          pending.completer.completeError(Exception(failure.message));
        }
      case TaskStatus.canceled:
        _uploads.remove(taskId);
        if (!pending.completer.isCompleted) {
          pending.completer.completeError(Exception('Tar upload cancelled'));
        }
      default:
        break;
    }
  }

  static const String _downloadTaskPrefix = 'tar-dl:';
  static const String _uploadTaskPrefix = 'tar-ul:';
}

String? _stripPrefix(String value, String prefix) {
  if (!value.startsWith(prefix)) return null;
  return value.substring(prefix.length);
}

TransferFailure _describeFailure(TaskStatusUpdate update) =>
    TransferFailure.fromTaskStatusUpdate(update);

/// Structured shape of a failed `background_downloader` transfer. Built
/// from the OS-native [TaskStatusUpdate] so the same data feeds both the
/// JSON log line and the rethrown exception string — neither gets
/// swallowed by the structured-vs-string seam.
///
/// Public (rather than file-private) so unit tests can construct one
/// directly and lock the wire shape that lands in the log: a regression
/// that goes back to logging `{task_id, status}` only fails the tests
/// in `background_tar_transfer_test.dart`.
class TransferFailure {
  /// OS-native cause (`description` from `background_downloader`'s
  /// [TaskException]). Null when no exception was attached — usually
  /// means a clean status-code rejection rather than a transport blow-up.
  final String? cause;

  /// HTTP status code from the server, if any. Null when the connection
  /// died before a response (CF 100 s timeout that cuts the TCP, network
  /// drop, abrupt RST, etc.).
  final int? status;

  /// First [bodyMaxLength] characters of the response body. Long enough
  /// to read a Cloudflare / Caddy / origin error page; short enough to
  /// keep the log line bounded.
  final String? body;

  /// Hard cap on the body slice we keep. The full response body is
  /// already stored on disk by `background_downloader` if the caller
  /// wants more — the log just needs enough to identify the proxy or
  /// origin error class.
  static const int bodyMaxLength = 500;

  const TransferFailure({this.cause, this.status, this.body});

  factory TransferFailure.fromTaskStatusUpdate(TaskStatusUpdate update) {
    final body = update.responseBody;
    final trimmed = body == null || body.isEmpty
        ? null
        : (body.length > bodyMaxLength
              ? '${body.substring(0, bodyMaxLength)}…'
              : body);
    return TransferFailure(
      cause: update.exception?.description,
      status: update.responseStatusCode,
      body: trimmed,
    );
  }

  /// Map suitable for `_log.warn(..., fields: ...)`. Every diagnostic
  /// dimension lands as its own field — no swallowing into a stringified
  /// exception, no later loss to `describeError`.
  Map<String, Object?> asLogFields(String taskId) => {
    'task_id': taskId,
    'status': status,
    'cause': cause,
    'body': body,
  };

  /// One-line human form for the rethrown `Exception` so callers up the
  /// stack still see something readable in `.toString()`.
  String get message {
    final buffer = StringBuffer(cause ?? 'unknown cause');
    if (status != null) buffer.write(' (status $status)');
    if (body != null) buffer.write(': $body');
    return buffer.toString();
  }
}

void _deleteIfExists(String path) {
  () async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }();
}

class _PendingDownload {
  final int totalBytes;
  final String outputPath;
  final Completer<void> completer;
  final void Function(int, int)? onProgress;

  _PendingDownload({
    required this.totalBytes,
    required this.outputPath,
    required this.completer,
    required this.onProgress,
  });
}

class _PendingUpload {
  final int totalBytes;
  final Completer<String> completer;
  final void Function(int, int)? onProgress;

  _PendingUpload({
    required this.totalBytes,
    required this.completer,
    required this.onProgress,
  });
}
