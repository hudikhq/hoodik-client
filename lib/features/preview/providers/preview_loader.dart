import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/file_operations.dart';
import '../../../core/services/offline_manager.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/utils/l10n_lookup.dart';
import 'offline_preview_helpers.dart';

/// Load preview file bytes through the 3-tier cache pipeline:
/// 1. In-memory [PreviewCache]
/// 2. Offline encrypted chunk cache on disk — decrypted in memory
/// 3. Download via [downloadAndPinOffline] → decrypt in memory
///
/// Nothing is ever written to disk: the offline cache holds only the
/// server-encrypted chunks, and plaintext lives in memory for the lifetime of
/// the preview.
///
/// Returns `null` when decryption is impossible (no file key or no API client).
/// Throws on download or decryption errors.
Future<Uint8List?> loadPreviewBytes(
  WidgetRef ref,
  FileItem file,
  Uint8List? fileKey, {
  String? displayName,
}) async {
  final cache = ref.read(previewCacheProvider);

  // 1. In-memory cache (instant).
  final cached = cache.get(file);
  if (cached != null) return cached;

  final offlineBytes = await loadBytesFromCache(ref, file, fileKey);
  if (offlineBytes != null) {
    cache.put(file, offlineBytes);
    return offlineBytes;
  }

  final ops = ref.read(fileOperationsProvider);
  if (ops == null || fileKey == null) return null;

  await _ensureDownloaded(ref, ops, file, displayName: displayName);

  final downloadedBytes = await loadBytesFromCache(ref, file, fileKey);
  if (downloadedBytes == null) {
    throw Exception(ambientL10n.previewDecryptAfterDownloadFailed);
  }

  cache.put(file, downloadedBytes);
  return downloadedBytes;
}

/// Ensure a file's encrypted chunks are present in the offline cache.
///
/// Dependency-injected variant of the preview download path, extracted so
/// the logic is unit-testable without a `WidgetRef`. Orders the three
/// checks that keep the preview pipeline from kicking off redundant work:
///
/// 1. An in-progress download for this file — wait for it, don't duplicate.
/// 2. Chunks already cached — short-circuit so preview doesn't re-download
///    a file the user made available offline.
/// 3. No cache, no in-flight transfer — start a fresh download, preserving
///    any existing pinned state so a cache-miss retry can't silently
///    unpin a file the user deliberately pinned.
Future<void> ensureFileDownloaded({
  required OfflineManager offlineManager,
  required TransferManager transferManager,
  required FileOperations ops,
  required String accountId,
  required FileItem file,
  String? displayName,
}) async {
  final existing = transferManager.transfers
      .where(
        (t) =>
            t.fileId == file.id &&
            t.type == TransferType.downloadHttp &&
            (t.status == TransferStatus.active ||
                t.status == TransferStatus.queued),
      )
      .firstOrNull;

  if (existing != null) {
    await _waitForTransfer(transferManager, existing.id);
    return;
  }

  if (await offlineManager.hasCachedFile(accountId, file.id)) {
    await offlineManager.touchCachedFile(accountId, file.id);
    return;
  }

  final wasPinned = await offlineManager.isFilePinned(accountId, file.id);

  final completer = Completer<void>();
  ops.downloadAndPinOffline(
    file,
    displayName: displayName,
    pinned: wasPinned,
    // Nobody asked for this download. They asked to read a note or look at a
    // photo, and the screen they are looking at draws its own progress.
    silent: true,
    onComplete: () => completer.complete(),
    onError: (error) => completer.completeError(Exception(error)),
  );
  await completer.future;
}

/// [WidgetRef]-bound wrapper around [ensureFileDownloaded].
///
/// Callers always pass a non-null `ops`, and [fileOperationsProvider]
/// only resolves non-null when an active account is present, so the
/// account read below is guaranteed to succeed.
Future<void> _ensureDownloaded(
  WidgetRef ref,
  FileOperations ops,
  FileItem file, {
  String? displayName,
}) {
  return ensureFileDownloaded(
    offlineManager: ref.read(offlineManagerProvider),
    transferManager: ref.read(transferManagerProvider),
    ops: ops,
    accountId: ref.read(activeAccountProvider)!.id,
    file: file,
    displayName: displayName,
  );
}

/// Wait for a transfer to reach a terminal state (completed/failed/cancelled).
Future<void> _waitForTransfer(TransferManager tm, String transferId) {
  final completer = Completer<void>();

  void listener() {
    final item = tm.transfers.where((t) => t.id == transferId).firstOrNull;

    if (item == null || item.status == TransferStatus.completed) {
      tm.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    } else if (item.status == TransferStatus.failed ||
        item.status == TransferStatus.cancelled) {
      tm.removeListener(listener);
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(item.errorMessage ?? ambientL10n.previewDownloadFailed),
        );
      }
    }
  }

  tm.addListener(listener);
  // Check immediately in case it already completed.
  listener();
  return completer.future;
}
