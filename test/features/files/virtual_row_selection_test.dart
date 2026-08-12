import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/files/widgets/file_list_item.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// "Shared with me" is a client-only navigation aid the server has never
/// heard of, so nothing the selection bar offers — move, delete — can act on
/// it. It used to accept a tick anyway, which put a row in the selection that
/// every batch action would then have to special-case.
FileItem _file({required String id, bool isDir = true}) => FileItem(
  id: id,
  encryptedName: 'enc-$id',
  mime: isDir ? 'dir' : 'text/plain',
  isOwner: true,
  finishedUploadAt: 1,
);

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    required FileItem file,
    required VoidCallback onToggle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FileListItem(
            file: file,
            displayName: 'row',
            isSelected: false,
            isOffline: false,
            selectionMode: true,
            onTap: () {},
            onToggleSelection: onToggle,
            onContextMenu: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('the virtual row keeps its checkbox but cannot be ticked', (
    tester,
  ) async {
    var toggled = 0;
    await pumpRow(
      tester,
      file: _file(id: sharedWithMeDirId),
      onToggle: () => toggled++,
    );

    // Present, so the column stays aligned with the rows around it.
    final box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(box.onChanged, isNull, reason: 'a null handler is what disables it');

    await tester.tap(find.byType(Checkbox), warnIfMissed: false);
    expect(toggled, 0);
  });

  testWidgets('a real row still ticks', (tester) async {
    var toggled = 0;
    await pumpRow(
      tester,
      file: _file(id: 'dir-1'),
      onToggle: () => toggled++,
    );

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNotNull);

    await tester.tap(find.byType(Checkbox));
    expect(toggled, 1);
  });

  test('the predicate names the one row that cannot be picked', () {
    expect(canSelectFile(_file(id: sharedWithMeDirId)), isFalse);
    expect(canSelectFile(_file(id: 'dir-1')), isTrue);
    expect(canSelectFile(_file(id: 'file-1', isDir: false)), isTrue);
  });
}
