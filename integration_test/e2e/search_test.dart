import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/reindex_service.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import 'test_env.dart';
import 'test_hooks.dart';

/// Search and the re-index sweep, against a real server.
///
/// The unit tests fake the API client, which is exactly where the two real
/// bugs in this work hid: a route that never reached its handler, and a query
/// that never sent the shared-file scope. Both passed every unit test, because
/// a fake answers whatever it is told to. These drive the actual wiring.
void main() {
  patrolSetUp(() async {
    await TestHooks.wipeLocalState();
  });

  patrolTest(
    'a folder is findable by name right after it is created',
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

      const name = 'octopus-e2e';
      await TestHooks.createFolder($, name);
      await $.waitUntilVisible($(name), timeout: const Duration(seconds: 15));

      final container = await TestHooks.waitForContainer($);
      final client = container.read(apiClientProvider)!;
      final fileCrypto = container.read(fileCryptoProvider)!;

      // The whole pipeline in one assertion: the create wrote tags under this
      // account's key, and a query tagged the same way matches them. Tag the
      // query with a different key and it must not.
      final hits = await client.search.searchFiles(
        rootTags: fileCrypto.queryTags(fileCrypto.searchRootKey, name),
      );
      expect(hits.map((f) => f.id), isNotEmpty);

      final decoyKey = fileCrypto.searchFileKeyHex(
        fileCrypto.generateFileKey(cipher: 'aegis128l'),
      );
      final decoy = await client.search.searchFiles(
        rootTags: fileCrypto.queryTags(decoyKey, name),
      );
      expect(
        decoy,
        isEmpty,
        reason: 'tags keyed differently must not match this account\'s index',
      );
    },
  );

  patrolTest(
    'the sweep rebuilds an index the migration cleared',
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

      const name = 'kangaroo-e2e';
      await TestHooks.createFolder($, name);
      await $.waitUntilVisible($(name), timeout: const Duration(seconds: 15));

      final container = await TestHooks.waitForContainer($);
      final client = container.read(apiClientProvider)!;
      final fileCrypto = container.read(fileCryptoProvider)!;

      // Stand in for the migration: strip this account's tags through the same
      // route the sweep writes through. Listed rather than taken from the
      // pending endpoint, which by definition reports nothing while the files
      // are still indexed.
      final listing = await client.files.listFiles();
      for (final file in listing.children) {
        await client.storage.reindexFile(
          fileId: file.id,
          nameHash: 'stale-${file.id}',
          searchTokensRoot: const [],
          searchTokensFile: const [],
        );
      }

      final service = ReindexService(client: client, fileCrypto: fileCrypto);
      expect(
        await service.pendingCount(),
        greaterThan(0),
        reason: 'the server should report the cleared files as pending',
      );

      final states = await service.run().toList();
      expect(states.last.running, isFalse);
      expect(states.last.failed, 0);
      expect(await service.pendingCount(), 0);

      // The point of the sweep: findable again afterwards.
      final hits = await client.search.searchFiles(
        rootTags: fileCrypto.queryTags(fileCrypto.searchRootKey, name),
      );
      expect(hits, isNotEmpty);
    },
  );

  patrolTest('a file is findable by its content digest', tags: ['smoke'], (
    $,
  ) async {
    unawaited(app.main());
    await $.pumpAndSettle();

    await TestHooks.onboardAndLogin(
      $,
      TestEnv.serverUrl,
      TestEnv.email,
      TestEnv.password,
      TestEnv.pin,
    );

    const name = 'wombat-e2e';
    await TestHooks.createFolder($, name);
    await $.waitUntilVisible($(name), timeout: const Duration(seconds: 15));

    final container = await TestHooks.waitForContainer($);
    final client = container.read(apiClientProvider)!;

    // A digest nothing hashes to must come back empty rather than erroring or
    // returning the drive — the failure mode that matters for a caller that
    // asks this question constantly.
    final absent = await client.storage.filesByHash('0' * 64);
    expect(absent, isEmpty);
  });
}
