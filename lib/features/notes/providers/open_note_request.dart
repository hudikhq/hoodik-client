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

  const OpenNoteRequest({required this.fileId, required this.epoch});
}

final openNoteRequestProvider = StateProvider<OpenNoteRequest?>((ref) => null);

/// Convenience: bump the epoch and set a fresh request. Used by callers
/// that route a file tap into the editor.
void requestOpenNote(Ref ref, String fileId) {
  final prev = ref.read(openNoteRequestProvider);
  final next = OpenNoteRequest(fileId: fileId, epoch: (prev?.epoch ?? 0) + 1);
  ref.read(openNoteRequestProvider.notifier).state = next;
}

/// Same as [requestOpenNote] but for callers that have a [WidgetRef]
/// (inside a Widget's build/event handler) rather than a plain [Ref].
void requestOpenNoteFromWidget(WidgetRef ref, String fileId) {
  final prev = ref.read(openNoteRequestProvider);
  final next = OpenNoteRequest(fileId: fileId, epoch: (prev?.epoch ?? 0) + 1);
  ref.read(openNoteRequestProvider.notifier).state = next;
}
