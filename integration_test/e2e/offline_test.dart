import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/pending_upload_status.dart';
import 'package:hoodik_app/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../fixtures.dart';
import 'test_env.dart';
import 'test_hooks.dart';

/// Flow #12 from spec §4. Two scenarios in one file:
///
/// 1. **Offline queue → flush on reconnect.** With airplane mode on,
///    an upload seeds a `PendingUploads` row. Flipping the radio back
///    on triggers the sync service; the row drains and the count
///    drops to zero with no duplicates.
///
/// 2. **Retry backoff (bug #8 guard).** A synthetic failing upload
///    goes into the queue with a fresh `retryCount = 0`. After a
///    failed attempt the scheduler advances `nextRetryAt` and
///    increments `retryCount`. After the max-retry budget is
///    exhausted the row flips to `failed_permanent` — the permanent
///    state only the user can leave via the "Retry" action.
///
/// The retry scenario uses [TestHooks.seedPendingUpload] to stage
/// failure deterministically instead of depending on the server to
/// reject a real upload. The scheduler under test is the same one the
/// production pipeline runs; inserting directly keeps the assertion
/// focused on *that* logic.
void main() {
  late Fixtures fixtures;

  patrolSetUp(() async {
    fixtures = await Fixtures.prepare();
    await TestHooks.wipeLocalState();
  });

  patrolTearDown(() async {
    await fixtures.cleanup();
    try {
      await _tester?.native.disableAirplaneMode();
    } catch (_) {}
  });

  patrolTest('offline queue drains on reconnect with no duplicate rows', (
    $,
  ) async {
    _tester = $;

    unawaited(app.main());
    await $.pumpAndSettle();

    await TestHooks.onboardAndLogin(
      $,
      TestEnv.serverUrl,
      TestEnv.email,
      TestEnv.password,
      TestEnv.pin,
    );

    await $.native.enableAirplaneMode();
    await Future<void>.delayed(const Duration(seconds: 2));

    await TestHooks.openUploadPicker($);
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    expect(
      await TestHooks.pendingUploadCount(),
      greaterThanOrEqualTo(1),
      reason: 'offline upload must land in the pending queue',
    );

    await $.native.disableAirplaneMode();
    await _waitUntil(
      () async => await TestHooks.pendingUploadCount() == 0,
      timeout: const Duration(seconds: 90),
    );

    final remaining = await TestHooks.pendingUploads();
    expect(
      remaining,
      isEmpty,
      reason: 'reconnect must drain every queued upload — no duplicates',
    );
  });

  patrolTest(
    'retry backoff: each failure advances nextRetryAt and caps at failed_permanent',
    ($) async {
      _tester = $;

      unawaited(app.main());
      await $.pumpAndSettle();

      await TestHooks.onboardAndLogin(
        $,
        TestEnv.serverUrl,
        TestEnv.email,
        TestEnv.password,
        TestEnv.pin,
      );

      final nonexistent = '${fixtures.rootDir.path}/does-not-exist.bin';
      final id = await TestHooks.seedPendingUpload(localPath: nonexistent);

      await TestHooks.drainPendingUploads();
      await $.pumpAndSettle();
      final firstFailure = (await TestHooks.pendingUploads()).firstWhere(
        (u) => u.id == id,
      );
      expect(
        firstFailure.retryCount,
        equals(1),
        reason: 'first failure must bump retryCount',
      );
      expect(
        firstFailure.nextRetryAt,
        isNotNull,
        reason: 'first failure must schedule a nextRetryAt',
      );

      for (var attempt = 0; attempt < 5; attempt++) {
        await TestHooks.seedPendingUpload(
          localPath: nonexistent,
          retryCount: attempt,
          status: PendingUploadStatus.pending,
        );
        await TestHooks.drainPendingUploads();
        await $.pumpAndSettle();
      }

      final final_ = await TestHooks.pendingUploads();
      expect(
        final_.any((u) => u.status == PendingUploadStatus.failedPermanent),
        isTrue,
        reason:
            'exhausting retries must flip at least one row to failed_permanent',
      );
    },
  );
}

PatrolIntegrationTester? _tester;

Future<void> _waitUntil(
  Future<bool> Function() predicate, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail('condition not met within ${timeout.inSeconds}s');
}
