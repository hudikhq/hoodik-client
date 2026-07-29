import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/at_rest_cipher.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/hardware_key_store.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

class _MemKeyStore extends HardwareKeyStore {
  _MemKeyStore() : super.withStorage(const FlutterSecureStorage());
  final Map<String, String> entries = {};
  @override
  Future<String?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, String value) async => entries[key] = value;
  @override
  Future<void> delete(String key) async => entries.remove(key);
}

AppDatabase _createTestDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

void main() {
  late AppDatabase db;

  // headerRefreshToken is sealed at rest, so persisting it needs a keyed
  // cipher — otherwise it fails closed to NULL.
  setUpAll(() async => await RustLib.init());

  setUp(() async {
    AtRestCipher.instance.resetForTesting();
    await AtRestCipher.instance.ensureInitialized(keychain: _MemKeyStore());
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
    AtRestCipher.instance.resetForTesting();
  });

  group('Server useHeaderAuth', () {
    test('defaults to false when not specified', () async {
      final server = await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );

      expect(server.useHeaderAuth, isFalse);
    });

    test('stores true when explicitly set', () async {
      final server = await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://header-auth.example.com'),
          name: const Value('Header Auth Server'),
          useHeaderAuth: const Value(true),
        ),
      );

      expect(server.useHeaderAuth, isTrue);
    });

    test('updateServerUseHeaderAuth toggles the flag', () async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );

      await db.updateServerUseHeaderAuth('s1', true);
      var server = await db.getServerByUrl('https://example.com');
      expect(server!.useHeaderAuth, isTrue);

      await db.updateServerUseHeaderAuth('s1', false);
      server = await db.getServerByUrl('https://example.com');
      expect(server!.useHeaderAuth, isFalse);
    });

    test('persists alongside trustSelfSignedCerts', () async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://lan.local:8443'),
          name: const Value('LAN'),
          trustSelfSignedCerts: const Value(true),
          useHeaderAuth: const Value(true),
        ),
      );

      final servers = await db.getAllServers();
      expect(servers.length, 1);
      expect(servers[0].trustSelfSignedCerts, isTrue);
      expect(servers[0].useHeaderAuth, isTrue);
    });
  });

  group('Account header tokens', () {
    setUp(() async {
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('test@test.com'),
        ),
      );
    });

    test('headerJwt and headerRefreshToken default to null', () async {
      final account = await db.getAccountById('a1');
      expect(account, isNotNull);
      expect(account!.headerJwt, isNull);
      expect(account.headerRefreshToken, isNull);
    });

    test('updateHeaderTokens stores tokens', () async {
      await db.updateHeaderTokens('a1', 'jwt-value', 'refresh-uuid');

      final account = await db.getAccountById('a1');
      expect(account!.headerJwt, 'jwt-value');
      expect(account.headerRefreshToken, 'refresh-uuid');
    });

    test('updateHeaderTokens overwrites previous tokens', () async {
      await db.updateHeaderTokens('a1', 'old-jwt', 'old-refresh');
      await db.updateHeaderTokens('a1', 'new-jwt', 'new-refresh');

      final account = await db.getAccountById('a1');
      expect(account!.headerJwt, 'new-jwt');
      expect(account.headerRefreshToken, 'new-refresh');
    });

    test('clearHeaderTokens sets tokens to null', () async {
      await db.updateHeaderTokens('a1', 'jwt', 'refresh');
      await db.clearHeaderTokens('a1');

      final account = await db.getAccountById('a1');
      expect(account!.headerJwt, isNull);
      expect(account.headerRefreshToken, isNull);
    });

    test('tokens survive insertAccount with insertOrIgnore', () async {
      // Store tokens first
      await db.updateHeaderTokens('a1', 'persisted-jwt', 'persisted-refresh');

      // Re-insert the same account (simulates re-login)
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('a1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('test@test.com'),
          isActive: const Value(true),
        ),
      );

      // Tokens should still be present because insertAccount uses
      // insertOrIgnore + selective update that doesn't touch token columns.
      final account = await db.getAccountById('a1');
      expect(account!.headerJwt, 'persisted-jwt');
      expect(account.headerRefreshToken, 'persisted-refresh');
    });
  });
}
