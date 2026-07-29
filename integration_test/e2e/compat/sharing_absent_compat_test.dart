import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/shares/services/move_router.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../test_hooks.dart';
import 'compat_helpers.dart';

/// The "move funnel must degrade on a server that doesn't speak sharing" gate.
///
/// Account-to-account sharing (`/api/capabilities` advertising
/// `sharing.enabled`, plus the `move-into-shared` / `move-out-of-shared`
/// endpoints) is on master; no released tag has it. Every server in the matrix
/// therefore reports sharing off, and the client must never reach for the
/// absent endpoints — [MoveRouter] gates every shared path on the live
/// `sharingEnabled` flag and falls back to a plain `move-many`. If that gate
/// regresses, a self-hoster on an older server would have every move into a
/// folder fail against an endpoint their server never wired.
///
/// The strongest signal is to read the *live* capabilities off the target
/// server and feed them into the real router, rather than asserting against a
/// mock — that proves the probe shape and the degradation routing together.
void main() {
  patrolSetUp(() async {
    loadCompatTarget();
    await TestHooks.wipeLocalState();
  });

  patrolTest('compat move funnel degrades when sharing is absent', ($) async {
    final caps = loadCompatTarget();
    if (caps.hasSharing) {
      // If a future matrix tag ships sharing, this absent-endpoint path no
      // longer exists for it — skip instead of asserting so the file stays
      // honest across the whole matrix without edits.
      markTestSkipped('compat[$caps]: server advertises sharing');
      return;
    }

    unawaited(app.main());
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    await compatLogin($);
    final container = await TestHooks.waitForContainer($);
    final client = container.read(apiClientProvider);
    expect(
      client,
      isNotNull,
      reason: 'compat[$caps]: ApiClient must be live after compatLogin',
    );

    // The live capability probe must report sharing off on a non-sharing
    // server — this is the master gate the whole move funnel keys on.
    final capabilities = await client!.shares.getCapabilities();
    expect(
      capabilities.sharingEnabled,
      isFalse,
      reason:
          'compat[$caps]: ${caps.version} predates account-to-account sharing; '
          'its /api/capabilities must report sharing disabled (or 404 to the '
          'fail-closed default). A true here means the table is stale.',
    );

    // Feed that gate into the real router: an owned folder dropped onto a
    // folder that *looks* shared (a signed roster) must still classify as a
    // plain move, because sharing is off — the absent endpoints are never hit.
    final router = MoveRouter(
      files: client.files,
      sharingEnabled: capabilities.sharingEnabled,
    );
    final decision = await router.classify(
      sources: [FileItem(id: 'src', encryptedName: 'e', mime: 'dir')],
      destination: FileItem(
        id: 'dst',
        encryptedName: 'e',
        mime: 'dir',
        membersSignedAt: 1736000000,
      ),
    );
    expect(
      decision,
      isA<PlainMove>(),
      reason:
          'compat[$caps]: with sharing off the funnel must fall back to a plain '
          'move-many; if it routes to move-into-shared, every move into a folder '
          'breaks for self-hosters on a server without the sharing endpoints',
    );
  });
}
