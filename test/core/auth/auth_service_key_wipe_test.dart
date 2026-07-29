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
  @override
  Future<void> logout() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();
  const pin = '246810';
  const identity = 'FAKE_IDENTITY_PEM';
  const wrapping = 'FAKE_WRAPPING_PEM';
  const accountId = 's1_u1';

  late AppDatabase db;
  late _MemKeyStore store;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = _MemKeyStore();
    await db.insertServer(
      ServersCompanion(
        id: const Value('s1'),
        url: const Value('https://example.com'),
        name: const Value('Test'),
      ),
    );
    await db.insertAccount(
      AccountsCompanion(
        id: const Value(accountId),
        serverId: const Value('s1'),
        userId: const Value('u1'),
        email: const Value('u1@test.io'),
        isActive: const Value(true),
      ),
    );
  });

  tearDown(() async => await db.close());

  // Builds a signed-in service with the identity and wrapping keys held in
  // memory (recovered silently through the stored PIN on switchAccount).
  Future<AuthService> signedIn() async {
    final service = AuthService(
      db,
      _FixedPinStorage(pin),
      deviceKeyVault: DeviceKeyVault(keychain: store, crypto: crypto),
      clientFactory: ({required String baseUrl, String? accountId}) async =>
          _FakeApiClient(
            _FakeAuthClient(
              AuthResponse(
                user: const {'id': 'u1', 'email': 'u1@test.io'},
                session: SessionInfo.fromJson(const {'expires_at': 2000000000}),
              ),
            ),
          ),
    );
    await service.setupPin(
      accountId,
      identity,
      pin,
      wrappingPrivateKeyPem: wrapping,
    );
    expect(await service.switchAccount(accountId), isTrue);
    expect(service.decryptedPrivateKey, identity);
    expect(service.decryptedWrappingPrivateKey, wrapping);
    return service;
  }

  void expectAllKeysCleared(AuthService s) {
    expect(s.decryptedPrivateKey, isNull);
    expect(s.decryptedWrappingPrivateKey, isNull);
    expect(s.decryptedLegacyRsaPrivateKey, isNull);
  }

  test('logout clears every in-memory key', () async {
    final service = await signedIn();
    await service.logout();
    expectAllKeysCleared(service);
  });

  test('removeAccount clears every in-memory key', () async {
    final service = await signedIn();
    await service.removeAccount(accountId);
    expectAllKeysCleared(service);
  });

  test('deleteServer clears every in-memory key', () async {
    final service = await signedIn();
    await service.deleteServer('s1');
    expectAllKeysCleared(service);
  });
}
