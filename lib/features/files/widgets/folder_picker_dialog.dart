import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/crypto/file_crypto.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Result of the folder picker dialog.
///
/// [folderId] is `null` when the user selected the root directory. [folder] is
/// the chosen directory's row (also null at root) — the move funnel reads its
/// `is_owner`/`members_signed_at` to decide whether the destination is shared,
/// and [folderName] is its already-decrypted name for the confirm copy, so the
/// caller needs neither a metadata fetch nor a second decrypt.
class FolderPickerResult {
  final String? folderId;
  final FileItem? folder;
  final String? folderName;
  const FolderPickerResult({this.folderId, this.folder, this.folderName});
}

/// Show a full-screen folder picker dialog.
///
/// Returns a [FolderPickerResult] with the chosen folder ID (`null` = root),
/// or `null` if the user cancelled.
///
/// Used for: move-to, upload-to, share-to flows.
Future<FolderPickerResult?> showFolderPicker({
  required BuildContext context,
  required ApiClient client,
  required FileCrypto? fileCrypto,
  String? title,
  String? confirmLabel,
  Set<String> excludeIds = const {},
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<FolderPickerResult>(
    context: context,
    builder: (ctx) => _FolderPickerDialog(
      client: client,
      fileCrypto: fileCrypto,
      title: title ?? l10n.filesChooseFolder,
      confirmLabel: confirmLabel ?? l10n.filesUploadHere,
      excludeIds: excludeIds,
    ),
  );
}

class _FolderPickerDialog extends StatefulWidget {
  final ApiClient client;
  final FileCrypto? fileCrypto;
  final String title;
  final String confirmLabel;
  final Set<String> excludeIds;

  const _FolderPickerDialog({
    required this.client,
    required this.fileCrypto,
    required this.title,
    required this.confirmLabel,
    required this.excludeIds,
  });

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  String? _currentDirId;

  /// The row for the directory currently being browsed (null at root), so the
  /// "confirm here" result can hand back the destination's share-state without
  /// a metadata fetch. Set when navigating into a folder and unwound when
  /// jumping back up the breadcrumbs.
  FileItem? _currentDir;
  List<FileItem> _dirs = [];
  final Map<String, String> _names = {};
  bool _loading = true;
  final List<_BreadcrumbEntry> _breadcrumbs = [
    _BreadcrumbEntry(id: null, name: ambientL10n.filesRootFolder, folder: null),
  ];

  @override
  void initState() {
    super.initState();
    _loadDirs();
  }

  Future<void> _loadDirs() async {
    setState(() => _loading = true);
    try {
      final resp = await widget.client.files.listFiles(dirId: _currentDirId);
      final dirs = resp.children
          .where((f) => f.isDir && !widget.excludeIds.contains(f.id))
          .toList();

      // Decrypt folder names.
      final fc = widget.fileCrypto;
      if (fc != null) {
        for (final d in dirs) {
          if (_names.containsKey(d.id)) continue;
          if (d.encryptedKey == null || d.encryptedKey!.isEmpty) continue;
          try {
            final key = fc.decryptFileKey(d.encryptedKey!);
            _names[d.id] = fc.decryptFileName(
              encryptedNameHex: d.encryptedName,
              fileKey: key,
              cipher: d.cipher,
            );
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _dirs = dirs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dirs = [];
          _loading = false;
        });
      }
    }
  }

  void _navigateInto(FileItem dir) {
    _breadcrumbs.add(
      _BreadcrumbEntry(
        id: dir.id,
        name: _names[dir.id] ?? dir.id.substring(0, 8),
        folder: dir,
      ),
    );
    _currentDirId = dir.id;
    _currentDir = dir;
    _loadDirs();
  }

  void _navigateToBreadcrumb(int index) {
    if (index >= _breadcrumbs.length - 1) return;
    _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
    _currentDirId = _breadcrumbs.last.id;
    _currentDir = _breadcrumbs.last.folder;
    _loadDirs();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                FolderPickerResult(
                  folderId: _currentDirId,
                  folder: _currentDir,
                  folderName: _currentDir == null
                      ? null
                      : _names[_currentDir!.id],
                ),
              ),
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
        body: Column(
          children: [
            // Breadcrumbs
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _breadcrumbs.length,
                separatorBuilder: (_, _) => const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: HoodikColors.brownish300,
                ),
                itemBuilder: (_, i) {
                  final isLast = i == _breadcrumbs.length - 1;
                  return Center(
                    child: GestureDetector(
                      onTap: isLast ? null : () => _navigateToBreadcrumb(i),
                      child: Text(
                        _breadcrumbs[i].name,
                        style: TextStyle(
                          color: isLast
                              ? HoodikColors.dirtyWhite
                              : HoodikColors.blueish300,
                          fontWeight: isLast
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Folder list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _dirs.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context).filesNoSubfolders,
                        style: const TextStyle(
                          color: HoodikColors.brownish300,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _dirs.length,
                      itemBuilder: (_, i) {
                        final dir = _dirs[i];
                        final name = _names[dir.id] ?? dir.id.substring(0, 8);
                        return ListTile(
                          leading: const Icon(
                            Icons.folder,
                            color: HoodikColors.orangy600,
                          ),
                          title: Text(name),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _navigateInto(dir),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbEntry {
  final String? id;
  final String name;

  /// The directory row for this crumb (null at root), retained so jumping back
  /// up the breadcrumbs restores the picker's notion of the current folder.
  final FileItem? folder;
  const _BreadcrumbEntry({
    required this.id,
    required this.name,
    required this.folder,
  });
}
