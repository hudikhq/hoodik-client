import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../test_hooks.dart';
import 'compat_helpers.dart';

/// The happy-path compat test. Runs against every server version in the
/// matrix — if this breaks, the app isn't shippable regardless of which
/// graceful-degradation paths work.
///
/// We verify the *protocol* layer, not the UI. Driving the add-server +
/// login flow through the real AuthService API exercises every piece the
/// compat gate cares about:
///
/// * HTTP compatibility with the older server's `/api/liveness`,
///   `/api/auth/login`, and `/api/auth/self` endpoints.
/// * RSA-2048 fingerprint round-trip (server hashes same way the client
///   generates).
/// * Ascon-128a private-key decryption (the single most important compat
///   assertion — a null `decryptedPrivateKey` means the crypto stack
///   drifted between the fixture and the live code).
///
/// Upload/download/delete end-to-end are UI-reachable flows covered by
/// the release-check e2e suite; the compat gate does not need to re-prove
/// them against every old tag.
void main() {
  patrolSetUp(() async {
    loadCompatTarget();
    await TestHooks.wipeLocalState();
  });

  patrolTest('compat login and crypto round trip', ($) async {
    unawaited(app.main());
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    final caps = loadCompatTarget();
    final result = await compatLogin($);

    expect(
      result.account.email,
      equals(CompatEnv.email),
      reason: 'compat[$caps]: server must echo the registered email',
    );
    expect(
      result.account.fingerprint,
      isNotNull,
      reason: 'compat[$caps]: login response must carry the user fingerprint',
    );
    expect(
      result.account.fingerprint!.length,
      greaterThan(60),
      reason: 'compat[$caps]: fingerprint is SHA-256 hex — expect 64 chars',
    );
    expect(
      result.account.publicKey,
      isNotNull,
      reason: 'compat[$caps]: login response must include pubkey',
    );
    expect(
      result.server.url,
      equals(CompatEnv.serverUrl),
      reason: 'compat[$caps]: Drift persisted the right base URL',
    );
    // compatLogin already asserts decryptedPrivateKey != null via StateError;
    // this test reaching here is itself the proof.
  });
}
