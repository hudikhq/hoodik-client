import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/preferences.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/auth/screens/unlock_screen.dart';
import 'package:hoodik_app/features/auth/screens/add_server_screen.dart'
    show selectedServerProvider;
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_helpers.dart';

void main() {
  group('UnlockScreen account switching', () {
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

    Widget buildApp({String? targetAccountId}) {
      final router = GoRouter(
        initialLocation: targetAccountId != null
            ? '/auth/unlock?accountId=$targetAccountId'
            : '/auth/unlock',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
          GoRoute(
            path: '/auth/login',
            builder: (_, _) {
              lastRoute = '/auth/login';
              return const Text('LOGIN');
            },
          ),
          GoRoute(
            path: '/auth/unlock',
            builder: (_, state) {
              final accountId = state.uri.queryParameters['accountId'];
              return UnlockScreen(targetAccountId: accountId);
            },
          ),
          GoRoute(
            path: '/setup/server',
            builder: (_, _) {
              lastRoute = '/setup/server';
              return const Text('SERVER');
            },
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
          selectedServerProvider.overrideWith((ref) => null),
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

    testWidgets('hides switch section when only one account exists', (
      tester,
    ) async {
      final account = fakeAccount(
        id: 'srv_user@test.com',
        pinEncryptedPrivateKey: 'encrypted-hex',
      );
      fakeAuth
        ..defaultPinAccount = account
        ..allAccounts = [account]
        ..allServers = [fakeServer()];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('SWITCH ACCOUNT'), findsNothing);
    });

    testWidgets('shows other accounts when multiple exist', (tester) async {
      final primary = fakeAccount(
        id: 'srv_user@test.com',
        pinEncryptedPrivateKey: 'encrypted-hex',
      );
      final other = fakeAccount(
        id: 'srv_other@test.com',
        email: 'other@test.com',
      );
      fakeAuth
        ..defaultPinAccount = primary
        ..allAccounts = [primary, other]
        ..allServers = [fakeServer()];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('SWITCH ACCOUNT'), findsOneWidget);
      expect(find.text('other@test.com'), findsOneWidget);
    });

    testWidgets('tapping account with PIN swaps in-place (no navigation)', (
      tester,
    ) async {
      final primary = fakeAccount(
        id: 'srv_user@test.com',
        pinEncryptedPrivateKey: 'encrypted-hex',
      );
      final other = fakeAccount(
        id: 'srv_other@test.com',
        email: 'other@test.com',
        pinEncryptedPrivateKey: 'encrypted-hex-2',
      );
      fakeAuth
        ..defaultPinAccount = primary
        ..allAccounts = [primary, other]
        ..allServers = [fakeServer()]
        ..pinSetupAccounts = {'srv_user@test.com', 'srv_other@test.com'}
        ..pinAccountByIdResolver = (id) =>
            id == 'srv_other@test.com' ? other : null;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Header shows the primary account.
      expect(find.text('user@test.com'), findsOneWidget);

      // Tap the other account.
      await tester.tap(find.text('other@test.com'));
      await tester.pumpAndSettle();

      // Header should now show the swapped account.
      expect(find.text('other@test.com'), findsOneWidget);
      // The previous account should now appear in the switch list.
      expect(find.text('user@test.com'), findsOneWidget);
      // Still on the unlock screen (Enter Passcode title still visible).
      expect(find.text('Enter Passcode'), findsOneWidget);
    });

    testWidgets('tapping account without PIN navigates to login', (
      tester,
    ) async {
      final primary = fakeAccount(
        id: 'srv_user@test.com',
        pinEncryptedPrivateKey: 'encrypted-hex',
      );
      final other = fakeAccount(
        id: 'srv_other@test.com',
        email: 'other@test.com',
      );
      fakeAuth
        ..defaultPinAccount = primary
        ..allAccounts = [primary, other]
        ..allServers = [fakeServer()]
        ..pinSetupAccounts = {'srv_user@test.com'};

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('other@test.com'));
      await tester.pumpAndSettle();

      expect(lastRoute, '/auth/login');
    });
  });
}
