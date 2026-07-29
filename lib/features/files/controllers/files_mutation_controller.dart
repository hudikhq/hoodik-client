import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../shares/services/move_executor.dart';
import '../../shares/services/move_into_shared_cascade.dart';
import '../../shares/services/move_router.dart';
import '../helpers/file_helpers.dart';
import '../providers/files_notifier.dart';
import 'files_action_result.dart';

/// Handlers that mutate file/folder metadata: create folder, rename,
/// delete, move, pin/unpin, convert-to-note. The controller always
/// reloads the active directory after a successful change so the view
/// picks up server-side derivations (ordering, breadcrumb, timestamps).
class FilesMutationController {
  final Ref _ref;
  final String? _dirId;

  FilesMutationController(this._ref, this._dirId);

  /// `true` once [_ref] can resolve a live [FileOperations]; surfaced so
  /// the screen can pop a consistent error before starting a dialog.
  bool get isReady => _ref.read(fileOperationsProvider) != null;

  Future<FilesActionResult> createFolder(String trimmedName) async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailableNoKey);
    }
    try {
      await ops.createFolder(trimmedName, parentDirId: _dirId);
      await _notifier.load();
      return FilesActionResult.success(ambientL10n.filesFolderCreated);
    } catch (e) {
      return FilesActionResult.error(
        ambientL10n.filesCreateFolderFailed(formatErrorMessage(e)),
      );
    }
  }

  Future<FilesActionResult> rename(FileItem file, String trimmedName) async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }
    final fileKey = _ref
        .read(filesNotifierProvider(_dirId))
        .decryptedKeys[file.id];
    if (fileKey == null) {
      return FilesActionResult.error(ambientL10n.filesCannotDecryptKey);
    }

    try {
      await ops.rename(file, trimmedName, fileKey: fileKey);
      _notifier.updateDecryptedName(file.id, trimmedName);
      await _notifier.load();
      return FilesActionResult.success(ambientL10n.filesRenamed);
    } catch (e) {
      return FilesActionResult.error(
        ambientL10n.filesRenameFailed(formatErrorMessage(e)),
      );
    }
  }

  Future<FilesActionResult> delete(FileItem file) async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }
    try {
      await ops.delete(file.id);
      _cleanupOfflineCache([file.id]);
      await _notifier.load();
      return FilesActionResult.success(ambientL10n.filesDeleted);
    } catch (e) {
      return FilesActionResult.error(
        ambientL10n.filesDeleteFailed(formatErrorMessage(e)),
      );
    }
  }

  Future<FilesActionResult> deleteMany(List<String> ids) async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }
    try {
      await ops.deleteMany(ids);
      _cleanupOfflineCache(ids);
      _notifier.exitSelectionMode();
      await _notifier.load();
      return FilesActionResult.success(
        ambientL10n.filesDeletedCount(ids.length),
      );
    } catch (e) {
      return FilesActionResult.error(
        ambientL10n.filesDeleteFailed(formatErrorMessage(e)),
      );
    }
  }

  /// Move [sources] into [destination] (null = the account root). The funnel
  /// branches on the source/destination share-state via [MoveRouter]:
  ///
  /// * private → private (or root): the unchanged owner-only `moveMany`.
  /// * into a shared folder: owned single file → `moveIntoShared`; owned folder
  ///   → cascade; any non-owned item blocks the whole move (no partial).
  /// * out of a shared folder into a private one: owner-only move-out, routed
  ///   per item by its own parent — a tree selection mixing shared and private
  ///   parents splits, each item taking its parent's route.
  ///
  /// [confirm] is the cascade's pre-wrap gate (the folder-into-shared dialog);
  /// returning false aborts before any key is wrapped. [onProgress] reports
  /// cascade re-wrap progress.
  Future<FilesActionResult> move(
    List<FileItem> sources, {
    required FileItem? destination,
    Future<bool> Function(MoveCascadePreview preview)? confirm,
    void Function(int done, int total)? onProgress,
  }) async {
    final destId = destination?.id;
    if (destId != null && sources.any((f) => f.id == destId)) {
      return const FilesActionResult.info('');
    }
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }

    final sharingEnabled =
        _ref.read(shareCapabilitiesProvider).valueOrNull?.sharingEnabled ??
        false;
    final router = MoveRouter(
      files: _ref.read(apiClientProvider)!.files,
      sharingEnabled: sharingEnabled,
    );

    try {
      final decision = await router.classify(
        sources: sources,
        destination: destination,
      );
      final result = await _ref
          .read(moveExecutorProvider)
          .run(
            decision: decision,
            ops: ops,
            sources: sources,
            destinationId: destId,
            confirm: confirm,
            onProgress: onProgress,
          );
      // A blocked move never touched the server, so keep the selection for the
      // user to correct it; anything that actually ran reloads to reflect the
      // resulting state.
      if (decision is! BlockedMove) {
        _notifier.exitSelectionMode();
        await _notifier.load();
      }
      return result;
    } catch (e) {
      return FilesActionResult.error(
        ambientL10n.filesMoveFailed(formatErrorMessage(e)),
      );
    }
  }

  Future<FilesActionResult> convertToNote(FileItem file) async {
    final client = _ref.read(apiClientProvider);
    if (client == null) {
      return FilesActionResult.error(ambientL10n.filesNotAuthenticated);
    }
    try {
      await client.storage.setEditable(fileId: file.id, editable: true);
      await _notifier.load();
      return FilesActionResult.success(ambientL10n.filesConvertedToNote);
    } catch (e) {
      return FilesActionResult.error(
        ambientL10n.filesConvertFailed(formatErrorMessage(e)),
      );
    }
  }

  /// Pin [file] for offline access. If the file is already fully
  /// cached (`alreadyCached == true` from [OfflineManager.pinFile]),
  /// returns a success message immediately. Otherwise dispatches a
  /// background download through [FileOperations.downloadAndPinOffline]
  /// and returns `null` — the controller wires [onComplete]/[onError]
  /// so the caller gets a callback when the download finishes.
  Future<FilesActionResult?> makeAvailableOffline(
    FileItem file, {
    required void Function(FilesActionResult result) onComplete,
  }) async {
    final account = _ref.read(activeAccountProvider);
    if (account == null) return null;

    final displayName = _ref
        .read(filesNotifierProvider(_dirId))
        .displayName(file);
    final offlineManager = _ref.read(offlineManagerProvider);
    final alreadyCached = await offlineManager.pinFile(account.id, file.id);
    if (alreadyCached) {
      await _notifier.refreshOfflineFileIds();
      return FilesActionResult.success(
        ambientL10n.filesPinnedForOffline(displayName),
      );
    }

    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }

    ops.downloadAndPinOffline(
      file,
      displayName: displayName,
      onComplete: () async {
        await _notifier.refreshOfflineFileIds();
        onComplete(
          FilesActionResult.success(
            ambientL10n.filesAvailableOffline(displayName),
          ),
        );
      },
      onError: (error) {
        onComplete(
          FilesActionResult.error(
            ambientL10n.filesCacheFailed(formatErrorMessage(error)),
          ),
        );
      },
    );
    return FilesActionResult.info(ambientL10n.filesDownloadingForOffline);
  }

  Future<FilesActionResult?> removeOfflineCopy(FileItem file) async {
    final account = _ref.read(activeAccountProvider);
    if (account == null) return null;
    final offlineManager = _ref.read(offlineManagerProvider);
    await offlineManager.removeCachedFile(account.id, file.id);
    await _notifier.refreshOfflineFileIds();
    return FilesActionResult.success(ambientL10n.filesOfflineCopyRemoved);
  }

  void _cleanupOfflineCache(List<String> fileIds) {
    final account = _ref.read(activeAccountProvider);
    if (account == null) return;
    final offlineManager = _ref.read(offlineManagerProvider);
    for (final id in fileIds) {
      offlineManager.removeCachedFile(account.id, id);
    }
  }

  FilesNotifier get _notifier =>
      _ref.read(filesNotifierProvider(_dirId).notifier);
}

final filesMutationControllerProvider =
    Provider.family<FilesMutationController, String?>((ref, dirId) {
      return FilesMutationController(ref, dirId);
    });
