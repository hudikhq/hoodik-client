import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/pending_uploads_dao.dart';
import 'package:hoodik_app/main.dart';
import 'package:patrol/patrol.dart';

/// Phase 1 + 2 test hooks. Each helper encapsulates one piece of state that
/// E2E tests need to inspect — kept here so individual test files stay
/// focused on user flow, not Riverpod plumbing.
///
/// Every accessor reads from the running app's `ProviderScope` via
/// [ProviderScope.containerOf] on a known root key. If any of these
/// helpers start accumulating real logic, split it into a dedicated
/// file — this is glue, not a framework.
class TestHooks {
  TestHooks._();

  /// Returns the provider container used by the currently running app
  /// instance. Tests assert on providers (auth state, private key,
  /// active account) via this container instead of trying to thread a
  /// `WidgetRef` through Patrol's `PatrolTester`.
  static ProviderContainer containerForTest() {
    final element = appRouter.routerDelegate.navigatorKey.currentContext;
    if (element == null) {
      throw StateError('router navigator has no context — app not running?');
    }
    return ProviderScope.containerOf(element, listen: false);
  }

  /// Poll until [containerForTest] succeeds — needed for tests that call
  /// `unawaited(app.main())` and then skip straight to provider reads
  /// (like the compat gate) without driving any UI. Without this poll
  /// the provider lookup fires before main() finishes registering the
  /// `late final appRouter`, and the test dies with `LateInitialization
  /// Error: Field 'appRouter' has not been initialized`.
  ///
  /// Pass [tester] so the poll actively pumps frames while waiting —
  /// plain `Future.delayed` lets us yield control, but the test binding
  /// won't build widgets (and thus won't assign `appRouter`) unless
  /// something drives its frame scheduler. On Android cold-boot, the
  /// app's async init (RustLib.init, Preferences.load) plus the first
  /// widget build routinely takes 10–20 s before `appRouter` is live.
  static Future<ProviderContainer> waitForContainer(
    PatrolIntegrationTester $, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        return containerForTest();
      } catch (_) {
        // pumpAndSettle with a short per-call timeout — we just need
        // ONE frame per poll, not a full settle, so the widget tree
        // keeps making forward progress while we wait for appRouter
        // to appear.
        try {
          await $.pumpAndSettle(timeout: const Duration(seconds: 1));
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    }
    throw StateError(
      'waitForContainer: appRouter / ProviderScope never came up within '
      '${timeout.inSeconds}s — check that app.main() actually runs and '
      'that a ProviderScope wraps the router',
    );
  }

  /// Current router location. Tests use this instead of inspecting
  /// widgets because GoRouter does not put the path into a findable
  /// `Text` node on every screen.
  static String currentRoute() {
    return appRouter.routerDelegate.currentConfiguration.uri.toString();
  }

  /// Clears the Drift database so each test starts from a fresh-install
  /// state. We do this rather than wiping the underlying SQLite file so
  /// the schema stays consistent with the running app.
  static Future<void> wipeLocalState() async {
    try {
      final container = containerForTest();
      final db = container.read(databaseProvider);
      await db.customStatement('DELETE FROM pending_uploads');
      await db.customStatement('DELETE FROM offline_files');
      await db.customStatement('DELETE FROM accounts');
      await db.customStatement('DELETE FROM servers');
    } catch (_) {
      // Pre-launch state: no container yet. First test will start clean
      // because the temp data dir does not have a DB file.
    }
  }

  /// Reads the per-account PIN row if present. Returns `null` when the
  /// user has not set a PIN yet. Column is named `pin_encrypted_private_key`
  /// in SQL (the Drift `pinEncryptedPrivateKey` column).
  static Future<dynamic> readPinRow(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM accounts WHERE pin_encrypted_private_key IS NOT NULL LIMIT 1',
          variables: const <Variable>[],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data;
  }

  /// Drives the onboarding flow end-to-end. Extracted here because
  /// multiple flows (upload, download, logout, preview) share it —
  /// duplicating the taps across every test file would invite drift.
  static Future<void> onboardAndLogin(
    PatrolIntegrationTester $,
    String serverUrl,
    String email,
    String password,
    String pin,
  ) async {
    await $(#serverUrlField).enterText(serverUrl);
    // Button label is 'Add Server' (title case) in lib/features/auth/screens/
    // add_server_screen.dart. Patrol's text finder is exact by default.
    await $('Add Server').tap();

    await $(#emailField).enterText(email);
    await $(#passwordField).enterText(password);
    // The string "Sign In" also renders as the AppBar title when a server
    // has no nickname set, so patrol's text finder hits both widgets and
    // taps the wrong one. Target the button by Key.
    await $(#signInButton).tap();

    // Login triggers a network round-trip (auth/login → auth/self) before
    // GoRouter pushes /auth/setup-pin. Bump the visibility window to 20s to
    // cover cold-boot Android emulators.
    await $.pumpAndSettle(timeout: const Duration(seconds: 20));
    // The Sign In tap leaves the soft keyboard up over the password field;
    // when SetupPinScreen mounts, the keyboard still covers the PIN inputs
    // and Patrol's hit-test reports them as not-visible. Send a "done"
    // action so the IME closes — this also fires before SetupPinScreen
    // tries to autofocus, so the PIN field becomes hit-testable.
    await $.native.pressBack();
    await $.pumpAndSettle();
    await $.waitUntilVisible(
      $(#pinField),
      timeout: const Duration(seconds: 20),
    );
    await $(#pinField).enterText(pin);
    await $(#pinConfirmField).enterText(pin);
    await $('Set PIN').tap();

    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  }

  /// Drives the FAB → "Create Folder" flow. Taps the floating "+" icon,
  /// picks Create Folder from the bottom sheet, enters [name] into the
  /// first TextField on screen, and confirms.
  static Future<void> createFolder(
    PatrolIntegrationTester $,
    String name,
  ) async {
    await $(FloatingActionButton).tap();
    await $('Create Folder').tap();
    await $(TextField).enterText(name);
    await $('OK').tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
  }

  /// Opens the FAB → "Upload File" sheet and taps the platform file
  /// picker's "Choose File" affordance. The caller must have staged the
  /// file in a location the simulator's picker can reach (iOS: the
  /// app's Documents dir; Android: pre-granted storage access). Kept
  /// here because every upload-exercising test follows the same three
  /// taps before the picker shows.
  static Future<void> openUploadPicker(PatrolIntegrationTester $) async {
    await $(FloatingActionButton).tap();
    await $('Upload File').tap();
    if (Platform.isIOS || Platform.isMacOS) {
      await $.native.tap(Selector(text: 'Choose File'));
    } else if (Platform.isAndroid) {
      await $.native.tap(Selector(text: 'Allow'));
    }
  }

  /// Count pending uploads for the active account. Used by the offline
  /// and retry-backoff tests to verify the queue drains correctly.
  static Future<int> pendingUploadCount() async {
    final container = containerForTest();
    final db = container.read(databaseProvider);
    final account = container.read(activeAccountProvider);
    if (account == null) return 0;
    return db.getPendingUploadCount(account.id);
  }

  /// Returns all pending uploads for the active account (including
  /// failed_permanent rows). Tests inspect [PendingUpload.retryCount]
  /// and [PendingUpload.nextRetryAt] to verify backoff behaviour.
  static Future<List<PendingUpload>> pendingUploads() async {
    final container = containerForTest();
    final db = container.read(databaseProvider);
    final account = container.read(activeAccountProvider);
    if (account == null) return const [];
    return db.getPendingUploads(account.id);
  }

  /// Kick the sync pipeline manually. On reconnect the connectivity
  /// listener does this automatically, but tests sometimes need to
  /// trigger a drain without relying on a platform-level toggle.
  static Future<void> drainPendingUploads() async {
    final container = containerForTest();
    final sync = container.read(syncServiceProvider);
    await sync.processPendingUploads();
  }

  /// Inserts a pending upload row directly. Used by the offline/backoff
  /// test so it can verify the queue semantics without having to stage
  /// a real network failure — we isolate the scheduler under test from
  /// the upload pipeline it would otherwise call.
  static Future<int> seedPendingUpload({
    required String localPath,
    String? targetDirId,
    String status = 'pending',
    int retryCount = 0,
    DateTime? nextRetryAt,
  }) async {
    final container = containerForTest();
    final db = container.read(databaseProvider);
    final account = container.read(activeAccountProvider);
    if (account == null) {
      throw StateError('seedPendingUpload requires an active account');
    }
    final row = await db.insertPendingUpload(
      PendingUploadsCompanion.insert(
        accountId: account.id,
        localPath: localPath,
        targetDirId: Value(targetDirId),
        status: Value(status),
        retryCount: Value(retryCount),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
    return row.id;
  }
}
