part of 'auth_service.dart';

extension AuthServicePin on AuthService {
  /// Store the private key encrypted with a PIN for quick unlock.
  Future<void> setupPin(
    String accountId,
    String privateKeyPem,
    String pin, {
    String? wrappingPrivateKeyPem,
  }) async {
    final toStore = _encodeForPin(privateKeyPem, wrappingPrivateKeyPem);
    final encryptedHex = await _vault.wrapBundle(accountId, toStore, pin);
    await _db.storePinEncryptedKey(accountId, encryptedHex);
    _log.info('PIN-encrypted private key stored');
  }

  String _encodeForPin(String identity, String? wrapping) {
    if (wrapping == null || wrapping.isEmpty) return identity;
    return 'v1|id:$identity|wrap:$wrapping';
  }

  /// Unwrap the stored PIN bundle, transparently re-sealing a legacy
  /// PIN-derived blob under a fresh device key so the weak format is retired on
  /// first unlock. The re-wrap is independent of any network auth that follows.
  Future<({String identity, String? wrapping})> _unwrapAndMigrate(
    String accountId,
    String pin,
    String encryptedHex,
  ) async {
    final unwrapped = await _vault.unwrapBundle(accountId, pin, encryptedHex);
    if (unwrapped.wasLegacy) {
      await _db.storePinEncryptedKey(
        accountId,
        await _vault.wrapBundle(accountId, unwrapped.plaintext, pin),
      );
    }
    return _decodeFromPin(unwrapped.plaintext);
  }

  ({String identity, String? wrapping}) _decodeFromPin(String stored) {
    if (stored.startsWith('v1|')) {
      String? id;
      String? w;
      for (final p in stored.split('|')) {
        if (p.startsWith('id:')) id = p.substring(3);
        if (p.startsWith('wrap:')) w = p.substring(5);
      }
      return (identity: id ?? stored, wrapping: w);
    }
    return (identity: stored, wrapping: null);
  }

  /// Verify a PIN locally without performing server authentication.
  /// Returns true if the PIN correctly decrypts the stored private key.
  /// Used by the lock overlay on app resume (session already active).
  Future<bool> verifyPin(String accountId, String pin) async {
    final encryptedHex = await _db.getPinEncryptedKey(accountId);
    if (encryptedHex == null || encryptedHex.isEmpty) return false;

    try {
      await _vault.unwrapBundle(accountId, pin, encryptedHex);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate using a stored PIN-encrypted key.
  /// Decrypts the key, performs signature auth, sets up the session.
  Future<Account> unlockWithPin(String accountId, String pin) async {
    final account = await _db.getAccountById(accountId);
    if (account == null) {
      throw Exception('Account not found');
    }

    final encryptedHex = await _db.getPinEncryptedKey(accountId);
    if (encryptedHex == null || encryptedHex.isEmpty) {
      throw Exception('No PIN-encrypted key found for this account');
    }

    // Decrypt the (possibly combined) private material with the PIN. A legacy
    // PIN-derived blob is transparently re-sealed under a fresh device key here,
    // so the weak on-disk format disappears the first time the user unlocks.
    final decoded = await _unwrapAndMigrate(accountId, pin, encryptedHex);
    final privateKeyPem = decoded.identity;

    // Prefer the fingerprint stored on the account (correct for both RSA and curve).
    // Fall back to deriving only for legacy RSA.
    String fingerprint = account.fingerprint ?? '';
    if (fingerprint.isEmpty) {
      try {
        final pubInfo = rust.rsaPublicFromPrivate(privateKeyPem: privateKeyPem);
        fingerprint = pubInfo.fingerprint;
      } catch (_) {
        // curve or other; without stored fp we can't easily recover here
      }
    }

    // Sign a fresh random-nonce challenge with the right algorithm for the
    // pem — the old deterministic minute-bucket nonce made a second unlock in
    // the same minute indistinguishable from a replay, so the server refused it.
    final challenge = _crypto.createSignatureLoginChallenge(fingerprint);
    final signature = pemIsCurve(privateKeyPem)
        ? _crypto.ed25519Sign(
            message: challenge.message,
            privatePem: privateKeyPem,
          )
        : rust.rsaSign(
            message: challenge.message,
            privateKeyPem: privateKeyPem,
          );

    // Find the server for this account
    final servers = await _db.getAllServers();
    final server = servers.where((s) => s.id == account.serverId).firstOrNull;
    if (server == null) {
      throw Exception('Server not found for account');
    }

    // Create client and authenticate via signature
    final client = await ApiClient.create(
      baseUrl: server.url,
      accountId: accountId,
    );

    final authResp = await client.auth.signatureLogin(
      fingerprint: fingerprint,
      signature: signature,
      timestamp: challenge.timestamp,
      nonce: challenge.nonce,
    );

    // Detect header auth mode from response headers
    if (authResp.isHeaderAuth) {
      client.useHeaderAuth = true;
      await _db.updateServerUseHeaderAuth(server.id, true);
    }

    // Verify we got a session (cookie or header token)
    if (!await client.hasSession) {
      throw Exception(
        'Signature auth succeeded but no session was established',
      );
    }

    // Set as active
    await _db.setActiveAccount(accountId);

    _activeServer = server;
    _activeAccount = account;
    _setActiveClient(client, authResp: authResp);
    _decryptedPrivateKey = privateKeyPem;
    _decryptedWrappingPrivateKey = decoded.wrapping;
    // The PIN bundle carries only identity + wrapping keys, so a PIN-unlocked
    // session has no retained RSA key (see the reported PIN plumbing gap).
    _decryptedLegacyRsaPrivateKey = null;

    _log.info('unlocked with PIN');

    return account;
  }

  /// Clear the stored PIN-encrypted key (forget account from lock screen).
  /// Also clears biometric PIN from secure storage.
  Future<void> clearPin(String accountId) async {
    await _db.clearPinEncryptedKey(accountId);
    await _vault.deleteDeviceKey(accountId);
    await _securePinStorage.delete(accountId);
    // Also clear legacy SQLite column if it still has data.
    await _db.clearBiometricPin(accountId);
    _log.info('PIN-encrypted key cleared');
  }

  /// Enable biometric unlock by storing the user's PIN in the platform
  /// keychain (iOS Keychain / Android Keystore) for retrieval after
  /// successful biometric authentication.
  Future<void> enableBiometric(String accountId, String pin) async {
    await _securePinStorage.store(accountId, pin);
    // Clear any legacy plaintext PIN from SQLite.
    await _db.clearBiometricPin(accountId);
    _log.info('biometric unlock enabled');
  }

  /// Disable biometric unlock.
  Future<void> disableBiometric(String accountId) async {
    await _securePinStorage.delete(accountId);
    await _db.clearBiometricPin(accountId);
    _log.info('biometric unlock disabled');
  }

  /// Migrate any legacy plaintext PINs from SQLite to secure storage.
  /// Should be called once during app startup.
  Future<void> migrateBiometricPins() async {
    final accounts = await _db.getAllAccounts();
    for (final account in accounts) {
      if (account.biometricPin != null && account.biometricPin!.isNotEmpty) {
        // Move to secure storage, then clear from SQLite.
        await _securePinStorage.store(account.id, account.biometricPin!);
        await _db.clearBiometricPin(account.id);
        _log.info('migrated biometric PIN to secure storage');
      }
    }
  }
}
