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
                child: FormattingToolbar(
                  onCommand: (_, [_]) {},
                  onHistory: onHistory,
                  onExportPdf: onExportPdf,
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
}
