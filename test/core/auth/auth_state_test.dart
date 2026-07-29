import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/auth/auth_state.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Account account;
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
}
