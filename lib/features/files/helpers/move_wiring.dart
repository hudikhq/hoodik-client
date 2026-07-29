import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../shares/widgets/move_into_shared_confirm_dialog.dart';
import '../controllers/files_action_result.dart';
import '../controllers/files_mutation_controller.dart';
import '../providers/files_notifier.dart';
import '../providers/files_state.dart';
import '../widgets/folder_picker_dialog.dart';
import 'decrypt_name.dart';
import 'file_helpers.dart';

/// Glue between the files screen and [FilesMutationController.move]: turns a
/// folder-picker choice or a tree drop into the funnel's inputs (the moved
/// `FileItem`s, the destination row, the parent id) and adapts the cascade
/// preview to the confirm dialog. Kept out of the screen so it stays a thin
/// coordinator and the move plumbing lives next to the funnel.
class FileMoveCoordinator {
  FileMoveCoordinator({
    required this.ref,
    required this.dirId,
    required this.mutations,
  });

  final WidgetRef ref;

  /// The screen's current directory — the notifier scope whose listing and
  /// selection this move reads. The move-out classification keys on each moved
  /// item's own parent, not this, so a tree-view move out of a shared folder
  /// fires even when the screen sits at the root.
  final String? dirId;
  final FilesMutationController mutations;

  /// Show the move-to picker, then move the selection into the chosen folder
  /// (null = drive root). A dismissed picker or an empty selection returns an
  /// empty-message info result, which the screen renders as a silent no-op.
  Future<FilesActionResult> Function() pickAndMove(BuildContext context) {
    return () async {
      if (!mutations.isReady) return _noop;
      final state = ref.read(filesNotifierProvider(dirId));
      final selectedIds = state.selectedIds;
      final result = await showFolderPicker(
        context: context,
        client: ref.read(apiClientProvider)!,
        fileCrypto: ref.read(fileCryptoProvider),
        title: ambientL10n.filesMoveToTitle,
        confirmLabel: ambientL10n.filesMoveHere,
        excludeIds: selectedIds,
      );
      if (result == null || !context.mounted) return _noop;
      final sources = await _resolveSources(state, selectedIds);
      if (sources.isEmpty || !context.mounted) return _noop;
      return _move(
        context,
        state,
        sources: sources,
        destination: result.folder,
        destinationName: result.folderName ?? ambientL10n.filesYourDrive,
      );
    };
  }

  /// Move [ids] onto a tree drop target. The drop hands over only the target
  /// id, so its row is fetched to recover the share-state the funnel classifies
  /// on. A `null` target is the drive root — there's no row to fetch, so the
  /// move runs with a null destination (mirroring [pickAndMove]). A no-op drop
  /// (onto itself, nothing resolvable) returns the silent no-op result.
  Future<FilesActionResult> Function() dropMove(
    BuildContext context,
    List<String> ids,
    String? targetDirId,
  ) {
    return () async {
      if (targetDirId != null && ids.contains(targetDirId)) return _noop;
      final state = ref.read(filesNotifierProvider(dirId));
      final sources = await _resolveSources(state, ids);
      if (sources.isEmpty || !context.mounted) return _noop;
      FileItem? destination;
      if (targetDirId != null) {
        try {
          destination = FileItem.fromJson(
            await ref
                .read(apiClientProvider)!
                .files
                .getFileMetadata(targetDirId),
          );
        } catch (e) {
          return FilesActionResult.error(
            ambientL10n.filesMoveFailed(formatErrorMessage(e)),
          );
        }
        if (!context.mounted) return _noop;
      }
      return _move(
        context,
        state,
        sources: sources,
        destination: destination,
        destinationName: destination == null
            ? ambientL10n.filesYourDrive
            : _destinationName(state, destination),
      );
    };
  }

  /// The destination folder's plaintext name for the confirm copy. The current
  /// listing's decrypt cache covers a sibling destination, but a drop onto a
  /// folder outside it (e.g. a shared folder shown elsewhere) misses the cache
  /// and would surface "[Encrypted]". When the destination carries its own
  /// wrapped key and encrypted name, decrypt it on-device so the real name
  /// shows; fall back to the cache placeholder if decryption isn't possible.
  @visibleForTesting
  String destinationNameForConfirm(FilesState state, FileItem destination) =>
      _destinationName(state, destination);

  String _destinationName(FilesState state, FileItem destination) {
    final cached = state.decryptedNames[destination.id];
    if (cached != null) return cached;
    return decryptOwnName(ref.read(fileCryptoProvider), destination) ??
        state.displayName(destination);
  }

  /// Empty-message info: [FilesActionResult]'s "nothing to report" — the screen
  /// skips the toast for it, so a dismissed picker shows no message.
  static const _noop = FilesActionResult.info('');

  /// Drive [FilesMutationController.move]: the funnel reads [destination]'s
  /// share-state to classify the move, the moved items' own parent drives the
  /// move-*out* detection, and the confirm closure shows the folder-into-shared
  /// dialog only when the funnel reaches a cascade.
  Future<FilesActionResult> _move(
    BuildContext context,
    FilesState state, {
    required List<FileItem> sources,
    required FileItem? destination,
    required String destinationName,
  }) {
    return mutations.move(
      sources,
      destination: destination,
      confirm: (preview) => confirmMoveIntoSharedFolder(
        context: context,
        folderName: _confirmFolderName(sources, state.displayName),
        destinationName: destinationName,
        itemCount: preview.itemCount,
        members: preview.members,
      ),
    );
  }

  /// Resolve selected/dropped [ids] to `FileItem`s carrying their
  /// `is_owner`/`encrypted_key`/parent in id order. The active listing holds
  /// rows for the current directory; an id outside it (a nested tree selection
  /// shown under an expanded folder) is fetched from its metadata so a move
  /// initiated from the tree resolves the same as one from inside the folder.
  /// An id that resolves to neither (a stale selection after a concurrent
  /// change) is dropped rather than faked.
  Future<List<FileItem>> _resolveSources(
    FilesState state,
    Iterable<String> ids,
  ) async {
    final byId = {for (final f in state.files ?? const <FileItem>[]) f.id: f};
    final client = ref.read(apiClientProvider);
    final resolved = await Future.wait(
      ids.map((id) async {
        final local = byId[id];
        if (local != null) return local;
        if (client == null) return null;
        try {
          return FileItem.fromJson(await client.files.getFileMetadata(id));
        } catch (_) {
          // A row that can't be fetched (deleted out from under the selection)
          // is dropped rather than faked.
          return null;
        }
      }),
    );
    return resolved.whereType<FileItem>().toList();
  }

  /// The folder name for the confirm copy: the single moved folder's display
  /// name when exactly one folder is moved, else a neutral phrasing because the
  /// per-folder confirm can't be tied to one name from the preview alone.
  static String _confirmFolderName(
    List<FileItem> sources,
    String Function(FileItem) displayName,
  ) {
    final folders = sources.where((f) => f.isDir).toList();
    return folders.length == 1
        ? displayName(folders.first)
        : ambientL10n.filesTheseFolders;
  }
}
