import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/tar_fallback.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../test_hooks.dart';
import 'compat_helpers.dart';

/// The degradation gate. Servers older than the tar-upload route must reject
/// `POST /api/storage/:id?format=tar` with an error that
/// [shouldFallbackToPerChunk] classifies as capability-missing rather than
/// transient. That classification is what flips [TarCapabilityCache] and
/// keeps uploads working against old servers. If the server's error shape
/// ever drifts in a way the matcher doesn't recognise, every self-hoster on
/// a tag older than the tar-upload feature starts seeing uploads hang.
///
/// We hit the route directly with Dio rather than going through
/// [BinaryUploadPipeline] because the pipeline needs encrypt workers, a
/// real staged file, and a full session — none of which add compat signal.
/// A single authenticated POST to the route produces the exact error the
/// classifier has to handle.
void main() {
  patrolSetUp(() async {
    loadCompatTarget();
    await TestHooks.wipeLocalState();
  });

  patrolTest('compat tar upload rejection classifies as fallback', ($) async {
    final caps = loadCompatTarget();
    if (caps.hasTarUpload) {
      // Future matrix additions: if a tag ever ships tar upload, the rejection
      // path this test covers goes away. Skip instead of assert so the test
      // file stays honest across the whole matrix without constant edits.
      markTestSkipped('compat[$caps]: server advertises tar upload route');
      return;
    }

    unawaited(app.main());
    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    final login = await compatLogin($);
    final container = await TestHooks.waitForContainer($);
    final client = container.read(apiClientProvider);
    expect(
      client,
      isNotNull,
      reason: 'compat[$caps]: ApiClient should be live after compatLogin',
    );

    // Any UUID-ish string does — the server rejects the tar *route* before
    // checking whether the file exists. The rejection shape (404/405 on
    // old servers that only wired per-chunk upload) is what the client
    // matcher has to recognise.
    final fakeFileId = login.account.userId.isEmpty
        ? 'compat-probe'
        : login.account.userId;
    DioException? caught;
    try {
      await client!.dio.post<void>(
        '/api/storage/$fakeFileId?format=tar',
        data: List<int>.filled(16, 0),
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Content-Type': 'application/octet-stream'},
        ),
      );
    } on DioException catch (e) {
      caught = e;
    }

    expect(
      caught,
      isNotNull,
      reason:
          'compat[$caps]: server should reject tar upload with a DioException; '
          'a 2xx here would mean the tag silently started supporting tar '
          'upload and our capability table is stale',
    );
    expect(
      shouldFallbackToPerChunk(caught!),
      isTrue,
      reason:
          'compat[$caps]: tar rejection "${caught.response?.statusCode} '
          '${caught.message}" must classify as fallback-eligible. If this '
          'fails, the server changed its rejection shape for absent routes '
          "and the client's per-chunk fallback is broken for self-hosters "
          'pinned to this tag.',
    );
  });
}
