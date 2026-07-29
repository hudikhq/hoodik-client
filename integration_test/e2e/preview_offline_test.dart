import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';
import 'package:photo_view/photo_view.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #9 from spec §4 — permanent regression guard for the
/// "offline preview re-downloads" bug (Wave 4 fix). Upload an image,
/// open it once (populates offline cache), close the preview, toggle
/// the device to airplane mode, then reopen the same file. If the
/// preview still renders while the network is down, the offline
/// cache served it — no round-trip.
///
/// Airplane mode stands in for zero-HTTP-request verification: `Dio`
/// is private to `ApiClient` and plumbing an interceptor through a
/// test-only hook would need a production-side seam. Toggling the
/// radios is both simpler and more faithful — any accidental network
/// fallback would *fail*, not silently "work because the server
/// happened to answer fast."
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
    try {
      final tester = await _activeTester?.call();
      await tester?.native.disableAirplaneMode();
    } catch (_) {}
  });

  patrolTest('preview loads from offline cache while airplane mode is on', (
    $,
  ) async {
    _activeTester = () async => $;

    unawaited(app.main());
    await $.pumpAndSettle();

    await TestHooks.onboardAndLogin(
      $,
      TestEnv.serverUrl,
      TestEnv.email,
      TestEnv.password,
      TestEnv.pin,
    );

    await TestHooks.openUploadPicker($);
    final fixtureName = fixtures.png2mb.uri.pathSegments.last;
    await $.waitUntilVisible(
      $(fixtureName),
      timeout: const Duration(seconds: 60),
    );

    await $(fixtureName).tap();
    await $.waitUntilVisible(
      $(PhotoView),
      timeout: const Duration(seconds: 15),
    );

    // Preview screen closes on a swipe-down dismiss gesture — equivalent
    // to the user's back-swipe — which works on both iOS and Android
    // without a hardware/software back button.
    await $.tester.flingFrom(const Offset(200, 200), const Offset(0, 600), 800);
    await $.pumpAndSettle();

    await $.native.enableAirplaneMode();
    await Future<void>.delayed(const Duration(seconds: 2));

    final started = DateTime.now();
    await $(fixtureName).tap();
    await $.waitUntilVisible(
      $(PhotoView),
      timeout: const Duration(seconds: 10),
    );
    final elapsed = DateTime.now().difference(started);
    expect(
      elapsed.inSeconds,
      lessThan(10),
      reason: 'offline preview must serve from cache within 10s',
    );
  });
}

Future<PatrolIntegrationTester> Function()? _activeTester;
