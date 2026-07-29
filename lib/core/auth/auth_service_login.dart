part of 'auth_service.dart';

extension AuthServiceLogin on AuthService {
  /// Login with email + password + optional 2FA token.
  /// Cookies are handled automatically by the cookie jar.
  ///
  /// For migrated (security_version >= 1) accounts this performs the OPAQUE
  /// login (password never leaves the device). The envelope is opened with the
  /// OPAQUE export_key to obtain the Curve25519 private keys.
  /// For legacy accounts the classic password login is used (and auto-migration
  /// is attempted while the plaintext password is still available).
  Future<Account> login({
    required Server server,
    required String email,
    required String password,
    String? tfaToken,
  }) async {
    // Derive a stable account ID from server + email (known before login).
    final accountId = '${server.id}_${email.toLowerCase()}';
    final client = await _clientFactory(
      baseUrl: server.url,
      accountId: accountId,
    );

    // Probe with OPAQUE client start (local only) to let the server tell us
    // whether to do OPAQUE or fall back to legacy password login.
    final pwBytes = Uint8List.fromList(utf8.encode(password));
    final clientStart = _crypto.opaqueClientLoginStart(password: pwBytes);
    final startResp = await client.auth.loginStart(
      email: email,
      credentialRequest: clientStart.message,
    );
    final method = (startResp?['method'] as String?) ?? 'password';

    final AuthResponse authResp;
    rust.OpaqueLoginFinish? opaqueFinish;

    if (method == 'opaque') {
      final loginId = startResp!['login_id'] as String;
      final credResp = startResp['credential_response'] as String;

      // The account's own KSF, echoed by login/start. The export_key only
      // unseals the envelope when stretched with the same parameters
      // registration used, so a future work-factor raise never locks the user
      // out. Reading a constant here instead would break exactly that.
      final ksf = (startResp['ksf'] as Map).cast<String, dynamic>();

      final finish = _crypto.opaqueClientLoginFinish(
        loginState: clientStart.state,
        credentialResponse: credResp,
        password: pwBytes,
        mCost: (ksf['m_cost'] as num).toInt(),
        tCost: (ksf['t_cost'] as num).toInt(),
        pCost: (ksf['p_cost'] as num).toInt(),
      );
      opaqueFinish = finish;

      authResp = await client.auth.loginFinishOpaque(
        loginId: loginId,
        credentialFinalization: finish.finalization,
        token: tfaToken,
      );
    } else {
      authResp = await client.auth.login(
        email: email,
        password: password,
        token: tfaToken,
      );
    }

    _log.info(
      'login: API returned 200',
      fields: {
        'has_enc_key': authResp.encryptedPrivateKey != null,
        'is_header_auth': authResp.isHeaderAuth,
        'method': method,
      },
    );

    if (authResp.isHeaderAuth) {
      client.useHeaderAuth = true;
      await _db.updateServerUseHeaderAuth(server.id, true);
    }

    if (!await client.hasSession) {
      _log.warn('login: no session established after API success');
      throw Exception('Login succeeded but no session was established');
    }
    _log.info('login: session established');

    final finalAccountId = accountId;
    final account = await _db.insertAccount(
      AccountsCompanion(
        id: Value(finalAccountId),
        serverId: Value(server.id),
        userId: Value(authResp.id ?? ''),
        email: Value(authResp.email ?? email),
        fingerprint: Value(authResp.fingerprint),
        publicKey: Value(authResp.pubkey),
        wrappingPublicKey: Value(authResp.wrappingPubkey),
        encryptedPrivateKey: Value(authResp.encryptedPrivateKey),
        quota: Value(authResp.quota),
        role: Value(authResp.role),
        isActive: const Value(true),
        lastUsedAt: Value(DateTime.now()),
      ),
    );
    _log.info(
      'login: account inserted',
      fields: {'account_id': finalAccountId},
    );

    await _db.setActiveAccount(finalAccountId);

    _activeServer = server;
    _activeAccount = account;
    _setActiveClient(client, authResp: authResp);

    if (method == 'opaque' && opaqueFinish != null) {
      // export_key crosses the binding as base64; it must be decoded the same
      // way here and at migration time or the envelope never opens (lockout).
      final exportKey = base64Decode(opaqueFinish.exportKey);
      final kek = _crypto.envelopeDeriveKek(exportKey: exportKey);
      final env = authResp.encryptedPrivateKey ?? '';
      if (env.isNotEmpty) {
        final bundle = _crypto.envelopeOpen(kek: kek, envelope: env);
        final decoded = decodeKeyBundle(bundle);
        _decryptedPrivateKey = decoded.identity;
        _decryptedWrappingPrivateKey = decoded.wrapping;
        _decryptedLegacyRsaPrivateKey = decoded.legacyRsa;
      } else {
        _decryptedPrivateKey = null;
        _decryptedWrappingPrivateKey = null;
        _decryptedLegacyRsaPrivateKey = null;
      }
    } else {
      // Legacy path: decrypt with password, then auto-migrate if needed.
      _decryptPrivateKeyFromAccount(
        encryptedPrivateKey: authResp.encryptedPrivateKey,
        password: password,
      );

      // Re-key legacy accounts on login while the plaintext password and the
      // decrypted RSA key are both in hand. The ceremony re-wraps every file
      // key to the hybrid wrapping key; on any failure it aborts and the account stays legacy.
      // Kept in lockstep with the web client.
      if (AuthService.autoMigrationEnabled &&
          authResp.securityVersion == 0 &&
          _decryptedPrivateKey != null) {
        try {
          await _runMigrationCeremony(
            server: server,
            email: email,
            password: password,
            oldRsaPrivPem: _decryptedPrivateKey!,
          );
        } catch (e) {
          _log.warn(
            'auto-migration failed (account stays legacy)',
            fields: {'err': e.toString()},
          );
        }
      }
    }

    _log.info('login: completed');
    return account;
  }

  /// Attempt to decrypt the private key. If it fails we log the error but
  /// do not prevent login — the user can still browse the app, just without
  /// decrypted file names.
  void _decryptPrivateKeyFromAccount({
    required String? encryptedPrivateKey,
    required String password,
  }) {
    if (encryptedPrivateKey == null || encryptedPrivateKey.isEmpty) {
      _log.warn('no encrypted private key on account');
      _decryptedPrivateKey = null;
      _decryptedWrappingPrivateKey = null;
      _decryptedLegacyRsaPrivateKey = null;
      return;
    }
    try {
      _decryptedPrivateKey = _crypto.decryptPrivateKey(
        encryptedPrivateKeyHex: encryptedPrivateKey,
        password: password,
      );
      // A still-legacy account's RSA key is its identity key above; there is no
      // separate retained-RSA slot until the account migrates.
      _decryptedLegacyRsaPrivateKey = null;
      _log.info('private key decrypted');
    } catch (e) {
      _log.warn(
        'private key decryption failed',
        fields: {'error': redactException(e)},
      );
      _decryptedPrivateKey = null;
      _decryptedWrappingPrivateKey = null;
      _decryptedLegacyRsaPrivateKey = null;
    }
  }
}
