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

  /// The shell branch to return to when the last tab closes, or null to
  /// stay in Notes. A note is opened from several places — the file list,
  /// search — and closing it should land back where it was opened from
  /// rather than always in Files.
  final int? returnToBranchIndex;

  /// When set, the workspace shows the in-note find bar and highlights
  /// this query once the editor has the note's content.
  final String? highlightQuery;

  const OpenNoteRequest({
    required this.fileId,
    required this.epoch,
    this.returnToBranchIndex,
    this.highlightQuery,
  });
}

final openNoteRequestProvider = StateProvider<OpenNoteRequest?>((ref) => null);

/// Convenience: bump the epoch and set a fresh request. Used by callers
/// that route a file tap into the editor.
void requestOpenNoteFromWidget(
  WidgetRef ref,
  String fileId, {
  int? returnToBranchIndex,
  String? highlightQuery,
}) {
  final prev = ref.read(openNoteRequestProvider);
  ref.read(openNoteRequestProvider.notifier).state = OpenNoteRequest(
    fileId: fileId,
    epoch: (prev?.epoch ?? 0) + 1,
    returnToBranchIndex: returnToBranchIndex,
    highlightQuery: highlightQuery,
  );
}
