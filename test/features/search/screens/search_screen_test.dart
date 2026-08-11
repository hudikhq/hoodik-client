import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/features/search/screens/search_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/core/widgets/app_icons.dart';

void main() {
  group('SearchScreen', () {
    testWidgets('shows initial hint text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search your files'), findsOneWidget);
      expect(find.byIcon(AppIcons.search), findsWidgets);
    });

    testWidgets('shows text field with autofocus', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, true);
      expect(textField.textInputAction, TextInputAction.search);
    });

    testWidgets('shows clear button when text is entered', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // Type something
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button clears text and resets state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
      expect(find.text('Search your files'), findsOneWidget);
    });
  });
}
