import 'package:intl/intl.dart' show Intl;

import '../api/api_client.dart';
import '../crypto/crypto_service.dart';
import '../crypto/crypto_service_migration.dart';
import '../crypto/pem_key_type.dart';
import '../crypto/device_key_vault.dart';
import '../storage/database.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import '../../src/rust/api.dart' as rust;
import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'secure_pin_storage.dart';
part 'auth_service_login.dart';
part 'auth_service_registration.dart';
part 'auth_service_migration.dart';
part 'auth_service_pin.dart';
part 'auth_service_session.dart';

const _uuid = Uuid();
const _log = Logger('AuthService');

/// Signature of the factory that produces an [ApiClient] for a given server.
/// Kept injectable so tests can substitute a fake client without hitting disk.
typedef ApiClientFactory =
    Future<ApiClient> Function({required String baseUrl, String? accountId});

Future<ApiClient> _defaultClientFactory({
  required String baseUrl,
  String? accountId,
}) => ApiClient.create(baseUrl: baseUrl, accountId: accountId);

/// Manages authentication state, accounts, and cookie-based sessions.
class AuthService {
  /// Whether a legacy account auto-migrates to Curve25519 + OPAQUE on login.
  /// On by default; a mutable static so tests can exercise the legacy-stays-
  /// legacy path. See the gate in the OPAQUE login path.
  static bool autoMigrationEnabled = true;

  final AppDatabase _db;
  final SecurePinStorage _securePinStorage;
  final CryptoService _crypto;
  final DeviceKeyVault _vault;
  final ApiClientFactory _clientFactory;

  ApiClient? _activeClient;
  Account? _activeAccount;
  Server? _activeServer;

  /// The decrypted PEM private key for the active account (identity key: RSA or Ed25519).
  /// Only available in memory — never persisted to disk.
  String? _decryptedPrivateKey;

  /// For Curve25519 accounts, the hybrid wrapping private key used to unwrap the caller's
  /// own file key wraps. Set alongside _decryptedPrivateKey on OPAQUE login / migration.
  String? _decryptedWrappingPrivateKey;

  /// For a *migrated* legacy account, the retained RSA private key. The
  /// migration ceremony seals it into the OPAQUE envelope (`rsa:` segment) so
  /// pre-migration ciphertext and the recovery path stay decryptable; kept in
  /// memory only, never on disk in plaintext. Null for still-legacy accounts
  /// (RSA is their identity key, held in [_decryptedPrivateKey]) and for
  /// natively registered v2 accounts.
  String? _decryptedLegacyRsaPrivateKey;

  /// Called when the session refresh fails — the UI layer should wire this
  /// up to clear Riverpod state and redirect to the login screen.
  void Function()? onSessionExpired;

  AuthService(
    this._db,
    this._securePinStorage, {
    CryptoService crypto = const CryptoService(),
    DeviceKeyVault? deviceKeyVault,
    ApiClientFactory clientFactory = _defaultClientFactory,
  }) : _crypto = crypto,
       _vault = deviceKeyVault ?? DeviceKeyVault(crypto: crypto),
       _clientFactory = clientFactory;

  ApiClient? get activeClient => _activeClient;
  Account? get activeAccount => _activeAccount;
  Server? get activeServer => _activeServer;
  bool get isLoggedIn => _activeClient != null;

  /// The decrypted PEM private key, or null if not yet decrypted.
  /// This is the *identity* key (RSA or Ed25519) used for signatures.
  String? get decryptedPrivateKey => _decryptedPrivateKey;

  /// The hybrid wrapping private key for curve accounts, or null for legacy.
  /// Used to (un)wrap the caller's own `encrypted_key` values for files.
  String? get decryptedWrappingPrivateKey => _decryptedWrappingPrivateKey;

  /// The retained RSA private key for a migrated account, or null. Available
  /// this session for decrypting pre-migration ciphertext and for recovery.
  String? get decryptedLegacyRsaPrivateKey => _decryptedLegacyRsaPrivateKey;

  /// Set the active client, seed the session expiry, and start the refresh
  /// timer.  Mirrors the web frontend's `setupAuthenticated`.
  void _setActiveClient(ApiClient client, {AuthResponse? authResp}) {
    _activeClient?.stopSessionRefreshTimer();
    _activeClient = client;
    if (authResp != null) {
      client.updateSessionExpiry(authResp);
    }
    client.onSessionExpired = _handleSessionExpired;
    client.onTokensUpdated = _persistTokens;
    client.startSessionRefreshTimer();
  }

  /// Persist header-auth tokens to the database so they survive app restarts.
  void _persistTokens(String jwt, String refresh) {
    final accountId = _activeAccount?.id;
    if (accountId == null) return;
    _db.updateHeaderTokens(accountId, jwt, refresh);
  }

  /// Clear the active client and stop refresh timer.
  void _clearActiveClient() {
    _activeClient?.stopSessionRefreshTimer();
    _activeClient = null;
  }

  /// Called by ApiClient when the proactive refresh fails.
  void _handleSessionExpired() {
    _log.info('session expired — clearing auth state');
    _clearActiveClient();
    _activeAccount = null;
    _activeServer = null;
    _decryptedPrivateKey = null;
    _decryptedWrappingPrivateKey = null;
    _decryptedLegacyRsaPrivateKey = null;
    onSessionExpired?.call();
  }

  Future<List<Server>> getServers() => _db.getAllServers();

  /// Get all accounts that belong to a specific server.
  Future<List<Account>> getAccountsForServer(String serverId) async {
    final all = await _db.getAllAccounts();
    return all.where((a) => a.serverId == serverId).toList();
  }

  Future<List<Account>> getAccounts() => _db.getAllAccounts();

  Future<bool> switchAccount(String accountId) async {
    final account = await _db.getAccountById(accountId);
    if (account == null) return false;

    final servers = await _db.getAllServers();
    final server = servers.where((s) => s.id == account.serverId).firstOrNull;
    if (server == null) return false;

    final client = await _clientFactory(
      baseUrl: server.url,
      accountId: accountId,
    );

    // For header-auth servers, restore persisted tokens.
    if (server.useHeaderAuth) {
      client.useHeaderAuth = true;
      if (account.headerJwt != null && account.headerRefreshToken != null) {
        client.setTokens(
          jwt: account.headerJwt!,
          refresh: account.headerRefreshToken!,
        );
      } else {
        return false;
      }
    }

    if (!await client.hasSession) return false;

    // Fetch session info BEFORE mutating state. If getSelf fails, the caller
    // needs to handle it (show "session expired", redirect to login) rather
    // than silently proceed with stale expiry info that breaks the refresh
    // timer. We rethrow so the caller's try/catch sees the error.
    final AuthResponse authResp;
    try {
      authResp = await client.auth.getSelf();
    } catch (e) {
      _log.warn(
        'switchAccount getSelf failed',
        fields: {'error': redactException(e)},
      );
      rethrow;
    }

    await _db.setActiveAccount(accountId);

    // Clear stale private key from the previous account before setting
    // the new one — prevents using the wrong key for file decryption.
    _decryptedPrivateKey = null;
    _decryptedWrappingPrivateKey = null;
    _decryptedLegacyRsaPrivateKey = null;

    _activeServer = server;
    _activeAccount = account;
    _setActiveClient(client, authResp: authResp);

    // Try to silently recover the private key via biometric PIN stored
    // in the platform keychain. If unavailable, the caller must redirect
    // the user to the unlock or login screen.
    await _tryRecoverPrivateKey(accountId);

    return true;
  }

  /// Check if an account has a PIN-encrypted key stored.
  Future<bool> hasPinSetup(String accountId) async {
    final key = await _db.getPinEncryptedKey(accountId);
    return key != null && key.isNotEmpty;
  }

  /// Get the account that has a PIN set up, preferring the active/last-used.
  Future<Account?> getAccountWithPinKey() async {
    return _db.getAccountWithPinKey();
  }

  /// Get a specific account by ID, only if it has a PIN set up.
  Future<Account?> getAccountWithPinKeyById(String accountId) async {
    return _db.getAccountWithPinKeyById(accountId);
  }

  /// Check if biometric unlock is enabled for an account.
  Future<bool> hasBiometricSetup(String accountId) async {
    return _securePinStorage.has(accountId);
  }

  /// Get the stored biometric PIN for an account (used after biometric auth).
  Future<String?> getBiometricPin(String accountId) async {
    return _securePinStorage.read(accountId);
  }
}
