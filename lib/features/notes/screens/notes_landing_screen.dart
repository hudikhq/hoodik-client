import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../helpers/create_note_flow.dart';
import '../widgets/notes_workspace.dart';

/// `/notes` landing route — shows the unified notes workspace with no
/// initial tab. The workspace itself renders the "recent notes" panel
/// as its empty state.
///
/// Accepts `?open=<fileId>` so deep links from other screens (notably
/// the files list when tapping a `.md` file) can seed the workspace
/// with a specific note as the first tab.
///
/// On mobile we overlay a FAB for creating a new note while the
/// recent-notes panel is showing. Once a note is open the FAB hides —
/// it would otherwise sit on top of the editor toolbar / content. The
/// FAB-vs-editor decision lives in [NotesLandingChrome] so a widget
/// test can drive it without mounting the full workspace.
///
/// Desktop doesn't get a FAB at all — the sidebar is always visible
/// there and already has its own "new" control in the kebab menu.
class NotesLandingScreen extends ConsumerWidget {
  final String? initialFileId;

  const NotesLandingScreen({super.key, this.initialFileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotesLandingChrome(
      isMobile: Platform.isIOS || Platform.isAndroid,
      onCreateNote: () => createNoteAndOpen(context: context, ref: ref),
      child: NotesWorkspace(initialFileId: initialFileId),
    );
  }
}

/// Outer chrome around the notes workspace. On mobile, hosts the
/// "new note" FAB but only when no note is currently open — when the
/// editor is visible the FAB would obscure the formatting toolbar /
/// content (see bug-report screenshot). Desktop / tablet falls
/// straight through to the workspace.
///
/// The "is a note open" signal piggy-backs on [notesBranchTitleProvider]:
/// the workspace already publishes the active tab's file name there
/// (or null when no tab is open) for the breadcrumb, so we get the
/// state for free without touching the workspace file.
@visibleForTesting
class NotesLandingChrome extends ConsumerWidget {
  final Widget child;
  final bool isMobile;
  final VoidCallback onCreateNote;

  const NotesLandingChrome({
    super.key,
    required this.child,
    required this.isMobile,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isMobile) return child;

    final hasOpenNote = ref.watch(notesBranchTitleProvider) != null;

    // Outer Scaffold wraps the workspace's own Scaffold purely to host
    // the FAB — nested Scaffolds are fine here because the inner one
    // owns the app bar and drawer and the outer one owns nothing but
    // the FAB slot. Keeps the workspace file untouched.
    return Scaffold(
      body: child,
      floatingActionButton: hasOpenNote
          ? null
          : FloatingActionButton(
              heroTag: 'notesFab',
              tooltip: AppLocalizations.of(context).notesNewNote,
              onPressed: onCreateNote,
              child: const Icon(Icons.add),
            ),
    );
  }
}
