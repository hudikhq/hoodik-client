import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #4 from spec §4. Create a folder named "e2e-test", navigate
/// into it, upload the 2 MB PNG fixture, pop back to the root, enter
/// the folder again, and assert the uploaded file appears.
///
/// Folder names are client-side encrypted, so the assertion on
/// presence runs against the decrypted display-name map owned by
/// [FilesNotifier]. The `parent_id` check confirms the folder row
/// wrote correctly — the backend stores only the encrypted name, and
/// a broken parent link would silently orphan the file.
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
  });

  patrolTest('create folder, upload into it, navigate back and in', ($) async {
    unawaited(app.main());
    await $.pumpAndSettle();

    await TestHooks.onboardAndLogin(
      $,
      TestEnv.serverUrl,
      TestEnv.email,
      TestEnv.password,
      TestEnv.pin,
    );

    const folderName = 'e2e-test';
    await TestHooks.createFolder($, folderName);

    await $.waitUntilVisible(
      $(folderName),
      timeout: const Duration(seconds: 15),
    );
    await $(folderName).tap();
    await $.pumpAndSettle();

    expect(
      TestHooks.currentRoute().startsWith('/files/'),
      isTrue,
      reason: 'navigating into a folder must push /files/:dirId',
    );

    final dirId = _currentDirId();
    expect(dirId, isNotNull, reason: 'files route must carry a dirId segment');

    await TestHooks.openUploadPicker($);
    final fixtureName = fixtures.png2mb.uri.pathSegments.last;
    await $.waitUntilVisible(
      $(fixtureName),
      timeout: const Duration(seconds: 60),
    );

    final containerBeforeBack = TestHooks.containerForTest();
    final stateBeforeBack = containerBeforeBack.read(
      filesNotifierProvider(dirId),
    );
    final uploadedFile = stateBeforeBack.files!.firstWhere(
      (f) => !f.isDir,
      orElse: () => throw StateError('no uploaded file in folder state'),
    );
    expect(
      uploadedFile.fileId,
      equals(dirId),
      reason: 'uploaded file must carry parent_id = folder dirId',
    );

    await $(Icons.arrow_back).tap();
    await $.pumpAndSettle();

    await $.waitUntilVisible(
      $(folderName),
      timeout: const Duration(seconds: 10),
    );
    await $(folderName).tap();
    await $.pumpAndSettle();

    await $.waitUntilVisible(
      $(fixtureName),
      timeout: const Duration(seconds: 10),
    );
    expect(
      $(fixtureName).evaluate().isNotEmpty,
      isTrue,
      reason: 're-entering the folder must show the previously uploaded file',
    );
  });
}

String? _currentDirId() {
  final route = TestHooks.currentRoute();
  const prefix = '/files/';
  if (!route.startsWith(prefix)) return null;
  return route.substring(prefix.length).split('?').first;
}
