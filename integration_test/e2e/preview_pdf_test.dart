import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';
import 'package:pdfx/pdfx.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #7 from spec §4. Upload the PDF fixture, open it, and verify
/// the `pdfx` view renders.
///
/// Note on page-swipe assertion: the synthetic PDF from
/// [Fixtures._synthesizePdf] is a single-page document padded to
/// 10 MB with an incompressible content stream. That exercises the
/// decrypt + streaming + render path realistically without making
/// the test environment depend on a bundled multi-page asset. When a
/// real multi-page fixture is introduced, the swipe portion here
/// should drive `PdfViewPinch.nextPage` and assert the page counter.
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
  });

  patrolTest('pdfx renders the decrypted PDF fixture', ($) async {
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
    final fixtureName = fixtures.pdf10mb.uri.pathSegments.last;
    await $.waitUntilVisible(
      $(fixtureName),
      timeout: const Duration(seconds: 120),
    );
    await $(fixtureName).tap();

    await $.waitUntilVisible(
      $(PdfViewPinch),
      timeout: const Duration(seconds: 30),
    );
    expect(
      $(PdfViewPinch).evaluate().isNotEmpty,
      isTrue,
      reason: 'PdfViewPinch must build once the decrypted PDF is on disk',
    );
  });
}
