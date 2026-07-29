import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/crypto/share_crypto.dart' show ShareRole;

/// Single note open in the editor.
///
/// Each tab owns its own dirty state and content. When a tab is not active
/// the webview doesn't reflect its content — instead, the last-known markdown
/// is preserved in [draftContent] so we can restore it when the user
/// switches back to this tab without losing unsaved edits.
class EditorTab {
  final String fileId;
  String fileName;
  FileItem? file;
  Uint8List? fileKey;

  /// Content loaded from disk/server. Null until [loaded] is true.
  String? loadedContent;

  /// Editor content captured when the user switched away from this tab.
  /// When non-null, this overrides [loadedContent] on re-activation.
  String? draftContent;

  bool loaded;
  bool loading;
  bool isDirty;
  bool isSaving;
  String? error;

  EditorTab({
    required this.fileId,
    required this.fileName,
    this.file,
    this.fileKey,
    this.loadedContent,
    this.draftContent,
    this.loaded = false,
    this.loading = false,
    this.isDirty = false,
    this.isSaving = false,
    this.error,
  });

  /// The content to push into the webview when this tab becomes active.
  String get currentContent => draftContent ?? loadedContent ?? '';

  /// `file.editable` is a server flag meaning "this is an editable markdown
  /// note" — it is true for a Reader's shared note too. Editing also requires
  /// write permission, so a Reader opens the same editor read-only. Mirrors the
  /// web's `canWrite` gate in `TableFileRow.vue` / `SearchModalResult.vue`.
  bool get editable {
    final f = file;
    if (f == null || !f.editable) return false;
    return f.isOwner ||
        f.shareRole == ShareRole.editor ||
        f.shareRole == ShareRole.coOwner;
  }
}
