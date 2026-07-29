part of 'auth_service.dart';

extension AuthServiceRegistration on AuthService {
  /// Create a brand-new account. New accounts are born v2 (Curve25519 identity
  /// + hybrid wrapping keys, OPAQUE password file); the server refuses legacy
  /// RSA registration. The ceremony mirrors the migration one minus the
  /// transition certificate and the key re-wrap — a fresh account holds no
  /// file keys yet.
  ///
  /// The [tfaSecret]/[tfaToken] pair is only set when the caller opted into
  /// 2FA during signup. When the server enforces email activation the account
  /// is created without a session; [register] returns without a decrypted key
  /// and the caller routes the user to log in once the email is verified.
  Future<Account> register({
    required Server server,
    required String email,
    required String password,
    String? tfaSecret,
    String? tfaToken,
    String? invitationId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final accountId = '${server.id}_$normalizedEmail';
    final client = await _clientFactory(
      baseUrl: server.url,
      accountId: accountId,
    );

    final ed = _crypto.generateEd25519KeyPair();
    final x = _crypto.generateWrappingKeyPair();
    final edPub = ed.publicPem;
    final xPub = x.publicPem;
    final fingerprint = _crypto.spkiFingerprint(publicPem: edPub);

    final pwBytes = Uint8List.fromList(utf8.encode(password));
    final regStart = _crypto.opaqueClientRegistrationStart(password: pwBytes);
    final registrationResponse = await client.auth.signupRegisterStart(
      email: normalizedEmail,
      registrationRequest: regStart.message,
    );
    final regFinish = _crypto.opaqueClientRegistrationFinish(
      registrationState: regStart.state,
      registrationResponse: registrationResponse,
      password: pwBytes,
    );

    // export_key crosses the binding as base64; decode it the same way the
    // login and migration paths do or the sealed envelope never re-opens.
    final exportKey = base64Decode(regFinish.exportKey);
    final kek = _crypto.envelopeDeriveKek(exportKey: exportKey);
    final bundle = Uint8List.fromList(
      encodeKeyBundle(
        identity: ed.privatePem,
        wrapping: x.privatePem,
      ).codeUnits,
    );
    final env = _crypto.envelopeSeal(kek: kek, bundle: bundle);

    // Never submit a bundle that cannot be re-opened or whose identity key
    // fails a sign/verify probe — that would lock the account out on first
    // login.
    final reopened = _crypto.envelopeOpen(kek: kek, envelope: env);
    if (reopened.isEmpty) throw Exception('envelope self-check failed');
    final probe = 'register-probe-$normalizedEmail';
    final probeSig = _crypto.ed25519Sign(
      message: probe,
      privatePem: ed.privatePem,
    );
    if (!_crypto.ed25519Verify(
      message: probe,
      signature: probeSig,
      publicPem: edPub,
    )) {
      throw Exception('ed25519 self-check failed');
    }

    final authResp = await client.auth.register(
      email: normalizedEmail,
      pubkey: edPub,
      wrappingPubkey: xPub,
      fingerprint: fingerprint,
      encryptedPrivateKey: env,
      opaqueRegistrationUpload: regFinish.message,
      secret: tfaSecret,
      token: tfaToken,
      invitationId: invitationId,
      locale: Intl.defaultLocale?.split('_').first,
    );

    // The server enforces email activation: the account exists but no session
    // was issued. Persist the identity so the login screen can find it, and
    // leave the key material for the post-activation login to establish.
    if (authResp == null) {
      final account = await _db.insertAccount(
        AccountsCompanion(
          id: Value(accountId),
          serverId: Value(server.id),
          userId: const Value(''),
          email: Value(normalizedEmail),
          fingerprint: Value(fingerprint),
          publicKey: Value(edPub),
          wrappingPublicKey: Value(xPub),
          isActive: const Value(false),
        ),
      );
      return account;
    }

    if (authResp.isHeaderAuth) {
      client.useHeaderAuth = true;
      await _db.updateServerUseHeaderAuth(server.id, true);
    }
    if (!await client.hasSession) {
      throw Exception('Registration succeeded but no session was established');
    }

    final account = await _db.insertAccount(
      AccountsCompanion(
        id: Value(accountId),
        serverId: Value(server.id),
        userId: Value(authResp.id ?? ''),
        email: Value(authResp.email ?? normalizedEmail),
        fingerprint: Value(authResp.fingerprint ?? fingerprint),
        publicKey: Value(authResp.pubkey ?? edPub),
        wrappingPublicKey: Value(authResp.wrappingPubkey ?? xPub),
        encryptedPrivateKey: Value(authResp.encryptedPrivateKey ?? env),
        quota: Value(authResp.quota),
        role: Value(authResp.role),
        isActive: const Value(true),
        lastUsedAt: Value(DateTime.now()),
      ),
    );
    await _db.setActiveAccount(accountId);

    _activeServer = server;
    _activeAccount = account;
    _setActiveClient(client, authResp: authResp);
    _decryptedPrivateKey = ed.privatePem;
    _decryptedWrappingPrivateKey = x.privatePem;
    _decryptedLegacyRsaPrivateKey = null;

    _log.info('register: completed');
    return account;
  }
}
