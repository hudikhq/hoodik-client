import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/editor_tab.dart';
import 'notes_landing_app_bar.dart';

/// Mobile notes app bar: landing create-action, or the open-note title row
/// with save / find / close. Extracted from the workspace so that file stays
/// under its CI line cap.
class NotesMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NotesMobileAppBar({
    super.key,
    required this.hasTabs,
    this.tab,
    required this.onCreateNote,
    required this.onSave,
    required this.onClose,
    required this.onFind,
  });

  final bool hasTabs;
  final EditorTab? tab;
  final VoidCallback onCreateNote;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback onFind;

  @override
  Size get preferredSize => hasTabs
      ? const Size.fromHeight(kToolbarHeight)
      : const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    if (!hasTabs) {
      return NotesLandingAppBar(onCreateNote: onCreateNote);
    }
    final tab = this.tab!;
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
            onPressed: onSave,
            child: Text(AppLocalizations.of(context).commonSave),
          ),
        IconButton(
          icon: Icon(AppIcons.search),
          tooltip: AppLocalizations.of(context).notesFind,
          onPressed: onFind,
        ),
        IconButton(
          icon: Icon(isApplePlatform ? CupertinoIcons.xmark : AppIcons.close),
          tooltip: AppLocalizations.of(context).notesCloseNote,
          onPressed: onClose,
        ),
      ],
    );
  }
}
