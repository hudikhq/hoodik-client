import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/notes/helpers/draft_capture.dart';
import 'package:hoodik_app/features/notes/models/editor_tab.dart';

EditorTab _tab(String id, {bool dirty = true}) =>
    EditorTab(fileId: id, fileName: id, isDirty: dirty);

void main() {
  test('pins the active tab before the read so a switch mid-read cannot '
      'redirect the draft into another note', () async {
    final a = _tab('a');
    final b = _tab('b');
    var active = a;
    final pending = Completer<String>();

    final future = captureActiveDraft(() => active, () {
      // The user switches to b while the markdown read is still in flight.
      active = b;
      return pending.future;
    });
    pending.complete("a's unsaved edits");
    await future;

    expect(a.draftContent, "a's unsaved edits");
    expect(b.draftContent, isNull);
  });

  test(
    'skips a clean tab — no read is issued and nothing is captured',
    () async {
      final tab = _tab('a', dirty: false);
      var read = false;

      await captureActiveDraft(() => tab, () async {
        read = true;
        return 'unexpected';
      });

      expect(read, isFalse);
      expect(tab.draftContent, isNull);
    },
  );

  test(
    'a failed read leaves any existing draft untouched (best-effort)',
    () async {
      final tab = _tab('a')..draftContent = 'previous';

      await captureActiveDraft(() => tab, () async => throw StateError('gone'));

      expect(tab.draftContent, 'previous');
    },
  );
}
