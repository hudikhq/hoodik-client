part of 'auth_service.dart';

/// Keys per `migration/rewrap` batch, and the page size when fetching them. A
/// hybrid X25519+ML-KEM wrap is ~1.7 KB of base64, so 500 entries is ~0.85 MB —
/// under the server's migration JSON limit with headroom, and the same partition
/// the web client uses so both emit byte-identical batch bodies.
const _migrationRewrapBatchSize = 500;

extension AuthServiceMigration on AuthService {
  Future<void> _runMigrationCeremony({
    required Server server,
    required String email,
    required String password,
    required String oldRsaPrivPem,
  }) async {
    _log.info('migration: starting legacy -> curve25519 + OPAQUE');

    final client = _activeClient;
    if (client == null) throw Exception('no active client for migration');

    // 1. Generate new Ed identity + hybrid wrapping keypairs (heavy but fast)
    final ed = _crypto.generateEd25519KeyPair();
    final x = _crypto.generateWrappingKeyPair();

    final newEdPriv = ed.privatePem;
    final newEdPub = ed.publicPem;
    final newXPriv = x.privatePem;
    final newXPub = x.publicPem;

    // fingerprint for the new identity (SPKI)
    final newFp = _crypto.spkiFingerprint(publicPem: newEdPub);

    // 2. Fetch every file key and public-link key we hold (must be
    // authenticated via the legacy session) and re-wrap both under the new
    // wrapping key. The rewrap is O(keys) synchronous RSA-decrypt + hybrid-wrap
    // calls — heavy enough to ANR a large account, so it runs in a one-shot
    // isolate. Any single failure throws out of Isolate.run and aborts the
    // whole migration (no partial commit): the old RSA key is about to be
    // discarded, so a skipped file key OR link key would be unrecoverable.
    // Page the key set to its end, accumulating every file and link key. The
    // server bounds each page so a large account's set is never held whole
    // server-side; the client reassembles it, then the isolate re-wraps it all.
    final fileKeys = <Map<String, dynamic>>[];
    final linkKeys = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await client.auth.migrationKeys(
        offset: offset,
        limit: _migrationRewrapBatchSize,
      );
      fileKeys.addAll(page.keys);
      linkKeys.addAll(page.linkKeys);
      if (page.nextOffset == null) break;
      offset = page.nextOffset!;
    }
    final result = await Isolate.run(
      () => rewrapMigrationKeys(
        fileKeys: fileKeys,
        linkKeys: linkKeys,
        oldRsaPrivPem: oldRsaPrivPem,
        newXPub: newXPub,
        newEdPriv: newEdPriv,
      ),
    );

    // 3. Transition certificate (old RSA endorses new Ed)
    final issuedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uid = (_activeAccount?.userId ?? '').replaceAll('-', '');
    final userIdBytes = _crypto.hexDecode(uid);
    final sigs = _crypto.transitionSign(
      userId: userIdBytes,
      oldKeyType: 'rsa',
      oldKeyPem: (_activeAccount?.publicKey ?? ''),
      oldFingerprint: (_activeAccount?.fingerprint ?? ''),
      newIdentityKeyPem: newEdPub,
      newWrappingKeyPem: newXPub,
      newFingerprint: newFp,
      issuedAt: issuedAt,
      oldPrivateKey: oldRsaPrivPem,
      newIdentityPrivateKey: newEdPriv,
    );

    // The key change is the single most security-relevant event on the owner's
    // audit chain, so the new identity signs it and the server logs it in-chain.
    // The server re-encodes this canonical from its own state and aborts the
    // whole migration if the signature is absent or does not verify.
    final auditSignature = _crypto.signKeyRotationAudit(
      userId: userIdBytes,
      oldFingerprint: (_activeAccount?.fingerprint ?? ''),
      newFingerprint: newFp,
      rotatedAt: issuedAt,
      newIdentityPrivateKey: newEdPriv,
    );

    // 4. OPAQUE registration (authenticated)
    final regStart = _crypto.opaqueClientRegistrationStart(
      password: Uint8List.fromList(utf8.encode(password)),
    );
    final regResp = await client.auth.pakeRegisterStart(
      registrationRequest: regStart.message,
    );
    final regFinish = _crypto.opaqueClientRegistrationFinish(
      registrationState: regStart.state,
      registrationResponse: regResp['registration_response'] as String,
      password: Uint8List.fromList(utf8.encode(password)),
    );

    // export_key crosses the binding as base64; decode it the same way the
    // login path does or the sealed envelope will never re-open (lockout).
    final exportKey = base64Decode(regFinish.exportKey);

    // 5. Envelope — retain the old RSA key so pre-migration ciphertext and the
    // recovery path stay decryptable after the account moves to curve keys.
    final bundle = Uint8List.fromList(
      encodeKeyBundle(
        identity: newEdPriv,
        wrapping: newXPriv,
        legacyRsa: oldRsaPrivPem,
      ).codeUnits,
    );
    final kek = _crypto.envelopeDeriveKek(exportKey: exportKey);
    final env = _crypto.envelopeSeal(kek: kek, bundle: bundle);

    // 6. Self-check before submitting: never commit a migration that would
    // lock the user out or lose a file key.
    final reopened = _crypto.envelopeOpen(kek: kek, envelope: env);
    if (reopened.isEmpty) throw Exception('envelope self-check failed');
    final probe = 'migration-probe-$issuedAt';
    final probeSig = _crypto.ed25519Sign(message: probe, privatePem: newEdPriv);
    final probeOk = _crypto.ed25519Verify(
      message: probe,
      signature: probeSig,
      publicPem: newEdPub,
    );
    if (!probeOk) throw Exception('ed25519 self-check failed');
    // A re-wrapped file key and link key must each unwrap under the new wrapping
    // key and match the original — this proves every file and every public link
    // survives the re-key. Each probe is skipped only when the account holds no
    // keys of that kind.
    if (result.sampleFileKey != null) {
      final recovered = _crypto.wrappingUnwrap(
        blob: result.sampleFileBlob!,
        privatePem: newXPriv,
      );
      if (!_bytesEqual(recovered, result.sampleFileKey!)) {
        throw Exception('rewrapped file key self-check failed');
      }
    }
    if (result.sampleLinkKey != null) {
      final recovered = _crypto.wrappingUnwrap(
        blob: result.sampleLinkBlob!,
        privatePem: newXPriv,
      );
      if (!_bytesEqual(recovered, result.sampleLinkKey!)) {
        throw Exception('rewrapped link key self-check failed');
      }
      // The re-signature must verify under the new identity, or the server
      // rejects the whole migration with link_signature_invalid.
      final linkSigOk = _crypto.ed25519Verify(
        message: result.sampleLinkFileId!,
        signature: result.sampleLinkSignature!,
        publicPem: newEdPub,
      );
      if (!linkSigOk) {
        throw Exception('rewrapped link signature self-check failed');
      }
    }

    // 7. Stage the re-wrapped keys in batches so no single request carries the
    // whole account's keys. A failure here throws before complete, so nothing is
    // applied and the staged rows are left for the server to purge — the account
    // stays legacy and the next login retries cleanly.
    final total = result.fileKeys.length + result.linkKeys.length;
    for (var start = 0; start < total; start += _migrationRewrapBatchSize) {
      final end = start + _migrationRewrapBatchSize < total
          ? start + _migrationRewrapBatchSize
          : total;
      final batchKeys = <Map<String, dynamic>>[];
      final batchLinks = <Map<String, dynamic>>[];
      for (var i = start; i < end; i++) {
        if (i < result.fileKeys.length) {
          batchKeys.add(result.fileKeys[i]);
        } else {
          batchLinks.add(result.linkKeys[i - result.fileKeys.length]);
        }
      }
      await client.auth.migrationRewrap(keys: batchKeys, linkKeys: batchLinks);
    }

    // 8. POST complete: the server applies the staged re-wraps and flips the
    // account in one transaction.
    await client.auth.migrationComplete(
      newIdentityPubkey: newEdPub,
      newWrappingPubkey: newXPub,
      newFingerprint: newFp,
      transitionOldSignature: sigs.oldSignature,
      transitionNewSignature: sigs.newSignature,
      transitionIssuedAt: issuedAt,
      opaqueRegistrationUpload: regFinish.message,
      encryptedPrivateKey: env,
      auditEventSignature: auditSignature,
    );

    // 9. Update in-memory privs for the session. The old RSA key stays in
    // memory (now sealed in the envelope) for legacy ciphertext and recovery.
    _decryptedPrivateKey = newEdPriv;
    _decryptedWrappingPrivateKey = newXPriv;
    _decryptedLegacyRsaPrivateKey = oldRsaPrivPem;

    // Persist the migrated identity to the local account row. The stored
    // fingerprint feeds quick-unlock's signature login and the wrapping key
    // feeds own-key encryption (the local MCP bearer token), so both must
    // reflect the new keys this session without waiting for a fresh login.
    final accountId = _activeAccount?.id;
    if (accountId != null) {
      await _db.persistMigratedIdentity(
        accountId,
        fingerprint: newFp,
        publicKey: newEdPub,
        wrappingPublicKey: newXPub,
        encryptedPrivateKey: env,
      );
      _activeAccount = await _db.getAccountById(accountId);
    }

    // The PIN store still holds the old RSA key, which no longer decrypts
    // anything. Clear it so the next unlock re-establishes a PIN over the new
    // key instead of failing against the stale one.
    if (accountId != null) {
      await clearPin(accountId);
    }

    _log.info('migration: ceremony completed');
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
