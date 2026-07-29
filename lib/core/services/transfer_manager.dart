import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../utils/format.dart' as fmt;
import '../utils/l10n_lookup.dart';

/// Independent transfer job types. Each is a standalone 0-100% progress item.
///
/// HTTP transfers (the long-running part) are delegated to OS-native
/// background workers, while encrypt/decrypt run in Dart isolates or Rust FFI.
enum TransferType {
  uploadEncrypt,
  uploadHttp,
  downloadHttp,
  downloadDecrypt;

  String get label => switch (this) {
    uploadEncrypt => ambientL10n.serviceTransferEncrypting,
    uploadHttp => ambientL10n.serviceTransferUploading,
    downloadHttp => ambientL10n.serviceTransferDownloading,
    downloadDecrypt => ambientL10n.serviceTransferDecrypting,
  };

  bool get isUpload => this == uploadEncrypt || this == uploadHttp;

  /// Whether this is a network transfer (meaningful speed/ETA).
  bool get isNetworkTransfer => this == uploadHttp || this == downloadHttp;
}

/// The status of a transfer.
enum TransferStatus { queued, active, completed, failed, cancelled }

/// A single speed sample for rolling-window speed calculation.
class _SpeedSample {
  final DateTime timestamp;
  final int bytesTransferred;

  const _SpeedSample({required this.timestamp, required this.bytesTransferred});
}

/// Represents a single file transfer (upload or download).
class TransferItem {
  final String id;
  String? fileId;
  final String fileName;
  final TransferType type;
  final bool onWorker;
  TransferStatus status;
  int totalBytes;
  int transferredBytes;
  int totalChunks;
  int completedChunks;
  DateTime startedAt;
  DateTime? lastChunkAt;
  String? errorMessage;

  /// Rolling window of speed samples (last 5 seconds).
  final List<_SpeedSample> _speedSamples = [];

  TransferItem({
    required this.id,
    this.fileId,
    required this.fileName,
    required this.type,
    this.onWorker = false,
    this.status = TransferStatus.queued,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.totalChunks = 0,
    this.completedChunks = 0,
    required this.startedAt,
    this.lastChunkAt,
    this.errorMessage,
  });

  /// Progress as a fraction from 0.0 to 1.0.
  double get progress => totalBytes > 0 ? transferredBytes / totalBytes : 0;

  /// Add a speed sample for the rolling window calculation.
  void addSpeedSample(int bytesInThisUpdate) {
    final now = DateTime.now();
    _speedSamples.add(
      _SpeedSample(timestamp: now, bytesTransferred: bytesInThisUpdate),
    );

    // Remove samples older than 5 seconds.
    final cutoff = now.subtract(const Duration(seconds: 5));
    _speedSamples.removeWhere((s) => s.timestamp.isBefore(cutoff));
  }

  /// Speed in bytes per second based on a rolling 5-second window.
  double get bytesPerSecond {
    if (_speedSamples.length < 2) {
      // Not enough samples; fall back to overall average.
      if (transferredBytes == 0) return 0;
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      if (elapsed <= 0) return 0;
      return transferredBytes / (elapsed / 1000.0);
    }

    final oldest = _speedSamples.first.timestamp;
    final newest = _speedSamples.last.timestamp;
    final windowMs = newest.difference(oldest).inMilliseconds;
    if (windowMs <= 0) return 0;

    final totalInWindow = _speedSamples.fold<int>(
      0,
      (sum, s) => sum + s.bytesTransferred,
    );
    return totalInWindow / (windowMs / 1000.0);
  }

  /// Estimated time remaining, or null if speed is zero.
  Duration? get estimatedTimeRemaining {
    final speed = bytesPerSecond;
    if (speed <= 0) return null;
    final remaining = totalBytes - transferredBytes;
    if (remaining <= 0) return Duration.zero;
    final seconds = remaining / speed;
    return Duration(seconds: seconds.ceil());
  }

  /// Human-readable speed string, e.g. "1.5 MB/s".
  String get speedString {
    final speed = bytesPerSecond;
    if (speed <= 0) return '';
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    if (speed < 1024 * 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }

  /// Human-readable ETA string, e.g. "2m 30s".
  String get etaString {
    final eta = estimatedTimeRemaining;
    if (eta == null) return '';
    if (eta.inSeconds <= 0) return '';
    if (eta.inSeconds < 60) return '~${eta.inSeconds}s';
    final minutes = eta.inMinutes;
    final seconds = eta.inSeconds % 60;
    if (minutes < 60) {
      return seconds > 0 ? '~${minutes}m ${seconds}s' : '~${minutes}m';
    }
    final hours = eta.inHours;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0
        ? '~${hours}h ${remainingMinutes}m'
        : '~${hours}h';
  }

  /// Human-readable transferred/total string, e.g. "2.3/5.1 MB".
  String get sizeProgressString {
    return '${formatBytes(transferredBytes)}/${formatBytes(totalBytes)}';
  }

  /// Format bytes as a human-readable string.
  static String formatBytes(int bytes) {
    return fmt.formatBytes(bytes);
  }
}

/// Singleton service that tracks all active transfers.
///
/// Uses [ChangeNotifier] so the UI can react to state changes.
class TransferManager extends ChangeNotifier {
  final List<TransferItem> _transfers = [];
  int _nextId = 0;

  /// All transfers (unmodifiable view).
  List<TransferItem> get transfers => UnmodifiableListView(_transfers);

  /// Only active transfers.
  List<TransferItem> get activeTransfers =>
      _transfers.where((t) => t.status == TransferStatus.active).toList();

  /// Whether there are any active transfers.
  bool get hasActiveTransfers =>
      _transfers.any((t) => t.status == TransferStatus.active);

  /// Whether there are any transfers at all (active, completed, or failed).
  bool get hasTransfers => _transfers.isNotEmpty;

  /// Callback invoked when a transfer cancel is requested.
  /// Receives the server-side fileId so the caller can propagate to workers/Rust.
  void Function(String fileId)? onCancelRequested;

  /// Start tracking a new transfer. Returns the created [TransferItem].
  TransferItem startTransfer({
    required String fileName,
    required TransferType type,
    required int totalBytes,
    required int totalChunks,
    String? fileId,
    bool onWorker = false,
  }) {
    final item = TransferItem(
      id: 'transfer_${_nextId++}_${DateTime.now().millisecondsSinceEpoch}',
      fileId: fileId,
      fileName: fileName,
      type: type,
      onWorker: onWorker,
      status: TransferStatus.active,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
      startedAt: DateTime.now(),
    );
    _transfers.insert(0, item);
    notifyListeners();
    return item;
  }

  /// Update the server-side fileId on a transfer (e.g. after file entry
  /// creation, when the temp ID is replaced with the real server ID).
  void updateFileId(String transferId, String fileId) {
    final item = _findById(transferId);
    if (item == null) return;
    item.fileId = fileId;
    notifyListeners();
  }

  /// Update progress for a transfer.
  ///
  /// The displayed progress is clamped to a high-water mark — both
  /// `transferredBytes` and `completedChunks` only ever move forward
  /// during a single transfer's lifetime. Several real-world cases
  /// would otherwise visually drag the bar backwards:
  ///
  ///   * `background_downloader` retries an `UploadTask` internally
  ///     (we configure `retries: 3`); each retry emits
  ///     `TaskProgressUpdate` events starting from byte 0, so the OS
  ///     would happily send us 30 % → 0 % → climbing again.
  ///   * The tar leg fails and the pipeline falls back to per-chunk —
  ///     [BackgroundUploadService] starts at "0 of N chunks", which
  ///     translates to 0 transferred bytes until completed-count
  ///     catches up to the bytes already streamed during the tar
  ///     attempt.
  ///
  /// Both cases are honest representations of the underlying byte
  /// counter, but neither is what the user wants to see — the upload
  /// is genuinely making progress overall, even when one HTTP request
  /// inside it restarts. We hide the noise here rather than at every
  /// caller.
  ///
  /// `bytesAdded` (used for the speed sample) is computed from the
  /// raw delta against the *post-clamp* counter, so a "regression"
  /// adds zero bytes to the speed average instead of polluting it
  /// with a sudden negative.
  void updateProgress(
    String transferId, {
    required int completedChunks,
    required int transferredBytes,
  }) {
    final item = _findById(transferId);
    if (item == null) return;

    final clampedBytes = max(item.transferredBytes, transferredBytes);
    final clampedChunks = max(item.completedChunks, completedChunks);
    final bytesAdded = clampedBytes - item.transferredBytes;

    item.completedChunks = clampedChunks;
    item.transferredBytes = clampedBytes;
    item.lastChunkAt = DateTime.now();

    if (bytesAdded > 0) {
      item.addSpeedSample(bytesAdded);
    }

    notifyListeners();
  }

  /// Mark a transfer as completed.
  void completeTransfer(String transferId) {
    final item = _findById(transferId);
    if (item == null) return;
    item.status = TransferStatus.completed;
    item.transferredBytes = item.totalBytes;
    item.completedChunks = item.totalChunks;
    item.lastChunkAt = DateTime.now();
    notifyListeners();
  }

  /// Mark a transfer as failed.
  void failTransfer(String transferId, String error) {
    final item = _findById(transferId);
    if (item == null) return;
    item.status = TransferStatus.failed;
    item.errorMessage = error;
    item.lastChunkAt = DateTime.now();
    notifyListeners();
  }

  /// Cancel a transfer. Notifies the worker/Rust layer via [onCancelRequested].
  void cancelTransfer(String transferId) {
    final item = _findById(transferId);
    if (item == null) return;
    if (item.status == TransferStatus.completed ||
        item.status == TransferStatus.cancelled) {
      return;
    }

    if (item.fileId != null) {
      onCancelRequested?.call(item.fileId!);
    }

    item.status = TransferStatus.cancelled;
    item.errorMessage = ambientL10n.serviceTransferCancelled;
    item.lastChunkAt = DateTime.now();
    notifyListeners();
  }

  /// Mark a transfer as cancelled (without triggering the cancel callback).
  /// Used by WorkerManager when it already sent the cancel signal.
  void markCancelled(String transferId) {
    final item = _findById(transferId);
    if (item == null) return;
    item.status = TransferStatus.cancelled;
    item.errorMessage = ambientL10n.serviceTransferCancelled;
    item.lastChunkAt = DateTime.now();
    notifyListeners();
  }

  /// Remove a single completed, failed, or cancelled transfer from the list.
  void dismissTransfer(String transferId) {
    _transfers.removeWhere(
      (t) =>
          t.id == transferId &&
          (t.status == TransferStatus.completed ||
              t.status == TransferStatus.failed ||
              t.status == TransferStatus.cancelled),
    );
    notifyListeners();
  }

  /// Clear all completed, failed, and cancelled transfers.
  void clearCompleted() {
    _transfers.removeWhere(
      (t) =>
          t.status == TransferStatus.completed ||
          t.status == TransferStatus.failed ||
          t.status == TransferStatus.cancelled,
    );
    notifyListeners();
  }

  TransferItem? _findById(String id) {
    for (final t in _transfers) {
      if (t.id == id) return t;
    }
    return null;
  }
}
