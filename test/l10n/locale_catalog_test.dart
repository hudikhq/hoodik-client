import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  test('every supported locale resolves a full catalog', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.commonSave, isNotEmpty);
      expect(l10n.languageTitle, isNotEmpty);
      expect(l10n.relativeMinutesAgo(5), contains('5'));
    }
  });

  test('croatian plurals follow one/few/other', () {
    final hr = lookupAppLocalizations(const Locale('hr'));
    expect(hr.accountLogsLineCount(1), isNot(hr.accountLogsLineCount(2)));
    expect(hr.accountLogsLineCount(2), isNot(hr.accountLogsLineCount(5)));
  });

  testWidgets('the app renders translated text under a non-English locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).commonSave),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spremi'), findsOneWidget);
  });
}
