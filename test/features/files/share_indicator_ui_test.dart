import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/core/theme/hoodik_colors.dart';
import 'package:hoodik_app/features/files/widgets/file_grid_item.dart';
import 'package:hoodik_app/features/files/widgets/files_tree_rows.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';
import 'package:hoodik_app/core/widgets/app_icons.dart';

FileItem _recipientRow() {
  return FileItem(
    id: 'shared-file',
    encryptedName: 'enc',
    mime: 'image/png',
    finishedUploadAt: 1,
    isOwner: false,
    shareRole: ShareRole.reader,
    ownerEmail: 'alice@example.com',
  );
}

FileItem _ownedSharedRow() {
  return FileItem(
    id: 'owned-file',
    encryptedName: 'enc',
    mime: 'image/png',
    finishedUploadAt: 1,
    sharedWithCount: 3,
  );
}

FileItem _ownedPlainRow() {
  return FileItem(
    id: 'plain',
    encryptedName: 'enc',
    mime: 'image/png',
    finishedUploadAt: 1,
  );
}

Finder _shareGlyph(IconData icon) => find.byWidgetPredicate(
  (w) => w is Icon && w.icon == icon && w.color == HoodikColors.blueish300,
);

Widget _wrapGrid(FileItem file, {required bool sharingEnabled}) {
  return MaterialApp(
    home: Scaffold(
      body: FileGridItem(
        file: file,
        displayName: 'name',
        isSelected: false,
        isOffline: false,
        selectionMode: false,
        sharingEnabled: sharingEnabled,
        onTap: () {},
        onContextMenu: (_) {},
        onToggleSelection: () {},
      ),
    ),
  );
}

Widget _wrapTreeFileRow(FileItem file, {required bool sharingEnabled}) {
  return MaterialApp(
    home: Scaffold(
      body: TreeFileRow(
        file: file,
        name: 'name',
        depth: 0,
        isActive: false,
        shareIcon: shareIndicatorIcon(file, sharingEnabled: sharingEnabled),
        onTap: () {},
        onContextMenu: (_) {},
      ),
    ),
  );
}

void main() {
  group('FileGridItem share badge', () {
    testWidgets('recipient row shows the incoming-share glyph', (tester) async {
      await tester.pumpWidget(_wrapGrid(_recipientRow(), sharingEnabled: true));
      expect(_shareGlyph(Icons.account_circle_outlined), findsOneWidget);
    });

    testWidgets('owned shared row shows the outgoing-share glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapGrid(_ownedSharedRow(), sharingEnabled: true),
      );
      expect(_shareGlyph(AppIcons.members), findsOneWidget);
    });

    testWidgets('owned non-shared row shows no share glyph', (tester) async {
      await tester.pumpWidget(
        _wrapGrid(_ownedPlainRow(), sharingEnabled: true),
      );
      expect(_shareGlyph(Icons.account_circle_outlined), findsNothing);
      expect(_shareGlyph(AppIcons.members), findsNothing);
    });

    testWidgets('badge is suppressed when sharing is disabled', (tester) async {
      await tester.pumpWidget(
        _wrapGrid(_recipientRow(), sharingEnabled: false),
      );
      expect(_shareGlyph(Icons.account_circle_outlined), findsNothing);

      await tester.pumpWidget(
        _wrapGrid(_ownedSharedRow(), sharingEnabled: false),
      );
      expect(_shareGlyph(AppIcons.members), findsNothing);
    });

    testWidgets('synthetic "Shared with me" root shows no share glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapGrid(sharedWithMeFolder(), sharingEnabled: true),
      );
      expect(_shareGlyph(Icons.account_circle_outlined), findsNothing);
      expect(_shareGlyph(AppIcons.members), findsNothing);
    });
  });

  group('Tree row share indicator', () {
    testWidgets('recipient row shows the incoming-share glyph', (tester) async {
      await tester.pumpWidget(
        _wrapTreeFileRow(_recipientRow(), sharingEnabled: true),
      );
      expect(_shareGlyph(Icons.account_circle_outlined), findsOneWidget);
    });

    testWidgets('owned shared row shows the outgoing-share glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapTreeFileRow(_ownedSharedRow(), sharingEnabled: true),
      );
      expect(_shareGlyph(AppIcons.members), findsOneWidget);
    });

    testWidgets('owned non-shared row shows no share glyph', (tester) async {
      await tester.pumpWidget(
        _wrapTreeFileRow(_ownedPlainRow(), sharingEnabled: true),
      );
      expect(_shareGlyph(Icons.account_circle_outlined), findsNothing);
      expect(_shareGlyph(AppIcons.members), findsNothing);
    });

    testWidgets('row is suppressed when sharing is disabled', (tester) async {
      await tester.pumpWidget(
        _wrapTreeFileRow(_recipientRow(), sharingEnabled: false),
      );
      expect(_shareGlyph(Icons.account_circle_outlined), findsNothing);
    });
  });

  group('shareIndicatorIcon gating', () {
    test('recipient row resolves to the incoming glyph', () {
      expect(
        shareIndicatorIcon(_recipientRow(), sharingEnabled: true),
        Icons.account_circle_outlined,
      );
    });

    test('owned shared row resolves to the outgoing glyph', () {
      expect(
        shareIndicatorIcon(_ownedSharedRow(), sharingEnabled: true),
        AppIcons.members,
      );
    });

    test('owned non-shared row resolves to no glyph', () {
      expect(shareIndicatorIcon(_ownedPlainRow(), sharingEnabled: true), null);
    });

    test('disabled sharing resolves to no glyph', () {
      expect(shareIndicatorIcon(_recipientRow(), sharingEnabled: false), null);
      expect(
        shareIndicatorIcon(_ownedSharedRow(), sharingEnabled: false),
        null,
      );
    });

    test('synthetic "Shared with me" root resolves to no glyph', () {
      expect(
        shareIndicatorIcon(sharedWithMeFolder(), sharingEnabled: true),
        null,
      );
    });
  });
}
