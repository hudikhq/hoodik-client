import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #14 from spec §4: the E2EE promise. Logout MUST null the
/// in-memory private key; a subsequent file operation MUST redirect to
/// the login screen. If either assertion fails, decrypted key material
/// survives a session boundary — exactly the regression this test
/// exists to catch.
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
  });

  patrolTest(
    'logout clears the decrypted private key and blocks file ops',
    tags: ['smoke'],
    ($) async {
      unawaited(app.main());
      await $.pumpAndSettle();

      await TestHooks.onboardAndLogin(
        $,
        TestEnv.serverUrl,
        TestEnv.email,
        TestEnv.password,
        TestEnv.pin,
      );

      final container = TestHooks.containerForTest();
      expect(
        container.read(decryptedPrivateKeyProvider),
        isNotNull,
        reason: 'private key must be populated after login',
      );

      await $('Account').tap();
      await $.pumpAndSettle();
      // Tile is keyed in lib/features/account/widgets/sign_out_section.dart;
      // the confirmation dialog's primary action and title are both "Sign
      // Out" — `.last` targets the dialog action button (newest in tree).
      await $(#signOutTile).scrollTo().tap();
      await $.pumpAndSettle();
      await $('Sign Out').last.tap();
      await $.pumpAndSettle();

      expect(
        container.read(decryptedPrivateKeyProvider),
        isNull,
        reason: 'logout must null the in-memory private key',
      );

      await $('Upload').tap().catchError((_) => null);
      await $.pumpAndSettle();

      expect(
        TestHooks.currentRoute(),
        anyOf('/auth/login', '/setup/server', '/auth/unlock'),
        reason: 'file ops after logout must redirect to an auth screen',
      );
    },
  );
}
