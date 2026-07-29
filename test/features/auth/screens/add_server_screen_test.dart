import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/auth/screens/add_server_screen.dart';
import 'package:hoodik_app/features/auth/widgets/cloud_nudge.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: HoodikTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AddServerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Add Server screen renders correctly', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Hoodik'), findsOneWidget);
    expect(find.text('Connect to a Server'), findsOneWidget);
    expect(find.text('Add Server'), findsOneWidget);
  });

  testWidgets('Add Server shows error on empty URL', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    // Tap connect without entering URL
    await tester.tap(find.text('Add Server'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a server URL'), findsOneWidget);
  });

  testWidgets('shows the server chooser card with no server saved', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byType(CloudNudge), findsOneWidget);
  });

  testWidgets('still shows the server chooser card with a server saved', (
    WidgetTester tester,
  ) async {
    await db.insertServer(
      const ServersCompanion(
        id: Value('srv-1'),
        url: Value('https://cloud.example.com'),
        name: Value('cloud.example.com'),
      ),
    );

    await pumpScreen(tester);

    expect(find.text('cloud.example.com'), findsWidgets);
    expect(find.byType(CloudNudge), findsOneWidget);
  });
}
