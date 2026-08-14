import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/connect_link.dart';
import 'package:hoodik_app/core/services/preferences.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/auth/screens/login_screen.dart';
import 'package:hoodik_app/features/auth/screens/add_server_screen.dart'
    show selectedServerProvider;
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_helpers.dart';

void main() {
  group('LoginScreen prefill from a scanned QR code', () {
    late FakeAuthService fakeAuth;
    late Preferences prefs;

    setUp(() async {
      fakeAuth = FakeAuthService();
      SharedPreferences.setMockInitialValues({});
      prefs = await Preferences.load();
    });

    Future<void> pumpScreen(WidgetTester tester, ConnectLink scanned) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(fakeAuth),
            selectedServerProvider.overrideWith((ref) => fakeServer()),
            pendingConnectProvider.overrideWith((ref) => scanned),
            preferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: HoodikTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('fills in the email the code carried', (tester) async {
      // fakeServer() is https://example.com, which is where the code points.
      await pumpScreen(
        tester,
        const ConnectLink(
          serverUrl: 'https://example.com',
          email: 'scanned@example.com',
        ),
      );

      expect(find.text('scanned@example.com'), findsOneWidget);
    });

    testWidgets('leaves the field alone when the code names another server', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const ConnectLink(
          serverUrl: 'https://somewhere-else.example.org',
          email: 'scanned@example.com',
        ),
      );

      expect(find.text('scanned@example.com'), findsNothing);
    });
  });
}
