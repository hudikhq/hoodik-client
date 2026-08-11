import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../shares/shared_constants.dart';
import '../providers/files_state.dart';
import 'file_grid_item.dart';
import 'file_list_item.dart';
import 'file_sort_controls.dart';
import 'files_drag_feedback.dart';
import 'files_tree_view.dart';
import '../../../core/widgets/app_icons.dart';

/// Renders the file listing for the active directory in whichever view
/// mode (list / icons / tree) the user picked. Owns the drag-and-drop
/// wrappers so every view uses the same payload + feedback visuals,
/// but leaves the actual mutations to the callbacks passed in.
class FilesList extends ConsumerWidget {
  final String? dirId;
  final FilesState state;
  final Future<void> Function() onRefresh;
  final void Function(FileItem file) onRowTap;
  final void Function(String fileId) onToggleSelection;
  final void Function(FileItem file, Offset pos) onContextMenu;
  final Future<void> Function(List<String> ids, String? targetDirId)
  onPerformMove;

  /// Swipe-to-delete on list rows (touch platforms only — desktop rows
  /// start an immediate drag on horizontal mouse movement, which would
  /// fight the swipe gesture).
  final void Function(FileItem file) onDelete;

  const FilesList({
    super.key,
    required this.dirId,
    required this.state,
    required this.onRefresh,
    required this.onRowTap,
    required this.onToggleSelection,
    required this.onContextMenu,
    required this.onPerformMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = state.files ?? [];
    final sorted = _pinSharedWithMe(
      sortFiles(
        files: files.where((f) => f.id != sharedWithMeDirId).toList(),
        field: state.sortField,
        order: state.sortOrder,
        displayName: state.displayName,
      ),
      files,
    );

    final viewMode = ref.watch(filesViewModeProvider);
    final sharingEnabled =
        ref.watch(shareCapabilitiesProvider).valueOrNull?.sharingEnabled ??
        false;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: switch (viewMode) {
        FilesViewMode.list => _buildListView(sorted, sharingEnabled),
        FilesViewMode.icons => _buildIconView(sorted, sharingEnabled),
        FilesViewMode.tree => _buildTreeView(sharingEnabled),
      },
    );
  }

  Widget _buildListView(List<FileItem> sorted, bool sharingEnabled) {
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final file = sorted[index];
        final tile = FileListItem(
          file: file,
          displayName: state.displayName(file),
          thumbnailBytes: state.decryptedThumbnails[file.id],
          isSelected: state.selectedIds.contains(file.id),
          isOffline: state.offlineFileIds.contains(file.id),
          selectionMode: state.selectionMode,
          sharingEnabled: sharingEnabled,
          onToggleSelection: () => onToggleSelection(file.id),
          onContextMenu: (pos) => onContextMenu(file, pos),
          onTap: () => onRowTap(file),
        );

        Widget row = _wrapDraggable(file: file, child: tile);
        if (file.isDir) {
          row = _wrapDropTarget(folder: file, child: row);
        }
        if (!_usesImmediateDrag &&
            !state.selectionMode &&
            file.id != sharedWithMeDirId) {
          row = _wrapSwipeToDelete(file: file, child: row);
        }
        return row;
      },
    );
  }

  /// Trailing swipe reveals delete; the row snaps back and the regular
  /// confirm flow takes over, so a swipe can never destroy silently.
  Widget _wrapSwipeToDelete({required FileItem file, required Widget child}) {
    return Dismissible(
      key: ValueKey('swipe-${file.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete(file);
        return false;
      },
      background: Container(
        color: HoodikColors.redish400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(AppIcons.delete, color: Colors.white),
      ),
      child: child,
    );
  }

  Widget _buildIconView(List<FileItem> sorted, bool sharingEnabled) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisExtent: 132,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final file = sorted[index];
        final tile = FileGridItem(
          file: file,
          displayName: state.displayName(file),
          thumbnailBytes: state.decryptedThumbnails[file.id],
          isSelected: state.selectedIds.contains(file.id),
          isOffline: state.offlineFileIds.contains(file.id),
          selectionMode: state.selectionMode,
          sharingEnabled: sharingEnabled,
          onTap: () => onRowTap(file),
          onToggleSelection: () => onToggleSelection(file.id),
          onContextMenu: (pos) => onContextMenu(file, pos),
        );

        Widget cell = _wrapDraggable(file: file, child: tile);
        if (file.isDir) cell = _wrapDropTarget(folder: file, child: cell);
        return cell;
      },
    );
  }

  Widget _buildTreeView(bool sharingEnabled) {
    return FilesTreeView(
      rootDirId: dirId,
      activeFileId: null,
      sharingEnabled: sharingEnabled,
      onTapFile: onRowTap,
      onContextMenu: onContextMenu,
      onMove: onPerformMove,
      dragPayloadFor: _dragPayloadFor,
      usesImmediateDrag: _usesImmediateDrag,
      buildFeedback: (count, label) =>
          FilesDragFeedback(count: count, label: label),
    );
  }

  /// Keep the synthetic "Shared with me" folder pinned at index 0 of the
  /// root listing regardless of the active sort — it's an injected affordance,
  /// not user content, so the sort field shouldn't bury it between owned
  /// folders that happen to alphabetize earlier.
  List<FileItem> _pinSharedWithMe(List<FileItem> sorted, List<FileItem> all) {
    final synthetic = all.where((f) => f.id == sharedWithMeDirId).firstOrNull;
    if (synthetic == null) return sorted;
    return [synthetic, ...sorted];
  }

  /// A dragged row carries every currently-selected id when the user
  /// drags something that is part of the selection; otherwise just the
  /// single file's id.
  List<String> _dragPayloadFor(FileItem file) {
    if (state.selectionMode && state.selectedIds.contains(file.id)) {
      return state.selectedIds.toList(growable: false);
    }
    return [file.id];
  }

  /// Desktop uses immediate-start drag (mouse) so dragging feels
  /// responsive; mobile uses a long-press so scroll gestures don't
  /// accidentally kick off a move.
  bool get _usesImmediateDrag =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Widget _wrapDraggable({required FileItem file, required Widget child}) {
    final payload = _dragPayloadFor(file);
    final feedback = FilesDragFeedback(
      count: payload.length,
      label: payload.length == 1 ? state.displayName(file) : null,
    );
    final ghost = Opacity(opacity: 0.4, child: child);

    if (_usesImmediateDrag) {
      return Draggable<List<String>>(
        data: payload,
        feedback: feedback,
        childWhenDragging: ghost,
        child: child,
      );
    }
    return LongPressDraggable<List<String>>(
      data: payload,
      feedback: feedback,
      childWhenDragging: ghost,
      delay: const Duration(milliseconds: 400),
      child: child,
    );
  }

  Widget _wrapDropTarget({required FileItem folder, required Widget child}) {
    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) => !details.data.contains(folder.id),
      onAcceptWithDetails: (details) => onPerformMove(details.data, folder.id),
      builder: (ctx, candidateData, _) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: hovering
                ? HoodikColors.orangy500.withValues(alpha: 0.12)
                : null,
            border: Border(
              left: BorderSide(
                color: hovering ? HoodikColors.orangy500 : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: child,
        );
      },
    );
  }
}
