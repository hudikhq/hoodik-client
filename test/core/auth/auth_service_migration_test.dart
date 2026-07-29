import 'dart:convert';

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
import 'package:hoodik_app/core/utils/hex.dart' as hex_utils;
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../helpers/legacy_pin.dart';

/// Scripts the legacy-login + migration handshake and records whether the
/// ceremony ever reached the commit POST, capturing what it posted.
class _FakeAuthClient extends Fake implements AuthClient {
  _FakeAuthClient({required this.loginResponse, required this.migration});

  final AuthResponse loginResponse;
  final MigrationKeysResponse migration;
  int migrationCompleteCalls = 0;
  int migrationRewrapCalls = 0;
  Map<String, String>? completed;

  @override
  Future<Map<String, dynamic>?> loginStart({
    required String email,
    required String credentialRequest,
  }) async => {'method': 'password'};

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
    String? token,
  }) async => loginResponse;

  @override
  Future<MigrationKeysResponse> migrationKeys({
    int offset = 0,
    int limit = 500,
  }) async => migration;

  @override
  Future<void> migrationRewrap({
    required List<Map<String, dynamic>> keys,
    required List<Map<String, dynamic>> linkKeys,
  }) async {
    migrationRewrapCalls++;
  }

  /// The OPAQUE server half isn't in the client FFI. Registration (unlike
  /// login) never authenticates the server, so any valid non-identity group
  /// element passes as both the evaluation element and the server public key
  /// — the ristretto255 basepoint drives the client finish to completion.
  @override
  Future<Map<String, dynamic>> pakeRegisterStart({
    required String registrationRequest,
  }) async {
    final basepoint = hex_utils.hexDecode(
      'e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76',
    );
    return {
      'registration_response': base64Encode([...basepoint, ...basepoint]),
    };
  }

  @override
  Future<Map<String, dynamic>> migrationComplete({
    required String newIdentityPubkey,
    required String newWrappingPubkey,
    required String newFingerprint,
    required String transitionOldSignature,
    required String transitionNewSignature,
    required int transitionIssuedAt,
    required String opaqueRegistrationUpload,
    required String encryptedPrivateKey,
    required String auditEventSignature,
  }) async {
    migrationCompleteCalls++;
    completed = {
      'fingerprint': newFingerprint,
      'pubkey': newIdentityPubkey,
      'wrapping': newWrappingPubkey,
      'envelope': encryptedPrivateKey,
    };
    return {'ok': true};
  }
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

class _FakePinStorage extends SecurePinStorage {
  _FakePinStorage() : super.forTesting(const FlutterSecureStorage());

  @override
  Future<String?> read(String accountId) async => null;

  @override
  Future<bool> has(String accountId) async => false;

  @override
  Future<void> delete(String accountId) async {}
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();
  const email = 'legacy@test.io';
  const password = 'correct horse battery staple';

  late rust.RsaKeyPair rsa;
  setUpAll(() => rsa = rust.generateRsaKeypair());

  late AppDatabase db;
  late Server server;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = await db.insertServer(
      ServersCompanion(
        id: const Value('s1'),
        url: const Value('https://example.com'),
        name: const Value('Test'),
      ),
    );
  });

  tearDown(() async => await db.close());

  test('a link-key re-wrap failure aborts migration and posts nothing', () async {
    final fileKey = crypto.generateSymmetricKey();
    final fakeAuth = _FakeAuthClient(
      loginResponse: AuthResponse(
        user: {
          'id': 'u1',
          'email': email,
          'security_version': 0,
          'key_type': 'rsa',
          'pubkey': rsa.publicKeyPem,
          'fingerprint': rsa.fingerprint,
          'encrypted_private_key': legacyPinEncrypt(
            rsa.privateKeyPem,
            password,
          ),
        },
        session: SessionInfo.fromJson(const {'expires_at': 2000000000}),
      ),
      migration: (
        keys: [
          {
            'file_id': 'f1',
            'encrypted_key': crypto.rsaEncrypt(
              plaintext: crypto.hexEncode(fileKey),
              publicKeyPem: rsa.publicKeyPem,
            ),
          },
        ],
        // A short valid-base64 blob is not a valid RSA ciphertext, so the
        // re-wrap throws on this link key after the file key already succeeded.
        linkKeys: [
          {'link_id': 'l1', 'encrypted_link_key': 'bm9wZQ=='},
        ],
        nextOffset: null,
      ),
    );

    final service = AuthService(
      db,
      _FakePinStorage(),
      clientFactory: ({required String baseUrl, String? accountId}) async =>
          _FakeApiClient(fakeAuth),
    );

    final account = await service.login(
      server: server,
      email: email,
      password: password,
    );

    // Login itself succeeds; the migration aborts silently and never commits.
    // The re-wrap threw before any batch was staged, so nothing was posted.
    expect(account.id, '${server.id}_$email');
    expect(fakeAuth.migrationRewrapCalls, 0);
    expect(fakeAuth.migrationCompleteCalls, 0);
    // The account stays on its legacy RSA identity key — no curve keys, and no
    // separate retained-RSA slot (that only appears after a successful migrate).
    expect(service.decryptedPrivateKey, rsa.privateKeyPem);
    expect(service.decryptedWrappingPrivateKey, isNull);
    expect(service.decryptedLegacyRsaPrivateKey, isNull);
  });

  test(
    'a committed migration persists the new identity to the account row',
    () async {
      final fakeAuth = _FakeAuthClient(
        loginResponse: AuthResponse(
          user: {
            'id': '00000000-0000-0000-0000-000000000001',
            'email': email,
            'security_version': 0,
            'key_type': 'rsa',
            'pubkey': rsa.publicKeyPem,
            'fingerprint': rsa.fingerprint,
            'encrypted_private_key': legacyPinEncrypt(
              rsa.privateKeyPem,
              password,
            ),
          },
          session: SessionInfo.fromJson(const {'expires_at': 2000000000}),
        ),
        migration: (
          keys: <Map<String, dynamic>>[],
          linkKeys: <Map<String, dynamic>>[],
          nextOffset: null,
        ),
      );

      final service = AuthService(
        db,
        _FakePinStorage(),
        deviceKeyVault: DeviceKeyVault(
          keychain: _MemKeyStore(),
          crypto: crypto,
        ),
        clientFactory: ({required String baseUrl, String? accountId}) async =>
            _FakeApiClient(fakeAuth),
      );

      await service.login(server: server, email: email, password: password);
      expect(fakeAuth.migrationCompleteCalls, 1);

      // The local row must mirror exactly what the server was told, or the next
      // quick unlock signs with the Ed25519 key but sends the stale RSA
      // fingerprint and every attempt fails signature verification.
      final posted = fakeAuth.completed!;
      final row = await db.getAccountById('${server.id}_$email');
      expect(row!.fingerprint, posted['fingerprint']);
      expect(row.publicKey, posted['pubkey']);
      expect(row.wrappingPublicKey, posted['wrapping']);
      expect(row.encryptedPrivateKey, posted['envelope']);
      expect(row.fingerprint, isNot(rsa.fingerprint));

      // The stored key is the sealed OPAQUE envelope, never plaintext material.
      expect(row.encryptedPrivateKey, isNot(contains('PRIVATE KEY')));
    },
  );
}
