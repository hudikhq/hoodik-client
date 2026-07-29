import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/hoodik_colors.dart';
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

/// Show a bottom sheet with actions for a single file.
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HoodikColors.dirtyWhite,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                if (!file.isDir && isPreviewable(file))
                  ListTile(
                    leading: const Icon(
                      Icons.visibility,
                      color: HoodikColors.greeny400,
                    ),
                    title: Text(l10n.filesPreview),
                    onTap: () {
                      Navigator.pop(ctx);
                      callbacks.onPreview(file);
                    },
                  ),
                if (!file.isDir &&
                    file.mime == 'text/markdown' &&
                    !file.editable)
                  ListTile(
                    leading: const Icon(
                      Icons.edit_note,
                      color: HoodikColors.orangy400,
                    ),
                    title: Text(l10n.filesConvertToNote),
                    onTap: () {
                      Navigator.pop(ctx);
                      callbacks.onConvertToNote(file);
                    },
                  ),
                if (!file.isDir) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.save_alt,
                      color: HoodikColors.blueish300,
                    ),
                    title: Text(l10n.filesExport),
                    onTap: () {
                      Navigator.pop(ctx);
                      callbacks.onDownload(file);
                    },
                  ),
                  if (isOffline)
                    ListTile(
                      leading: const Icon(
                        Icons.cloud_off,
                        color: HoodikColors.brownish200,
                      ),
                      title: Text(l10n.filesRemoveOfflineCopy),
                      onTap: () {
                        Navigator.pop(ctx);
                        callbacks.onRemoveOffline(file);
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(
                        Icons.cloud_download,
                        color: HoodikColors.greeny400,
                      ),
                      title: Text(l10n.filesMakeAvailableOffline),
                      onTap: () {
                        Navigator.pop(ctx);
                        callbacks.onMakeOffline(file);
                      },
                    ),
                ],
                ListTile(
                  leading: const Icon(
                    Icons.edit,
                    color: HoodikColors.orangy400,
                  ),
                  title: Text(l10n.commonRename),
                  onTap: () {
                    Navigator.pop(ctx);
                    callbacks.onRename(file);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: HoodikColors.redish400,
                  ),
                  title: Text(l10n.commonDelete),
                  onTap: () {
                    Navigator.pop(ctx);
                    callbacks.onDelete(file);
                  },
                ),
                if (callbacks.onLeave != null &&
                    canLeaveFile(file, sharingEnabled: sharingEnabled))
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: HoodikColors.redish400,
                    ),
                    title: Text(l10n.filesLeave),
                    onTap: () {
                      Navigator.pop(ctx);
                      callbacks.onLeave!(file);
                    },
                  ),
                if (file.isDir &&
                    callbacks.onShare != null &&
                    canShareFolder(file, sharingEnabled: sharingEnabled))
                  ListTile(
                    leading: const Icon(
                      Icons.group_outlined,
                      color: HoodikColors.greeny400,
                    ),
                    title: Text(l10n.filesMembers),
                    onTap: () {
                      Navigator.pop(ctx);
                      callbacks.onShare!(file);
                    },
                  ),
                if (!file.isDir) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.link,
                      color: HoodikColors.blueish400,
                    ),
                    title: Text(l10n.filesCreateLink),
                    onTap: () {
                      Navigator.pop(ctx);
                      callbacks.onCreateLink(file);
                    },
                  ),
                  if (callbacks.onShare != null &&
                      canShareFile(file, sharingEnabled: sharingEnabled))
                    ListTile(
                      leading: const Icon(
                        Icons.group_add_outlined,
                        color: HoodikColors.greeny400,
                      ),
                      title: Text(l10n.commonShare),
                      onTap: () {
                        Navigator.pop(ctx);
                        callbacks.onShare!(file);
                      },
                    ),
                  if (callbacks.onFork != null &&
                      canFork(file, sharingEnabled: sharingEnabled))
                    ListTile(
                      leading: const Icon(
                        Icons.drive_file_move_outline,
                        color: HoodikColors.blueish300,
                      ),
                      title: Text(l10n.filesSaveToMyDrive),
                      onTap: () {
                        Navigator.pop(ctx);
                        callbacks.onFork!(file);
                      },
                    ),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: HoodikColors.brownish100,
                    ),
                    title: Text(l10n.filesDetails),
                    onTap: () {
                      Navigator.pop(ctx);
                      callbacks.onDetails(file);
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

/// Show the FAB bottom sheet with Create Folder, Upload File, and optionally
/// Upload Media and Take Photo (hidden on desktop platforms).
void showFabMenuSheet({
  required BuildContext context,
  required VoidCallback onCreateFolder,
  required VoidCallback onUploadFile,
  VoidCallback? onUploadPhoto,
  VoidCallback? onTakePhoto,
}) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return SafeArea(
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
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.create_new_folder,
                color: HoodikColors.orangy600,
              ),
              title: Text(l10n.filesCreateFolder),
              onTap: () {
                Navigator.pop(ctx);
                onCreateFolder();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.upload_file,
                color: HoodikColors.blueish400,
              ),
              title: Text(l10n.filesUploadFile),
              onTap: () {
                Navigator.pop(ctx);
                onUploadFile();
              },
            ),
            if (onUploadPhoto != null)
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: HoodikColors.greeny400,
                ),
                title: Text(l10n.filesUploadMedia),
                onTap: () {
                  Navigator.pop(ctx);
                  onUploadPhoto();
                },
              ),
            if (onTakePhoto != null)
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: HoodikColors.redish500,
                ),
                title: Text(l10n.filesTakePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  onTakePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
