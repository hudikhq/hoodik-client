import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/features/notes/models/editor_tab.dart';

FileItem _note({
  required bool isOwner,
  ShareRole? shareRole,
  bool editable = true,
}) {
  return FileItem(
    id: 'note-1',
    encryptedName: 'enc',
    mime: 'text/markdown',
    editable: editable,
    finishedUploadAt: 100,
    isOwner: isOwner,
    shareRole: shareRole,
  );
}

EditorTab _tab(FileItem? file) =>
    EditorTab(fileId: 'note-1', fileName: 'note.md', file: file);

void main() {
  group('EditorTab.editable', () {
    test('false for a Reader share even when the file is an editable note', () {
      final tab = _tab(_note(isOwner: false, shareRole: ShareRole.reader));
      expect(tab.editable, isFalse);
    });

    test('true for the owner', () {
      final tab = _tab(_note(isOwner: true));
      expect(tab.editable, isTrue);
    });

    test('true for an editor share', () {
      final tab = _tab(_note(isOwner: false, shareRole: ShareRole.editor));
      expect(tab.editable, isTrue);
    });

    test('true for a co-owner share', () {
      final tab = _tab(_note(isOwner: false, shareRole: ShareRole.coOwner));
      expect(tab.editable, isTrue);
    });

    test('false when the file is not an editable note', () {
      final tab = _tab(_note(isOwner: true, editable: false));
      expect(tab.editable, isFalse);
    });

    test('false before the file row is loaded', () {
      expect(_tab(null).editable, isFalse);
    });
  });
}
