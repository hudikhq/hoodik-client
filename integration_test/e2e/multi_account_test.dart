import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #11 from spec §4. Onboard account A, add a second server and
/// log in as account B, then switch back to A. Verifies per-account
/// cookie-jar isolation, private-key provider swap, and that the
/// landing state after the second switch reflects account A — not a
/// leaked copy of B's.
///
/// The second account reuses [TestEnv.serverUrl] with the suffix
/// `/b` — Hoodik servers commonly run on a subpath for this exact
/// scenario, and a shared backend is sufficient because the app
/// keys accounts by `(serverId, userId)`. If the local demo server
/// cannot serve a second virtual instance, override the URL via
/// `--dart-define=HOODIK_E2E_URL_B` for tests running in CI.
void main() {
  late Fixtures fixtures;
  const serverUrlB = String.fromEnvironment(
    'HOODIK_E2E_URL_B',
    defaultValue: '${TestEnv.serverUrl}/b',
  );
  const emailB = String.fromEnvironment(
    'HOODIK_E2E_EMAIL_B',
    defaultValue: 'e2e-b@hoodik.local',
  );
  const passwordB = String.fromEnvironment(
    'HOODIK_E2E_PASSWORD_B',
    defaultValue: 'e2e-user-b-password-1234',
  );
  const pinB = String.fromEnvironment(
    'HOODIK_E2E_PIN_B',
    defaultValue: '654321',
  );

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
  });

  patrolTest('switch between two accounts preserves per-account isolation', (
    $,
  ) async {
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
    final accountA = container.read(activeAccountProvider);
    final pkA = container.read(decryptedPrivateKeyProvider);
    expect(accountA, isNotNull);
    expect(pkA, isNotNull);

    await $('Account').tap();
    await $('Manage Accounts').tap();
    await $.pumpAndSettle();

    await TestHooks.onboardAndLogin($, serverUrlB, emailB, passwordB, pinB);

    final accountB = container.read(activeAccountProvider);
    final pkB = container.read(decryptedPrivateKeyProvider);
    expect(accountB, isNotNull);
    expect(
      accountB!.id,
      isNot(equals(accountA!.id)),
      reason: 'second login must produce a distinct account row',
    );
    expect(
      pkB,
      isNotNull,
      reason: 'account B must have its private key in memory after login',
    );
    expect(
      pkB,
      isNot(equals(pkA)),
      reason: 'private keys must differ between the two accounts',
    );

    await $('Account').tap();
    await $(accountA.email).tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    final accountAfterSwitch = container.read(activeAccountProvider);
    expect(
      accountAfterSwitch?.id,
      equals(accountA.id),
      reason: 'switching back must restore account A',
    );
    final pkAfterSwitch = container.read(decryptedPrivateKeyProvider);
    expect(
      pkAfterSwitch,
      isNot(equals(pkB)),
      reason: 'private key must swap back to A — never leak B into A session',
    );
  });
}
