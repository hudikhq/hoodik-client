import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../storage/database.dart';
import '../storage/pending_uploads_dao.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'connectivity_service.dart';
import 'file_operations.dart';
import 'pending_upload_status.dart';

const _log = Logger('SyncService');

/// Retry schedule: 30s, 60s, 120s, 240s, 480s. After the fifth failure
/// the upload is marked [PendingUploadStatus.failedPermanent] and only
/// a manual retry moves it out of that state.
const int _maxUploadRetries = 5;
const Duration _baseRetryDelay = Duration(seconds: 30);

/// Result of a directory listing fetch.
///
/// [isFromCache] is true when the data came from the local database
/// (offline or server error), false when freshly fetched from the server.
class DirectoryListingResult {
  final List<FileItem> files;
  final bool isFromCache;

  const DirectoryListingResult({
    required this.files,
    required this.isFromCache,
  });
}

/// Orchestrates offline sync: directory listing cache and pending upload queue.
///
/// Sits between the UI and the network layer to provide:
/// 1. Fetch directory listings with automatic cache fallback when offline.
/// 2. Queue uploads when offline and process them when connectivity returns.
/// 3. Respond to connectivity changes (trigger sync, drain pending queue).
///
/// Security: only encrypted metadata is stored in the database. No plaintext
/// file names ever touch persistent storage.
class SyncService extends ChangeNotifier {
  final AppDatabase _db;
  final ConnectivityService _connectivity;

  /// Time source, overridable in tests so the backoff schedule is deterministic.
  final DateTime Function() _clock;

  /// Set externally when the user logs in; cleared on logout.
  ApiClient? apiClient;

  /// Set externally; used to process pending uploads.
  FileOperations? fileOperations;

  /// The account ID for the currently active account.
  String? accountId;

  /// Number of pending uploads awaiting processing.
  int _pendingUploadCount = 0;
  int get pendingUploadCount => _pendingUploadCount;

  /// Whether the pending upload queue is currently being processed.
  bool _processingQueue = false;
  bool get processingQueue => _processingQueue;

  /// Whether this service has been disposed.
  bool _disposed = false;

  SyncService({
    required AppDatabase db,
    required ConnectivityService connectivity,
    DateTime Function()? clock,
  }) : _db = db,
       _connectivity = connectivity,
       _clock = clock ?? DateTime.now {
    _connectivity.onReconnected = _onReconnected;
  }

  bool get isOnline => _connectivity.isOnline;

  // ── Directory listing with cache fallback ────────────────────────────

  /// Fetch files for a directory. Returns server data when online,
  /// falls back to cached data when offline or on error.
  ///
  /// On success: updates the CachedFiles table (batch upsert) and
  /// removes stale entries for files deleted on the server.
  Future<DirectoryListingResult> fetchFiles({String? dirId}) async {
    final acctId = accountId;
    final client = apiClient;

    if (acctId == null || client == null) {
      return const DirectoryListingResult(files: [], isFromCache: true);
    }

    try {
      final response = await client.files.listFiles(dirId: dirId);
      final files = response.children;

      // Cache the listing before returning so subsequent cache reads are
      // consistent (e.g. deleted files are pruned immediately).
      await _cacheDirectoryListing(acctId, dirId, files);

      return DirectoryListingResult(files: files, isFromCache: false);
    } catch (e) {
      _log.warn(
        'failed to fetch from server — falling back to cache',
        fields: {'dir_id': dirId, 'error': describeError(e)},
      );

      final cached = await _db.getFilesInDir(acctId, dirId);
      final fileItems = cached.map(_cachedFileToFileItem).toList();
      return DirectoryListingResult(files: fileItems, isFromCache: true);
    }
  }

  /// Batch-upsert a directory listing into CachedFiles and prune stale entries.
  Future<void> _cacheDirectoryListing(
    String acctId,
    String? dirId,
    List<FileItem> files,
  ) async {
    try {
      // Listings arrive without thumbnail blobs (they ask for `compact`
      // rows); the upsert replaces whole rows, so carry over any
      // ciphertext the lazy loader already wrote back — otherwise every
      // refresh would wipe the offline thumbnails.
      final cached = await _db.getFilesInDir(acctId, dirId);
      final cachedThumbnails = {
        for (final row in cached) row.id: row.encryptedThumbnail,
      };

      final companions = files
          .map(
            (f) => CachedFilesCompanion(
              accountId: Value(acctId),
              id: Value(f.id),
              dirId: f.fileId == null ? const Value.absent() : Value(f.fileId),
              encryptedName: Value(f.encryptedName),
              encryptedKey: Value(f.encryptedKey),
              encryptedThumbnail: Value(
                f.encryptedThumbnail ??
                    (f.hasThumbnail ? cachedThumbnails[f.id] : null),
              ),
              mime: Value(f.mime),
              size: Value(f.size),
              chunks: Value(f.chunks),
              chunksStored: Value(f.chunksStored),
              cipher: Value(f.cipher),
              fileModifiedAt: Value(f.fileModifiedAt),
              createdAt: Value(f.createdAt),
              finishedUploadAt: Value(f.finishedUploadAt),
              syncedAt: Value(DateTime.now()),
            ),
          )
          .toList();

      await _db.upsertCachedFiles(companions);

      // Remove files that exist in cache but no longer on the server.
      final currentIds = files.map((f) => f.id).toSet();
      await _db.removeStaleCachedFiles(acctId, dirId, currentIds);

      _log.debug(
        'cached directory listing',
        fields: {'dir_id': dirId, 'count': files.length},
      );
    } catch (e) {
      _log.warn(
        'failed to cache directory listing',
        fields: {'error': describeError(e)},
      );
    }
  }

  /// Convert a CachedFile DB row back to a FileItem for the UI.
  static FileItem _cachedFileToFileItem(CachedFile cf) {
    return FileItem(
      id: cf.id,
      fileId: cf.dirId,
      encryptedName: cf.encryptedName,
      encryptedKey: cf.encryptedKey,
      encryptedThumbnail: cf.encryptedThumbnail,
      mime: cf.mime,
      size: cf.size,
      chunks: cf.chunks,
      chunksStored: cf.chunksStored,
      cipher: cf.cipher,
      fileModifiedAt: cf.fileModifiedAt,
      createdAt: cf.createdAt,
      finishedUploadAt: cf.finishedUploadAt,
    );
  }

  // ── Pending upload queue ─────────────────────────────────────────────

  /// Queue a file for upload. Used when offline or when an upload fails.
  Future<void> queueUpload({
    required String localPath,
    String? targetDirId,
  }) async {
    final acctId = accountId;
    if (acctId == null) return;

    await _db.insertPendingUpload(
      PendingUploadsCompanion.insert(
        accountId: acctId,
        localPath: localPath,
        targetDirId: Value(targetDirId),
      ),
    );

    await _refreshPendingCount();

    _log.info('queued upload', fields: {'target_dir_id': targetDirId});
  }

  /// Upload a file, falling back to the pending queue on failure.
  ///
  /// If online: attempts immediate upload via FileOperations.
  /// If offline or upload fails: queues for later retry.
  Future<void> uploadFileOrQueue({
    required String localPath,
    String? parentDirId,
  }) async {
    if (!isOnline || fileOperations == null) {
      await queueUpload(localPath: localPath, targetDirId: parentDirId);
      return;
    }

    try {
      await fileOperations!.uploadFile(localPath, parentDirId: parentDirId);
    } catch (e) {
      _log.warn(
        'upload failed — queuing for retry',
        fields: {'error': describeError(e)},
      );
      await queueUpload(localPath: localPath, targetDirId: parentDirId);
    }
  }

  /// Drain the pending upload queue, respecting per-row exponential
  /// backoff. Rows whose [PendingUpload.nextRetryAt] lies in the future
  /// are skipped this pass; after [_maxUploadRetries] failures a row is
  /// flipped to [PendingUploadStatus.failedPermanent] and only reappears
  /// when the user taps Retry (see [retryPermanentlyFailed]).
  Future<void> processPendingUploads() async {
    final acctId = accountId;
    final ops = fileOperations;
    if (acctId == null || ops == null || !isOnline) return;
    if (_processingQueue) return;

    _processingQueue = true;
    _safeNotifyListeners();

    try {
      final queue = await _db.getPendingUploadsEligibleForRetry(
        acctId,
        _clock(),
      );

      for (final upload in queue) {
        if (!isOnline) break;
        await _attemptUpload(upload, ops);
      }
    } finally {
      _processingQueue = false;
      await _refreshPendingCount();
      _safeNotifyListeners();
    }
  }

  Future<void> _attemptUpload(PendingUpload upload, FileOperations ops) async {
    try {
      await _db.updatePendingUploadStatus(
        upload.id,
        PendingUploadStatus.uploading,
      );
      await ops.uploadFile(upload.localPath, parentDirId: upload.targetDirId);
      await _db.deletePendingUpload(upload.id);

      _log.info('pending upload completed', fields: {'upload_id': upload.id});
    } catch (e) {
      await _recordUploadFailure(upload, e);
    }
  }

  Future<void> _recordUploadFailure(PendingUpload upload, Object error) async {
    final newRetryCount = upload.retryCount + 1;

    if (newRetryCount >= _maxUploadRetries) {
      await _db.markPendingUploadPermanentlyFailed(upload.id, newRetryCount);
      _log.warn(
        'pending upload gave up',
        fields: {
          'upload_id': upload.id,
          'attempts': newRetryCount,
          'error': describeError(error),
        },
      );
      return;
    }

    // 30s, 60s, 120s, 240s after failures #1..#4.
    final delay = _baseRetryDelay * (1 << (newRetryCount - 1));
    await _db.scheduleNextUploadRetry(
      upload.id,
      retryCount: newRetryCount,
      nextRetryAt: _clock().add(delay),
    );

    _log.warn(
      'pending upload failed — scheduling retry',
      fields: {
        'upload_id': upload.id,
        'attempt': newRetryCount,
        'retry_in_seconds': delay.inSeconds,
        'error': describeError(error),
      },
    );
  }

  /// User-initiated retry for a [PendingUploadStatus.failedPermanent] row.
  /// Resets its retry budget and kicks the queue processor.
  Future<void> retryPermanentlyFailed(int id) async {
    if (_disposed) return;
    await _db.resetPendingUploadForRetry(id);
    await _refreshPendingCount();
    _safeNotifyListeners();
    await processPendingUploads();
  }

  /// Uploads that exhausted their retry budget and are waiting for the
  /// user to intervene. Exposed so the UI can surface them with a
  /// manual "Retry" affordance.
  Future<List<PendingUpload>> permanentlyFailedUploads() async {
    final acctId = accountId;
    if (acctId == null) return const [];
    return _db.getPermanentlyFailedUploads(acctId);
  }

  /// Drop a permanently-failed upload from the queue when the user
  /// decides to abandon it instead of retrying.
  Future<void> discardPermanentlyFailed(int id) async {
    if (_disposed) return;
    await _db.deletePendingUpload(id);
    await _refreshPendingCount();
    _safeNotifyListeners();
  }

  /// Refresh the cached pending upload count and notify listeners.
  Future<void> _refreshPendingCount() async {
    if (_disposed) return;
    final acctId = accountId;
    if (acctId == null) {
      _pendingUploadCount = 0;
    } else {
      _pendingUploadCount = await _db.getPendingUploadCount(acctId);
    }
    _safeNotifyListeners();
  }

  // ── Reconnection handler ─────────────────────────────────────────────

  void _onReconnected() {
    if (_disposed) return;
    _log.info('reconnected — processing pending uploads');
    processPendingUploads();
    _safeNotifyListeners();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  /// Call after login to set up the service for the active account.
  Future<void> activate({
    required String accountId,
    required ApiClient apiClient,
    FileOperations? fileOperations,
  }) async {
    this.accountId = accountId;
    this.apiClient = apiClient;
    this.fileOperations = fileOperations;
    await _refreshPendingCount();
  }

  /// Call on logout to clear state.
  void deactivate() {
    accountId = null;
    apiClient = null;
    fileOperations = null;
    _pendingUploadCount = 0;
    _processingQueue = false;
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivity.onReconnected = null;
    super.dispose();
  }

  /// Call [notifyListeners] only if the service has not been disposed.
  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }
}
