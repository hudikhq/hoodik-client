import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../files/controllers/files_download_controller.dart';
import '../../files/helpers/files_preview_navigation.dart';
import '../../files/helpers/share_surface.dart';
import '../../files/widgets/file_dialogs.dart';
import '../../../core/widgets/adaptive_menu.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/thumbnail_loader.dart';
import '../../../core/utils/log_redact.dart';
import '../../../core/utils/logger.dart';
import '../../../core/workers/worker_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/helpers/file_helpers.dart';
import '../../files/widgets/file_list_item.dart';
import '../../preview/providers/preview_providers.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../core/theme/hoodik_scheme.dart';

const _log = Logger('SearchScreen');

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<FileItem>? _results;
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;

  final Map<String, String> _decryptedNames = {};
  final Map<String, Uint8List> _decryptedKeys = {};
  final Map<String, Uint8List?> _decryptedThumbnails = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Rebuild to show/hide the clear button.
  void _onTextChanged() => setState(() {});

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value.trim());
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    _search(value.trim());
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _hasSearched = false;
        _error = null;
      });
      return;
    }

    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    // An older server still holds the reversible digests this build cannot
    // produce, so its search would answer 200 with an empty list forever. Say
    // so instead: "no results" reads as "my files are gone".
    final liveness = ref.read(serverLivenessProvider).valueOrNull;
    if (liveness != null && liveness.isServerBelowClientMinimum) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).serverTooOldForSearch;
        _hasSearched = true;
      });
      return;
    }

    try {
      final fileCrypto = ref.read(fileCryptoProvider);
      if (fileCrypto == null) {
        throw StateError('Cannot search without an unlocked private key');
      }

      // The whole trimmed query rides along as one exact-match tag per
      // scope, which is what makes pasting a file's content digest find it —
      // through the ordinary index, with nothing plaintext on the wire.
      final exact = query.trim().toLowerCase();
      final rootKey = fileCrypto.searchRootKey;
      final results = await client.search.searchFiles(
        rootTags: [
          ...fileCrypto.queryTags(rootKey, query),
          fileCrypto.exactTag(rootKey, exact),
        ],
        fileTags: await ref
            .read(incomingSearchKeysProvider.future)
            .then(
              (keys) => keys.expand((key) {
                final fileKey = fileCrypto.searchFileKeyHex(key);
                return [
                  ...fileCrypto.queryTags(fileKey, query),
                  fileCrypto.exactTag(fileKey, exact),
                ];
              }).toList(),
            ),
      );
      if (!mounted) return;

      _decryptFileNames(results);

      setState(() {
        _results = results;
        _loading = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        // A 426 means this build cannot search this server at all, so say that
        // plainly instead of wrapping a transport error the user cannot act on.
        _error = isUpgradeRequired(e)
            ? l10n.searchRequiresUpdate
            : l10n.searchFailed(formatErrorMessage(e));
        _hasSearched = true;
      });
    }
  }

  /// Decrypt file names using the same pattern as FilesScreen.
  void _decryptFileNames(List<FileItem> files) {
    final pending = files
        .where(
          (f) =>
              !_decryptedNames.containsKey(f.id) &&
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
        if (mounted) {
          _decryptedNames.addAll(names);
          _decryptedKeys.addAll(keys);
          _decryptThumbnails(pending);
          setState(() {});
        }
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

    // Fallback: main-thread synchronous decryption.
    final fileCrypto = ref.read(fileCryptoProvider);
    if (fileCrypto == null) {
      _log.warn('file crypto not available — cannot decrypt file names');
      return;
    }

    for (final file in pending) {
      try {
        final fileKey = fileCrypto.decryptFileKey(file.encryptedKey!);
        _decryptedKeys[file.id] = fileKey;
        final name = fileCrypto.decryptFileName(
          encryptedNameHex: file.encryptedName,
          fileKey: fileKey,
          cipher: file.cipher,
        );
        _decryptedNames[file.id] = name;
      } catch (e) {
        _log.warn(
          'failed to decrypt file name',
          fields: {'file_id': file.id, 'error': redactException(e)},
        );
      }
    }

    _decryptThumbnails(pending);
  }

  void _decryptThumbnails(List<FileItem> files) {
    final loader = ref.read(thumbnailLoaderProvider);

    for (final file in files) {
      if (_decryptedThumbnails.containsKey(file.id)) continue;
      final fileKey = _decryptedKeys[file.id];
      if (fileKey == null || !file.thumbnailAvailable) continue;

      // Results stream in one by one; each completion repaints just the
      // affected row via setState.
      loader
          .loadBytes(file, fileKey)
          .then((bytes) {
            if (bytes == null || !mounted) return;
            setState(() => _decryptedThumbnails[file.id] = bytes);
          })
          .catchError((_) {});
    }
  }

  String _displayName(FileItem file) {
    final l10n = AppLocalizations.of(context);
    return _decryptedNames[file.id] ??
        (file.encryptedName.isNotEmpty
            ? l10n.searchEncryptedFileFallback(file.id.substring(0, 8))
            : l10n.commonUnknown);
  }

  void _onResultTap(FileItem file) {
    if (file.isDir) {
      context.push('/files/${file.id}', extra: _decryptedNames[file.id]);
      return;
    }

    // A note belongs in the editor, the same as it does from the file list.
    // The preview screen says so itself — markdown reaching it falls through
    // to the plain-text view as a safety net — and that is what a search
    // result got: the note's source, tags and all, with no way to edit it.
    if (isMarkdownFile(file, displayName: _displayName(file))) {
      openEditor(
        context: context,
        ref: ref,
        file: file,
        siblings: _results ?? const <FileItem>[],
        names: _decryptedNames,
        keys: _decryptedKeys,
        returnToBranchIndex: searchBranchIndex,
      );
      return;
    }

    if (isPreviewable(file)) {
      _openPreview(file);
    }
  }

  /// A search hit's own menu, rather than the file list's.
  ///
  /// Deliberately not the same set: the actions that mutate a listing —
  /// rename, delete, move — belong to the screen that shows that listing and
  /// can refresh it. What a search result needs is a way out of the search:
  /// to the file's folder, to its details, to sharing it, or to a copy on
  /// disk.
  Future<void> _showResultMenu(FileItem file, Offset anchor) async {
    final l10n = AppLocalizations.of(context);
    final name = _displayName(file);
    final sharingEnabled =
        ref.read(shareCapabilitiesProvider).valueOrNull?.sharingEnabled ??
        false;

    await showAdaptiveMenu(
      context: context,
      title: name,
      anchor: anchor,
      actions: [
        AdaptiveMenuAction(
          label: l10n.searchViewFolder,
          icon: AppIcons.folderOpen,
          iconColor: context.colors.iconSlate,
          onTap: () => _openContainingFolder(file),
        ),
        AdaptiveMenuAction(
          label: l10n.filesDetails,
          icon: AppIcons.info,
          iconColor: context.colors.iconMuted,
          onTap: () => showFileDetailsDialog(
            context: context,
            file: file,
            displayName: name,
          ),
        ),
        if (sharingEnabled && !file.isDir)
          AdaptiveMenuAction(
            label: l10n.commonShare,
            icon: AppIcons.memberAdd,
            iconColor: context.colors.sageFill,
            onTap: () =>
                openShareSurface(context, ref, dirId: file.fileId, file: file),
          ),
        if (!file.isDir)
          AdaptiveMenuAction(
            label: l10n.filesExport,
            icon: AppIcons.download,
            iconColor: context.colors.iconSlate,
            onTap: () => _export(file),
          ),
      ],
    );
  }

  /// Open the folder the file lives in. A file at the account root has no
  /// parent id, which is the root listing itself.
  void _openContainingFolder(FileItem file) {
    final parent = file.fileId;
    if (parent == null || parent.isEmpty) {
      // The account root is the Files branch's own route; there is no
      // '/files' without a folder id, and asking for one is a routing error.
      ref.read(shellBranchRequestProvider.notifier).state = filesBranchIndex;
      return;
    }

    context.push('/files/$parent');
  }

  Future<void> _export(FileItem file) async {
    final origin = shareOriginRect(context);
    final result = await ref
        .read(filesDownloadControllerProvider(file.fileId))
        .exportToDisk(
          file,
          shareOriginRect: origin,
          // Search decrypted these itself; the folder's listing may never
          // have been opened, so its caches are empty.
          key: _decryptedKeys[file.id],
          name: _displayName(file),
        );

    // Null means the user dismissed the desktop save dialog, which needs no
    // telling.
    if (!mounted || result == null || result.message.isEmpty) return;

    AppNotification.show(context, message: result.message, type: result.type);
  }

  void _openPreview(FileItem file) {
    final previewableFiles = (_results ?? [])
        .where((f) => isPreviewable(f))
        .toList();

    ref.read(previewContextProvider.notifier).state = PreviewContext(
      files: previewableFiles,
      names: Map.of(_decryptedNames),
      keys: Map.of(_decryptedKeys),
    );

    context.push('/preview/${file.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          // Override every state — the global inputDecorationTheme paints
          // a red focused outline + 14px vertical padding that doesn't
          // fit inside the compact AppBar.
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchHint,
            hintStyle: TextStyle(color: context.colors.textMuted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            isCollapsed: true,
          ),
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: context.colors.textCrimson),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.search,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).searchEmptyPrompt,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_results == null || _results!.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).searchNoResults,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _results!.length,
      itemBuilder: (context, index) {
        final file = _results![index];
        return FileListItem(
          file: file,
          displayName: _displayName(file),
          thumbnailBytes: _decryptedThumbnails[file.id],
          isSelected: false,
          isOffline: false,
          selectionMode: false,
          onToggleSelection: () {},
          onContextMenu: (pos) => _showResultMenu(file, pos),
          onTap: () => _onResultTap(file),
        );
      },
    );
  }
}
