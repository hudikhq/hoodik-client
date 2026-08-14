import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/core/services/connect_link.dart';
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

  Future<void> pumpScreen(WidgetTester tester, {ConnectLink? scanned}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (scanned != null)
            pendingConnectProvider.overrideWith((ref) => scanned),
        ],
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

  // A port nothing listens on: the connection is refused immediately, so the
  // attempt is observable offline without waiting on a real network.
  const unreachable = 'http://127.0.0.1:1';

  testWidgets('connects on its own when arriving from a scanned QR code', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      scanned: const ConnectLink(
        serverUrl: unreachable,
        email: 'someone@example.com',
      ),
    );

    expect(find.text(unreachable), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // The attempt fails here (the test binding answers every request with a
    // 400), and that failure is the proof it ran with nobody tapping.
    expect(find.byType(ErrorBanner), findsOneWidget);

    // Consumed, so backing out of login and returning doesn't reconnect.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AddServerScreen)),
    );
    expect(container.read(pendingConnectProvider)?.autoConnect, isFalse);
  });

  /// Routing to a screen that is already showing creates nothing, so a scan
  /// that lands here reaches the screen as a provider change rather than a
  /// fresh initState. This is the common path: someone with no server yet is
  /// looking at this screen when they scan.
  testWidgets('takes a scan that arrives while it is already open', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HoodikTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AddServerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(unreachable), findsNothing);

    container.read(pendingConnectProvider.notifier).state = const ConnectLink(
      serverUrl: unreachable,
      email: 'someone@example.com',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text(unreachable), findsOneWidget);
    expect(find.byType(ErrorBanner), findsOneWidget);
  });

  testWidgets('does not reconnect when the link has already been used', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      scanned: const ConnectLink(serverUrl: unreachable, autoConnect: false),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text(unreachable), findsOneWidget);
    expect(find.byType(ErrorBanner), findsNothing);
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
