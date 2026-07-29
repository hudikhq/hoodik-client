import 'package:flutter/material.dart';

import '../widgets/notes_workspace.dart';

/// `/editor/:fileId` deep-link route — opens the unified notes
/// workspace with the target note seeded as the active tab. Kept as a
/// named entry point so external callers (files screen, notifications,
/// deep links) don't need to know about the `/notes?open=<id>` form.
class NoteEditorScreen extends StatelessWidget {
  final String fileId;

  const NoteEditorScreen({super.key, required this.fileId});

  @override
  Widget build(BuildContext context) {
    return NotesWorkspace(initialFileId: fileId);
  }
}
