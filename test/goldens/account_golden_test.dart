import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/account/screens/account_screen.dart';

import 'account_test_fakes.dart';
import 'golden_harness.dart';

/// Account-screen golden. Pins every value the real screen's sub-widgets
/// watch (active account, active server, offline cache count, transfer
/// manager) so the captured frame is a pure function of theme +
/// viewport + platform.
void main() {
  late AccountGoldenAuthService auth;
  late AppDatabase db;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await configureGoldenEnvironment();
    db = fakeInMemoryDatabase();
    auth = AccountGoldenAuthService(
      accounts: [fakeAccount(), fakeSecondaryAccount()],
      servers: [fakeServer(), fakeSecondaryServer()],
    );
  });

  tearDownAll(() async {
    await db.close();
  });

  Future<List<Override>> overrides() async {
    final prefs = await fakePreferences();
    final account = fakeAccount(quota: 50 * 1024 * 1024 * 1024);
    return [
      databaseProvider.overrideWithValue(db),
      activeAccountProvider.overrideWith((ref) => account),
      activeServerProvider.overrideWith((ref) => fakeServer()),
      authServiceProvider.overrideWithValue(auth),
      preferencesProvider.overrideWithValue(prefs),
      permanentlyFailedCountProvider.overrideWith((ref) async => 0),
      // The recovery-key tile hides itself while no decrypted key is in
      // memory. Pin a placeholder so the tile is part of the captured
      // frame; nothing in the rendered tree parses the value.
      decryptedPrivateKeyProvider.overrideWith((ref) => 'golden-placeholder'),
    ];
  }

  runGoldenMatrix(
    screen: 'account',
    body: (tester, config) async {
      await pumpGoldenHarness(
        tester,
        config: config,
        child: const AccountScreen(),
        overrides: await overrides(),
      );
      // Account widgets load their section data (offline cache count,
      // account switcher list, PIN/biometric state) asynchronously in
      // `initState`. Pump past the first microtask batch so the screen
      // captures its hydrated form rather than its skeleton.
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
}
