import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/core/widgets/adaptive_menu.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

/// The bug this file guards: the same file used to grow two different menus.
/// Tapping a row opened a Cupertino action sheet; tapping its kebab opened a
/// Material dropdown — on the same device, with different entries, because
/// each surface built its own list.
void main() {
  final apple = Platform.isIOS || Platform.isMacOS;

  final actions = [
    AdaptiveMenuAction(
      label: 'Rename',
      icon: Icons.edit,
      iconColor: const Color(0xFF888888),
      onTap: () {},
    ),
    AdaptiveMenuAction(
      label: 'Delete',
      icon: Icons.delete,
      iconColor: const Color(0xFF888888),
      onTap: () {},
      isDestructive: true,
    ),
  ];

  // A fresh key per open remounts the app, so an already-open menu from the
  // previous call can't swallow the next tap.
  var mount = 0;

  Future<void> open(WidgetTester tester, {Offset? anchor}) async {
    await tester.pumpWidget(
      MaterialApp(
        key: ValueKey(mount++),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAdaptiveMenu(
                  context: context,
                  title: 'photo.png',
                  anchor: anchor,
                  actions: actions,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a row tap and a kebab tap offer the same entries', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await open(tester, anchor: const Offset(120, 200));
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('touch ignores the anchor, a pointer honours it', (tester) async {
    await open(tester, anchor: const Offset(120, 200));

    if (isTouchPlatform) {
      // A phone answers a list of choices one way whatever opened it, so a
      // kebab does not get its own dropdown.
      expect(find.byType(PopupMenuItem<void>), findsNothing);
      expect(
        apple ? find.byType(CupertinoActionSheet) : find.byType(BottomSheet),
        findsOneWidget,
      );
    } else {
      expect(find.byType(PopupMenuItem<void>), findsNWidgets(2));
    }
  });

  testWidgets('a menu with no anchor is a sheet everywhere', (tester) async {
    await open(tester);

    if (apple) {
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
    } else {
      expect(find.byType(BottomSheet), findsOneWidget);
    }
  });

  testWidgets('an empty action list opens nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showAdaptiveMenu(context: context, actions: const []),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(PopupMenuItem<void>), findsNothing);
  });

  testWidgets('the pointer menu is drawn at AppKit density', (tester) async {
    if (isTouchPlatform) return; // No anchored variant exists on touch.
    await open(tester, anchor: const Offset(120, 200));

    final item = tester.widget<PopupMenuItem<void>>(
      find.byType(PopupMenuItem<void>).first,
    );
    // AppKit draws 22pt rows; Material's 48dp default reads as a mobile sheet
    // stuck to a button.
    expect(item.height, 24.0);
  });
}
