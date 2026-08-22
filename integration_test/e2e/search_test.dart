import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
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

  // CLAUDE.md security rule 6, born from a real incident where this client
  // POSTed raw search queries for months: assert against the bytes actually
  // serialized, with a term whose characters cannot occur in a hex digest, so
  // a substring check on the raw body is conclusive. Runs here rather than in
  // a unit test because it must drive the query through the real FFI
  // tokenizer, not a mock.
  patrolTest('a plaintext query never reaches the wire', tags: ['smoke'], (
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

    final container = await TestHooks.waitForContainer($);
    final client = container.read(apiClientProvider)!;
    final fileCrypto = container.read(fileCryptoProvider)!;

    // 'zanzibar' contains characters (z, i) that never appear in a hex
    // digest, so finding it anywhere in the raw body is unambiguous.
    const term = 'zanzibar';
    final bodies = <String>[];
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/api/storage/search')) {
            bodies.add(jsonEncode(options.data));
          }
          handler.next(options);
        },
      ),
    );

    await client.search.searchFiles(
      rootTags: [
        ...fileCrypto.queryTags(fileCrypto.searchRootKey, term),
        // The exact-match tag every real query carries — the digest-search
        // path, exercised here to prove it leaks nothing either.
        fileCrypto.exactTag(fileCrypto.searchRootKey, term),
      ],
    );

    expect(bodies, isNotEmpty, reason: 'the search request should have been captured');
    for (final raw in bodies) {
      expect(
        raw.toLowerCase().contains(term),
        isFalse,
        reason: 'the plaintext query leaked into the request body: $raw',
      );
      final digest = sha256.convert(utf8.encode(term)).toString();
      expect(
        raw.contains(digest),
        isFalse,
        reason: 'the unsalted digest of the query leaked into the body',
      );
    }
  });

  patrolTest(
    'the sweep runs clean on a healthy account and search still works',
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

      // A file only becomes pending when its keyed `name_hash` is blanked,
      // which happens in the re-key migration and the OPAQUE key rotation —
      // neither reachable from a client over HTTP, so this exercises the
      // drained steady state rather than forcing one. The sweep must complete
      // reporting nothing pending, never spin.
      final service = ReindexService(client: client, fileCrypto: fileCrypto);
      final states = await service.run().toList();
      expect(states.last.running, isFalse);
      expect(states.last.failed, 0);

      // Freshly created files carry keyed tags already, so they are findable
      // without any sweep.
      final hits = await client.search.searchFiles(
        rootTags: fileCrypto.queryTags(fileCrypto.searchRootKey, name),
      );
      expect(hits, isNotEmpty);
    },
  );
}
