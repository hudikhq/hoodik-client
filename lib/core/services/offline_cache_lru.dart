import 'dart:async';

import '../storage/database.dart';
import '../storage/pending_downloads_dao.dart';
import '../utils/logger.dart';
import 'file_downloader_config.dart';

const _log = Logger('OfflineCacheLru');

/// Default cap when `accounts.cacheLimitBytes` is null. Same number
/// `docs/security.md` advertised before this walker was wired.
const int kDefaultCacheLimitBytes = 8 * 1024 * 1024 * 1024;
const int kCacheLimit2Gb = 2 * 1024 * 1024 * 1024;
const int kCacheLimit32Gb = 32 * 1024 * 1024 * 1024;

const _downloadGroups = ['chunk-downloads', 'direct-chunks', 'tar-downloads'];

/// Bytes of cache allowed for [cacheLimitBytes]: null → 8 GB, 0 → unlimited.
int? resolvedCacheLimitBytes(int? cacheLimitBytes) {
  if (cacheLimitBytes == 0) return null;
  return cacheLimitBytes ?? kDefaultCacheLimitBytes;
}

Future<Set<String>> _osInFlightFileIds() async {
  try {
    final ids = <String>{};
    for (final group in _downloadGroups) {
      for (final taskId in await tasksInFlight(group)) {
        final fileId = fileIdFromTaskId(taskId);
        if (fileId != null) ids.add(fileId);
      }
    }
    return ids;
  } catch (_) {
    return {};
  }
}

/// Evict unpinned files, oldest [OfflineFile.lastAccessedAt] first, until
/// [getOfflineCacheSize] is at or under the account's cap.
Future<void> enforceOfflineCacheLimit({
  required AppDatabase db,
  required String accountId,
  required Future<void> Function(String accountId, String fileId) remove,
  required Set<String> keep,
  Set<String> Function()? activeTransferIds,
  Future<Set<String>> Function()? osInFlightIds,
}) async {
  final account = await db.getAccountById(accountId);
  final limit = resolvedCacheLimitBytes(account?.cacheLimitBytes);
  if (limit == null) return;

  var size = await db.getOfflineCacheSize(accountId);
  if (size <= limit) return;

  final skip = {...keep, ...?activeTransferIds?.call()};
  for (final row in await db.getPendingDownloads(accountId)) {
    skip.add(row.fileId);
  }
  skip.addAll(await (osInFlightIds ?? _osInFlightFileIds)());

  final victims = await db.getEvictableFiles(accountId);
  for (final file in victims) {
    if (size <= limit) break;
    if (skip.contains(file.fileId)) continue;
    try {
      await remove(accountId, file.fileId);
      size -= file.sizeOnDisk;
    } catch (e) {
      _log.warn(
        'could not evict cached file',
        fields: {'file_id': file.fileId, 'error': e.toString()},
      );
    }
  }
}
