import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/auth/secure_pin_storage.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/device_key_vault.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/hardware_key_store.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../helpers/legacy_pin.dart';

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

class _FixedPinStorage extends SecurePinStorage {
  _FixedPinStorage(this._pin) : super.forTesting(const FlutterSecureStorage());
  final String _pin;
  @override
  Future<String?> read(String accountId) async => _pin;
  @override
  Future<bool> has(String accountId) async => true;
  @override
  Future<void> delete(String accountId) async {}
}

class _FakeAuthClient extends Fake implements AuthClient {
  _FakeAuthClient(this._self);
  final AuthResponse _self;
  @override
  Future<AuthResponse> getSelf() async => _self;
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._auth);
  final _FakeAuthClient _auth;
  @override
  AuthClient get auth => _auth;
  @override
  bool useHeaderAuth = false;
  @override
  void Function()? onSessionExpired;
  @override
  void Function(String jwt, String refresh)? onTokensUpdated;
  @override
  Future<bool> get hasSession async => true;
  @override
  void updateSessionExpiry(AuthResponse authResp) {}
  @override
  void startSessionRefreshTimer() {}
  @override
  void stopSessionRefreshTimer() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();
  const pin = '424242';
  const identity =
      '-----BEGIN PRIVATE KEY-----\nIDENTITY\n-----END PRIVATE KEY-----';
  const wrapping =
      '-----BEGIN PRIVATE KEY-----\nWRAPPING\n-----END PRIVATE KEY-----';
  final legacyBundle = 'v1|id:$identity|wrap:$wrapping';

  late AppDatabase db;
  late _MemKeyStore store;
  late Server server;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = _MemKeyStore();
    server = await db.insertServer(
      ServersCompanion(
        id: const Value('s1'),
        url: const Value('https://example.com'),
        name: const Value('Test'),
      ),
    );
  });

  tearDown(() async => await db.close());

  test(
    'a legacy PIN blob migrates to the device-key format on unlock',
    () async {
      final accountId = '${server.id}_u1';
      await db.insertAccount(
        AccountsCompanion(
          id: Value(accountId),
          serverId: Value(server.id),
          userId: const Value('u1'),
          email: const Value('u1@test.io'),
          isActive: const Value(true),
        ),
      );
      final legacyHex = legacyPinEncrypt(legacyBundle, pin);
      await db.storePinEncryptedKey(accountId, legacyHex);

      final service = AuthService(
        db,
        _FixedPinStorage(pin),
        deviceKeyVault: DeviceKeyVault(keychain: store, crypto: crypto),
        clientFactory: ({required String baseUrl, String? accountId}) async =>
            _FakeApiClient(
              _FakeAuthClient(
                AuthResponse(
                  user: const {'id': 'u1', 'email': 'u1@test.io'},
                  session: SessionInfo.fromJson(const {
                    'expires_at': 2000000000,
                  }),
                ),
              ),
            ),
      );

      expect(await service.switchAccount(accountId), isTrue);

      // The private key is recovered identically through the migration.
      expect(service.decryptedPrivateKey, identity);
      expect(service.decryptedWrappingPrivateKey, wrapping);

      // The on-disk blob has been re-sealed: it is no longer the legacy hex and
      // now carries the v3 (Argon2id) format byte, backed by a freshly minted
      // device key.
      final migrated = await db.getPinEncryptedKey(accountId);
      expect(migrated, isNot(legacyHex));
      expect(migrated, startsWith('03'));
      expect(store.entries['hoodik_devkey_$accountId'], isNotNull);

      // And the migrated blob round-trips under the device key.
      final vault = DeviceKeyVault(keychain: store, crypto: crypto);
      final reopened = await vault.unwrapBundle(accountId, pin, migrated!);
      expect(reopened.plaintext, legacyBundle);
      expect(reopened.wasLegacy, isFalse);
    },
  );

  test('removeAccount deletes the device key from the keychain', () async {
    final accountId = '${server.id}_u2';
    await db.insertAccount(
      AccountsCompanion(
        id: Value(accountId),
        serverId: Value(server.id),
        userId: const Value('u2'),
        email: const Value('u2@test.io'),
      ),
    );

    final service = AuthService(
      db,
      _FixedPinStorage(pin),
      deviceKeyVault: DeviceKeyVault(keychain: store, crypto: crypto),
    );
    await service.setupPin(
      accountId,
      identity,
      pin,
      wrappingPrivateKeyPem: wrapping,
    );
    expect(store.entries['hoodik_devkey_$accountId'], isNotNull);

    await service.removeAccount(accountId);
    expect(store.entries.containsKey('hoodik_devkey_$accountId'), isFalse);
    expect(await db.getAccountById(accountId), isNull);
  });
}
