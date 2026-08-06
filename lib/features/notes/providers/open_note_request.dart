import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A "please open this note" signal from anywhere in the app to the
/// [NotesWorkspace]. Carries the target file id plus a monotonic epoch.
///
/// The epoch matters: GoRouter treats `context.go('/notes?open=X')` as a
/// no-op when the Notes branch is already at that URL, which is exactly
/// what happens after the user opens note X, closes its tab, and taps it
/// again in the files list. Before this signal existed, the second tap
/// silently did nothing — the URL hadn't changed so the workspace never
/// rebuilt. Bumping the epoch on every request guarantees the listener
/// fires regardless of URL state.
class OpenNoteRequest {
  final String fileId;
  final int epoch;

  /// True when the request came from the Files branch. Closing the last
  /// workspace tab then switches the shell back to Files instead of
  /// stranding the user on the Notes landing screen.
  final bool returnToFiles;

  const OpenNoteRequest({
    required this.fileId,
    required this.epoch,
    this.returnToFiles = false,
  });
}

final openNoteRequestProvider = StateProvider<OpenNoteRequest?>((ref) => null);

/// Convenience: bump the epoch and set a fresh request. Used by callers
/// that route a file tap into the editor.
void requestOpenNoteFromWidget(
  WidgetRef ref,
  String fileId, {
  bool returnToFiles = false,
}) {
  final prev = ref.read(openNoteRequestProvider);
  ref.read(openNoteRequestProvider.notifier).state = OpenNoteRequest(
    fileId: fileId,
    epoch: (prev?.epoch ?? 0) + 1,
    returnToFiles: returnToFiles,
  );
}
