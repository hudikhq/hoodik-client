import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/providers/files_notifier.dart';
import '../../files/widgets/file_dialogs.dart';
import '../../files/widgets/folder_picker_dialog.dart';
import '../../preview/providers/preview_providers.dart';
import '../providers/notes_sidebar_notifier.dart';
import 'new_folder_dialog.dart';
import 'new_note_dialog.dart';
import 'rename_note_dialog.dart';

/// True on platforms where touch is the primary interaction. On these, the
/// row's kebab button is always visible because there's no hover to reveal
/// it; on desktop it stays hidden until the user hovers the row.
bool get _isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Sidebar tree of folders and markdown notes.
///
/// Fetches and decrypts directory listings on demand. Non-markdown leaf
/// files are hidden — only folders (for navigation) and `.md` files show up.
/// Desktop-only; mobile hides the sidebar and opens notes in place.
class NotesSidebar extends ConsumerStatefulWidget {
  final String? activeFileId;

  /// Called when the user taps a note. The sidebar has already decrypted
  /// the name and symmetric key — it passes both up so the host doesn't
  /// have to decrypt again.
  final void Function(FileItem file, String name, Uint8List fileKey)
  onSelectNote;

  /// Called after the sidebar successfully creates a new note, with the
  /// new file's ID. The host typically opens it in a new tab.
  final void Function(FileItem file, String name, Uint8List fileKey)
  onNoteCreated;

  /// Seed the decrypted cache with names/keys the host already has (e.g.
  /// passed in via PreviewContext). Lets us highlight the active note in
  /// the tree without re-decrypting.
  final Map<String, String> seedNames;
  final Map<String, Uint8List> seedKeys;

  /// Close the editor screen entirely. Shown as the back button in the
  /// sidebar header when provided.
  final VoidCallback? onClose;

  /// Called after a note is renamed on the server so the host can update
  /// the matching tab's display name.
  final void Function(String fileId, String newName)? onNoteRenamed;

  /// Called after a note is deleted on the server so the host can close
  /// the matching tab if open.
  final void Function(String fileId)? onNoteDeleted;

  /// Collapse the sidebar out of view. Shown as a small chevron button
  /// in the sidebar header when provided. The host is responsible for
  /// re-expanding it (e.g. via a tab-bar button).
  final VoidCallback? onCollapse;

  const NotesSidebar({
    super.key,
    required this.activeFileId,
    required this.onSelectNote,
    required this.onNoteCreated,
    this.seedNames = const {},
    this.seedKeys = const {},
    this.onClose,
    this.onNoteRenamed,
    this.onNoteDeleted,
    this.onCollapse,
  });

  @override
  ConsumerState<NotesSidebar> createState() => _NotesSidebarState();
}

class _NotesSidebarState extends ConsumerState<NotesSidebar> {
  /// Dirs that are mid-fetch with a visible spinner (first-time load or
  /// after an explicit invalidation). Transient — not worth persisting.
  final Set<String?> _loading = {};

  /// Dirs that are being refreshed silently behind already-cached
  /// content. Tracked only to de-dupe concurrent refreshes; the UI
  /// doesn't show anything for these.
  final Set<String?> _refreshing = {};

  /// Root load error shown inline when the first fetch fails and we
  /// don't have any cached tree to fall back on.
  String? _rootError;

  NotesSidebarNotifier get _notifier =>
      ref.read(notesSidebarStateProvider.notifier);

  NotesSidebarState get _snapshot => ref.read(notesSidebarStateProvider);

  AppLocalizations get _l10n => AppLocalizations.of(context);

  void _notify(
    String message, {
    NotificationType type = NotificationType.error,
  }) {
    AppNotification.show(context, message: message, type: type);
  }

  @override
  void initState() {
    super.initState();
    // Provider writes during `initState` throw in Riverpod because the
    // widget tree is still being built. Defer all of our side-effecting
    // work to the next microtask — by then the first frame is in and
    // the notifier is safe to mutate.
    Future.microtask(() {
      if (!mounted) return;
      // Seed any decrypted names/keys the host already knows so the
      // first render can skip decryption for those files.
      _notifier.seed(names: widget.seedNames, keys: widget.seedKeys);

      final cached = _snapshot;
      if (!cached.hasRootCache) {
        // Cold start within this session — show a spinner while root
        // loads.
        _loadDirectory(null);
      } else {
        // Warm cache — render instantly, then kick off a silent refresh
        // of the root + every currently-expanded folder so we pick up
        // anything that changed since the user last visited.
        _refreshSilently(null);
        for (final dirId in cached.expanded) {
          _refreshSilently(dirId);
        }
      }
    });
  }

  Future<void> _loadDirectory(String? dirId) async {
    if (_loading.contains(dirId)) return;

    setState(() {
      _loading.add(dirId);
      if (dirId == null) _rootError = null;
    });

    try {
      final sync = ref.read(syncServiceProvider);
      final result = await sync.fetchFiles(dirId: dirId);
      _decryptChildren(result.files);

      if (!mounted) return;
      _notifier.setChildren(dirId, result.files);
      setState(() => _loading.remove(dirId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading.remove(dirId);
        if (dirId == null) _rootError = e.toString();
      });
    }
  }

  /// Re-fetch a directory whose children are already cached, without
  /// showing a loading spinner. The provider gets overwritten on
  /// success; errors are swallowed because the user is already looking
  /// at valid-enough data.
  Future<void> _refreshSilently(String? dirId) async {
    if (_refreshing.contains(dirId) || _loading.contains(dirId)) return;
    _refreshing.add(dirId);
    try {
      final sync = ref.read(syncServiceProvider);
      final result = await sync.fetchFiles(dirId: dirId);
      _decryptChildren(result.files);
      if (!mounted) return;
      _notifier.setChildren(dirId, result.files);
    } catch (_) {
      // Leave the stale-but-valid cache in place.
    } finally {
      _refreshing.remove(dirId);
    }
  }

  void _decryptChildren(List<FileItem> files) {
    final fileCrypto = ref.read(fileCryptoProvider);
    if (fileCrypto == null) return;

    final known = _snapshot.names;
    for (final f in files) {
      if (known.containsKey(f.id)) continue;
      if (f.encryptedKey == null || f.encryptedKey!.isEmpty) continue;
      try {
        final key = fileCrypto.decryptFileKey(f.encryptedKey!);
        final name = fileCrypto.decryptFileName(
          encryptedNameHex: f.encryptedName,
          fileKey: key,
          cipher: f.cipher,
        );
        _notifier.setDecrypted(f.id, name, key);
      } catch (_) {
        _notifier.setName(f.id, ambientL10n.notesEncryptedName);
      }
    }
  }

  void _toggleExpand(String dirId) {
    final current = _snapshot;
    final willExpand = !current.expanded.contains(dirId);
    _notifier.setExpanded(dirId, willExpand);
    if (willExpand) {
      if (!current.children.containsKey(dirId)) {
        _loadDirectory(dirId);
      } else {
        _refreshSilently(dirId);
      }
    }
  }

  void _handleNoteTap(FileItem file) {
    final snapshot = _snapshot;
    final name = snapshot.names[file.id] ?? '';
    final key = snapshot.keys[file.id];
    if (key == null) return;
    widget.onSelectNote(file, name, key);
  }

  Future<void> _handleRenameNote(FileItem file) async {
    final snapshot = _snapshot;
    final currentName = snapshot.names[file.id] ?? '';
    final key = snapshot.keys[file.id];
    if (key == null) return;

    final newName = await showRenameNoteDialog(
      context: context,
      currentName: currentName,
    );
    if (newName == null || newName.isEmpty) return;
    if (newName == currentName) return;

    // Preserve the `.md` extension unless the user typed another one.
    final effectiveName = newName.contains('.') ? newName : '$newName.md';

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    try {
      await ops.rename(file, effectiveName, fileKey: key);

      // Refresh the parent directory so the listing reflects the new name.
      final parentDir = file.fileId;
      _notifier
        ..setName(file.id, effectiveName)
        ..invalidateDir(parentDir);
      await _loadDirectory(parentDir);

      if (mounted) widget.onNoteRenamed?.call(file.id, effectiveName);
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesRenameFailed('$e'));
    }
  }

  Future<void> _handleDeleteNote(FileItem file) async {
    final name = _snapshot.names[file.id] ?? _l10n.notesThisNote;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n.notesDeleteNoteTitle),
        content: Text(_l10n.notesDeleteNoteBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: HoodikColors.textCrimson,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    try {
      await ops.delete(file.id);

      final parentDir = file.fileId;
      _notifier
        ..forgetFile(file.id)
        ..invalidateDir(parentDir);
      await _loadDirectory(parentDir);

      if (mounted) widget.onNoteDeleted?.call(file.id);
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesDeleteNoteFailed('$e'));
    }
  }

  /// Download + decrypt the note and hand it to the platform share sheet
  /// (mobile) or a save dialog (desktop). Mirrors the files-screen export
  /// flow without any of its bulk-selection plumbing.
  Future<void> _handleExportNote(FileItem file) async {
    final ops = ref.read(fileOperationsProvider);
    final key = _snapshot.keys[file.id];
    if (ops == null || key == null) return;
    final displayName = _snapshot.names[file.id] ?? 'note.md';
    final isMobile = Platform.isIOS || Platform.isAndroid;

    String savePath;
    if (isMobile) {
      final tmpDir = await getTemporaryDirectory();
      savePath = p.join(tmpDir.path, displayName);
    } else {
      final picked = await FilePicker.platform.saveFile(
        dialogTitle: _l10n.notesSaveNoteDialogTitle,
        fileName: displayName,
      );
      if (picked == null) return; // user dismissed the save dialog — cancel
      savePath = picked;
    }

    try {
      ops.downloadFileToDisk(
        file,
        fileKey: key,
        outputPath: savePath,
        displayName: displayName,
        onComplete: isMobile
            ? () async {
                final xFile = XFile(savePath, name: displayName);
                await Share.shareXFiles([xFile]);
                try {
                  await File(savePath).delete();
                } catch (_) {}
              }
            : null,
      );
      if (!mounted) return;
      _notify(
        isMobile ? _l10n.notesExportStarted : _l10n.notesExportingTo(savePath),
        type: NotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesExportFailed('$e'));
    }
  }

  void _handleShowDetails(FileItem file) {
    final displayName = _snapshot.names[file.id] ?? file.id;
    showFileDetailsDialog(
      context: context,
      file: file,
      displayName: displayName,
    );
  }

  /// Move a file or folder to a new parent via the folder-picker dialog,
  /// then refresh both the old and new parent directories so the tree
  /// reflects the move.
  Future<void> _handleMove(FileItem file) async {
    final client = ref.read(apiClientProvider);
    final fileCrypto = ref.read(fileCryptoProvider);
    if (client == null) return;

    final currentParent = file.fileId;
    final result = await showFolderPicker(
      context: context,
      client: client,
      fileCrypto: fileCrypto,
      title: _l10n.notesMoveToTitle,
      confirmLabel: _l10n.notesMoveHere,
      excludeIds: {file.id},
    );
    if (result == null) return;
    if (result.folderId == currentParent) return;

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    try {
      await ops.moveMany([file.id], targetDirId: result.folderId);
      _notifier
        ..invalidateDir(currentParent)
        ..invalidateDir(result.folderId);
      await Future.wait([
        _loadDirectory(currentParent),
        _loadDirectory(result.folderId),
      ]);
      if (!mounted) return;
      _notify(_l10n.notesMoved, type: NotificationType.success);
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesMoveFailed('$e'));
    }
  }

  void _handleFolderTap(FileItem dir) {
    _notifier.selectFolder(dir.id);
    _toggleExpand(dir.id);
  }

  String get _selectedFolderName {
    final snapshot = _snapshot;
    if (snapshot.selectedFolderId == null) return _l10n.notesRootName;
    return snapshot.names[snapshot.selectedFolderId] ?? _l10n.notesFolderName;
  }

  Future<void> _handleCreateFolder() async {
    final snapshot = _snapshot;
    final name = await showNewFolderDialog(
      context: context,
      parentFolderName: snapshot.selectedFolderId == null
          ? null
          : snapshot.names[snapshot.selectedFolderId],
    );
    if (name == null || name.isEmpty) return;

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    final targetDir = snapshot.selectedFolderId;

    try {
      await ops.createFolder(name, parentDirId: targetDir);

      // Reload and expand the target so the new folder is visible.
      _notifier.invalidateDir(targetDir);
      if (targetDir != null) _notifier.setExpanded(targetDir, true);
      await _loadDirectory(targetDir);
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesCreateFolderFailed('$e'));
    }
  }

  Future<void> _handleRenameFolder(FileItem folder) async {
    final snapshot = _snapshot;
    final currentName = snapshot.names[folder.id] ?? '';
    final key = snapshot.keys[folder.id];
    if (key == null) return;

    final newName = await showRenameNoteDialog(
      context: context,
      currentName: currentName,
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    try {
      await ops.rename(folder, newName, fileKey: key);

      final parentDir = folder.fileId;
      _notifier
        ..setName(folder.id, newName)
        ..invalidateDir(parentDir);
      await _loadDirectory(parentDir);
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesRenameFolderFailed('$e'));
    }
  }

  Future<void> _handleDeleteFolder(FileItem folder) async {
    final name = _snapshot.names[folder.id] ?? _l10n.notesThisFolder;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n.notesDeleteFolderTitle),
        content: Text(_l10n.notesDeleteFolderBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: HoodikColors.textCrimson,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    // Collect note IDs we know about under this folder so the host can
    // close the matching tabs. Unexpanded branches won't appear in
    // _children — any tabs from those will just fail to load on next
    // activation, which is acceptable since the user hasn't touched them.
    final affectedNoteIds = _collectDescendantNoteIds(folder.id);

    try {
      await ops.delete(folder.id);

      final parentDir = folder.fileId;
      _notifier
        ..removeSubtree(folder.id)
        ..invalidateDir(parentDir);
      await _loadDirectory(parentDir);

      if (!mounted) return;
      for (final noteId in affectedNoteIds) {
        widget.onNoteDeleted?.call(noteId);
      }
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesDeleteFolderFailed('$e'));
    }
  }

  /// Walk every cached descendant of [folderId] and return the IDs of
  /// markdown notes found. Used before a cascade delete so the host can
  /// close affected tabs.
  List<String> _collectDescendantNoteIds(String folderId) {
    final snapshot = _snapshot;
    final ids = <String>[];
    void walk(String? dirId) {
      final children = snapshot.children[dirId];
      if (children == null) return;
      for (final c in children) {
        if (c.isDir) {
          walk(c.id);
        } else {
          final name = snapshot.names[c.id] ?? '';
          if (getPreviewType(c.mime, fileName: name) == PreviewType.markdown) {
            ids.add(c.id);
          }
        }
      }
    }

    walk(folderId);
    return ids;
  }

  Future<void> _handleCreateNote() async {
    final snapshot = _snapshot;
    final name = await showNewNoteDialog(
      context: context,
      parentFolderName: snapshot.selectedFolderId == null
          ? null
          : snapshot.names[snapshot.selectedFolderId],
    );
    if (name == null || name.isEmpty) return;

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    final noteName = name.endsWith('.md') ? name : '$name.md';
    final targetDir = snapshot.selectedFolderId;

    // Seed with a heading matching the file name. The web app does the
    // same; an empty upload is rejected by the server validator (size=0).
    final displayTitle = noteName.replaceAll(
      RegExp(r'\.md$', caseSensitive: false),
      '',
    );
    final initialContent = '# $displayTitle\n';

    try {
      final newId = await ops.createNote(
        noteName,
        initialContent,
        parentDirId: targetDir,
      );

      // Reload the folder where we just created the note so the new entry
      // shows up. Expand it if it isn't root.
      _notifier.invalidateDir(targetDir);
      if (targetDir != null) _notifier.setExpanded(targetDir, true);
      await _loadDirectory(targetDir);
      // Mirror it into the Files list/grid so the new note appears there too.
      await ref.read(filesNotifierProvider(targetDir).notifier).load();

      // After reload, find the new file so we can pass its decrypted data
      // to the host.
      final after = _snapshot;
      final children = after.children[targetDir] ?? const <FileItem>[];
      final newFile = children.where((f) => f.id == newId).firstOrNull;
      final key = after.keys[newId];
      if (newFile != null && key != null && mounted) {
        widget.onNoteCreated(newFile, after.names[newId] ?? noteName, key);
      }
    } catch (e) {
      if (!mounted) return;
      _notify(_l10n.notesCreateNoteFailed('$e'));
    }
  }

  /// Flatten the currently-visible tree into a list of rows for ListView.
  List<_TreeRow> _flattenTree(NotesSidebarState snapshot) {
    final rows = <_TreeRow>[];

    void walk(String? dirId, int depth) {
      final children = snapshot.children[dirId];
      if (children == null) return;

      final sorted = [...children]
        ..sort((a, b) {
          if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
          final an = (snapshot.names[a.id] ?? '').toLowerCase();
          final bn = (snapshot.names[b.id] ?? '').toLowerCase();
          return an.compareTo(bn);
        });

      for (final c in sorted) {
        if (c.isDir) {
          rows.add(_TreeRow.folder(c, depth));
          if (snapshot.expanded.contains(c.id)) {
            walk(c.id, depth + 1);
          }
        } else {
          final name = snapshot.names[c.id] ?? '';
          if (getPreviewType(c.mime, fileName: name) == PreviewType.markdown) {
            rows.add(_TreeRow.note(c, depth));
          }
        }
      }
    }

    walk(null, 0);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(notesSidebarStateProvider);
    final rows = _flattenTree(snapshot);
    final rootLoading =
        _loading.contains(null) && snapshot.children[null] == null;

    return Container(
      decoration: const BoxDecoration(
        color: HoodikColors.brownish800,
        border: Border(
          right: BorderSide(color: HoodikColors.brownish600, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(
            selectedFolderName: _selectedFolderName,
            onCreateNote: _handleCreateNote,
            onCreateFolder: _handleCreateFolder,
            onClose: widget.onClose,
            onCollapse: widget.onCollapse,
          ),
          Expanded(
            child: rootLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _rootError != null
                ? _SidebarError(
                    message: _rootError!,
                    onRetry: () => _loadDirectory(null),
                  )
                : rows.isEmpty
                ? const _SidebarEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row.isFolder) {
                        return _FolderRow(
                          name: snapshot.names[row.file.id] ?? '…',
                          depth: row.depth,
                          isExpanded: snapshot.expanded.contains(row.file.id),
                          isSelected: snapshot.selectedFolderId == row.file.id,
                          isLoading: _loading.contains(row.file.id),
                          onTap: () => _handleFolderTap(row.file),
                          onRename: () => _handleRenameFolder(row.file),
                          onDelete: () => _handleDeleteFolder(row.file),
                          onMove: () => _handleMove(row.file),
                          onDetails: () => _handleShowDetails(row.file),
                        );
                      }
                      return _NoteRow(
                        name: snapshot.names[row.file.id] ?? '…',
                        depth: row.depth,
                        isActive: widget.activeFileId == row.file.id,
                        onTap: () => _handleNoteTap(row.file),
                        onRename: () => _handleRenameNote(row.file),
                        onDelete: () => _handleDeleteNote(row.file),
                        onExport: () => _handleExportNote(row.file),
                        onMove: () => _handleMove(row.file),
                        onDetails: () => _handleShowDetails(row.file),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TreeRow {
  final FileItem file;
  final int depth;
  final bool isFolder;

  const _TreeRow.folder(this.file, this.depth) : isFolder = true;
  const _TreeRow.note(this.file, this.depth) : isFolder = false;
}

class _SidebarHeader extends StatelessWidget {
  final String selectedFolderName;
  final VoidCallback onCreateNote;
  final VoidCallback onCreateFolder;
  final VoidCallback? onClose;
  final VoidCallback? onCollapse;

  const _SidebarHeader({
    required this.selectedFolderName,
    required this.onCreateNote,
    required this.onCreateFolder,
    this.onClose,
    this.onCollapse,
  });

  Future<void> _showCreateMenu(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final anchor = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
    );
    final position = RelativeRect.fromRect(
      Rect.fromPoints(anchor, anchor),
      Offset.zero & overlay.size,
    );

    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'note',
          child: Row(
            children: [
              const Icon(
                Icons.sticky_note_2_outlined,
                size: 16,
                color: HoodikColors.iconMuted,
              ),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).notesNewNote),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'folder',
          child: Row(
            children: [
              const Icon(
                Icons.create_new_folder_outlined,
                size: 16,
                color: HoodikColors.iconMuted,
              ),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context).notesNewFolder),
            ],
          ),
        ),
      ],
    );

    if (choice == 'note') onCreateNote();
    if (choice == 'folder') onCreateFolder();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Row(
        children: [
          if (onClose != null) ...[
            Tooltip(
              message: AppLocalizations.of(context).notesCloseEditor,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isApplePlatform
                        ? CupertinoIcons.chevron_left
                        : Icons.arrow_back,
                    size: 16,
                    color: HoodikColors.iconMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              AppLocalizations.of(context).notesSidebarHeader,
              style: const TextStyle(
                color: HoodikColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Builder(
            builder: (ctx) => Tooltip(
              message: AppLocalizations.of(ctx).notesNewIn(selectedFolderName),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showCreateMenu(ctx),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: HoodikColors.iconCrimson,
                  ),
                ),
              ),
            ),
          ),
          if (onCollapse != null)
            Tooltip(
              message: AppLocalizations.of(context).notesHideSidebar,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onCollapse,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.menu_open,
                    size: 16,
                    color: HoodikColors.iconMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatefulWidget {
  final String name;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final VoidCallback onDetails;

  const _FolderRow({
    required this.name,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onMove,
    required this.onDetails,
  });

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hovered = false;

  Future<void> _showContextMenu(Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );

    final l10n = AppLocalizations.of(context);
    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          child: _MenuRow(icon: Icons.edit, label: l10n.commonRename),
        ),
        PopupMenuItem<String>(
          value: 'move',
          child: _MenuRow(
            icon: Icons.drive_file_move_outline,
            label: l10n.commonMove,
          ),
        ),
        PopupMenuItem<String>(
          value: 'details',
          child: _MenuRow(icon: Icons.info_outline, label: l10n.notesDetails),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: _MenuRow(
            icon: Icons.delete_outline,
            label: l10n.commonDelete,
            color: HoodikColors.textCrimson,
          ),
        ),
      ],
    );

    if (!mounted) return;
    switch (choice) {
      case 'rename':
        widget.onRename();
      case 'move':
        widget.onMove();
      case 'details':
        widget.onDetails();
      case 'delete':
        widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chevron = isApplePlatform
        ? (widget.isExpanded
              ? CupertinoIcons.chevron_down
              : CupertinoIcons.chevron_right)
        : (widget.isExpanded ? Icons.expand_more : Icons.chevron_right);

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onSecondaryTapDown: (details) =>
              _showContextMenu(details.globalPosition),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: widget.onTap,
              child: Container(
                padding: EdgeInsets.only(
                  left: 8 + widget.depth * 14.0,
                  right: 4,
                  top: 5,
                  bottom: 5,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? HoodikColors.brownish700
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(chevron, size: 14, color: HoodikColors.iconMuted),
                    const SizedBox(width: 4),
                    Icon(
                      widget.isExpanded ? Icons.folder_open : Icons.folder,
                      size: 15,
                      color: HoodikColors.orangy400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Tooltip(
                        message: widget.name,
                        waitDuration: const Duration(milliseconds: 400),
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Fixed-width trailing slot so neither the loading
                    // spinner nor the hover-visible action button causes
                    // the row to reflow.
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Center(
                        child: widget.isLoading
                            ? const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              )
                            : _NoteRowActionButton(
                                visible:
                                    _hovered ||
                                    widget.isSelected ||
                                    _isTouchPlatform,
                                onTap: () {
                                  final renderBox =
                                      context.findRenderObject() as RenderBox?;
                                  final anchor =
                                      renderBox?.localToGlobal(
                                        renderBox.size.bottomRight(Offset.zero),
                                      ) ??
                                      Offset.zero;
                                  _showContextMenu(anchor);
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatefulWidget {
  final String name;
  final int depth;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onMove;
  final VoidCallback onDetails;

  const _NoteRow({
    required this.name,
    required this.depth,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onExport,
    required this.onMove,
    required this.onDetails,
  });

  @override
  State<_NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<_NoteRow> {
  bool _hovered = false;

  Future<void> _showContextMenu(Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );

    final l10n = AppLocalizations.of(context);
    final choice = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          child: _MenuRow(icon: Icons.edit, label: l10n.commonRename),
        ),
        PopupMenuItem<String>(
          value: 'export',
          child: _MenuRow(icon: Icons.save_alt, label: l10n.notesExport),
        ),
        PopupMenuItem<String>(
          value: 'move',
          child: _MenuRow(
            icon: Icons.drive_file_move_outline,
            label: l10n.commonMove,
          ),
        ),
        PopupMenuItem<String>(
          value: 'details',
          child: _MenuRow(icon: Icons.info_outline, label: l10n.notesDetails),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: _MenuRow(
            icon: Icons.delete_outline,
            label: l10n.commonDelete,
            color: HoodikColors.textCrimson,
          ),
        ),
      ],
    );

    if (!mounted) return;
    switch (choice) {
      case 'rename':
        widget.onRename();
      case 'export':
        widget.onExport();
      case 'move':
        widget.onMove();
      case 'details':
        widget.onDetails();
      case 'delete':
        widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onSecondaryTapDown: (details) =>
              _showContextMenu(details.globalPosition),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: widget.onTap,
              child: Container(
                padding: EdgeInsets.only(
                  left: 8 + widget.depth * 14.0 + 18,
                  right: 4,
                  top: 5,
                  bottom: 5,
                ),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? HoodikColors.brownish700
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 14,
                      color: widget.isActive
                          ? HoodikColors.iconCrimson
                          : HoodikColors.iconMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Tooltip(
                        message: widget.name,
                        waitDuration: const Duration(milliseconds: 400),
                        child: Text(
                          widget.name,
                          style: TextStyle(
                            color: widget.isActive
                                ? Colors.white
                                : HoodikColors.textMuted,
                            fontSize: 13,
                            fontWeight: widget.isActive
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Always in the tree so the row layout stays stable;
                    // Visibility hides the button without reclaiming its space.
                    _NoteRowActionButton(
                      visible: _hovered || widget.isActive || _isTouchPlatform,
                      onTap: () {
                        final renderBox =
                            context.findRenderObject() as RenderBox?;
                        final anchor =
                            renderBox?.localToGlobal(
                              renderBox.size.bottomRight(Offset.zero),
                            ) ??
                            Offset.zero;
                        _showContextMenu(anchor);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteRowActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool visible;

  const _NoteRowActionButton({required this.onTap, this.visible = true});

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Tooltip(
        message: AppLocalizations.of(context).notesMoreActions,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.more_horiz,
              size: 14,
              color: HoodikColors.iconMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + label row shared by the folder/note popup menus. Mirrors the
/// visual rhythm of the files-screen bottom sheet so the two menu
/// surfaces don't drift apart.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? HoodikColors.iconMuted),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}

class _SidebarError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SidebarError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 20,
            color: HoodikColors.iconCrimson,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.notesLoadFailed,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(color: HoodikColors.textMuted, fontSize: 11),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}

class _SidebarEmpty extends StatelessWidget {
  const _SidebarEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          AppLocalizations.of(context).notesSidebarEmpty,
          style: const TextStyle(color: HoodikColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
