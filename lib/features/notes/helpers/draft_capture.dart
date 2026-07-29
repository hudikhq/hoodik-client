import '../models/editor_tab.dart';

/// Snapshot the editor's in-flight markdown into the active tab's draft so an
/// unsaved edit survives a tab switch.
///
/// [activeTab] is read once, before the [readMarkdown] await, pinning the
/// destination. Reading it again after the await would let a tab switch made
/// while the read is in flight write one note's content into another — the
/// corruption this guards against. A clean tab holds nothing worth keeping, so
/// it is skipped; the read is best-effort and a failure leaves any existing
/// draft untouched.
Future<void> captureActiveDraft(
  EditorTab Function() activeTab,
  Future<String> Function() readMarkdown,
) async {
  final tab = activeTab();
  if (!tab.isDirty) return;
  try {
    tab.draftContent = await readMarkdown();
  } catch (_) {
    // Best-effort only.
  }
}
