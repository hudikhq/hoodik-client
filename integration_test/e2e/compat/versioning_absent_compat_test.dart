import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/server_version.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../test_hooks.dart';
import 'compat_helpers.dart';

/// The "app must recognise an older server and nudge the user" compat test.
///
/// Every tag in the matrix today predates v1.16.0 — when the `/api/liveness`
/// endpoint started returning the `version` field. The app treats that
/// absence as verified evidence the server is old, regardless of whether
/// the GitHub latest-release fetch succeeded. The outdated-server banner
/// keys off [LivenessInfo.isOutdatedAgainst]; if that signal breaks for a
/// real old server, self-hosters get no upgrade prompt.
///
/// Originally this covered the `.md file on non-editable server` widget
/// assertion, but driving the markdown editor through Patrol brings in the
/// same UI fragility the basic test was rewritten to avoid. The more
/// informative compat signal is the liveness probe's classification — and
/// that hits the same server-feature-parity surface (`files.editable`
/// presence correlates with server version, which the liveness reports).
void main() {
  patrolSetUp(() async {
    loadCompatTarget();
    await TestHooks.wipeLocalState();
  });

  patrolTest('compat older server flagged as outdated', ($) async {
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

    final liveness = await client!.auth.checkLiveness();
    expect(
      liveness.alive,
      isTrue,
      reason: 'compat[$caps]: /api/liveness must respond on a booted server',
    );

    // Every version in the matrix today is older than v1.16.0 (which adds
    // the `version` field). Confirm both the absence of the field AND the
    // outdated classification — the banner uses the latter.
    expect(
      liveness.version,
      isNull,
      reason:
          'compat[$caps]: ${caps.version} predates v1.16.0\'s liveness '
          'version field — expected null, got ${liveness.version}',
    );
    // Pass `null` for the latest release: pre-v1.16.0 servers are flagged
    // by the absence-of-version branch alone, so the test doesn't depend
    // on GitHub being reachable from the emulator.
    expect(
      liveness.isOutdatedAgainst(null),
      isTrue,
      reason:
          'compat[$caps]: ${caps.version} must classify as outdated by the '
          'missing-version-field branch alone (it predates v1.16.0); if this '
          'silently passes, the banner is broken and self-hosters never see it',
    );
  });
}
