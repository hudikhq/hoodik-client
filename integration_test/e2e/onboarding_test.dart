import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #1 from spec §4. Fresh install → add server → login → set PIN →
/// land on the files screen. Asserts Drift has exactly one server and one
/// account, the decrypted private key is populated, and the router
/// settled on `/` (the files screen root).
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
    'first-time onboarding: add server, login, set PIN, reach files',
    tags: ['smoke'],
    ($) async {
      unawaited(app.main());
      await $.pumpAndSettle();

      await $(#serverUrlField).enterText(TestEnv.serverUrl);
      await $('Add Server').tap();

      await $(#emailField).enterText(TestEnv.email);
      await $(#passwordField).enterText(TestEnv.password);
      await $(#signInButton).tap();
      // Sign In leaves the soft keyboard up; SetupPinScreen mounts behind it
      // so pinField fails Patrol's hit-test until we dismiss the IME.
      await $.pumpAndSettle(timeout: const Duration(seconds: 20));
      await $.native.pressBack();
      await $.pumpAndSettle();

      await $(#pinField).enterText(TestEnv.pin);
      await $(#pinConfirmField).enterText(TestEnv.pin);
      await $('Set PIN').tap();

      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      final container = TestHooks.containerForTest();
      final db = container.read(databaseProvider);
      final servers = await db.select(db.servers).get();
      final accounts = await db.select(db.accounts).get();

      expect(servers, hasLength(1), reason: 'exactly one server after onboard');
      expect(
        accounts,
        hasLength(1),
        reason: 'exactly one account after onboard',
      );

      final privateKey = container.read(decryptedPrivateKeyProvider);
      expect(
        privateKey,
        isNotNull,
        reason: 'private key must be in memory after login+PIN',
      );

      expect(TestHooks.currentRoute(), '/');

      final pinRow = await TestHooks.readPinRow(db);
      expect(pinRow, isNotNull, reason: 'PIN row must persist');
    },
  );
}
