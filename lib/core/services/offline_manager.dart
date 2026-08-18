import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../src/rust/api.dart' as rust;
import '../storage/database.dart';
import '../storage/pending_downloads_dao.dart';
import '../utils/format.dart' as fmt;
import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('OfflineManager');

/// Manages encrypted offline file storage. Files are stored as raw
/// server-encrypted chunks (no re-encryption; decryptable only with the
/// per-file symmetric key). Cached indefinitely until the user clears the
/// cache from Account Settings. Peak memory during decrypt is ~4 MB (one
/// chunk), not the full file size.
///
/// Layout: `{applicationSupportDirectory}/offline_cache/{accountId}/{fileId}/NNNNNN.enc`
class OfflineManager extends ChangeNotifier {
  final AppDatabase _db;
  String? _basePath;

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
    required String outputDir,
    String? outputPath,
  }) => _db.recordPendingDownload(
    accountId: accountId,
    fileId: fileId,
    chunkCount: chunkCount,
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

    await _db.insertOfflineFile(
      OfflineFilesCompanion(
        accountId: Value(accountId),
        fileId: Value(fileId),
        localPath: Value(chunksDir),
        sizeOnDisk: Value(totalSize),
        pinned: Value(pinned),
        downloadedAt: Value(DateTime.now()),
        lastAccessedAt: Value(DateTime.now()),
      ),
    );

    _log.info(
      'registered chunks',
      fields: {
        'file_id': fileId,
        'pinned': pinned,
        'chunks': chunkCount,
        'size_bytes': totalSize,
        'size_human': fmt.formatBytes(totalSize),
      },
    );

    notifyListeners();
  }

  /// Decrypt cached chunks to a temp file and return the path.
  ///
  /// Returns `null` if no chunks are cached for this file. The caller is
  /// responsible for reading or sharing the temp file. Temp files live in
  /// the system temp directory and are cleaned up by [PreviewCache.dispose]
  /// on logout.
  ///
  /// Uses the Rust FFI `decryptChunksToFile` which reads one chunk at a
  /// time (~4 MB peak memory) — safe for large files.
  Future<String?> decryptToTempFile({
    required String accountId,
    required String fileId,
    required Uint8List fileKey,
    required String cipher,
    required int chunkCount,
    required String extension,
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

    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      final tempPath = p.join(tempDir.path, 'hoodik_$fileId.$extension');

      await rust.decryptChunksToFile(
        chunksDir: entry.localPath,
        chunkCount: BigInt.from(chunkCount),
        decryptionKey: fileKey,
        cipher: cipher,
        outputPath: tempPath,
        fileId: fileId,
      );

      // Update access time.
      await _db.touchOfflineFile(accountId, fileId);

      _log.debug('decrypted chunks to temp file', fields: {'file_id': fileId});

      return tempPath;
    } catch (e) {
      _log.warn(
        'failed to decrypt chunks',
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
  /// in LRU eviction order; [decryptToTempFile] already touches when it
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
