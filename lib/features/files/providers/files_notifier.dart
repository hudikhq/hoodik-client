import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/thumbnail_loader.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../core/utils/log_redact.dart';
import '../../../core/utils/logger.dart';
import '../../../core/workers/worker_messages.dart';
import '../../shares/services/incoming_shares.dart';
import '../../shares/shared_constants.dart';
import '../widgets/file_sort_controls.dart';
import 'files_state.dart';

const _log = Logger('FilesNotifier');

/// Notifier that owns the listing state for one directory on the files
/// screen. Lives per-`dirId` via [filesNotifierProvider] so switching
/// directories gets a fresh view while keeping each directory's cache
/// hot across navigation.
class FilesNotifier extends FamilyNotifier<FilesState, String?> {
  String? _dirId;
  Timer? _offlineRefreshTimer;
  final Set<String> _refreshedTransferIds = {};

  @override
  FilesState build(String? arg) {
    _dirId = arg;
    final account = ref.read(activeAccountProvider);

    _wireAccountSwitchListener();
    _wireConnectivityListener();
    _wireTransferCompletionListener();
    _wireOfflineCacheListener();

    ref.onDispose(() {
      _offlineRefreshTimer?.cancel();
    });

    return FilesState(loadedAccountId: account?.id);
  }

  void _wireAccountSwitchListener() {
    ref.listen(activeAccountProvider, (prev, next) {
      if (next != null && next.id != state.loadedAccountId) {
        clearCaches();
        load();
      }
    });
  }

  void _wireConnectivityListener() {
    ref.listen(connectivityProvider, (prev, next) {
      if (prev != null && !prev.isOnline && next.isOnline) {
        load();
      }
    });
  }

  void _wireTransferCompletionListener() {
    ref.listen(transferManagerProvider, (_, next) {
      for (final item in next.transfers) {
        if (item.type == TransferType.uploadHttp &&
            item.status == TransferStatus.completed &&
            _refreshedTransferIds.add(item.id)) {
          load();
          break;
        }
      }
    });
  }

  void _wireOfflineCacheListener() {
    ref.listen(offlineManagerProvider, (_, _) {
      _offlineRefreshTimer?.cancel();
      _offlineRefreshTimer = Timer(
        const Duration(milliseconds: 300),
        refreshOfflineFileIds,
      );
    });
  }

  /// Wipe every per-account cache so a stale listing from the previous
  /// account is never rendered after a switch.
  void clearCaches() {
    _refreshedTransferIds.clear();
    state = FilesState(loadedAccountId: state.loadedAccountId);
  }

  /// Fetch the current directory listing and decrypt names + thumbnails.
  ///
  /// Safe to call repeatedly — later invocations replace the previous
  /// listing atomically so transient failures don't wipe a good view.
  Future<void> load() async {
    final account = ref.read(activeAccountProvider);
    state = state.copyWith(
      loading: true,
      clearError: true,
      loadedAccountId: account?.id,
    );

    if (_dirId == sharedWithMeDirId) {
      await _loadSharedWithMe();
      return;
    }

    try {
      final syncService = ref.read(syncServiceProvider);
      final result = await syncService.fetchFiles(dirId: _dirId);
      final files = await _withSharedWithMeRoot(result.files);

      _decryptFileNames(files);
      await refreshOfflineFileIds();

      state = state.copyWith(
        files: files,
        isFromCache: result.isFromCache,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: ambientL10n.filesLoadFailed(_formatError(e)),
      );
    }
  }

  /// Source the synthetic folder's listing live from `GET /api/shares/mine`,
  /// mapping each incoming share into a [FileItem]. These rows are
  /// deliberately never written to the offline cache: persisting them under
  /// the fake dir id would drop `is_owner`/`share_role` and leak shares into
  /// the recipient's own root on the next cache read. When offline we surface
  /// an explicit needs-connection state instead of a stale view.
  Future<void> _loadSharedWithMe() async {
    if (!ref.read(connectivityProvider).isOnline) {
      state = state.copyWith(
        files: const [],
        isFromCache: false,
        loading: false,
        error: ambientL10n.filesSharedItemsNeedConnection,
      );
      return;
    }

    final client = ref.read(apiClientProvider);
    if (client == null) {
      state = state.copyWith(files: const [], loading: false);
      return;
    }

    try {
      final files = await fetchIncomingShareItems(client);

      _decryptFileNames(files);
      await refreshOfflineFileIds();

      state = state.copyWith(files: files, isFromCache: false, loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: ambientL10n.filesLoadSharedFailed(_formatError(e)),
      );
    }
  }

  /// Prepend the synthetic "Shared with me" folder to the root listing when
  /// the caller has at least one incoming share. A light `limit: 1` probe is
  /// enough to learn the total; a probe failure simply omits the folder this
  /// render rather than blocking the regular listing.
  Future<List<FileItem>> _withSharedWithMeRoot(List<FileItem> files) async {
    if (_dirId != null) return files;
    final client = ref.read(apiClientProvider);
    if (client == null) return files;

    // Fail closed while the capability probe is unresolved or errored — a
    // server that doesn't speak sharing should never trigger the probe.
    final capabilities = ref.read(shareCapabilitiesProvider).valueOrNull;
    if (capabilities == null || !capabilities.sharingEnabled) return files;

    try {
      if (!await hasIncomingShares(client)) return files;
      return [sharedWithMeFolder(), ...files];
    } catch (e) {
      _log.debug(
        'shared-with-me probe failed — omitting synthetic folder',
        fields: {'error': describeError(e)},
      );
      return files;
    }
  }

  /// Dispatch decryption for file names either to the decrypt-worker
  /// isolate (when available) or to the main thread. The worker path
  /// keeps the UI responsive on large listings.
  ///
  /// Re-decrypts when the encrypted name changes (rename happened
  /// elsewhere — web client, another device — and the server returned
  /// fresh ciphertext); the cached decrypted name would otherwise stick
  /// to the pre-rename value forever because the file ID is unchanged.
  void _decryptFileNames(List<FileItem> files) {
    final previousEncrypted = <String, String>{
      for (final f in state.files ?? const <FileItem>[]) f.id: f.encryptedName,
    };
    final pending = files
        .where(
          (f) =>
              (!state.decryptedNames.containsKey(f.id) ||
                  previousEncrypted[f.id] != f.encryptedName) &&
              f.encryptedName.isNotEmpty &&
              f.encryptedKey != null &&
              f.encryptedKey!.isNotEmpty,
        )
        .toList();
    if (pending.isEmpty) return;

    final privateKey = ref.read(decryptedPrivateKeyProvider);
    final wrappingPrivateKey = ref.read(decryptedWrappingPrivateKeyProvider);
    final workerManager = ref.read(workerManagerProvider);

    if (privateKey != null &&
        workerManager != null &&
        workerManager.decryptWorkerActive) {
      workerManager.onNamesDecrypted = (names, keys) {
        final mergedNames = {...state.decryptedNames, ...names};
        final mergedKeys = {...state.decryptedKeys, ...keys};
        state = state.copyWith(
          decryptedNames: mergedNames,
          decryptedKeys: mergedKeys,
        );
        _decryptThumbnails(pending);
      };
      workerManager.decryptNames(
        DecryptNamesCommand(
          privateKeyPem: privateKey,
          wrappingPrivateKeyPem: wrappingPrivateKey,
          files: pending
              .map(
                (f) => FileItemData(
                  id: f.id,
                  encryptedKey: f.encryptedKey!,
                  encryptedName: f.encryptedName,
                  cipher: f.cipher,
                ),
              )
              .toList(),
        ),
      );
      return;
    }

    final fileCrypto = ref.read(fileCryptoProvider);
    if (fileCrypto == null) {
      _log.warn('file crypto not available — cannot decrypt file names');
      return;
    }

    final names = {...state.decryptedNames};
    final keys = {...state.decryptedKeys};
    for (final file in pending) {
      try {
        final fileKey = fileCrypto.decryptFileKey(file.encryptedKey!);
        keys[file.id] = fileKey;
        names[file.id] = fileCrypto.decryptFileName(
          encryptedNameHex: file.encryptedName,
          fileKey: fileKey,
          cipher: file.cipher,
        );
      } catch (e) {
        _log.warn(
          'failed to decrypt file name',
          fields: {'file_id': file.id, 'error': redactException(e)},
        );
      }
    }
    state = state.copyWith(decryptedNames: names, decryptedKeys: keys);

    _decryptThumbnails(pending);
  }

  void _decryptThumbnails(List<FileItem> files) {
    final loader = ref.read(thumbnailLoaderProvider);

    for (final file in files) {
      if (state.decryptedThumbnails.containsKey(file.id)) continue;
      final fileKey = state.decryptedKeys[file.id];
      if (fileKey == null || !file.thumbnailAvailable) continue;

      // Each row resolves independently — from the loader's cache, the
      // offline store, or the thumbnail route — so thumbnails stream in
      // one by one instead of weighing down the listing itself.
      loader
          .loadBytes(file, fileKey)
          .then((bytes) {
            if (bytes == null) return;
            state = state.copyWith(
              decryptedThumbnails: {
                ...state.decryptedThumbnails,
                file.id: bytes,
              },
            );
          })
          .catchError((_) {});
    }
  }

  /// Re-read the set of offline file IDs from [OfflineManager] and
  /// update the state so pin indicators stay in sync with the cache.
  Future<void> refreshOfflineFileIds() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final offlineManager = ref.read(offlineManagerProvider);
    final ids = await offlineManager.getOfflineFileIds(account.id);
    state = state.copyWith(offlineFileIds: ids);
  }

  /// Store an already-decrypted display name — used after a rename
  /// locally so the new name appears immediately without a re-fetch.
  void updateDecryptedName(String fileId, String name) {
    final names = {...state.decryptedNames, fileId: name};
    state = state.copyWith(decryptedNames: names);
  }

  /// Mark an owned row as shared out so its "shared with" indicator shows at
  /// once, without waiting for a re-fetch. Bumps `sharedWithCount` to at least
  /// one (the row already lists at least the new recipient); the exact count is
  /// reconciled on the next load.
  void markFileSharedOut(String fileId) {
    final current = state.files;
    if (current == null) return;
    var changed = false;
    final updated = [
      for (final f in current)
        if (f.id == fileId && f.isOwner && (f.sharedWithCount ?? 0) == 0)
          () {
            changed = true;
            return f.copyWith(sharedWithCount: 1);
          }()
        else
          f,
    ];
    if (changed) state = state.copyWith(files: updated);
  }

  /// Clear an owned row's "shared with" indicator the moment its last recipient
  /// is revoked — the inverse of [markFileSharedOut]. Zeroes `sharedWithCount`
  /// so the glyph disappears at once; the exact count reconciles on next load.
  void markFileSharedInNone(String fileId) {
    final current = state.files;
    if (current == null) return;
    var changed = false;
    final updated = [
      for (final f in current)
        if (f.id == fileId && f.isOwner && (f.sharedWithCount ?? 0) > 0)
          () {
            changed = true;
            return f.copyWith(sharedWithCount: 0);
          }()
        else
          f,
    ];
    if (changed) state = state.copyWith(files: updated);
  }

  void enterSelectionMode(String fileId) {
    state = state.copyWith(
      selectionMode: true,
      selectedIds: {...state.selectedIds, fileId},
    );
  }

  void exitSelectionMode() {
    state = state.copyWith(selectionMode: false, selectedIds: {});
  }

  void toggleSelection(String fileId) {
    final next = {...state.selectedIds};
    if (next.contains(fileId)) {
      next.remove(fileId);
    } else {
      next.add(fileId);
    }
    state = state.copyWith(
      selectedIds: next,
      selectionMode: next.isEmpty ? false : state.selectionMode,
    );
  }

  void enterEmptySelectionMode() {
    state = state.copyWith(selectionMode: true);
  }

  void toggleSort(SortField field) {
    if (state.sortField == field) {
      state = state.copyWith(
        sortOrder: state.sortOrder == SortOrder.asc
            ? SortOrder.desc
            : SortOrder.asc,
      );
    } else {
      state = state.copyWith(sortField: field, sortOrder: SortOrder.asc);
    }
  }

  String _formatError(Object e) {
    return e.toString().replaceFirst('Exception: ', '');
  }
}

final filesNotifierProvider =
    NotifierProvider.family<FilesNotifier, FilesState, String?>(
      FilesNotifier.new,
    );
