import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/files/widgets/file_grid_item.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';

Widget _wrap(
  FileItem file, {
  bool selectionMode = false,
  void Function(Offset)? onContextMenu,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FileGridItem(
        file: file,
        displayName: 'name',
        isSelected: false,
        isOffline: false,
        selectionMode: selectionMode,
        sharingEnabled: true,
        onTap: () {},
        onToggleSelection: () {},
        onContextMenu: onContextMenu ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('FileGridItem overflow trigger', () {
    testWidgets('a normal folder renders the kebab and it opens the menu', (
      tester,
    ) async {
      Offset? requested;
      await tester.pumpWidget(
        _wrap(
          FileItem(id: 'dir-1', encryptedName: 'enc', mime: 'dir'),
          onContextMenu: (pos) => requested = pos,
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      expect(requested, isNotNull);
    });

    testWidgets('the "Shared with me" virtual folder renders no kebab', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(sharedWithMeFolder()));

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('selection mode hides the kebab for a normal folder too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FileItem(id: 'dir-1', encryptedName: 'enc', mime: 'dir'),
          selectionMode: true,
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
