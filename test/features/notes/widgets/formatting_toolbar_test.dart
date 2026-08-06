import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/features/notes/widgets/formatting_toolbar.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  /// 360dp is the Pixel 8 / common Android mid-range width; a 393dp iPhone
  /// (14/15/17) sits just above. Both hit the compact layout, so this width
  /// is the one that has to fit without overflow.
  const narrowWidth = 360.0;

  Future<void> pumpToolbar(
    WidgetTester tester, {
    double width = narrowWidth,
    VoidCallback? onHistory,
    VoidCallback? onExportPdf,
    VoidCallback? onHideKeyboard,
    bool keyboardOpen = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: width,
                child: Builder(
                  builder: (context) => MediaQuery(
                    // The notes branch keeps resize off, so the toolbar
                    // sees the raw keyboard inset in the real app.
                    data: MediaQuery.of(context).copyWith(
                      viewInsets: EdgeInsets.only(
                        bottom: keyboardOpen ? 300 : 0,
                      ),
                    ),
                    child: FormattingToolbar(
                      onCommand: (_, [_]) {},
                      onHistory: onHistory,
                      onExportPdf: onExportPdf,
                      onHideKeyboard: onHideKeyboard,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('compact toolbar does not overflow at 360dp width', (
    tester,
  ) async {
    await pumpToolbar(tester, onHistory: () {}, onExportPdf: () {});
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact toolbar exposes PDF + history via the more-menu', (
    tester,
  ) async {
    await pumpToolbar(tester, onHistory: () {}, onExportPdf: () {});

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Export to PDF'), findsOneWidget);
    expect(find.text('Version history'), findsOneWidget);
  });

  testWidgets('more-menu hides PDF/history entries when callbacks are null', (
    tester,
  ) async {
    await pumpToolbar(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Export to PDF'), findsNothing);
    expect(find.text('Version history'), findsNothing);
  });

  testWidgets('hide-keyboard button appears only while the keyboard is up', (
    tester,
  ) async {
    var hidden = false;
    await pumpToolbar(tester, onHideKeyboard: () => hidden = true);
    expect(find.byIcon(Icons.keyboard_hide_outlined), findsNothing);

    await pumpToolbar(
      tester,
      onHideKeyboard: () => hidden = true,
      keyboardOpen: true,
    );
    expect(find.byIcon(Icons.keyboard_hide_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_hide_outlined));
    expect(hidden, isTrue);
  });
}
