import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../notes/providers/open_note_request.dart';
import '../../preview/providers/preview_providers.dart';

/// Whether [file] renders with the markdown editor. Uses [displayName]
/// to detect `.md` files uploaded with generic `text/plain` MIME.
bool isMarkdownFile(FileItem file, {required String displayName}) {
  return getPreviewType(file.mime, fileName: displayName) ==
      PreviewType.markdown;
}

/// Route to the notes editor for [file], seeding [previewContextProvider]
/// with every markdown file in [siblings] so the editor's "next/prev note"
/// affordance can walk the folder without a round-trip.
///
/// Uses `context.go` (not `push`) so the StatefulShellRoute activates the
/// Notes branch cleanly — the IndexedStack swaps in the notes workspace
/// and the bottom nav stays visible with Notes highlighted.
///
/// [names] and [keys] are indexed by file id. They do not have to be
/// restricted to [siblings] — the workspace reads entries for the target
/// file's id, plus any it encounters later when navigating through the
/// sibling list. Callers that have decrypted more than just the current
/// folder (tree view, search results) should pass their full caches so
/// cross-folder navigation works without a re-decrypt.
void openEditor({
  required BuildContext context,
  required WidgetRef ref,
  required FileItem file,
  required List<FileItem> siblings,
  required Map<String, String> names,
  required Map<String, Uint8List> keys,
  String? parentDirId,
}) {
  final markdownFiles = siblings
      .where((f) => isMarkdownFile(f, displayName: names[f.id] ?? ''))
      .toList();
  // A note shared directly to the caller resolves its parent to the account
  // root, whose sibling list doesn't contain it, so it can be absent here.
  // Seed it explicitly — the workspace looks the target up by id and bails
  // silently if it's missing.
  if (!markdownFiles.any((f) => f.id == file.id)) {
    markdownFiles.insert(0, file);
  }

  ref.read(previewContextProvider.notifier).state = PreviewContext(
    files: markdownFiles,
    names: Map.of(names),
    keys: Map.of(keys),
    parentDirId: parentDirId,
  );

  // Tell the workspace to open this note. The provider's epoch-bumped
  // signal fires even when the URL doesn't change (re-tap of a note the
  // user just closed), which a plain `?open=` query wouldn't.
  requestOpenNoteFromWidget(ref, file.id, returnToFiles: true);

  context.go('/editor/${file.id}');
}

/// Route to the generic preview screen for [file], seeding
/// [previewContextProvider] with every previewable file in [siblings].
///
/// See [openEditor] for the [names]/[keys] contract.
void openPreview({
  required BuildContext context,
  required WidgetRef ref,
  required FileItem file,
  required List<FileItem> siblings,
  required Map<String, String> names,
  required Map<String, Uint8List> keys,
  String? parentDirId,
}) {
  final previewableFiles = siblings.where(isPreviewable).toList();
  // See openEditor: a row shared directly to the caller can be absent from
  // its resolved siblings, so seed it explicitly.
  if (!previewableFiles.any((f) => f.id == file.id)) {
    previewableFiles.insert(0, file);
  }

  ref.read(previewContextProvider.notifier).state = PreviewContext(
    files: previewableFiles,
    names: Map.of(names),
    keys: Map.of(keys),
    parentDirId: parentDirId,
  );

  context.push('/preview/${file.id}');
}
