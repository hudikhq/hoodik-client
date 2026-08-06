import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

enum UnsavedChangesChoice { cancel, discard, save }

/// Three-way prompt shown before closing a dirty note tab.
Future<UnsavedChangesChoice> showUnsavedChangesDialog(
  BuildContext context,
  String fileName,
) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showDialog<UnsavedChangesChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.notesUnsavedChangesTitle(fileName)),
      content: Text(l10n.notesUnsavedChangesBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChangesChoice.cancel),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: HoodikColors.redish400),
          onPressed: () => Navigator.pop(ctx, UnsavedChangesChoice.discard),
          child: Text(l10n.notesDiscard),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChangesChoice.save),
          child: Text(l10n.notesSaveAndClose),
        ),
      ],
    ),
  );
  return choice ?? UnsavedChangesChoice.cancel;
}
