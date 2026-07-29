import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';
import 'package:hoodik_app/features/account/widgets/recovery_key_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  Widget buildApp({String? identity}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: RecoveryKeyTile()),
        ),
        GoRoute(
          path: '/account/recovery-key',
          builder: (_, _) => const Text('RECOVERY_KEY_SCREEN'),
        ),
      ],
    );

    return ProviderScope(
      overrides: [decryptedPrivateKeyProvider.overrideWith((ref) => identity)],
      child: MaterialApp.router(
        theme: HoodikTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('hidden while no private key is in memory', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Recovery Key'), findsNothing);
  });

  testWidgets('opens the recovery-key screen when tapped', (tester) async {
    await tester.pumpWidget(buildApp(identity: 'ID_PEM'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recovery Key'));
    await tester.pumpAndSettle();

    expect(find.text('RECOVERY_KEY_SCREEN'), findsOneWidget);
  });
}
