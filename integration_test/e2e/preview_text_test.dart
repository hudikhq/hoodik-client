import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/preview/widgets/preview_text.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #8 from spec §4. Upload a small known-content `.txt` file,
/// open it, and verify the decrypted content decoded in
/// [PreviewText] matches the fixture bytes.
///
/// The 500 KB random fixture is impractical for visible-text
/// equality — we stage a small deterministic file instead, so the
/// assertion is a direct byte/string comparison of what was uploaded
/// versus what the preview shows.
void main() {
  late Fixtures fixtures;
  late File smallText;
  const sample = 'hoodik e2e preview text — unicode OK: αβγ 🌵';

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    smallText = File('${fixtures.rootDir.path}/preview-sample.txt');
    await smallText.writeAsString(sample);
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
  });

  patrolTest('text preview decodes uploaded content verbatim', ($) async {
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
    final fixtureName = smallText.uri.pathSegments.last;
    await $.waitUntilVisible(
      $(fixtureName),
      timeout: const Duration(seconds: 30),
    );
    await $(fixtureName).tap();

    await $.waitUntilVisible(
      $(PreviewText),
      timeout: const Duration(seconds: 15),
    );

    await $.pumpAndSettle();

    final textWidgets = $(PreviewText).$(Text);
    final rendered = textWidgets.evaluate().any((element) {
      final widget = element.widget as Text;
      return widget.data == sample;
    });
    expect(
      rendered,
      isTrue,
      reason: 'decoded text must match the uploaded fixture exactly',
    );
  });
}
