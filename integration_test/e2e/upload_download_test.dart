import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #3 from spec §4: upload a 2 MB PNG, find it in the list, download
/// it to a temp path, and assert the SHA-256 of the downloaded bytes
/// equals the SHA-256 of the fixture. This is the single most
/// regression-prone path — chunked encryption, CRC16, multipart upload,
/// decrypted re-assembly — exercised end-to-end through real UI taps.
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
    'upload 2MB PNG, list, download, verify byte equality',
    tags: ['smoke'],
    ($) async {
      unawaited(app.main());
      await $.pumpAndSettle();

      await TestHooks.onboardAndLogin(
        $,
        TestEnv.serverUrl,
        TestEnv.email,
        TestEnv.password,
        TestEnv.pin,
      );

      // FAB opens the "Create Folder / Upload Media / Take Photo" bottom
      // sheet; "Upload Media" is the option that triggers the system file
      // picker (lib/features/files/widgets/file_actions_sheet.dart).
      await $(#filesFab).tap();
      await $('Upload Media').tap();
      await $.native.tap(Selector(text: 'Choose File'));

      final upload = fixtures.png2mb;
      expect(await upload.exists(), isTrue);

      await $.waitUntilVisible(
        $(upload.uri.pathSegments.last),
        timeout: const Duration(seconds: 60),
      );

      await $(upload.uri.pathSegments.last).tap();
      await $('Download').tap();

      final downloaded = File('${fixtures.rootDir.path}/downloaded.png');
      await _waitForFile(downloaded, timeout: const Duration(seconds: 60));

      final originalHash = crypto.sha256.convert(await upload.readAsBytes());
      final downloadedHash = crypto.sha256.convert(
        await downloaded.readAsBytes(),
      );

      expect(
        downloadedHash,
        equals(originalHash),
        reason: 'downloaded bytes must match the original 2MB PNG exactly',
      );
    },
  );
}

Future<void> _waitForFile(File file, {required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await file.exists()) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail(
    'file did not appear on disk within ${timeout.inSeconds}s: ${file.path}',
  );
}
