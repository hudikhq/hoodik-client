import 'package:flutter/material.dart';

import '../widgets/notes_workspace.dart';

/// Route target for `/notes` and `/editor/:fileId`.
///
/// Creating a note is an app-bar action on every platform now — mobile in
/// [NotesWorkspace]'s own bar, desktop in the always-visible sidebar header —
/// so this no longer wraps the workspace in anything.
class NotesLandingScreen extends StatelessWidget {
  final String? initialFileId;

  const NotesLandingScreen({super.key, this.initialFileId});

  @override
  Widget build(BuildContext context) =>
      NotesWorkspace(initialFileId: initialFileId);
}
