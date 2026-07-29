import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/preferences.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/auth/screens/login_screen.dart';
import 'package:hoodik_app/features/auth/screens/add_server_screen.dart'
    show selectedServerProvider;
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_helpers.dart';

void main() {
  group('LoginScreen account switching', () {
    late FakeAuthService fakeAuth;
    late String lastRoute;
    late Preferences prefs;

    setUp(() async {
      fakeAuth = FakeAuthService();
      lastRoute = '';
      // Stub SharedPreferences so landingBranchProvider resolves to its
      // default (Files → `/`) instead of throwing.
      SharedPreferences.setMockInitialValues({});
      prefs = await Preferences.load();
    });

    Widget buildApp() {
      final router = GoRouter(
        initialLocation: '/auth/login',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
          GoRoute(path: '/auth/login', builder: (_, _) => const LoginScreen()),
          GoRoute(
            path: '/auth/unlock',
            builder: (_, state) {
              lastRoute =
                  '/auth/unlock?accountId=${state.uri.queryParameters['accountId']}';
              return const Text('UNLOCK');
            },
          ),
        ],
      );

      final server = fakeServer();

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
          selectedServerProvider.overrideWith((ref) => server),
          preferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          theme: HoodikTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    testWidgets('navigates to home when private key is recovered', (
      tester,
    ) async {
      fakeAuth
        ..switchAccountResult = true
        ..fakeDecryptedPrivateKey = 'RSA_KEY_PEM'
        ..fakeActiveAccount = fakeAccount(id: 'srv_user@test.com')
        ..fakeActiveServer = fakeServer()
        ..serverAccounts = [fakeAccount(id: 'srv_user@test.com')];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tap the existing account tile.
      await tester.tap(find.text('user@test.com'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets(
      'redirects to unlock screen when account has PIN but no private key',
      (tester) async {
        fakeAuth
          ..switchAccountResult = true
          ..fakeDecryptedPrivateKey = null
          ..fakeActiveAccount = fakeAccount(id: 'srv_user@test.com')
          ..fakeActiveServer = fakeServer()
          ..serverAccounts = [fakeAccount(id: 'srv_user@test.com')]
          ..pinSetupAccounts = {'srv_user@test.com'};

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('user@test.com'));
        await tester.pumpAndSettle();

        expect(lastRoute, '/auth/unlock?accountId=srv_user@test.com');
      },
    );

    testWidgets(
      'shows password form when account has no PIN and no private key',
      (tester) async {
        fakeAuth
          ..switchAccountResult = true
          ..fakeDecryptedPrivateKey = null
          ..fakeActiveAccount = fakeAccount(id: 'srv_user@test.com')
          ..fakeActiveServer = fakeServer()
          ..serverAccounts = [fakeAccount(id: 'srv_user@test.com')]
          ..pinSetupAccounts = {};

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('user@test.com'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please sign in with your password to unlock encryption.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('asks for a password sign-in when switchAccount fails', (
      tester,
    ) async {
      fakeAuth
        ..switchAccountResult = false
        ..serverAccounts = [fakeAccount(id: 'srv_user@test.com')];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('user@test.com'));
      await tester.pumpAndSettle();

      expect(find.text('Please sign in to continue.'), findsOneWidget);
    });
  });
}
