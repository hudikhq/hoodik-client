import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';
import 'package:photo_view/photo_view.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #5 from spec §4. Upload the 2 MB PNG fixture, tap it in the
/// list, and assert the image preview widget (`PhotoView`) renders the
/// decrypted bytes. The loader budget (10 seconds on a 5 MB image per
/// the spec) is asserted with a wall-clock timer wrapping the wait for
/// `PhotoView`; the 2 MB fixture must complete well inside that window.
///
/// Pre-seeding via a dedicated setup path was considered but rejected —
/// the upload flow is already exercised by [upload_download_test.dart]
/// and we need a decrypted file on the server anyway, so sharing the
/// UI upload path keeps the test a faithful end-to-end exercise of the
/// image preview pipeline.
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
  });

  patrolTest('image preview renders decrypted PhotoView under 10s', ($) async {
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

    final started = DateTime.now();
    await $(fixtureName).tap();

    await $.waitUntilVisible(
      $(PhotoView),
      timeout: const Duration(seconds: 15),
    );
    final elapsed = DateTime.now().difference(started);
    expect(
      elapsed.inSeconds,
      lessThan(10),
      reason: 'preview loader must complete in <10s on a 2 MB PNG',
    );

    expect(
      $(PhotoView).evaluate().isNotEmpty,
      isTrue,
      reason: 'PhotoView must build once the decrypted bytes are ready',
    );
    expect(
      $(CircularProgressIndicator).evaluate().isEmpty,
      isTrue,
      reason: 'no spinner should remain after full-resolution load',
    );
  });
}
