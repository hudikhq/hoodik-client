import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/auth/auth_state.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this.label);
  final String label;
}

/// Stands in for the real service so the test can flip [activeClient] the
/// way `switchAccount` does before the UI publishes the new session.
class _FakeAuthService extends Fake implements AuthService {
  @override
  ApiClient? activeClient;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Account account;
  late Account otherAccount;
  late Server server;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = await db.insertServer(
      ServersCompanion(
        id: const Value('s1'),
        url: const Value('https://example.com'),
        name: const Value('Test Server'),
      ),
    );
    account = await db.insertAccount(
      AccountsCompanion(
        id: const Value('a1'),
        serverId: const Value('s1'),
        userId: const Value('u1'),
        email: const Value('a@test.io'),
      ),
    );
    otherAccount = await db.insertAccount(
      AccountsCompanion(
        id: const Value('a2'),
        serverId: const Value('s1'),
        userId: const Value('u2'),
        email: const Value('b@test.io'),
      ),
    );
  });

  tearDown(() async => await db.close());

  testWidgets('setLoggedIn completes the sign-in even when the MCP warm-up '
      'throws an uninitialized-provider error', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Reproduce the unlock-path failure: reading the MCP server during
          // sign-in throws the Bad state seen on startup. The guard must keep
          // it from aborting the rest of setLoggedIn.
          mcpServerProvider.overrideWith(
            (_) => throw StateError(
              'Tried to read the state of an uninitialized provider',
            ),
          ),
        ],
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      () => ref.setLoggedIn(
        account: account,
        server: server,
        privateKey: 'pk',
        wrappingPrivateKey: null,
      ),
      returnsNormally,
    );

    expect(ref.read(isLoggedInProvider), isTrue);
    expect(ref.read(activeAccountProvider)?.id, 'a1');
    expect(ref.read(activeServerProvider)?.id, 's1');
    expect(ref.read(decryptedPrivateKeyProvider), 'pk');
  });

  // Riverpod runs `ref.listen` callbacks synchronously and only marks
  // dependent providers dirty afterwards, so anything watching the active
  // account observes the exact instant it is published. FilesNotifier reloads
  // the drive from there — with the account published first it fetched the
  // previous account's listing over the previous account's client and then
  // failed to decrypt it with the new key, leaving a drive of "Encrypted …"
  // rows behind every switch.
  testWidgets('an account-switch listener sees the new client and key', (
    tester,
  ) async {
    final oldClient = _FakeApiClient('old');
    final newClient = _FakeApiClient('new');
    final authService = _FakeAuthService()..activeClient = oldClient;

    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(authService),
          mcpServerProvider.overrideWithValue(null),
          // Touching `background_downloader` here would start real platform
          // work the fake-async zone never gets to finish.
          transferReconcilerProvider.overrideWithValue(null),
        ],
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    ref.setLoggedIn(account: account, server: server, privateKey: 'key-a1');
    expect(ref.read(apiClientProvider), same(oldClient));

    ApiClient? seenClient;
    String? seenKey;
    String? seenAccountId;
    ref.listenManual(activeAccountProvider, (_, _) {
      seenClient = ref.read(apiClientProvider);
      seenKey = ref.read(decryptedPrivateKeyProvider);
      seenAccountId = ref.read(activeAccountProvider)?.id;
    });

    // What AuthService.switchAccount does before the caller publishes.
    authService.activeClient = newClient;
    ref.setLoggedIn(
      account: otherAccount,
      server: server,
      privateKey: 'key-a2',
    );

    expect(seenAccountId, 'a2');
    expect(seenClient, same(newClient));
    expect(seenKey, 'key-a2');
  });
}
