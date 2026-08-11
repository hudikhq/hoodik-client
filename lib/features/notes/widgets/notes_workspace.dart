import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/file_operations.dart' show SaveConflictException;
import '../../../core/services/transfer_manager.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../preview/providers/preview_loader.dart';
import '../../preview/widgets/preview_loading.dart';
import '../helpers/draft_capture.dart';
import '../models/editor_tab.dart';
import '../providers/open_note_request.dart';
import '../services/note_pdf_exporter.dart';
import 'ios_editor_layout.dart' show injectIosCaretInset;
import 'notes_main_area.dart';
import 'notes_sidebar.dart';
import 'recent_notes_panel.dart';
import 'unsaved_changes_dialog.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

const _log = Logger('NotesWorkspace');

/// Width of the inline sidebar panel on desktop.
const double _kSidebarWidth = 260;

/// Auto-save delay after the user stops editing.
const Duration _kAutoSaveDelay = Duration(seconds: 5);

/// Unified notes workspace — the full sidebar-tabs-editor layout used
/// by both the `/notes` landing route and the `/editor/:fileId` deep
/// link route.
///
/// When [initialFileId] is set (deep-link flow), the matching file is
/// opened as the first tab. When it's null (landing flow), the workspace
/// starts with no tabs and the main area shows a "recent notes" list as
/// the empty state.
class NotesWorkspace extends ConsumerStatefulWidget {
  final String? initialFileId;

  const NotesWorkspace({super.key, this.initialFileId});

  @override
  ConsumerState<NotesWorkspace> createState() => _NotesWorkspaceState();
}

class _NotesWorkspaceState extends ConsumerState<NotesWorkspace> {
  late final WebViewController _webViewController;
  bool _webViewContentLoaded = false;

  final List<EditorTab> _tabs = [];
  int _activeTabIndex = 0;

  /// Shared decrypted-name cache. The sidebar decrypts as it expands,
  /// the recent-notes panel has its own cache, and we seed here from
  /// the PreviewContext when arriving via deep-link.
  final Map<String, String> _seedNames = {};
  final Map<String, Uint8List> _seedKeys = {};

  bool _editorReady = false;

  /// Set when the workspace was seeded from the Files branch; closing the
  /// last tab then switches the shell back there instead of falling
  /// through to the recent-notes landing state.
  bool _returnToFilesOnLastClose = false;

  Timer? _autoSaveTimer;
  Completer<String>? _getMarkdownCompleter;

  bool get _hasTabs => _tabs.isNotEmpty;
  EditorTab get _activeTab => _tabs[_activeTabIndex];
  bool get _hasDirtyTab => _tabs.any((t) => t.isDirty);

  @override
  void initState() {
    super.initState();
    _initWebView();

    if (widget.initialFileId != null) {
      _seedInitialTab(widget.initialFileId!);
      _loadTab(_activeTab);
      // The request that seeded this workspace was set before the listener
      // below existed, so its origin flag has to be read directly.
      final req = ref.read(openNoteRequestProvider);
      _returnToFilesOnLastClose =
          req != null &&
          req.fileId == widget.initialFileId &&
          req.returnToFiles;
    }

    // Re-apply zoom to the webview whenever the host preference changes.
    ref.listenManual<double>(editorZoomProvider, (_, next) {
      if (_editorReady) _sendToEditor('setZoom', {'scale': next});
    });

    // Epoch guard: fires even when [fileId] is unchanged, which GoRouter
    // misses because the route URL stays the same.
    ref.listenManual<OpenNoteRequest?>(openNoteRequestProvider, (prev, next) {
      if (next == null) return;
      if (prev?.epoch == next.epoch) return;
      _openFromRequest(next);
    });

    // Seed the branch title from whatever tab we started with (or null
    // when launched from `/notes` with no initial file).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishBranchTitle();
    });
  }

  void _openFromRequest(OpenNoteRequest req) {
    if (req.returnToFiles) _returnToFilesOnLastClose = true;
    final existing = _tabs.indexWhere((t) => t.fileId == req.fileId);
    if (existing >= 0) {
      if (existing != _activeTabIndex) {
        setState(() => _activeTabIndex = existing);
        _publishBranchTitle();
      }
      return;
    }
    final ctx = ref.read(previewContextProvider);
    final file = ctx?.files.where((f) => f.id == req.fileId).firstOrNull;
    final key = ctx?.keys[req.fileId];
    final name = ctx?.names[req.fileId] ?? '';
    if (file != null && key != null) {
      _openNote(file, name, key);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_hasTabs &&
        _activeTabIndex < _tabs.length &&
        _activeTab.isDirty &&
        !_activeTab.isSaving) {
      _saveActiveContent();
    }
    // Clear our branch-title contribution so the shell falls back to
    // the "Notes" tab label once this workspace is gone.
    try {
      final notifier = ref.read(notesBranchTitleProvider.notifier);
      if (notifier.state != null) notifier.state = null;
    } catch (_) {
      // Container already disposed — nothing to clear.
    }
    super.dispose();
  }

  void _publishBranchTitle() {
    final next = _hasTabs ? _activeTab.fileName : null;
    final notifier = ref.read(notesBranchTitleProvider.notifier);
    if (notifier.state != next) notifier.state = next;
  }

  void _seedInitialTab(String fileId) {
    final ctx = ref.read(previewContextProvider);
    final file = ctx?.files.where((f) => f.id == fileId).firstOrNull;
    final name = ctx?.names[fileId] ?? '';
    final key = ctx?.keys[fileId];

    if (ctx != null) {
      _seedNames.addAll(ctx.names);
      _seedKeys.addAll(ctx.keys);
    }

    _tabs.add(
      EditorTab(fileId: fileId, fileName: name, file: file, fileKey: key),
    );
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'HoodikBridge',
        onMessageReceived: _onBridgeMessage,
      );

    if (!Platform.isMacOS) {
      _webViewController.setBackgroundColor(context.colors.canvas);
    }
  }

  Future<void> _ensureEditorHtmlLoaded() async {
    if (_webViewContentLoaded) return;
    _webViewContentLoaded = true;
    final html = await rootBundle.loadString('assets/editor/editor.html');
    await _webViewController.loadHtmlString(html, baseUrl: 'about:blank');
  }

  Future<void> _loadTab(EditorTab tab) async {
    if (tab.loading || tab.loaded) return;

    setState(() {
      tab.loading = true;
      tab.error = null;
    });

    final initialFile = tab.file;
    if (initialFile == null) {
      setState(() {
        tab.loading = false;
        tab.error = ambientL10n.notesFileNotFound;
      });
      return;
    }

    try {
      final refreshed = await _refreshFileMetadata(initialFile) ?? initialFile;
      tab.file = refreshed;

      // A note that never finished uploading has a DB entry but no
      // chunks on disk — the tar endpoint will return empty and the
      // extractor throws "extracted 0 chunks". Surface a readable state
      // instead. The file is orphaned until the user deletes it or the
      // background upload retries.
      if (refreshed.isUploading) {
        if (!mounted) return;
        setState(() {
          tab.loading = false;
          tab.error = ambientL10n.notesStillUploading;
        });
        return;
      }

      final bytes = await loadPreviewBytes(
        ref,
        refreshed,
        tab.fileKey,
        'md',
        displayName: tab.fileName,
      );

      if (!mounted) return;

      if (bytes == null) {
        setState(() {
          tab.loading = false;
          tab.error = ambientL10n.notesCannotDecrypt;
        });
        return;
      }

      String content;
      try {
        content = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        content = latin1.decode(bytes);
      }

      setState(() {
        tab.loadedContent = content;
        tab.loaded = true;
        tab.loading = false;
      });

      if (_hasTabs && identical(tab, _activeTab)) {
        if (_editorReady) {
          _pushActiveTabToEditor();
        } else {
          await _ensureEditorHtmlLoaded();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        tab.loading = false;
        tab.error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<FileItem?> _refreshFileMetadata(FileItem current) async {
    final client = ref.read(apiClientProvider);
    if (client == null) return null;
    try {
      final json = await client.files.getFileMetadata(current.id);
      return FileItem.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  void _pushActiveTabToEditor() {
    final tab = _activeTab;
    _sendToEditor('setContent', {'markdown': tab.currentContent});
    _sendToEditor('setEditable', {'editable': tab.editable});
  }

  /// At medium width and up the sidebar and tab strip show inline; below it
  /// the sidebar becomes a swipe-accessible drawer and the workspace runs a
  /// single-tab model.
  bool _isDesktopWidth() => isMediumWidth(context);

  /// Desktop: new tab (or focus existing). Mobile: replace current tab after
  /// a dirty check. No tabs: seed the first tab and load the webview HTML.
  Future<void> _openNote(FileItem file, String name, Uint8List fileKey) async {
    _seedNames[file.id] = name;
    _seedKeys[file.id] = fileKey;

    final existing = _tabs.indexWhere((t) => t.fileId == file.id);
    if (existing >= 0) {
      await _switchTab(existing);
      return;
    }

    if (!_hasTabs) {
      // First tab — set up state and trigger the HTML load.
      final newTab = EditorTab(
        fileId: file.id,
        fileName: name,
        file: file,
        fileKey: fileKey,
      );
      setState(() {
        _tabs.add(newTab);
        _activeTabIndex = 0;
      });
      await _loadTab(newTab);
      return;
    }

    if (!_isDesktopWidth()) {
      // Mobile single-tab model — replace current tab.
      if (_activeTab.isDirty && !_activeTab.isSaving) {
        final ok = await _confirmDiscardTab(_activeTab);
        if (!ok) return;
      }
      final newTab = EditorTab(
        fileId: file.id,
        fileName: name,
        file: file,
        fileKey: fileKey,
      );
      setState(() {
        _tabs[_activeTabIndex] = newTab;
      });
      await _loadTab(newTab);
      return;
    }

    // Desktop — spawn a new tab alongside the existing ones.
    final newTab = EditorTab(
      fileId: file.id,
      fileName: name,
      file: file,
      fileKey: fileKey,
    );

    await _captureActiveDraft();

    setState(() {
      _tabs.add(newTab);
      _activeTabIndex = _tabs.length - 1;
    });

    await _loadTab(newTab);

    if (_editorReady && newTab.loaded) {
      _pushActiveTabToEditor();
    }
  }

  Future<void> _switchTab(int index) async {
    if (index == _activeTabIndex) return;
    if (index < 0 || index >= _tabs.length) return;

    await _captureActiveDraft();
    _autoSaveTimer?.cancel();
    _getMarkdownCompleter = null;

    setState(() {
      _activeTabIndex = index;
    });

    final tab = _activeTab;
    if (!tab.loaded && !tab.loading) {
      await _loadTab(tab);
    } else if (_editorReady) {
      _pushActiveTabToEditor();
    }
  }

  Future<void> _captureActiveDraft() async {
    if (!_editorReady || !_hasTabs) return;
    await captureActiveDraft(() => _activeTab, _getMarkdown);
  }

  /// Remove the tab at [index] and shift the active index. Returns true
  /// when that was the last tab (the workspace is now empty).
  bool _removeTabAt(int index) {
    if (_tabs.length == 1) {
      setState(() {
        _tabs.clear();
        _activeTabIndex = 0;
      });
      return true;
    }

    int newActive = _activeTabIndex;
    if (index == _activeTabIndex) {
      newActive = index > 0 ? index - 1 : 0;
    } else if (index < _activeTabIndex) {
      newActive = _activeTabIndex - 1;
    }

    setState(() {
      _tabs.removeAt(index);
      _activeTabIndex = newActive.clamp(0, _tabs.length - 1);
    });
    return false;
  }

  /// A workspace seeded from Files hands control back on last-tab close;
  /// one opened from the Notes tab falls through to the recent-notes
  /// empty state instead.
  void _maybeReturnToFiles() {
    if (!_returnToFilesOnLastClose) return;
    _returnToFilesOnLastClose = false;
    ref.read(shellBranchRequestProvider.notifier).state = filesBranchIndex;
  }

  Future<void> _closeTab(int index) async {
    if (index < 0 || index >= _tabs.length) return;

    final tab = _tabs[index];
    if (tab.isDirty && !tab.isSaving) {
      final ok = await _confirmDiscardTab(tab);
      if (!ok) return;
    }

    if (_removeTabAt(index)) {
      _maybeReturnToFiles();
      return;
    }

    if (index <= _activeTabIndex) {
      final tab = _activeTab;
      if (!tab.loaded && !tab.loading) {
        await _loadTab(tab);
      } else if (_editorReady) {
        _pushActiveTabToEditor();
      }
    }
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type'] as String?) {
      case 'ready':
        _onEditorReady();
      case 'contentChanged':
        _onContentChanged(msg['isDirty'] as bool? ?? true);
      case 'saveRequested':
        _saveActiveContent();
      case 'markdownResult':
        _getMarkdownCompleter?.complete(msg['markdown'] as String? ?? '');
        _getMarkdownCompleter = null;
      case 'error':
        _log.warn(
          'editor bridge error',
          fields: {'error_message': msg['message']?.toString()},
        );
    }
  }

  void _onEditorReady() {
    setState(() => _editorReady = true);
    final zoom = ref.read(editorZoomProvider);
    if (zoom != 1.0) _sendToEditor('setZoom', {'scale': zoom});
    if (Platform.isIOS) injectIosCaretInset(_webViewController);
    if (_hasTabs && _activeTab.loaded) {
      _pushActiveTabToEditor();
    }
  }

  void _onContentChanged(bool isDirty) {
    if (!mounted || !_hasTabs) return;
    if (isDirty && !_activeTab.isDirty) {
      setState(() => _activeTab.isDirty = true);
    }
    if (_activeTab.isDirty) _resetAutoSaveTimer();
  }

  void _resetAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    if (!_hasTabs || !_activeTab.isDirty) return;
    _autoSaveTimer = Timer(_kAutoSaveDelay, () {
      if (mounted && _hasTabs && _activeTab.isDirty && !_activeTab.isSaving) {
        _saveActiveContent();
      }
    });
  }

  void _sendToEditor(String type, Map<String, dynamic> payload) {
    final msg = jsonEncode({'type': type, ...payload});
    _webViewController.runJavaScript(
      'window.hoodik.receiveMessage(${jsonEncode(msg)})',
    );
  }

  void _runCommand(String command, [dynamic payload]) {
    final msg = <String, dynamic>{'command': command};
    if (payload != null) msg['payload'] = payload;
    _sendToEditor('runCommand', msg);
  }

  Future<String> _getMarkdown() async {
    if (_getMarkdownCompleter != null) return _getMarkdownCompleter!.future;
    _getMarkdownCompleter = Completer<String>();
    _sendToEditor('getMarkdown', {'requestId': 'save'});

    return _getMarkdownCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _getMarkdownCompleter = null;
        throw TimeoutException('Editor did not respond');
      },
    );
  }

  Future<void> _saveActiveContent({bool force = false}) async {
    if (!_hasTabs) return;
    final tab = _activeTab;
    if (tab.isSaving || !_editorReady) return;

    final ops = ref.read(fileOperationsProvider);
    if (ops == null) return;

    setState(() => tab.isSaving = true);

    try {
      // When called from the conflict prompt with `force = true`, the
      // markdown is already in the draft buffer — re-fetching from the
      // webview would race with the user's next keystroke.
      final markdown = force && tab.draftContent != null
          ? tab.draftContent!
          : await _getMarkdown();
      await ops.updateNoteContent(tab.fileId, markdown, force: force);

      ref.read(previewCacheProvider).remove(tab.fileId);
      final account = ref.read(activeAccountProvider);
      if (account != null) {
        await ref
            .read(offlineManagerProvider)
            .removeCachedFile(account.id, tab.fileId);
      }

      if (!mounted) return;
      setState(() {
        tab.isDirty = false;
        tab.isSaving = false;
        tab.loadedContent = markdown;
        tab.draftContent = null;
      });
    } on SaveConflictException {
      if (!mounted) return;
      setState(() => tab.isSaving = false);
      await _promptResolveConflict();
    } catch (e) {
      if (!mounted) return;
      setState(() => tab.isSaving = false);
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).notesSaveFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _promptResolveConflict() async {
    final tab = _activeTab;
    final l10n = AppLocalizations.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notesConflictTitle),
        content: Text(l10n.notesConflictBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(l10n.notesConflictDiscardMine),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.textCrimson,
            ),
            onPressed: () => Navigator.pop(ctx, 'overwrite'),
            child: Text(l10n.notesConflictOverwrite),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'overwrite') {
      await _saveActiveContent(force: true);
    } else if (action == 'discard') {
      // Drop the dirty flag — next render of the tab will reload the
      // committed content from the server (whichever save wins).
      setState(() {
        tab.isDirty = false;
        tab.draftContent = null;
      });
    }
  }

  Future<void> _exportActiveAsPdf() async {
    if (!_hasTabs) return;
    final tab = _activeTab;
    if (!_editorReady) return;

    try {
      // Pull the live editor content rather than the last-saved snapshot
      // so the PDF reflects unsaved edits the user can still see on
      // screen — matches what the web export does.
      final markdown = await _getMarkdown();
      await exportNoteToPdf(markdown: markdown, fileName: tab.fileName);
    } catch (e) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).notesPdfExportFailed('$e'),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _openHistory() async {
    if (!_hasTabs) return;
    final tab = _activeTab;
    final restored = await context.push<bool>('/notes/${tab.fileId}/history');
    if (!mounted) return;
    if (restored == true) {
      // Active version flipped — drop our cached content and force the
      // editor to re-fetch the new active version.
      ref.read(previewCacheProvider).remove(tab.fileId);
      final account = ref.read(activeAccountProvider);
      if (account != null) {
        await ref
            .read(offlineManagerProvider)
            .removeCachedFile(account.id, tab.fileId);
      }
      if (!mounted) return;
      setState(() {
        tab.loaded = false;
        tab.loadedContent = null;
        tab.draftContent = null;
        tab.isDirty = false;
      });
      await _loadTab(tab);
    }
  }

  Future<bool> _confirmDiscardTab(EditorTab tab) async {
    if (!tab.isDirty) return true;

    final choice = await showUnsavedChangesDialog(context, tab.fileName);
    if (choice == UnsavedChangesChoice.save) {
      if (identical(tab, _activeTab)) {
        await _saveActiveContent();
      }
      return true;
    }
    return choice == UnsavedChangesChoice.discard;
  }

  Future<bool> _confirmDiscardAll() async {
    if (!_hasDirtyTab) return true;
    return _confirmDiscardTab(_activeTab);
  }

  void _handleNoteRenamed(String fileId, String newName) {
    if (!mounted) return;
    final idx = _tabs.indexWhere((t) => t.fileId == fileId);
    _seedNames[fileId] = newName;
    if (idx < 0) return;
    setState(() => _tabs[idx].fileName = newName);
  }

  void _handleNoteDeleted(String fileId) {
    if (!mounted) return;
    _seedNames.remove(fileId);
    _seedKeys.remove(fileId);
    final idx = _tabs.indexWhere((t) => t.fileId == fileId);
    if (idx < 0) return;

    _tabs[idx].isDirty = false;
    _tabs[idx].isSaving = false;

    if (_removeTabAt(idx)) return;

    if (idx <= _activeTabIndex + 1 && _editorReady) {
      final tab = _activeTab;
      if (tab.loaded) {
        _pushActiveTabToEditor();
      } else if (!tab.loading) {
        _loadTab(tab);
      }
    }
  }

  void _collapseSidebar() {
    ref.read(notesSidebarCollapsedProvider.notifier).state = true;
  }

  void _expandSidebar() {
    ref.read(notesSidebarCollapsedProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktopWidth();

    // Keep the shell's Notes-branch title in sync with whatever tab is
    // active (or clear when empty). Post-frame so we don't mutate the
    // provider during build; `_publishBranchTitle` dedupes no-ops.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishBranchTitle();
    });

    final sidebar = NotesSidebar(
      activeFileId: _hasTabs ? _activeTab.fileId : null,
      seedNames: _seedNames,
      seedKeys: _seedKeys,
      onSelectNote: _openNote,
      onNoteCreated: _openNote,
      onNoteRenamed: _handleNoteRenamed,
      onNoteDeleted: _handleNoteDeleted,
      // Desktop exposes an inline collapse affordance; mobile reaches
      // the sidebar via swipe only so there's no collapse button.
      onCollapse: isDesktop ? _collapseSidebar : null,
    );

    return PopScope(
      canPop: !_hasDirtyTab,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardAll();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          // Cmd+W on macOS, Ctrl+W on Linux/Windows — matches the
          // "close tab" convention across desktop browsers and IDEs.
          const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
              _closeActiveTabViaShortcut,
          const SingleActivator(LogicalKeyboardKey.keyW, control: true):
              _closeActiveTabViaShortcut,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            resizeToAvoidBottomInset: !Platform.isIOS,
            // Mobile uses the app bar + swipe-in drawer; desktop reclaims
            // the app-bar height by putting navigation inside the sidebar
            // and per-tab state in the tab bar.
            appBar: isDesktop ? null : _buildMobileAppBar(),
            drawer: isDesktop
                ? null
                : Drawer(width: 300, child: SafeArea(child: sidebar)),
            body: isDesktop ? _buildDesktopBody(sidebar) : _buildMobileBody(),
          ),
        ),
      ),
    );
  }

  void _closeActiveTabViaShortcut() {
    if (!_hasTabs) return;
    _closeTab(_activeTabIndex);
  }

  Widget _buildDesktopBody(Widget sidebar) {
    final collapsed = ref.watch(notesSidebarCollapsedProvider);

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: collapsed ? 0 : _kSidebarWidth,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: _kSidebarWidth,
              child: SizedBox(width: _kSidebarWidth, child: sidebar),
            ),
          ),
        ),
        Expanded(child: _buildMainArea(showTabs: true)),
      ],
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    if (!_hasTabs) {
      return AppBar(
        // Leave `leading` null so Scaffold auto-adds the hamburger for
        // the drawer. Users can also swipe from the left edge.
        title: Text(AppLocalizations.of(context).notesTitle),
      );
    }

    final tab = _activeTab;
    final saveWidget = tab.isSaving
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.iconEmber,
            ),
          )
        : tab.isDirty
        ? Icon(
            isApplePlatform ? CupertinoIcons.circle_fill : Icons.circle,
            size: 8,
            color: context.colors.iconEmber,
          )
        : null;

    // Leave `leading` null so Scaffold keeps the hamburger — the user
    // can open the sidebar drawer mid-edit to pick a different note
    // without first closing the current one. Closing happens via the
    // trailing X action instead.
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saveWidget != null) ...[saveWidget, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              tab.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (tab.isDirty && !tab.isSaving)
          TextButton(
            onPressed: _saveActiveContent,
            child: Text(AppLocalizations.of(context).commonSave),
          ),
        IconButton(
          icon: Icon(isApplePlatform ? CupertinoIcons.xmark : AppIcons.close),
          tooltip: AppLocalizations.of(context).notesCloseNote,
          onPressed: () => _closeTab(_activeTabIndex),
        ),
      ],
    );
  }

  Widget _buildMobileBody() => _buildMainArea(showTabs: false);

  /// Empty tabs → recent-notes panel; one or more tabs → editor chrome.
  Widget _buildMainArea({required bool showTabs}) {
    if (!_hasTabs) return RecentNotesPanel(onOpenNote: _openNote);
    final collapsed = showTabs
        ? ref.watch(notesSidebarCollapsedProvider)
        : false;
    return NotesMainArea(
      tabs: _tabs,
      activeTabIndex: _activeTabIndex,
      showTabs: showTabs,
      editorReady: _editorReady,
      editor: _buildEditorContent(),
      onSelectTab: _switchTab,
      onCloseTab: _closeTab,
      onExpandSidebar: collapsed ? _expandSidebar : null,
      onCommand: _runCommand,
      onHistory: _openHistory,
      onExportPdf: _exportActiveAsPdf,
      onHideKeyboard: _hideKeyboard,
    );
  }

  /// The WebView holds native focus while typing, so the keyboard drops by
  /// blurring the editor's active element, not by unfocusing Flutter nodes.
  void _hideKeyboard() => _webViewController.runJavaScript(
    'document.activeElement && document.activeElement.blur()',
  );

  Widget _buildEditorContent() {
    final tab = _activeTab;

    if (tab.loading || !tab.loaded) {
      final file = tab.file;
      if (file != null) {
        final manager = ref.watch(transferManagerProvider);
        final transfer = manager.transfers
            .where(
              (t) => t.fileId == file.id && t.status == TransferStatus.active,
            )
            .firstOrNull;

        return PreviewLoading(
          progress: transfer?.progress,
          stage: transfer?.type.label,
        );
      }
      return const PreviewLoading();
    }

    if (tab.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            tab.error!,
            style: TextStyle(color: context.colors.text, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return WebViewWidget(controller: _webViewController);
  }
}
