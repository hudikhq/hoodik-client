import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../preview/providers/preview_providers.dart';
import '../../shares/services/incoming_shares.dart';
import '../../shares/shared_constants.dart';
import '../helpers/files_preview_navigation.dart';
import '../providers/files_notifier.dart';
import '../providers/files_state.dart';
import 'files_tree_rows.dart';

/// Recursive, lazy-loaded tree rooted at [rootDirId] (`null` = account
/// root). Folders expand in-place; every row — folder or file — routes
/// taps, context menus, and drag-and-drop back to the host.
///
/// This is a drop-in body for the files screen when the user picks
/// "Tree" from the view switcher. Owns its own expansion + decryption
/// cache, scoped to this subtree.
class FilesTreeView extends ConsumerStatefulWidget {
  final String? rootDirId;
  final String? activeFileId;

  /// When false the per-row share glyph is suppressed — mirrors the list and
  /// icon views so all three agree on when sharing context surfaces.
  final bool sharingEnabled;
  final void Function(FileItem file) onTapFile;
  final void Function(FileItem file, Offset globalPosition) onContextMenu;
  final Future<void> Function(List<String> ids, String? targetDirId) onMove;
  final List<String> Function(FileItem file) dragPayloadFor;
  final bool usesImmediateDrag;

  /// Callback that builds the drag feedback widget. We let the host own
  /// the visual so the list/icon/tree views all drag with identical
  /// feedback rather than duplicating the pill here.
  final Widget Function(int count, String? label) buildFeedback;

  const FilesTreeView({
    super.key,
    required this.rootDirId,
    required this.activeFileId,
    required this.sharingEnabled,
    required this.onTapFile,
    required this.onContextMenu,
    required this.onMove,
    required this.dragPayloadFor,
    required this.usesImmediateDrag,
    required this.buildFeedback,
  });

  @override
  ConsumerState<FilesTreeView> createState() => _FilesTreeViewState();
}

class _FilesTreeViewState extends ConsumerState<FilesTreeView> {
  /// Key `null` = the argument `rootDirId` (so `null` rows into this
  /// map mean "children of whatever root was passed in").
  final Map<String?, List<FileItem>> _children = {};
  final Set<String> _expanded = {};
  final Set<String?> _loading = {};
  final Map<String, String> _names = {};
  final Map<String, Uint8List> _keys = {};
  String? _rootError;

  @override
  void initState() {
    super.initState();
    _loadDirectory(widget.rootDirId);
  }

  Future<void> _loadDirectory(String? dirId) async {
    if (_loading.contains(dirId)) return;

    setState(() {
      _loading.add(dirId);
      if (dirId == widget.rootDirId) _rootError = null;
    });

    try {
      final files = await _fetchChildren(dirId);
      _decryptChildren(files);

      if (!mounted) return;
      setState(() {
        _children[dirId] = files;
        _loading.remove(dirId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading.remove(dirId);
        if (dirId == widget.rootDirId) _rootError = e.toString();
      });
    }
  }

  /// Fetch one directory's children, special-casing the synthetic "Shared with
  /// me" folder: its listing comes live from the incoming-shares endpoint (the
  /// server has no such directory), and the account root gains the synthetic
  /// folder when the caller has shares — mirroring the list view.
  Future<List<FileItem>> _fetchChildren(String? dirId) async {
    if (dirId == sharedWithMeDirId) {
      final client = ref.read(apiClientProvider);
      return client == null ? <FileItem>[] : fetchIncomingShareItems(client);
    }
    final result = await ref.read(syncServiceProvider).fetchFiles(dirId: dirId);
    if (dirId == null) return _withSharedWithMeRoot(result.files);
    return result.files;
  }

  Future<List<FileItem>> _withSharedWithMeRoot(List<FileItem> files) async {
    if (!widget.sharingEnabled) return files;
    final client = ref.read(apiClientProvider);
    if (client == null) return files;
    try {
      if (await hasIncomingShares(client)) {
        return [sharedWithMeFolder(), ...files];
      }
    } catch (_) {
      // Probe failure: omit the synthetic folder rather than block the listing.
    }
    return files;
  }

  void _decryptChildren(List<FileItem> files) {
    final fileCrypto = ref.read(fileCryptoProvider);
    if (fileCrypto == null) return;

    for (final f in files) {
      if (_names.containsKey(f.id)) continue;
      if (f.encryptedKey == null || f.encryptedKey!.isEmpty) continue;
      try {
        final key = fileCrypto.decryptFileKey(f.encryptedKey!);
        _keys[f.id] = key;
        _names[f.id] = fileCrypto.decryptFileName(
          encryptedNameHex: f.encryptedName,
          fileKey: key,
          cipher: f.cipher,
        );
      } catch (_) {
        _names[f.id] = ambientL10n.filesEncryptedFallback;
      }
    }
  }

  void _toggleExpand(String dirId) {
    final willExpand = !_expanded.contains(dirId);
    setState(() {
      if (willExpand) {
        _expanded.add(dirId);
      } else {
        _expanded.remove(dirId);
      }
    });
    if (willExpand && !_children.containsKey(dirId)) {
      _loadDirectory(dirId);
    }
  }

  /// Walk the currently-visible tree into a flat list of rows. Each
  /// row carries its depth so the builder can indent accordingly.
  List<_TreeRow> _flatten() {
    final rows = <_TreeRow>[];

    void walk(String? dirId, int depth) {
      final children = _children[dirId];
      if (children == null) return;

      final sorted = [...children]
        ..sort((a, b) {
          // Folders first, then alphabetical on decrypted name.
          if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
          final an = (_names[a.id] ?? '').toLowerCase();
          final bn = (_names[b.id] ?? '').toLowerCase();
          return an.compareTo(bn);
        });

      for (final f in sorted) {
        rows.add(_TreeRow(file: f, depth: depth));
        if (f.isDir && _expanded.contains(f.id)) {
          walk(f.id, depth + 1);
        }
      }
    }

    walk(widget.rootDirId, 0);
    return rows;
  }

  Widget _wrapDraggable({required FileItem file, required Widget child}) {
    final payload = widget.dragPayloadFor(file);
    final feedback = widget.buildFeedback(
      payload.length,
      payload.length == 1 ? _names[file.id] : null,
    );
    final ghost = Opacity(opacity: 0.4, child: child);

    if (widget.usesImmediateDrag) {
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
      onWillAcceptWithDetails: (d) => !d.data.contains(folder.id),
      onAcceptWithDetails: (d) => widget.onMove(d.data, folder.id),
      builder: (_, candidateData, _) {
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

  /// Route file taps using the tree's own caches — the host's tap handler
  /// only knows the root folder, so tapping a note in a nested folder
  /// there misses the file in `previewContextProvider`. Falls back to
  /// [widget.onTapFile] for selection-mode, non-previewable, and unknown
  /// states.
  void _onFileTap(FileItem f) {
    final FilesState hostState = ref.read(
      filesNotifierProvider(widget.rootDirId),
    );
    if (hostState.selectionMode) {
      widget.onTapFile(f);
      return;
    }

    final name = _names[f.id] ?? '';
    final parentId = f.fileId;
    final siblings = _children[parentId] ?? <FileItem>[f];

    if (isMarkdownFile(f, displayName: name)) {
      openEditor(
        context: context,
        ref: ref,
        file: f,
        siblings: siblings,
        names: _names,
        keys: _keys,
        parentDirId: parentId,
      );
      return;
    }

    if (isPreviewable(f)) {
      openPreview(
        context: context,
        ref: ref,
        file: f,
        siblings: siblings,
        names: _names,
        keys: _keys,
        parentDirId: parentId,
      );
      return;
    }

    widget.onTapFile(f);
  }

  /// Mirror an owner-side share that just happened in the list/grid view into
  /// the tree's own row cache, so the shared-out glyph appears here too without
  /// a manual refresh. The notifier holds the same root listing the tree shows;
  /// any cached row whose `sharedWithCount` flips on (and is still zero here)
  /// is patched in place.
  void _syncSharedOutFromNotifier(FilesState state) {
    final shared = {
      for (final f in state.files ?? const <FileItem>[])
        if (f.isOwner && (f.sharedWithCount ?? 0) > 0) f.id,
    };
    if (shared.isEmpty) return;
    var changed = false;
    _children.forEach((dirId, files) {
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        if (shared.contains(f.id) &&
            f.isOwner &&
            (f.sharedWithCount ?? 0) == 0) {
          files[i] = f.copyWith(sharedWithCount: 1);
          changed = true;
        }
      }
    });
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(filesNotifierProvider(widget.rootDirId), (_, next) {
      _syncSharedOutFromNotifier(next);
    });
    final rows = _flatten();
    final rootLoading =
        _loading.contains(widget.rootDirId) &&
        _children[widget.rootDirId] == null;

    if (rootLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rootError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: HoodikColors.redish400,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                _rootError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HoodikColors.dirtyWhite),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _loadDirectory(widget.rootDirId),
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).filesEmptyFolder,
            style: const TextStyle(color: HoodikColors.brownish100),
          ),
        ),
      );
    }

    final list = ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final f = row.file;
        final name = f.id == sharedWithMeDirId
            ? sharedWithMeDirName
            : (_names[f.id] ?? '…');
        final shareIcon = shareIndicatorIcon(
          f,
          sharingEnabled: widget.sharingEnabled,
        );

        Widget tile;
        if (f.isDir) {
          tile = TreeFolderRow(
            file: f,
            name: name,
            depth: row.depth,
            expanded: _expanded.contains(f.id),
            loading: _loading.contains(f.id),
            isActive: widget.activeFileId == f.id,
            shareIcon: shareIcon,
            onExpand: () => _toggleExpand(f.id),
            onTap: () => widget.onTapFile(f),
            onDoubleTap: () => _toggleExpand(f.id),
            onContextMenu: (pos) => widget.onContextMenu(f, pos),
          );
        } else {
          tile = TreeFileRow(
            file: f,
            name: name,
            depth: row.depth,
            isActive: widget.activeFileId == f.id,
            shareIcon: shareIcon,
            onTap: () => _onFileTap(f),
            onContextMenu: (pos) => widget.onContextMenu(f, pos),
          );
        }

        Widget wrapped = _wrapDraggable(file: f, child: tile);
        if (f.isDir) wrapped = _wrapDropTarget(folder: f, child: wrapped);
        return wrapped;
      },
    );

    // The whole list is a drop target for the account root, so an item can be
    // dragged out to the drive root (folder rows above capture drops into a
    // folder; anything dropped off a folder lands here).
    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => widget.onMove(d.data, widget.rootDirId),
      builder: (_, candidate, _) => ColoredBox(
        color: candidate.isNotEmpty
            ? HoodikColors.orangy500.withValues(alpha: 0.06)
            : Colors.transparent,
        child: list,
      ),
    );
  }
}

class _TreeRow {
  final FileItem file;
  final int depth;

  const _TreeRow({required this.file, required this.depth});
}
