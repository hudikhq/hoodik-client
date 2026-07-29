import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/file_operations.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../files/controllers/files_action_result.dart';
import '../controllers/folder_relocation_controller.dart';
import '../controllers/folder_share_controller.dart'
    show FolderShareFailure, FolderShareOutcome;
import 'move_into_shared_cascade.dart';
import 'move_router.dart';

/// Executes a classified move. The funnel ([MoveRouter.classify]) decides the
/// route; this runs it: a plain `moveMany`, the per-item move-into-shared fan
/// (single-file vs folder cascade), or move-out. Kept out of
/// `FilesMutationController` so that controller stays a thin coordinator and the
/// per-member-wrap paths live next to the cascade service.
class MoveExecutor {
  MoveExecutor(this._ref);

  final Ref _ref;

  Future<FilesActionResult> run({
    required MoveDecision decision,
    required FileOperations ops,
    required List<FileItem> sources,
    required String? destinationId,
    Future<bool> Function(MoveCascadePreview preview)? confirm,
    void Function(int done, int total)? onProgress,
  }) async {
    return switch (decision) {
      PlainMove() => _plain(ops, sources, destinationId),
      BlockedMove(:final message) => FilesActionResult.error(message),
      MoveIntoShared(:final destinationFolderId) => _intoShared(
        sources,
        destinationFolderId,
        confirm: confirm,
        onProgress: onProgress,
      ),
      MoveOutOfShared(:final destinationFolderId) => _outOfShared(
        sources,
        destinationFolderId,
      ),
      SplitMove(
        :final plainSources,
        :final outSources,
        :final destinationFolderId,
      ) =>
        _split(ops, plainSources, outSources, destinationFolderId),
    };
  }

  Future<FilesActionResult> _plain(
    FileOperations ops,
    List<FileItem> sources,
    String? destinationId,
  ) async {
    await ops.moveMany(
      sources.map((f) => f.id).toList(),
      targetDirId: destinationId,
    );
    return _moved(sources.length);
  }

  /// Route each owned item individually: a non-directory through the single-file
  /// `moveIntoShared`, a directory through the cascade (which fires [confirm]
  /// before wrapping). The batch was guaranteed all-owned by [MoveRouter], so
  /// there is no partial-skip — the first failure aborts and surfaces.
  Future<FilesActionResult> _intoShared(
    List<FileItem> sources,
    String destinationFolderId, {
    Future<bool> Function(MoveCascadePreview preview)? confirm,
    void Function(int done, int total)? onProgress,
  }) async {
    final relocation = _ref.read(folderRelocationControllerProvider);
    final cascade = _ref.read(moveIntoSharedCascadeProvider);
    for (final item in sources) {
      final outcome = item.isDir
          ? await cascade.moveFolderIntoShared(
              folder: item,
              destinationFolderId: destinationFolderId,
              confirm: confirm,
              onProgress: onProgress,
            )
          : await relocation.moveIntoShared(
              file: item,
              destinationFolderId: destinationFolderId,
            );
      final blocked = _error(outcome);
      if (blocked != null) return blocked;
    }
    return _moved(sources.length);
  }

  Future<FilesActionResult> _outOfShared(
    List<FileItem> sources,
    String? destinationFolderId,
  ) async {
    final blocked = await _detachEach(sources, destinationFolderId);
    return blocked ?? _moved(sources.length);
  }

  /// A mixed private-destination batch. The plain relocation runs first because
  /// it is the reversible leg — a `moveMany` failure throws before anything is
  /// detached, so nothing half-moves. Only once it lands does the irreversible
  /// move-out fire (it drops the other members' rows); a later move-out failure
  /// surfaces its own message, the same per-item way the pure move-out path does.
  Future<FilesActionResult> _split(
    FileOperations ops,
    List<FileItem> plainSources,
    List<FileItem> outSources,
    String? destinationId,
  ) async {
    await ops.moveMany(
      plainSources.map((f) => f.id).toList(),
      targetDirId: destinationId,
    );
    final blocked = await _detachEach(outSources, destinationId);
    if (blocked != null) return blocked;
    return _moved(plainSources.length + outSources.length);
  }

  /// Move each item out of its shared scope in turn, returning the blocking
  /// result on the first failure or cancel, or null when every item detached.
  Future<FilesActionResult?> _detachEach(
    List<FileItem> sources,
    String? destinationFolderId,
  ) async {
    final cascade = _ref.read(moveIntoSharedCascadeProvider);
    for (final item in sources) {
      final blocked = _error(
        await cascade.moveOutOfShared(
          file: item,
          destinationFolderId: destinationFolderId,
        ),
      );
      if (blocked != null) return blocked;
    }
    return null;
  }

  FilesActionResult _moved(int count) =>
      FilesActionResult.success(ambientL10n.sharesMovedItems(count));

  /// Map a failed share outcome to a UI result, or null on success. An empty
  /// failure message is the cascade's "user cancelled the confirm" signal —
  /// surfaced as a no-op info rather than an error toast.
  FilesActionResult? _error(FolderShareOutcome outcome) {
    if (outcome is FolderShareFailure) {
      return outcome.message.isEmpty
          ? const FilesActionResult.info('')
          : FilesActionResult.error(outcome.message);
    }
    return null;
  }
}

final moveExecutorProvider = Provider<MoveExecutor>((ref) => MoveExecutor(ref));
