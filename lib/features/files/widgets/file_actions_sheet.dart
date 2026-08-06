import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../preview/providers/preview_providers.dart';
import '../../shares/shared_constants.dart';

/// Callbacks for file actions triggered from the bottom sheet.
class FileActionCallbacks {
  final void Function(FileItem file) onPreview;
  final void Function(FileItem file) onDownload;
  final void Function(FileItem file) onRename;
  final void Function(FileItem file) onDelete;
  final void Function(FileItem file) onCreateLink;

  /// Opens the share dialog. Optional so a caller that hasn't wired sharing
  /// yet simply omits the "Share" entry; [showFileActionsSheet] hides it when
  /// this is null.
  final void Function(FileItem file)? onShare;

  /// Recipient self-remove from a share. Optional like [onShare]: a caller that
  /// hasn't wired leaving omits the "Leave" entry; [showFileActionsSheet]
  /// hides it when this is null.
  final void Function(FileItem file)? onLeave;

  /// Save a shared file into the caller's own drive (fork). Optional like
  /// [onShare]: a caller that hasn't wired forking omits the "Save to my drive"
  /// entry; [showFileActionsSheet] hides it when this is null.
  final void Function(FileItem file)? onFork;
  final void Function(FileItem file) onMakeOffline;
  final void Function(FileItem file) onRemoveOffline;
  final void Function(FileItem file) onDetails;
  final void Function(FileItem file) onConvertToNote;
  final void Function(String fileId) onSelect;

  const FileActionCallbacks({
    required this.onPreview,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
    required this.onCreateLink,
    this.onShare,
    this.onLeave,
    this.onFork,
    required this.onMakeOffline,
    required this.onRemoveOffline,
    required this.onDetails,
    required this.onConvertToNote,
    required this.onSelect,
  });
}

/// One row in a sheet, platform-neutral. [sectionBreak] renders as a
/// divider (Material) or a plain action-list continuation (Cupertino,
/// where action sheets carry no separators).
class _SheetAction {
  const _SheetAction(
    this.label,
    this.icon,
    this.iconColor,
    this.onTap, {
    this.isDestructive = false,
    this.sectionBreak = false,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool sectionBreak;
}

/// Show the per-file action sheet: a Cupertino action sheet on Apple
/// platforms, a Material bottom sheet elsewhere. Both render the same
/// gated action list.
void showFileActionsSheet({
  required BuildContext context,
  required FileItem file,
  required String displayName,
  required bool isOffline,
  required FileActionCallbacks callbacks,
  bool sharingEnabled = false,
}) {
  // The "Shared with me" virtual folder is a navigation aid, not real content —
  // it has no per-file actions.
  if (file.id == sharedWithMeDirId) return;

  final l10n = AppLocalizations.of(context);
  final actions = <_SheetAction>[
    if (!file.isDir && isPreviewable(file))
      _SheetAction(
        l10n.filesPreview,
        Icons.visibility,
        HoodikColors.greeny400,
        () => callbacks.onPreview(file),
      ),
    if (!file.isDir && file.mime == 'text/markdown' && !file.editable)
      _SheetAction(
        l10n.filesConvertToNote,
        Icons.edit_note,
        HoodikColors.orangy400,
        () => callbacks.onConvertToNote(file),
      ),
    if (!file.isDir) ...[
      _SheetAction(
        l10n.filesExport,
        Icons.save_alt,
        HoodikColors.blueish300,
        () => callbacks.onDownload(file),
      ),
      if (isOffline)
        _SheetAction(
          l10n.filesRemoveOfflineCopy,
          Icons.cloud_off,
          HoodikColors.brownish200,
          () => callbacks.onRemoveOffline(file),
        )
      else
        _SheetAction(
          l10n.filesMakeAvailableOffline,
          Icons.cloud_download,
          HoodikColors.greeny400,
          () => callbacks.onMakeOffline(file),
        ),
    ],
    _SheetAction(
      l10n.commonRename,
      Icons.edit,
      HoodikColors.orangy400,
      () => callbacks.onRename(file),
    ),
    _SheetAction(
      l10n.commonDelete,
      Icons.delete_outline,
      HoodikColors.redish400,
      () => callbacks.onDelete(file),
      isDestructive: true,
    ),
    if (callbacks.onLeave != null &&
        canLeaveFile(file, sharingEnabled: sharingEnabled))
      _SheetAction(
        l10n.filesLeave,
        Icons.logout,
        HoodikColors.redish400,
        () => callbacks.onLeave!(file),
        isDestructive: true,
      ),
    if (file.isDir &&
        callbacks.onShare != null &&
        canShareFolder(file, sharingEnabled: sharingEnabled))
      _SheetAction(
        l10n.filesMembers,
        Icons.group_outlined,
        HoodikColors.greeny400,
        () => callbacks.onShare!(file),
      ),
    if (!file.isDir) ...[
      _SheetAction(
        l10n.filesCreateLink,
        Icons.link,
        HoodikColors.blueish400,
        () => callbacks.onCreateLink(file),
        sectionBreak: true,
      ),
      if (callbacks.onShare != null &&
          canShareFile(file, sharingEnabled: sharingEnabled))
        _SheetAction(
          l10n.commonShare,
          Icons.group_add_outlined,
          HoodikColors.greeny400,
          () => callbacks.onShare!(file),
        ),
      if (callbacks.onFork != null &&
          canFork(file, sharingEnabled: sharingEnabled))
        _SheetAction(
          l10n.filesSaveToMyDrive,
          Icons.drive_file_move_outline,
          HoodikColors.blueish300,
          () => callbacks.onFork!(file),
        ),
      _SheetAction(
        l10n.filesDetails,
        Icons.info_outline,
        HoodikColors.brownish100,
        () => callbacks.onDetails(file),
      ),
    ],
  ];

  _showActionSheet(context, title: displayName, actions: actions);
}

/// Show the FAB sheet, grouped into a Create section (folder, note) and an
/// Upload section (file, media, camera — the latter two hidden on desktop
/// platforms). On Apple the groups flatten into one action sheet, which is
/// the HIG idiom.
void showFabMenuSheet({
  required BuildContext context,
  required VoidCallback onCreateFolder,
  required VoidCallback onCreateNote,
  required VoidCallback onUploadFile,
  VoidCallback? onUploadPhoto,
  VoidCallback? onTakePhoto,
}) {
  final l10n = AppLocalizations.of(context);
  final actions = <_SheetAction>[
    _SheetAction(
      l10n.filesCreateFolder,
      Icons.create_new_folder,
      HoodikColors.orangy600,
      onCreateFolder,
    ),
    _SheetAction(
      l10n.notesNewNote,
      Icons.edit_note,
      HoodikColors.orangy400,
      onCreateNote,
    ),
    _SheetAction(
      l10n.filesUploadFile,
      Icons.upload_file,
      HoodikColors.blueish400,
      onUploadFile,
      sectionBreak: true,
    ),
    if (onUploadPhoto != null)
      _SheetAction(
        l10n.filesUploadMedia,
        Icons.photo_library,
        HoodikColors.greeny400,
        onUploadPhoto,
      ),
    if (onTakePhoto != null)
      _SheetAction(
        l10n.filesTakePhoto,
        Icons.camera_alt,
        HoodikColors.redish500,
        onTakePhoto,
      ),
  ];

  _showActionSheet(
    context,
    actions: actions,
    sectionHeaders: [l10n.commonCreate, l10n.commonUpload],
  );
}

void _showActionSheet(
  BuildContext context, {
  String? title,
  required List<_SheetAction> actions,
  List<String> sectionHeaders = const [],
}) {
  if (isApplePlatform) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title != null ? Text(title) : null,
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: () {
                Navigator.pop(ctx);
                action.onTap();
              },
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(ctx).commonCancel),
        ),
      ),
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var headerIndex = 0;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HoodikColors.brownish400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HoodikColors.dirtyWhite,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                for (final action in actions) ...[
                  if (action.sectionBreak && sectionHeaders.isEmpty)
                    const Divider(height: 1),
                  if (sectionHeaders.isNotEmpty &&
                      (identical(action, actions.first) || action.sectionBreak))
                    _sheetSectionHeader(sectionHeaders[headerIndex++]),
                  ListTile(
                    leading: Icon(action.icon, color: action.iconColor),
                    title: Text(action.label),
                    onTap: () {
                      Navigator.pop(ctx);
                      action.onTap();
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _sheetSectionHeader(String label) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: HoodikColors.brownish100,
        ),
      ),
    ),
  );
}
