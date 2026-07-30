import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/account/widgets/legal_section.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: LegalSection()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers privacy policy, terms, and open source licenses', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Open source licenses'), findsOneWidget);
  });

  testWidgets('the licenses row opens the license page', (tester) async {
    // Register something recognisable so the page has content to render
    // regardless of what the test binding collected on its own.
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks([
        'a-test-package',
      ], 'Copyright (c) nobody. Test license body.');
    });

    await pump(tester);
    await tester.tap(find.text('Open source licenses'));
    await tester.pumpAndSettle();

    // showLicensePage renders a Material LicensePage listing the packages.
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('a-test-package'), findsOneWidget);
  });

  testWidgets('the row is translated, not hardcoded English', (tester) async {
    await pump(tester, locale: const Locale('hr'));

    expect(find.text('Licence otvorenog koda'), findsOneWidget);
    expect(find.text('Open source licenses'), findsNothing);
  });
}
