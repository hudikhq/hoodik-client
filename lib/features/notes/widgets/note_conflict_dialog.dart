import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_scheme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Which side of a save collision the user chose to keep.
enum NoteConflictChoice {
  /// Throw away the local edits and take what the server already has.
  discardMine,

  /// Save over the newer version on the server.
  overwrite,
}

/// Asks which version of a note survives when a save collided with a newer
/// one on the server.
///
/// Returns null when the dialog is dismissed without a choice, which is not
/// the same as discarding: the draft stays exactly where it was and the user
/// can decide again on the next save.
Future<NoteConflictChoice?> showNoteConflictDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  return showDialog<NoteConflictChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.notesConflictTitle),
      content: Text(l10n.notesConflictBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, NoteConflictChoice.discardMine),
          child: Text(l10n.notesConflictDiscardMine),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: context.colors.textCrimson,
          ),
          onPressed: () => Navigator.pop(ctx, NoteConflictChoice.overwrite),
          child: Text(l10n.notesConflictOverwrite),
        ),
      ],
    ),
  );
}
