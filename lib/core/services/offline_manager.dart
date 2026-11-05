import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/database.dart';
import '../storage/pending_downloads_dao.dart';
import '../utils/format.dart' as fmt;
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'offline_cache_lru.dart';

const _log = Logger('OfflineManager');

/// Manages encrypted offline file storage. Files are stored as raw
/// server-encrypted chunks (no re-encryption; decryptable only with the
/// per-file symmetric key). Unpinned files are evicted when the account is
/// over its size cap (default 8 GB); pinned files stay until the user
/// clears the cache. Peak memory during decrypt is ~4 MB (one chunk).
///
/// Layout: `{applicationSupportDirectory}/offline_cache/{accountId}/{fileId}/NNNNNN.enc`
class OfflineManager extends ChangeNotifier {
  final AppDatabase _db;
  String? _basePath;
  Future<void>? _enforcing;

  /// File IDs [TransferManager] currently has in flight. Set by
  /// [FileDownloader] so LRU can skip them without importing the overlay.
  Set<String> Function()? activeTransferIds;

  OfflineManager(this._db);

  /// Note that a download is in flight, or refresh it if one already is.
  ///
  /// Lives here because this is what already owns the database and the
  /// on-disk chunk state a resume has to diff against. Only the intent is
  /// stored — never the presigned URLs, which stay valid for days and have no
  /// business persisting past the transfer they belong to.
  Future<void> recordPendingDownload({
    required String accountId,
    required String fileId,
    required int chunkCount,
    required int fileSize,
    required String outputDir,
    String? outputPath,
  }) => _db.recordPendingDownload(
    accountId: accountId,
    fileId: fileId,
    chunkCount: chunkCount,
    fileSize: fileSize,
    outputDir: outputDir,
    outputPath: outputPath,
  );

  /// Forget a download once its chunks are all on disk, or the user drops it.
  Future<void> clearPendingDownload({
    required String accountId,
    required String fileId,
  }) => _db.clearPendingDownload(accountId: accountId, fileId: fileId);

  /// Downloads this account expected to finish but has not.
  Future<List<PendingDownload>> pendingDownloads(String accountId) =>
      _db.getPendingDownloads(accountId);

  /// Register that encrypted chunks for a file are stored in [chunksDir].
  /// Call after a chunk download completes to record the file in the cache.
  Future<void> registerChunks({
    required String accountId,
    required String fileId,
    required String chunksDir,
    required int chunkCount,
    bool pinned = false,
  }) async {
    int totalSize = 0;
    for (var i = 0; i < chunkCount; i++) {
      final f = File(p.join(chunksDir, '${i.toString().padLeft(6, '0')}.enc'));
      if (await f.exists()) {
        totalSize += await f.length();
      }
    }

    final existing = await _db.getOfflineFile(accountId, fileId);
    final keepPinned = pinned || (existing?.pinned ?? false);

    await _db.insertOfflineFile(
      OfflineFilesCompanion(
        accountId: Value(accountId),
        fileId: Value(fileId),
        localPath: Value(chunksDir),
        sizeOnDisk: Value(totalSize),
        pinned: Value(keepPinned),
        downloadedAt: Value(DateTime.now()),
        lastAccessedAt: Value(DateTime.now()),
      ),
    );

    _log.info(
      'registered chunks',
      fields: {
        'file_id': fileId,
        'pinned': keepPinned,
        'chunks': chunkCount,
        'size_bytes': totalSize,
        'size_human': fmt.formatBytes(totalSize),
      },
    );

    notifyListeners();
    await enforceLimit(accountId, keep: {fileId});
  }

  Future<Uint8List?> decryptToMemory({
    required String accountId,
    required String fileId,
    required int chunkCount,
    required Uint8List Function(Uint8List encrypted, int index) decryptChunk,
  }) async {
    final entry = await _db.getOfflineFile(accountId, fileId);
    if (entry == null) return null;

    final dir = Directory(entry.localPath);
    if (!await dir.exists()) {
      // Stale record — chunk directory was deleted externally.
      await _db.deleteOfflineFile(accountId, fileId);
      notifyListeners();
      return null;
    }

    final builder = BytesBuilder(copy: false);
    try {
      for (var i = 0; i < chunkCount; i++) {
        final chunk = File(
          p.join(entry.localPath, '${i.toString().padLeft(6, '0')}.enc'),
        );
        if (!await chunk.exists()) {
          await _removeEntry(accountId, fileId, entry.localPath);
          return null;
        }
        builder.add(decryptChunk(await chunk.readAsBytes(), i));
      }

      // Update access time.
      await _db.touchOfflineFile(accountId, fileId);

      _log.debug('decrypted chunks to memory', fields: {'file_id': fileId});

      return builder.toBytes();
    } catch (e) {
      _log.warn(
        'failed to decrypt chunks to memory',
        fields: {'file_id': fileId, 'error': describeError(e)},
      );
      // Corrupted cache entry — remove it.
      await _removeEntry(accountId, fileId, entry.localPath);
      return null;
    }
  }

  /// Return indices of chunks already downloaded for a file.
  ///
  /// Used for resume support: pass the result as `alreadyDownloaded` to
  /// [DownloadChunksCommand] so only missing chunks are fetched.
  Future<List<int>> getDownloadedChunks(String accountId, String fileId) async {
    final entry = await _db.getOfflineFile(accountId, fileId);
    if (entry == null) return [];

    final dir = Directory(entry.localPath);
    if (!await dir.exists()) return [];

    final indices = <int>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.enc')) {
        final name = p.basenameWithoutExtension(entity.path);
        final index = int.tryParse(name);
        if (index != null) indices.add(index);
      }
    }
    return indices..sort();
  }

  /// Return the chunk directory path for a file (creates parent if needed).
  ///
  /// The directory may or may not exist yet — the download worker creates
  /// it when chunks start arriving.
  Future<String> chunksDir(String accountId, String fileId) async {
    final dir = await _ensureDir(accountId);
    return p.join(dir, fileId);
  }

  /// Check if a file has an offline copy available (chunks on disk).
  Future<bool> hasCachedFile(String accountId, String fileId) async {
    final entry = await _db.getOfflineFile(accountId, fileId);
    return entry != null;
  }

  /// Bump an offline file's last-accessed timestamp. Preview-layer cache
  /// hits call this so recently-viewed files don't trail less-recent ones
  /// in LRU eviction order; [decryptToMemory] already touches when it
  /// runs.
  Future<void> touchCachedFile(String accountId, String fileId) =>
      _db.touchOfflineFile(accountId, fileId);

  /// Check if a file is pinned for offline access.
  Future<bool> isFilePinned(String accountId, String fileId) async {
    final entry = await _db.getOfflineFile(accountId, fileId);
    return entry?.pinned ?? false;
  }

  /// Get the set of file IDs that are available offline for an account.
  /// Efficient for bulk UI checks (e.g. showing offline indicators on a
  /// file listing).
  Future<Set<String>> getOfflineFileIds(String accountId) {
    return _db.getOfflineFileIds(accountId);
  }

  /// Pin a file for offline access. If the file is already cached,
  /// promotes it to pinned. If not cached, the caller should download the
  /// chunks and call [registerChunks] with `pinned: true`.
  ///
  /// Returns `true` if the file was already cached and just promoted.
  /// Returns `false` if the file needs to be downloaded first.
  Future<bool> pinFile(String accountId, String fileId) async {
    final entry = await _db.getOfflineFile(accountId, fileId);
    if (entry != null) {
      await _db.setOfflineFilePinned(accountId, fileId, true);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Unpin a file. The file stays in cache.
  Future<void> unpinFile(String accountId, String fileId) async {
    await _db.setOfflineFilePinned(accountId, fileId, false);
    notifyListeners();
  }

  /// Remove a specific file from the offline cache (chunks + DB record).
  Future<void> removeCachedFile(String accountId, String fileId) async {
    final entry = await _db.getOfflineFile(accountId, fileId);
    if (entry != null) {
      await _removeEntry(accountId, fileId, entry.localPath);
    }
  }

  /// Clear the entire offline cache for an account.
  Future<void> clearCache(String accountId) async {
    final entries = await _db.getOfflineFilesForAccount(accountId);
    for (final entry in entries) {
      try {
        final dir = Directory(entry.localPath);
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
    await _db.deleteAllOfflineFiles(accountId);

    // Also try to remove the account directory.
    try {
      final dir = Directory(await _accountDir(accountId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}

    notifyListeners();

    _log.info('cleared offline cache', fields: {'count': entries.length});
  }

  /// Total bytes used by offline files for an account.
  Future<int> getCacheSize(String accountId) {
    return _db.getOfflineCacheSize(accountId);
  }

  /// Reclaim unpinned files until this account is at or under its cap.
  Future<void> enforceLimit(
    String accountId, {
    Set<String> keep = const {},
    Future<Set<String>> Function()? osInFlightIds,
  }) async {
    final previous = _enforcing;
    final gate = Completer<void>();
    _enforcing = gate.future;
    try {
      if (previous != null) await previous;
      await enforceOfflineCacheLimit(
        db: _db,
        accountId: accountId,
        remove: removeCachedFile,
        keep: keep,
        activeTransferIds: activeTransferIds,
        osInFlightIds: osInFlightIds,
      );
    } catch (e) {
      _log.warn('cache eviction failed', fields: {'error': describeError(e)});
    } finally {
      gate.complete();
      if (identical(_enforcing, gate.future)) _enforcing = null;
    }
  }

  /// Number of offline files for an account.
  Future<int> getCacheFileCount(String accountId) async {
    final files = await _db.getOfflineFilesForAccount(accountId);
    return files.length;
  }

  Future<String> _getBasePath() async {
    if (_basePath != null) return _basePath!;
    final appDir = await getApplicationSupportDirectory();
    _basePath = p.join(appDir.path, 'offline_cache');
    return _basePath!;
  }

  Future<String> _accountDir(String accountId) async {
    final base = await _getBasePath();
    // Sanitize account ID for use as directory name.
    final safe = accountId.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return p.join(base, safe);
  }

  /// Ensure the account's cache directory exists and return its path.
  Future<String> _ensureDir(String accountId) async {
    final dirPath = await _accountDir(accountId);
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dirPath;
  }

  /// Delete an offline entry's chunk directory from disk and its DB record.
  Future<void> _removeEntry(
    String accountId,
    String fileId,
    String localPath,
  ) async {
    try {
      // localPath points to the chunk directory (e.g. .../fileId/).
      final dir = Directory(localPath);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    await _db.deleteOfflineFile(accountId, fileId);
    notifyListeners();
  }
}
