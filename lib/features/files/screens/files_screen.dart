import 'dart:async';
import 'dart:io' show Platform;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/app_update_nudge.dart';
import '../../../core/widgets/outdated_server_warning.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../notes/helpers/create_note_flow.dart';
import '../../preview/providers/preview_providers.dart';
import '../../shares/shared_constants.dart';
import '../helpers/fork_surface.dart';
import '../helpers/share_surface.dart';
import '../controllers/files_action_result.dart';
import '../controllers/files_download_controller.dart';
import '../controllers/files_link_controller.dart';
import '../controllers/files_mutation_controller.dart';
import '../controllers/files_share_controller.dart';
import '../controllers/files_upload_controller.dart';
import '../helpers/file_helpers.dart';
import '../helpers/file_name_validation.dart';
import '../helpers/files_preview_navigation.dart';
import '../helpers/move_wiring.dart';
import '../providers/files_notifier.dart';
import '../providers/files_state.dart';
import '../widgets/file_actions_sheet.dart';
import '../widgets/file_dialogs.dart';
import '../widgets/file_menu_actions_builder.dart';
import '../widgets/files_app_bar.dart';
import '../widgets/files_busy_overlay.dart';
import '../widgets/files_drop_overlay.dart';
import '../widgets/files_empty_state.dart';
import '../widgets/files_list.dart';
import '../../../core/widgets/adaptive.dart';

class FilesScreen extends ConsumerStatefulWidget {
  final String? dirId;

  /// Decrypted name of [dirId], handed over by the tap site. Null on the
  /// root listing and on cold deep-links, where the app bar falls back to
  /// the generic title.
  final String? dirName;

  const FilesScreen({super.key, this.dirId, this.dirName});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  bool _busy = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.load();
    });
  }

  @override
  void didUpdateWidget(FilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dirId != widget.dirId) {
      ref
          .read(filesNotifierProvider(oldWidget.dirId).notifier)
          .exitSelectionMode();
      _notifier.load();
    }
  }

  FilesNotifier get _notifier =>
      ref.read(filesNotifierProvider(widget.dirId).notifier);

  FilesUploadController get _uploads =>
      ref.read(filesUploadControllerProvider(widget.dirId));

  FilesDownloadController get _downloads =>
      ref.read(filesDownloadControllerProvider(widget.dirId));

  FilesMutationController get _mutations =>
      ref.read(filesMutationControllerProvider(widget.dirId));

  FilesLinkController get _links =>
      ref.read(filesLinkControllerProvider(widget.dirId));

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _loadFiles() => _notifier.load();

  Future<void> _createFolder() async {
    if (!_mutations.isReady) {
      _showSnack(_l10n.filesOpsUnavailableNoKey, NotificationType.error);
      return;
    }
    final name = await showTextInputDialog(
      context: context,
      title: _l10n.filesCreateFolder,
      hint: _l10n.filesFolderNameHint,
    );
    final validated = validateFileName(name);
    switch (validated) {
      case NameUnchanged():
        return;
      case NameInvalid(:final reason):
        _showSnack(reason, NotificationType.error);
        return;
      case NameOk(:final trimmed):
        await _runBusy(() => _mutations.createFolder(trimmed));
    }
  }

  Future<void> _uploadFile() async {
    final result = await _uploads.pickAndUploadFiles();
    if (result != null) _applyResult(result);
  }

  Future<void> _uploadPhoto() async {
    final result = await _uploads.pickAndUploadMedia();
    if (result != null) _applyResult(result);
  }

  Future<void> _takePhoto() async {
    final result = await _uploads.captureAndUploadPhoto();
    if (result != null) _applyResult(result);
  }

  Future<void> _uploadDroppedFiles(List<String> paths) async {
    final result = await _uploads.uploadPaths(paths);
    if (result != null) _applyResult(result);
  }

  Future<void> _downloadFile(FileItem file) async {
    final shareOrigin = shareOriginRect(context);
    final result = await _downloads.exportToDisk(
      file,
      shareOriginRect: shareOrigin,
    );
    if (result != null) _applyResult(result);
  }

  Future<void> _renameFile(FileItem file) async {
    if (!_mutations.isReady) {
      _showSnack(_l10n.filesOpsUnavailable, NotificationType.error);
      return;
    }
    final state = ref.read(filesNotifierProvider(widget.dirId));
    if (state.decryptedKeys[file.id] == null) {
      _showSnack(_l10n.filesCannotDecryptKey, NotificationType.error);
      return;
    }

    final currentName = state.displayName(file);
    final newName = await showTextInputDialog(
      context: context,
      title: _l10n.commonRename,
      hint: _l10n.filesNewNameHint,
      initialValue: currentName,
    );
    final validated = validateFileName(newName, current: currentName);
    switch (validated) {
      case NameUnchanged():
        return;
      case NameInvalid(:final reason):
        _showSnack(reason, NotificationType.error);
        return;
      case NameOk(:final trimmed):
        await _runBusy(() => _mutations.rename(file, trimmed));
    }
  }

  Future<void> _convertToNote(FileItem file) async {
    await _runBusy(() => _mutations.convertToNote(file));
  }

  Future<void> _deleteFile(FileItem file) async {
    if (!_mutations.isReady) return;
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: file.isDir
          ? _l10n.filesDeleteFolderTitle
          : _l10n.filesDeleteFileTitle,
      message: _l10n.filesDeleteConfirmMessage(
        ref.read(filesNotifierProvider(widget.dirId)).displayName(file),
      ),
    );
    if (confirmed != true) return;
    await _runBusy(() => _mutations.delete(file));
  }

  Future<void> _deleteSelected() async {
    if (!_mutations.isReady) return;
    final selectedIds = ref
        .read(filesNotifierProvider(widget.dirId))
        .selectedIds
        .toList();
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: _l10n.filesDeleteCountTitle(selectedIds.length),
      message: _l10n.filesCannotBeUndone,
    );
    if (confirmed != true) return;
    await _runBusy(() => _mutations.deleteMany(selectedIds));
  }

  Future<void> _createLink(FileItem file) async {
    setState(() => _busy = true);
    final outcome = await _links.createLink(file);
    if (!mounted) return;
    setState(() => _busy = false);

    if (outcome.error != null) {
      _applyResult(outcome.error!);
      return;
    }
    final link = outcome.link!;
    showLinkCreatedDialog(
      context: context,
      fileName: link.fileName,
      linkUrl: link.url,
      onSnack: _showSnack,
    );
  }

  Future<void> _makeAvailableOffline(FileItem file) async {
    final result = await _mutations.makeAvailableOffline(
      file,
      onComplete: _applyResult,
    );
    if (result != null) _applyResult(result);
  }

  Future<void> _removeOfflineCopy(FileItem file) async {
    final result = await _mutations.removeOfflineCopy(file);
    if (result != null) _applyResult(result);
  }

  FileMoveCoordinator get _moves =>
      FileMoveCoordinator(ref: ref, dirId: widget.dirId, mutations: _mutations);

  Future<void> _moveSelected() => _runBusy(_moves.pickAndMove(context));

  Future<void> _performMove(List<String> ids, String? targetDirId) =>
      _runBusy(_moves.dropMove(context, ids, targetDirId));

  void _openPreview(FileItem file) {
    // An in-progress upload has a DB entry but no chunks yet. Opening
    // it fires a tar download that the server can't fulfil (we've seen
    // "extracted 0 chunks from tar" on files stuck mid-upload). For
    // non-markdown files `isPreviewable` already filters these out —
    // the markdown path bypasses it and needs the same guard.
    if (file.isUploading) {
      _showSnack(_l10n.filesStillUploading, NotificationType.info);
      return;
    }

    final state = ref.read(filesNotifierProvider(widget.dirId));
    final siblings = state.files ?? const <FileItem>[];
    if (isMarkdownFile(file, displayName: state.displayName(file))) {
      openEditor(
        context: context,
        ref: ref,
        file: file,
        siblings: siblings,
        names: state.decryptedNames,
        keys: state.decryptedKeys,
        parentDirId: widget.dirId,
      );
      return;
    }
    openPreview(
      context: context,
      ref: ref,
      file: file,
      siblings: siblings,
      names: state.decryptedNames,
      keys: state.decryptedKeys,
      parentDirId: widget.dirId,
    );
  }

  /// Opens the create/upload sheet — the FAB's action, also offered by the
  /// empty state so a fresh folder doesn't depend on spotting the FAB.
  void _openCreateSheet([Offset? anchor]) {
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    showFabMenuSheet(
      context: context,
      anchor: anchor,
      onCreateFolder: _createFolder,
      onCreateNote: _createNote,
      onUploadFile: _uploadFile,
      onUploadPhoto: isDesktop ? null : _uploadPhoto,
      onTakePhoto: isDesktop ? null : _takePhoto,
    );
  }

  Future<void> _createNote() => createNoteAndOpen(
    context: context,
    ref: ref,
    parentDirId: widget.dirId,
    returnToFiles: true,
  );

  void _share(FileItem file) =>
      openShareSurface(context, ref, dirId: widget.dirId, file: file);

  void _fork(FileItem file) =>
      openForkSurface(context, ref, dirId: widget.dirId, file: file);

  void _showDetails(FileItem file) => showFileDetailsDialog(
    context: context,
    file: file,
    displayName: ref
        .read(filesNotifierProvider(widget.dirId))
        .displayName(file),
  );

  bool get _sharingEnabled =>
      ref.read(shareCapabilitiesProvider).valueOrNull?.sharingEnabled ?? false;

  Future<void> _leave(FileItem file) async {
    final confirmed = await confirmLeaveShare(
      context: context,
      displayName: ref
          .read(filesNotifierProvider(widget.dirId))
          .displayName(file),
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(filesShareControllerProvider(widget.dirId))
        .leaveShare(file);
    if (!mounted) return;
    if (outcome is ShareFailure) {
      AppNotification.show(
        context,
        message: outcome.message,
        type: NotificationType.error,
      );
    } else {
      await _notifier.load();
    }
  }

  FileMenuCallbacks get _menuCallbacks => FileMenuCallbacks(
    onPreview: _openPreview,
    onConvertToNote: _convertToNote,
    onDownload: _downloadFile,
    onMakeOffline: _makeAvailableOffline,
    onRemoveOffline: _removeOfflineCopy,
    onRename: _renameFile,
    onDelete: _deleteFile,
    onCreateLink: _createLink,
    onShare: _share,
    onLeave: _leave,
    onFork: _fork,
    onDetails: _showDetails,
    onSelect: (file) => _notifier.enterSelectionMode(file.id),
  );

  /// Open the file menu. [anchor] is the point the gesture came from — a
  /// kebab, right-click or long-press — and null for a row tap, which is
  /// what tells the platform layer whether a pointer menu is appropriate.
  void _showFileMenu(FileItem file, [Offset? anchor]) {
    if (_busy) return;
    final state = ref.read(filesNotifierProvider(widget.dirId));
    showFileActionsSheet(
      context: context,
      file: file,
      displayName: state.displayName(file),
      isOffline: state.offlineFileIds.contains(file.id),
      callbacks: _menuCallbacks,
      sharingEnabled: _sharingEnabled,
      anchor: anchor,
    );
  }

  void _onRowTap(FileItem file) {
    final state = ref.read(filesNotifierProvider(widget.dirId));
    if (state.selectionMode) {
      _notifier.toggleSelection(file.id);
    } else if (file.isDir) {
      context.push('/files/${file.id}', extra: state.displayName(file));
    } else if (isPreviewable(file)) {
      _openPreview(file);
    } else if (isTouchPlatform) {
      // A phone has no kebab-on-hover and no right-click, so the row itself
      // has to be the way in. On desktop both exist, and a click that opens
      // a menu the user didn't ask for is just noise.
      _showFileMenu(file);
    }
  }

  void _showSnack(
    String message, [
    NotificationType type = NotificationType.info,
  ]) {
    if (!mounted) return;
    AppNotification.show(context, message: message, type: type);
  }

  void _applyResult(FilesActionResult result) {
    if (result.message.isEmpty) return;
    _showSnack(result.message, result.type);
  }

  /// Run an async mutation inside a "busy" scope so the backdrop
  /// blocks stacking inputs while the operation is in flight.
  Future<void> _runBusy(Future<FilesActionResult> Function() task) async {
    setState(() => _busy = true);
    try {
      final result = await task();
      if (!mounted) return;
      _applyResult(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What this listing contributes to the window title: null on the root
  /// (the shell falls back to the branch label) and the decrypted folder
  /// name below it.
  String? get _branchTitle {
    if (widget.dirId == null) return null;
    if (widget.dirId == sharedWithMeDirId) return sharedWithMeDirName;
    return widget.dirName;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(filesNotifierProvider(widget.dirId));

    // Publish the visible folder to the window title. GoRouter rebuilds
    // the whole page stack on navigation, so the screen that ends up on
    // top always runs this last.
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      final title = _branchTitle;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(filesBranchTitleProvider.notifier);
        if (notifier.state != title) notifier.state = title;
      });
    }

    return Scaffold(
      appBar: FilesAppBar(
        dirId: widget.dirId,
        dirName: widget.dirName,
        selectionMode: state.selectionMode,
        selectionCount: state.selectedIds.length,
        busy: _busy,
        hasFiles: state.files != null && state.files!.isNotEmpty,
        isFromCache: state.isFromCache,
        sortField: state.sortField,
        sortOrder: state.sortOrder,
        onExitSelection: _notifier.exitSelectionMode,
        onMoveSelected: _moveSelected,
        onDeleteSelected: _deleteSelected,
        onEnterSelection: _notifier.enterEmptySelectionMode,
        onCreate: _openCreateSheet,
        onSortFieldSelected: _notifier.toggleSort,
      ),
      body: DropTarget(
        onDragDone: (detail) {
          final paths = detail.files
              .map((f) => f.path)
              .where((p) => p.isNotEmpty)
              .toList();
          if (paths.isNotEmpty) _uploadDroppedFiles(paths);
        },
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            Column(
              children: [
                const AppUpdateNudge(),
                const OutdatedServerWarning(),
                Expanded(child: _buildBody(state)),
              ],
            ),
            FilesBusyOverlay(busy: _busy),
            if (_isDragging) const FilesDropOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FilesState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return FilesErrorState(message: state.error!, onRetry: _loadFiles);
    }
    final files = state.files ?? [];
    if (files.isEmpty) return FilesEmptyState(onAdd: _openCreateSheet);

    return FilesList(
      dirId: widget.dirId,
      state: state,
      onRefresh: _loadFiles,
      onRowTap: _onRowTap,
      onToggleSelection: _notifier.toggleSelection,
      onContextMenu: _showFileMenu,
      onPerformMove: _performMove,
      onDelete: _deleteFile,
    );
  }
}
