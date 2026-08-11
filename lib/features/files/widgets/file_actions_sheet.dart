import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive_menu.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'file_menu_actions_builder.dart';

/// Show the per-file menu for [file].
///
/// [anchor] is the global point the gesture came from — a kebab, a
/// right-click, a long-press. Row taps have no anchor, and the platform
/// decides what that means: see [showAdaptiveMenu].
void showFileActionsSheet({
  required BuildContext context,
  required FileItem file,
  required String displayName,
  required bool isOffline,
  required FileMenuCallbacks callbacks,
  bool sharingEnabled = false,
  Offset? anchor,
}) {
  showAdaptiveMenu(
    context: context,
    title: displayName,
    anchor: anchor,
    actions: buildFileMenuActions(
      context: context,
      file: file,
      isOffline: isOffline,
      callbacks: callbacks,
      sharingEnabled: sharingEnabled,
    ),
  );
}

/// Show the create menu, grouped into a Create section (folder, note) and an
/// Upload section (file, media, camera — the latter two hidden on desktop).
/// [anchor] is where the trigger sits, so a pointer gets the menu under the
/// button it clicked.
void showFabMenuSheet({
  required BuildContext context,
  required VoidCallback onCreateFolder,
  required VoidCallback onCreateNote,
  required VoidCallback onUploadFile,
  VoidCallback? onUploadPhoto,
  VoidCallback? onTakePhoto,
  Offset? anchor,
}) {
  final l10n = AppLocalizations.of(context);

  showAdaptiveMenu(
    context: context,
    anchor: anchor,
    sectionHeaders: [l10n.commonCreate, l10n.commonUpload],
    actions: [
      AdaptiveMenuAction(
        label: l10n.filesCreateFolder,
        icon: Icons.create_new_folder,
        iconColor: context.colors.iconEmber,
        onTap: onCreateFolder,
      ),
      AdaptiveMenuAction(
        label: l10n.notesNewNote,
        icon: AppIcons.noteEdit,
        iconColor: context.colors.textEmber,
        onTap: onCreateNote,
      ),
      AdaptiveMenuAction(
        label: l10n.filesUploadFile,
        icon: AppIcons.cloudUpload,
        iconColor: context.colors.iconSlate,
        onTap: onUploadFile,
        sectionBreak: true,
      ),
      if (onUploadPhoto != null)
        AdaptiveMenuAction(
          label: l10n.filesUploadMedia,
          icon: Icons.photo_library,
          iconColor: context.colors.sageFill,
          onTap: onUploadPhoto,
        ),
      if (onTakePhoto != null)
        AdaptiveMenuAction(
          label: l10n.filesTakePhoto,
          icon: Icons.camera_alt,
          iconColor: context.colors.dangerFill,
          onTap: onTakePhoto,
        ),
    ],
  );
}
