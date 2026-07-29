import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/preferences.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/auth/screens/add_server_screen.dart'
    show selectedServerProvider;
import 'package:hoodik_app/features/auth/screens/key_login_screen.dart';
import 'package:hoodik_app/features/auth/services/key_login_service.dart';
import 'package:hoodik_app/features/auth/services/recovery_bundle.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_helpers.dart';

class _FakeKeyLoginService implements KeyLoginService {
  Object? error;
  String? receivedMaterial;
  Server? receivedServer;

  @override
  Future<ParsedRecoveryKey> login({
    required Server server,
    required String material,
  }) async {
    receivedServer = server;
    receivedMaterial = material;
    final err = error;
    if (err != null) throw err;
    return const ParsedRecoveryKey(identity: 'ID_PEM', wrapping: 'WRAP_PEM');
  }
}

void main() {
  group('KeyLoginScreen', () {
    late FakeAuthService fakeAuth;
    late _FakeKeyLoginService fakeKeyLogin;
    late Preferences prefs;

    setUp(() async {
      fakeAuth = FakeAuthService();
      fakeKeyLogin = _FakeKeyLoginService();
      SharedPreferences.setMockInitialValues({});
      prefs = await Preferences.load();
    });

    Widget buildApp() {
      final router = GoRouter(
        initialLocation: '/auth/key-login',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
          GoRoute(path: '/auth/login', builder: (_, _) => const Text('LOGIN')),
          GoRoute(
            path: '/auth/setup-pin',
            builder: (_, _) => const Text('SETUP_PIN'),
          ),
          GoRoute(
            path: '/auth/key-login',
            builder: (_, _) => const KeyLoginScreen(),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
          keyLoginServiceProvider.overrideWithValue(fakeKeyLogin),
          selectedServerProvider.overrideWith((ref) => fakeServer()),
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

    testWidgets('shows an error when submitted empty', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('keyLoginButton')));
      await tester.pumpAndSettle();

      expect(find.text('Paste your recovery key first'), findsOneWidget);
      expect(fakeKeyLogin.receivedMaterial, isNull);
    });

    testWidgets('submits pasted material and routes to PIN setup', (
      tester,
    ) async {
      fakeAuth.fakeActiveAccount = fakeAccount(id: 'srv_user@test.com');
      fakeAuth.fakeActiveServer = fakeServer();

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('recoveryKeyField')),
        'v1|ed:ID_PEM|x:WRAP_PEM',
      );
      await tester.tap(find.byKey(const Key('keyLoginButton')));
      await tester.pumpAndSettle();

      expect(fakeKeyLogin.receivedMaterial, 'v1|ed:ID_PEM|x:WRAP_PEM');
      expect(fakeKeyLogin.receivedServer?.id, 'srv');
      expect(find.text('SETUP_PIN'), findsOneWidget);
    });

    testWidgets('routes to home when the account already has a PIN', (
      tester,
    ) async {
      fakeAuth
        ..fakeActiveAccount = fakeAccount(id: 'srv_user@test.com')
        ..fakeActiveServer = fakeServer()
        ..pinSetupAccounts = {'srv_user@test.com'};

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('recoveryKeyField')),
        'v1|ed:ID_PEM|x:WRAP_PEM',
      );
      await tester.tap(find.byKey(const Key('keyLoginButton')));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('surfaces a parse failure from the service', (tester) async {
      fakeKeyLogin.error = const FormatException(
        'This does not look like a Hoodik recovery key',
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('recoveryKeyField')),
        'not a key',
      );
      await tester.tap(find.byKey(const Key('keyLoginButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('This does not look like a Hoodik recovery key'),
        findsOneWidget,
      );
    });

    testWidgets('surfaces a rejected key from the service', (tester) async {
      fakeKeyLogin.error = const KeyLoginException(
        'The server did not recognize this key',
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('recoveryKeyField')),
        'v1|ed:ID_PEM|x:WRAP_PEM',
      );
      await tester.tap(find.byKey(const Key('keyLoginButton')));
      await tester.pumpAndSettle();

      expect(
        find.text('The server did not recognize this key'),
        findsOneWidget,
      );
    });
  });
}
