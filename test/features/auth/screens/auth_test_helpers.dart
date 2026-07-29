import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hoodik_app/core/auth/auth_service.dart';
import 'package:hoodik_app/core/auth/secure_pin_storage.dart';
import 'package:hoodik_app/core/storage/database.dart';

/// Create a fake [Account] for testing.
Account fakeAccount({
  required String id,
  String? email,
  String serverId = 'srv',
  String? pinEncryptedPrivateKey,
  DateTime? lastUsedAt,
}) {
  final resolvedEmail = email ?? id.replaceFirst('${serverId}_', '');
  return Account(
    id: id,
    serverId: serverId,
    userId: 'uid-$id',
    email: resolvedEmail,
    fingerprint: null,
    publicKey: null,
    encryptedPrivateKey: null,
    pinEncryptedPrivateKey: pinEncryptedPrivateKey,
    biometricPin: null,
    quota: null,
    role: null,
    isActive: false,
    createdAt: DateTime(2026),
    lastUsedAt: lastUsedAt,
    cacheLimitBytes: null,
    headerJwt: null,
    headerRefreshToken: null,
  );
}

/// Create a fake [Server] for testing.
Server fakeServer({String id = 'srv', String name = 'Test Server'}) {
  return Server(
    id: id,
    url: 'https://example.com',
    name: name,
    trustSelfSignedCerts: false,
    useHeaderAuth: false,
    createdAt: DateTime(2026),
  );
}

/// Minimal fake [AuthService] for widget tests.
///
/// Set the public fields to control what each method returns.
class FakeAuthService extends AuthService {
  FakeAuthService() : super(_fakeDb(), _FakePinStorage());

  static AppDatabase _fakeDb() =>
      AppDatabase.forTesting(NativeDatabase.memory());

  // ── Controllable return values ──────────────────────────────────────

  bool switchAccountResult = true;
  String? fakeDecryptedPrivateKey;
  Account? fakeActiveAccount;
  Server? fakeActiveServer;

  /// Accounts returned by [getAccountsForServer].
  List<Account> serverAccounts = [];

  /// Accounts returned by [getAccounts].
  List<Account> allAccounts = [];

  /// Servers returned by [getServers].
  List<Server> allServers = [];

  /// Account IDs that have a PIN set up.
  Set<String> pinSetupAccounts = {};

  /// Account returned by [getAccountWithPinKey].
  Account? defaultPinAccount;

  /// Account returned by [getAccountWithPinKeyById].
  Account? Function(String id)? pinAccountByIdResolver;

  // ── Overrides ──────────────────────────────────────────────────────

  @override
  String? get decryptedPrivateKey => fakeDecryptedPrivateKey;

  @override
  Account? get activeAccount => fakeActiveAccount;

  @override
  Server? get activeServer => fakeActiveServer;

  @override
  Future<bool> switchAccount(String accountId) async => switchAccountResult;

  @override
  Future<bool> hasPinSetup(String accountId) async =>
      pinSetupAccounts.contains(accountId);

  @override
  Future<List<Account>> getAccountsForServer(String serverId) async =>
      serverAccounts;

  @override
  Future<List<Account>> getAccounts() async => allAccounts;

  @override
  Future<List<Server>> getServers() async => allServers;

  @override
  Future<Account?> getAccountWithPinKey() async => defaultPinAccount;

  @override
  Future<Account?> getAccountWithPinKeyById(String accountId) async =>
      pinAccountByIdResolver?.call(accountId);

  @override
  Future<bool> hasBiometricSetup(String accountId) async => false;

  @override
  Future<String?> getBiometricPin(String accountId) async => null;
}

/// Stub [SecurePinStorage] backed by an in-memory map — avoids platform
/// channel calls to the real keychain.
class _FakePinStorage extends SecurePinStorage {
  _FakePinStorage() : super.forTesting(const FlutterSecureStorage());

  final _store = <String, String>{};

  @override
  Future<void> store(String accountId, String pin) async =>
      _store[accountId] = pin;

  @override
  Future<String?> read(String accountId) async => _store[accountId];

  @override
  Future<bool> has(String accountId) async => _store.containsKey(accountId);

  @override
  Future<void> delete(String accountId) async => _store.remove(accountId);
}
