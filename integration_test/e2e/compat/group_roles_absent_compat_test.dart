import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../test_hooks.dart';
import 'compat_helpers.dart';

/// The "group surface must stay hidden on a server that doesn't speak groups"
/// gate.
///
/// Share groups (`/api/capabilities` advertising `share_groups`, plus the
/// `groups` routes and the client-side share-to-group fan-out) are on master;
/// no released tag has them. Every server in the matrix therefore reports
/// `share_groups == false`, and the client must keep the Groups tab and the
/// share-dialog group target hidden so an old server never receives a call its
/// routes don't wire.
///
/// The whole group UI keys on `sharing.enabled && share_groups`, so reading the
/// live probe and confirming `share_groups` is off is the strongest cross-version
/// signal — the same shape as the sibling `sharing_absent_compat_test`.
void main() {
  patrolSetUp(() async {
    loadCompatTarget();
    await TestHooks.wipeLocalState();
  });

  patrolTest('compat group surface stays hidden when absent', ($) async {
    final caps = loadCompatTarget();

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

    final capabilities = await client!.shares.getCapabilities();

    // No released tag ships share groups, so the probe must report the flag off
    // (or a fail-closed default against a 404). A true here means the matrix
    // gained a tag with the feature and this absent-path test no longer applies
    // to it — fail loud so the table is kept honest.
    expect(
      capabilities.shareGroups,
      isFalse,
      reason:
          'compat[${caps.version}]: server predates share groups; its '
          '/api/capabilities must report share_groups disabled (or 404 to the '
          'fail-closed default). A true here means the matrix is stale.',
    );
  });
}
