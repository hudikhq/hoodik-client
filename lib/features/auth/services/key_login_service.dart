import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../src/rust/api.dart' as rust;
import 'recovery_bundle.dart';

/// A key-login failure with a message safe to show the user. The recovery
/// material itself must never appear in messages or logs.
class KeyLoginException implements Exception {
  const KeyLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

final keyLoginServiceProvider = Provider<KeyLoginService>((ref) {
  return KeyLoginService(
    authService: ref.watch(authServiceProvider),
    crypto: ref.watch(cryptoServiceProvider),
    db: ref.watch(databaseProvider),
  );
});

/// Signs the server's fingerprint challenge with a pasted recovery key and
/// hands the resulting session to [AuthService] — the mobile counterpart of
/// the web client's "log in with your key" flow. The recovery material is
/// used only to sign locally; it is never sent anywhere.
class KeyLoginService {
  KeyLoginService({
    required AuthService authService,
    required CryptoService crypto,
    required AppDatabase db,
  }) : _authService = authService,
       _crypto = crypto,
       _db = db;

  final AuthService _authService;
  final CryptoService _crypto;
  final AppDatabase _db;

  /// Authenticate against [server] with pasted recovery [material].
  ///
  /// On success the auth service owns the session (active account, refresh
  /// timer) and the parsed keys are returned so the caller can seed the
  /// in-memory key providers. Throws [FormatException] for unparseable
  /// material and [KeyLoginException] for everything past parsing.
  Future<ParsedRecoveryKey> login({
    required Server server,
    required String material,
  }) async {
    final keys = parseRecoveryKey(material);
    final fingerprint = _fingerprintOf(keys);
    final resp = await _signatureLogin(server, keys, fingerprint);

    final email = resp.auth.email;
    if (email == null || email.isEmpty) {
      throw KeyLoginException(ambientL10n.authKeyLoginNoAccount);
    }

    // Same account-id scheme as the password login, so both flows share one
    // local account row and one persisted cookie jar. The email is only known
    // after the signature login, which is why the session starts in a
    // temporary client and is copied over here.
    final accountId = '${server.id}_${email.toLowerCase()}';
    final client = await ApiClient.create(
      baseUrl: server.url,
      accountId: accountId,
    );
    final uri = Uri.parse(server.url);
    await client.cookieJar.saveFromResponse(
      uri,
      await resp.probeJar.loadForRequest(uri),
    );

    if (resp.auth.isHeaderAuth) {
      await _db.updateServerUseHeaderAuth(server.id, true);
      await _db.updateHeaderTokens(
        accountId,
        resp.auth.headerJwt!,
        resp.auth.headerRefresh ?? '',
      );
    }

    await _db.insertAccount(
      AccountsCompanion(
        id: Value(accountId),
        serverId: Value(server.id),
        userId: Value(resp.auth.id ?? ''),
        email: Value(email),
        fingerprint: Value(resp.auth.fingerprint),
        publicKey: Value(resp.auth.pubkey),
        wrappingPublicKey: Value(resp.auth.wrappingPubkey),
        encryptedPrivateKey: Value(resp.auth.encryptedPrivateKey),
        quota: Value(resp.auth.quota),
        role: Value(resp.auth.role),
        isActive: const Value(true),
        lastUsedAt: Value(DateTime.now()),
      ),
    );

    final adopted = await _authService.switchAccount(accountId);
    if (!adopted) {
      throw KeyLoginException(ambientL10n.authKeyLoginSessionFailed);
    }
    return keys;
  }

  String _fingerprintOf(ParsedRecoveryKey keys) {
    if (!keys.isCurve) {
      try {
        return rust
            .rsaPublicFromPrivate(privateKeyPem: keys.identity)
            .fingerprint;
      } catch (_) {
        throw KeyLoginException(ambientL10n.authKeyLoginInvalidKey);
      }
    }

    final publicPem = ed25519PublicPemFromPrivate(keys.identity);
    if (publicPem == null) {
      throw KeyLoginException(ambientL10n.authKeyLoginNoIdentityKey);
    }
    // Prove the extracted public key pairs with the pasted private key —
    // a wrong pairing must fail here, not as a rejected server login.
    const probe = 'key-login-probe';
    final String signature;
    try {
      signature = _crypto.ed25519Sign(
        message: probe,
        privatePem: keys.identity,
      );
    } catch (_) {
      throw KeyLoginException(ambientL10n.authKeyLoginInvalidKey);
    }
    final paired = _crypto.ed25519Verify(
      message: probe,
      signature: signature,
      publicPem: publicPem,
    );
    if (!paired) {
      throw KeyLoginException(ambientL10n.authKeyLoginSelfCheckFailed);
    }
    return _crypto.spkiFingerprint(publicPem: publicPem);
  }

  Future<({AuthResponse auth, CookieJar probeJar})> _signatureLogin(
    Server server,
    ParsedRecoveryKey keys,
    String fingerprint,
  ) async {
    final challenge = _crypto.createSignatureLoginChallenge(fingerprint);
    final signature = keys.isCurve
        ? _crypto.ed25519Sign(
            message: challenge.message,
            privatePem: keys.identity,
          )
        : _crypto.rsaSign(
            message: challenge.message,
            privateKeyPem: keys.identity,
          );

    final probeClient = ApiClient.createTemporary(baseUrl: server.url);
    try {
      final auth = await probeClient.auth.signatureLogin(
        fingerprint: fingerprint,
        signature: signature,
        timestamp: challenge.timestamp,
        nonce: challenge.nonce,
      );
      return (auth: auth, probeJar: probeClient.cookieJar);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 404) {
        throw KeyLoginException(ambientL10n.authKeyLoginUnrecognizedKey);
      }
      throw KeyLoginException(
        ambientL10n.authConnectionFailed(e.message ?? ''),
      );
    }
  }
}
