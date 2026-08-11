import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../preview/providers/preview_providers.dart';
import '../../shares/shared_constants.dart';
import 'file_context_menu.dart';
import '../../../core/widgets/app_icons.dart';

/// Callbacks the menu-actions builder needs. Grouped so the call site
/// passes one object instead of a long parameter list.
class FileMenuCallbacks {
  final void Function(FileItem) onPreview;
  final void Function(FileItem) onConvertToNote;
  final void Function(FileItem) onDownload;
  final void Function(FileItem) onMakeOffline;
  final void Function(FileItem) onRemoveOffline;
  final void Function(FileItem) onRename;
  final void Function(FileItem) onDelete;
  final void Function(FileItem) onCreateLink;

  /// Opens the share dialog. Optional so a caller that hasn't wired sharing
  /// yet simply omits the "Share" entry; [buildFileMenuActions] hides it when
  /// this is null.
  final void Function(FileItem)? onShare;

  /// Recipient self-remove from a share. Optional like [onShare]: a caller that
  /// hasn't wired leaving omits the "Leave" entry; [buildFileMenuActions]
  /// hides it when this is null.
  final void Function(FileItem)? onLeave;

  /// Save a shared file into the caller's own drive (fork). Optional like
  /// [onShare]: a caller that hasn't wired forking omits the "Save to my drive"
  /// entry; [buildFileMenuActions] hides it when this is null.
  final void Function(FileItem)? onFork;
  final void Function(FileItem) onDetails;
  final void Function(FileItem) onSelect;

  const FileMenuCallbacks({
    required this.onPreview,
    required this.onConvertToNote,
    required this.onDownload,
    required this.onMakeOffline,
    required this.onRemoveOffline,
    required this.onRename,
    required this.onDelete,
    required this.onCreateLink,
    this.onShare,
    this.onLeave,
    this.onFork,
    required this.onDetails,
    required this.onSelect,
  });
}

/// Produce the ordered list of context-menu entries for [file]. Rules:
/// - Preview only for non-directory files that [isPreviewable].
/// - "Convert to note" shows only for non-editable markdown files.
/// - "Remove/Make Offline" toggles on [isOffline].
/// - "Share" only for owned non-directory files when [sharingEnabled]
///   ([canShareFile]); "Members" for sharable folders ([canShareFolder]),
///   both routed through [FileMenuCallbacks.onShare].
/// - "Leave" only for rows shared with the caller when [sharingEnabled]
///   ([canLeaveFile]).
/// - "Save to my drive" only for co-owned non-dir shares when [sharingEnabled]
///   ([canFork]).
/// - Links, details, and file-specific actions are hidden for folders.
List<FileMenuAction> buildFileMenuActions({
  required FileItem file,
  required bool isOffline,
  required FileMenuCallbacks callbacks,
  bool sharingEnabled = false,
}) {
  // The "Shared with me" virtual folder is a navigation aid, not real content —
  // it carries no rename/delete/details/share actions.
  if (file.id == sharedWithMeDirId) return const [];
  return [
    if (!file.isDir && isPreviewable(file))
      FileMenuAction(
        icon: AppIcons.preview,
        iconColor: HoodikColors.greeny400,
        label: ambientL10n.filesPreview,
        onTap: () => callbacks.onPreview(file),
      ),
    if (!file.isDir && file.mime == 'text/markdown' && !file.editable)
      FileMenuAction(
        icon: AppIcons.noteEdit,
        iconColor: HoodikColors.orangy400,
        label: ambientL10n.filesConvertToNote,
        onTap: () => callbacks.onConvertToNote(file),
      ),
    if (!file.isDir) ...[
      FileMenuAction(
        icon: AppIcons.download,
        iconColor: HoodikColors.blueish300,
        label: ambientL10n.filesExport,
        onTap: () => callbacks.onDownload(file),
      ),
      if (isOffline)
        FileMenuAction(
          icon: Icons.cloud_off,
          iconColor: HoodikColors.iconMuted,
          label: ambientL10n.filesRemoveOfflineCopy,
          onTap: () => callbacks.onRemoveOffline(file),
        )
      else
        FileMenuAction(
          icon: AppIcons.cloudDownload,
          iconColor: HoodikColors.greeny400,
          label: ambientL10n.filesMakeAvailableOffline,
          onTap: () => callbacks.onMakeOffline(file),
        ),
    ],
    FileMenuAction(
      icon: AppIcons.edit,
      iconColor: HoodikColors.orangy400,
      label: ambientL10n.commonRename,
      onTap: () => callbacks.onRename(file),
    ),
    FileMenuAction(
      icon: AppIcons.delete,
      iconColor: HoodikColors.iconCrimson,
      label: ambientL10n.commonDelete,
      onTap: () => callbacks.onDelete(file),
    ),
    if (callbacks.onLeave != null &&
        canLeaveFile(file, sharingEnabled: sharingEnabled))
      FileMenuAction(
        icon: AppIcons.signOut,
        iconColor: HoodikColors.iconCrimson,
        label: ambientL10n.filesLeave,
        onTap: () => callbacks.onLeave!(file),
      ),
    if (file.isDir &&
        callbacks.onShare != null &&
        canShareFolder(file, sharingEnabled: sharingEnabled))
      FileMenuAction(
        icon: AppIcons.members,
        iconColor: HoodikColors.greeny400,
        label: ambientL10n.filesMembers,
        onTap: () => callbacks.onShare!(file),
      ),
    if (!file.isDir) ...[
      FileMenuAction(
        icon: AppIcons.link,
        iconColor: HoodikColors.blueish400,
        label: ambientL10n.filesCreateLink,
        onTap: () => callbacks.onCreateLink(file),
      ),
      if (callbacks.onShare != null &&
          canShareFile(file, sharingEnabled: sharingEnabled))
        FileMenuAction(
          icon: AppIcons.memberAdd,
          iconColor: HoodikColors.greeny400,
          label: ambientL10n.commonShare,
          onTap: () => callbacks.onShare!(file),
        ),
      if (callbacks.onFork != null &&
          canFork(file, sharingEnabled: sharingEnabled))
        FileMenuAction(
          icon: AppIcons.move,
          iconColor: HoodikColors.blueish300,
          label: ambientL10n.filesSaveToMyDrive,
          onTap: () => callbacks.onFork!(file),
        ),
      FileMenuAction(
        icon: AppIcons.info,
        iconColor: HoodikColors.iconMuted,
        label: ambientL10n.filesDetails,
        onTap: () => callbacks.onDetails(file),
      ),
    ],
    FileMenuAction(
      icon: Icons.checklist,
      iconColor: HoodikColors.iconMuted,
      label: ambientL10n.filesSelect,
      onTap: () => callbacks.onSelect(file),
    ),
  ];
}
