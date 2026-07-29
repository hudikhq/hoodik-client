import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/key_transition.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

Uint8List _repeat(int byte, int length) =>
    Uint8List.fromList(List.filled(length, byte));

String _uuid(int byte) {
  final hex = byte.toRadixString(16).padLeft(2, '0') * 16;
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late rust.RsaKeyPair kp;
  late ShareCrypto shareCrypto;
  const crypto = CryptoService();

  setUp(() {
    kp = rust.generateRsaKeypair();
    shareCrypto = ShareCrypto(privateKeyPem: kp.privateKeyPem);
  });

  group('wrapForRecipient / decryptOwnFileKey', () {
    test('roundtrips a file key through the recipient wrap', () {
      final fileKey = crypto.generateSymmetricKey();
      final fileKeyHex = crypto.hexEncode(fileKey);

      final wrapped = shareCrypto.wrapForRecipient(
        fileKey: fileKey,
        recipientPubkey: kp.publicKeyPem,
      );
      expect(shareCrypto.decryptOwnFileKey(wrapped), equals(fileKeyHex));
    });

    test('wraps raw key bytes under a curve25519 recipient wrapping key', () {
      final recipient = crypto.generateWrappingKeyPair();
      final identity = crypto.generateEd25519KeyPair();
      final fileKey = crypto.generateSymmetricKey();

      final wrapped = shareCrypto.wrapForRecipient(
        fileKey: fileKey,
        recipientPubkey: identity.publicPem,
        recipientKeyType: 'curve25519',
        recipientWrappingPubkey: recipient.publicPem,
      );
      expect(
        crypto.wrappingUnwrap(blob: wrapped, privatePem: recipient.privatePem),
        equals(fileKey),
      );
    });

    test('refuses a curve25519 recipient without a wrapping key', () {
      final identity = crypto.generateEd25519KeyPair();
      expect(
        () => shareCrypto.wrapForRecipient(
          fileKey: crypto.generateSymmetricKey(),
          recipientPubkey: identity.publicPem,
          recipientKeyType: 'curve25519',
        ),
        throwsStateError,
      );
    });

    test('decryptOwnFileKey unwraps a hybrid self-wrap on a curve account', () {
      final identity = crypto.generateEd25519KeyPair();
      final wrapping = crypto.generateWrappingKeyPair();
      final curveShareCrypto = ShareCrypto(
        privateKeyPem: identity.privatePem,
        wrappingPrivateKeyPem: wrapping.privatePem,
      );
      final fileKey = crypto.generateSymmetricKey();

      final wrapped = curveShareCrypto.wrapForRecipient(
        fileKey: fileKey,
        recipientPubkey: identity.publicPem,
        recipientKeyType: 'curve25519',
        recipientWrappingPubkey: wrapping.publicPem,
      );

      expect(
        curveShareCrypto.decryptOwnFileKey(wrapped),
        equals(crypto.hexEncode(fileKey)),
      );
    });
  });

  group('computeEntriesHash', () {
    test('is order-independent', () {
      final entries = [
        ShareEntryInput(
          fileId: _uuid(0xA1),
          encryptedKey: base64.encode(_repeat(0xA1, 64)),
        ),
        ShareEntryInput(
          fileId: _uuid(0xB2),
          encryptedKey: base64.encode(_repeat(0xB2, 64)),
        ),
      ];
      final hashA = shareCrypto.computeEntriesHash(entries);
      final hashB = shareCrypto.computeEntriesHash(entries.reversed.toList());
      expect(hashB, equals(hashA));
    });

    test('matches sha256(entries_encode_v1) for the same inputs', () {
      final entries = [
        ShareEntryInput(
          fileId: _uuid(0xDD),
          encryptedKey: base64.encode(_repeat(0x11, 256)),
        ),
        ShareEntryInput(
          fileId: _uuid(0x99),
          encryptedKey: base64.encode(_repeat(0x22, 256)),
        ),
      ];
      final hashBytes = shareCrypto.computeEntriesHash(entries);

      final fileIds = Uint8List(2 * 16)
        ..setRange(0, 16, _repeat(0xDD, 16))
        ..setRange(16, 32, _repeat(0x99, 16));
      final flat = Uint8List(2 * 256)
        ..setRange(0, 256, _repeat(0x11, 256))
        ..setRange(256, 512, _repeat(0x22, 256));
      final der = rust.entriesEncodeV1(
        fileIds: fileIds,
        encryptedKeysFlat: flat,
        encryptedKeyLengths: [256, 256],
      );
      expect(crypto.hexEncode(hashBytes), equals(rust.sha256Digest(data: der)));
    });

    test('throws on an empty entries list', () {
      expect(() => shareCrypto.computeEntriesHash([]), throwsArgumentError);
    });
  });

  group('signSharePayload', () {
    test('signs prefix ‖ payloadDer and verifies against the own pubkey', () {
      final entries = [
        ShareEntryInput(
          fileId: _uuid(0x44),
          encryptedKey: base64.encode(_repeat(0x77, 64)),
        ),
      ];
      final entriesHash = shareCrypto.computeEntriesHash(entries);

      final signed = shareCrypto.signSharePayload(
        senderId: _uuid(0x11),
        recipientId: _uuid(0x22),
        recipientPubkeyFingerprint: _repeat(0x33, 32),
        shareRole: ShareRole.editor,
        rootFileId: _uuid(0x44),
        entriesHash: entriesHash,
        timestamp: 1735689600,
        nonce: _repeat(0x66, 16),
      );

      final der = base64.decode(signed.payloadDer);
      final prefix = utf8.encode('hoodik-share-v1\x00');
      final signingInput = Uint8List(prefix.length + der.length)
        ..setRange(0, prefix.length, prefix)
        ..setRange(prefix.length, prefix.length + der.length, der);
      expect(
        rust.rsaVerifyBytes(
          message: signingInput,
          signature: signed.signature,
          publicKeyPem: kp.publicKeyPem,
        ),
        isTrue,
      );
    });

    test('rejects a tampered payload', () {
      final entries = [
        ShareEntryInput(
          fileId: _uuid(0x44),
          encryptedKey: base64.encode(_repeat(0x77, 64)),
        ),
      ];
      final signed = shareCrypto.signSharePayload(
        senderId: _uuid(0x11),
        recipientId: _uuid(0x22),
        recipientPubkeyFingerprint: _repeat(0x33, 32),
        shareRole: ShareRole.reader,
        rootFileId: _uuid(0x44),
        entriesHash: shareCrypto.computeEntriesHash(entries),
        timestamp: 1735689600,
        nonce: _repeat(0x66, 16),
      );

      final der = Uint8List.fromList(base64.decode(signed.payloadDer));
      der[20] ^= 0xFF;
      final prefix = utf8.encode('hoodik-share-v1\x00');
      final tampered = Uint8List(prefix.length + der.length)
        ..setRange(0, prefix.length, prefix)
        ..setRange(prefix.length, prefix.length + der.length, der);
      expect(
        rust.rsaVerifyBytes(
          message: tampered,
          signature: signed.signature,
          publicKeyPem: kp.publicKeyPem,
        ),
        isFalse,
      );
    });
  });

  group('signAuditEvent / verifyAuditEvent', () {
    AuditEventSigInput input({
      String? recipientId,
      ShareRole? before,
      ShareRole? after,
      AuditEventAction action = AuditEventAction.grant,
    }) {
      return AuditEventSigInput(
        senderId: _uuid(0xAA),
        recipientId: recipientId,
        fileId: _uuid(0xCC),
        action: action,
        shareRoleBefore: before,
        shareRoleAfter: after,
        timestamp: 1735689900,
      );
    }

    test('roundtrips with an absent recipient and before-role', () {
      final i = input(after: ShareRole.editor);
      final sig = shareCrypto.signAuditEvent(i);
      expect(
        shareCrypto.verifyAuditEvent(
          input: i,
          signature: sig,
          senderPubkey: kp.publicKeyPem,
        ),
        isTrue,
      );
    });

    test('role_change commits to both before and after roles', () {
      final i = input(
        recipientId: _uuid(0xBB),
        action: AuditEventAction.roleChange,
        before: ShareRole.editor,
        after: ShareRole.coOwner,
      );
      final sig = shareCrypto.signAuditEvent(i);
      expect(
        shareCrypto.verifyAuditEvent(
          input: i,
          signature: sig,
          senderPubkey: kp.publicKeyPem,
        ),
        isTrue,
      );

      bool verify(AuditEventSigInput other) => shareCrypto.verifyAuditEvent(
        input: other,
        signature: sig,
        senderPubkey: kp.publicKeyPem,
      );
      expect(
        verify(
          input(
            recipientId: _uuid(0xBB),
            action: AuditEventAction.roleChange,
            before: ShareRole.reader,
            after: ShareRole.coOwner,
          ),
        ),
        isFalse,
      );
      expect(
        verify(
          input(
            recipientId: _uuid(0xBB),
            action: AuditEventAction.roleChange,
            before: ShareRole.editor,
            after: ShareRole.editor,
          ),
        ),
        isFalse,
      );
      expect(
        verify(
          input(
            recipientId: _uuid(0xBB),
            action: AuditEventAction.grant,
            before: ShareRole.editor,
            after: ShareRole.coOwner,
          ),
        ),
        isFalse,
      );
    });

    test('a changed timestamp fails verification', () {
      final i = input(after: ShareRole.reader);
      final sig = shareCrypto.signAuditEvent(i);
      final tampered = AuditEventSigInput(
        senderId: i.senderId,
        recipientId: i.recipientId,
        fileId: i.fileId,
        action: i.action,
        shareRoleBefore: i.shareRoleBefore,
        shareRoleAfter: i.shareRoleAfter,
        timestamp: i.timestamp + 1,
      );
      expect(
        shareCrypto.verifyAuditEvent(
          input: tampered,
          signature: sig,
          senderPubkey: kp.publicKeyPem,
        ),
        isFalse,
      );
    });

    test('move-out canonical byte-matches the server reconstruction', () {
      // The server signs/verifies move-out with action ENUMERATED 9, an
      // absent recipient, and both roles absent. Sign through ShareCrypto,
      // then independently rebuild the canonical the way the server does
      // (raw FFI, action byte 9, empty recipient, role sentinel 255) and
      // confirm the same signature verifies over prefix ‖ der. If the Dart
      // enum's wire weren't exactly 9, the FFI would encode a different
      // ENUMERATED — or reject the discriminant — and this would fail.
      final i = input(action: AuditEventAction.sharedFolderMoveOut);
      final sig = shareCrypto.signAuditEvent(i);

      final der = rust.auditEventSigInputEncodeV1(
        senderId: _repeat(0xAA, 16),
        recipientId: Uint8List(0),
        fileId: _repeat(0xCC, 16),
        action: 9,
        shareRoleBefore: 255,
        shareRoleAfter: 255,
        timestamp: 1735689900,
      );
      final prefix = utf8.encode('hoodik-audit-sig-v1\x00');
      final signingInput = Uint8List(prefix.length + der.length)
        ..setRange(0, prefix.length, prefix)
        ..setRange(prefix.length, prefix.length + der.length, der);
      expect(
        rust.rsaVerifyBytes(
          message: signingInput,
          signature: sig,
          publicKeyPem: kp.publicKeyPem,
        ),
        isTrue,
      );
    });
  });

  group('signMember / verifyMemberSignature', () {
    test('roundtrips a member signature', () {
      final fp = crypto.rsaFingerprintPublic(publicKeyPem: kp.publicKeyPem);
      final sig = shareCrypto.signMember(
        userId: _uuid(0x77),
        pubkeyPem: kp.publicKeyPem,
        pubkeyFingerprintHex: fp,
        shareRole: ShareRole.coOwner,
        signedAt: 1735689700,
      );
      expect(
        shareCrypto.verifyMemberSignature(
          userId: _uuid(0x77),
          pubkeyPem: kp.publicKeyPem,
          pubkeyFingerprintHex: fp,
          shareRole: ShareRole.coOwner,
          signedAt: 1735689700,
          signature: sig,
          signerPubkey: kp.publicKeyPem,
        ),
        isTrue,
      );
    });

    test('verifies a curve25519 signer over a curve25519 member', () {
      final member = crypto.generateEd25519KeyPair();
      final signer = crypto.generateEd25519KeyPair();
      final fp = crypto.spkiFingerprint(publicPem: member.publicPem);

      final der = crypto.memberSigEncodeV1(
        userId: Uint8List.fromList(List.filled(16, 0x77)),
        pubkeyDer: crypto.memberPubkeyDer(
          keyType: 'curve25519',
          publicKeyPem: member.publicPem,
        ),
        fingerprint: crypto.hexDecode(fp),
        shareRole: ShareRole.coOwner.wire,
        signedAt: 1735689700,
      );
      final prefix = utf8.encode('hoodik-folder-mem-v1\x00');
      final signingInput = Uint8List(prefix.length + der.length)
        ..setRange(0, prefix.length, prefix)
        ..setRange(prefix.length, prefix.length + der.length, der);
      final sig = crypto.ed25519SignBytes(
        message: signingInput,
        privatePem: signer.privatePem,
      );

      expect(
        shareCrypto.verifyMemberSignature(
          userId: _uuid(0x77),
          pubkeyPem: member.publicPem,
          keyType: 'curve25519',
          pubkeyFingerprintHex: fp,
          shareRole: ShareRole.coOwner,
          signedAt: 1735689700,
          signature: sig,
          signerPubkey: signer.publicPem,
          signerKeyType: 'curve25519',
        ),
        isTrue,
      );
      expect(
        shareCrypto.verifyMemberSignature(
          userId: _uuid(0x77),
          pubkeyPem: member.publicPem,
          keyType: 'curve25519',
          pubkeyFingerprintHex: fp,
          shareRole: ShareRole.editor,
          signedAt: 1735689700,
          signature: sig,
          signerPubkey: signer.publicPem,
          signerKeyType: 'curve25519',
        ),
        isFalse,
      );
    });
  });

  group('memberPubkeyDer', () {
    test('rsa dispatch matches rsaPkcs1DerFromPem', () {
      expect(
        crypto.memberPubkeyDer(keyType: 'rsa', publicKeyPem: kp.publicKeyPem),
        equals(crypto.rsaPkcs1DerFromPem(publicKeyPem: kp.publicKeyPem)),
      );
    });

    test('curve25519 dispatch returns the SPKI PEM body', () {
      final identity = crypto.generateEd25519KeyPair();
      final pemBody = identity.publicPem
          .split('\n')
          .where((line) => line.isNotEmpty && !line.startsWith('-----'))
          .join();
      expect(
        crypto.memberPubkeyDer(
          keyType: 'curve25519',
          publicKeyPem: identity.publicPem,
        ),
        equals(base64.decode(pemBody)),
      );
    });
  });

  group('signFolderMemberList / verifyFolderMemberListSignature', () {
    FolderMemberList list() {
      final fp = crypto.rsaFingerprintPublic(publicKeyPem: kp.publicKeyPem);
      return FolderMemberList(
        folderId: _uuid(0xF0),
        folderOwnerId: _uuid(0x11),
        members: [
          FolderMemberListMember(
            userId: _uuid(0x11),
            pubkeyFingerprintHex: fp,
            shareRole: ShareRole.reader,
            isOwner: true,
            signedByUserId: _uuid(0x11),
          ),
          FolderMemberListMember(
            userId: _uuid(0x22),
            pubkeyFingerprintHex: fp,
            shareRole: ShareRole.coOwner,
            isOwner: false,
            signedByUserId: _uuid(0x11),
          ),
        ],
        membersSignedAt: 1736000000,
      );
    }

    test('roundtrips the list signature', () {
      final signed = shareCrypto.signFolderMemberList(list());
      expect(
        shareCrypto.verifyFolderMemberListSignature(
          list: list(),
          signature: signed.signature,
          signerPubkey: kp.publicKeyPem,
        ),
        isTrue,
      );
    });

    test('verification is order-independent (encoder sorts members)', () {
      final signed = shareCrypto.signFolderMemberList(list());
      final reordered = FolderMemberList(
        folderId: list().folderId,
        folderOwnerId: list().folderOwnerId,
        members: list().members.reversed.toList(),
        membersSignedAt: list().membersSignedAt,
      );
      expect(
        shareCrypto.verifyFolderMemberListSignature(
          list: reordered,
          signature: signed.signature,
          signerPubkey: kp.publicKeyPem,
        ),
        isTrue,
      );
    });
  });

  group('recomputeChainHash / verifyChain', () {
    ShareEventRow event({
      required String id,
      required int createdAt,
      String? prevEventHash,
      required String thisEventHash,
    }) {
      return ShareEventRow(
        id: id,
        senderId: _uuid(0xAA),
        recipientId: _uuid(0xBB),
        fileId: _uuid(0xCC),
        action: AuditEventAction.grant,
        shareRoleBefore: null,
        shareRoleAfter: ShareRole.reader,
        createdAt: createdAt,
        prevEventHash: prevEventHash,
        thisEventHash: thisEventHash,
        senderSignature: null,
      );
    }

    test('recompute matches sha256(prefix ‖ prev ‖ audit_event_encode)', () {
      final row = event(id: '1', createdAt: 100, thisEventHash: 'unused');
      final got = shareCrypto.recomputeChainHash(row, null);

      final eventDer = rust.auditEventEncodeV1(
        senderId: _repeat(0xAA, 16),
        recipientId: _repeat(0xBB, 16),
        fileId: _repeat(0xCC, 16),
        action: 'grant',
        shareRole: 0,
        createdAt: 100,
      );
      final prefix = utf8.encode('hoodik-audit-v1\x00');
      final input = Uint8List(prefix.length + 32 + eventDer.length);
      input.setRange(0, prefix.length, prefix);
      input.setRange(prefix.length + 32, input.length, eventDer);
      final expected = base64.encode(
        crypto.hexDecode(rust.sha256Digest(data: input)),
      );
      expect(got, equals(expected));
    });

    test('a clean two-row chain verifies', () {
      final first = event(id: '1', createdAt: 100, thisEventHash: 'unverified');
      final firstHash = shareCrypto.recomputeChainHash(first, null);
      final firstRow = event(id: '1', createdAt: 100, thisEventHash: firstHash);

      final second = event(
        id: '2',
        createdAt: 200,
        prevEventHash: firstHash,
        thisEventHash: 'unverified',
      );
      final secondHash = shareCrypto.recomputeChainHash(second, firstHash);
      final secondRow = event(
        id: '2',
        createdAt: 200,
        prevEventHash: firstHash,
        thisEventHash: secondHash,
      );

      final result = shareCrypto.verifyChain([secondRow, firstRow]);
      expect(result.chainOk, everyElement(isTrue));
      expect(result.firstBreakIndex, -1);
      expect(result.rowStatus, contains(ChainRowStatus.linked));
    });

    test('a forged self-hash is flagged', () {
      final row = event(
        id: '1',
        createdAt: 100,
        thisEventHash: 'not-the-real-hash',
      );
      final result = shareCrypto.verifyChain([row]);
      expect(result.chainOk.first, isFalse);
      expect(result.rowStatus.first, ChainRowStatus.selfHashMismatch);
      expect(result.firstBreakIndex, 0);
    });
  });

  group('fingerprint', () {
    test('computeFingerprint matches rsaFingerprintPublic', () {
      expect(
        shareCrypto.computeFingerprint(kp.publicKeyPem),
        equals(rust.rsaFingerprintPublic(publicKeyPem: kp.publicKeyPem)),
      );
    });

    test('computeFingerprint hashes the SPKI for a curve25519 identity', () {
      final identity = crypto.generateEd25519KeyPair();
      expect(
        shareCrypto.computeFingerprint(
          identity.publicPem,
          keyType: 'curve25519',
        ),
        equals(rust.spkiFingerprint(publicPem: identity.publicPem)),
      );
    });

    test('formatFingerprint renders byte-aligned quad groups', () {
      expect(
        shareCrypto.formatFingerprint('aabbccdd11223344'),
        'AABB-CCDD-1122-3344',
      );
      expect(
        shareCrypto.formatFingerprint('abcdef' * 4),
        'ABCD-EFAB-CDEF-ABCD-EFAB-CDEF',
      );
    });
  });

  // A signer that migrated RSA->curve25519 leaves signatures made under the old
  // key. The server hands back the superseded key inside a `key_transition`
  // certificate; verify that the client falls back to it only after the
  // certificate itself verifies — a fabricated transition is exactly how a
  // hostile server would substitute an identity.
  group('key-transition fallback', () {
    late rust.RsaKeyPair oldRsa;
    late rust.Ed25519KeyPair newCurve;
    late rust.WrappingKeyPair newWrapping;
    late ShareCrypto rsaSigner;
    late KeyTransition transition;

    const owner = '11111111-1111-1111-1111-111111111111';
    const member = '22222222-2222-2222-2222-222222222222';

    // A genuinely dual-signed certificate for [userId], optionally lying about
    // the old key's fingerprint the way a forger naming a victim's would.
    KeyTransition signedTransition({
      required rust.RsaKeyPair old,
      required rust.Ed25519KeyPair identity,
      required rust.WrappingKeyPair wrapping,
      required Uint8List userId,
      String? claimedOldFingerprint,
    }) {
      final oldFp =
          claimedOldFingerprint ??
          crypto.rsaFingerprintPublic(publicKeyPem: old.publicKeyPem);
      final newFp = crypto.spkiFingerprint(publicPem: identity.publicPem);
      final sigs = rust.transitionSign(
        userId: userId,
        oldKeyType: 'rsa',
        oldKeyPem: old.publicKeyPem,
        oldFingerprint: oldFp,
        newIdentityKeyPem: identity.publicPem,
        newWrappingKeyPem: wrapping.publicPem,
        newFingerprint: newFp,
        issuedAt: 1736000000,
        oldPrivateKey: old.privateKeyPem,
        newIdentityPrivateKey: identity.privatePem,
      );
      return KeyTransition(
        oldKeyPem: old.publicKeyPem,
        oldKeyType: 'rsa',
        oldFingerprint: oldFp,
        newIdentityKeyPem: identity.publicPem,
        newWrappingKeyPem: wrapping.publicPem,
        newFingerprint: newFp,
        oldSignature: sigs.oldSignature,
        newSignature: sigs.newSignature,
        issuedAt: 1736000000,
      );
    }

    setUp(() {
      oldRsa = rust.generateRsaKeypair();
      newCurve = crypto.generateEd25519KeyPair();
      newWrapping = crypto.generateWrappingKeyPair();
      rsaSigner = ShareCrypto(privateKeyPem: oldRsa.privateKeyPem);
      transition = signedTransition(
        old: oldRsa,
        identity: newCurve,
        wrapping: newWrapping,
        userId: _repeat(0x11, 16),
      );
    });

    // The roster the server serves post-migration carries the owner's CURRENT
    // (curve) fingerprint; the stored signature was made over the OLD (rsa) one.
    FolderMemberList servedList(String ownerFingerprintHex) {
      return FolderMemberList(
        folderId: _uuid(0xF0),
        folderOwnerId: owner,
        members: [
          FolderMemberListMember(
            userId: owner,
            pubkeyFingerprintHex: ownerFingerprintHex,
            shareRole: ShareRole.coOwner,
            isOwner: true,
            signedByUserId: owner,
          ),
          FolderMemberListMember(
            userId: member,
            pubkeyFingerprintHex: crypto.rsaFingerprintPublic(
              publicKeyPem: oldRsa.publicKeyPem,
            ),
            shareRole: ShareRole.editor,
            isOwner: false,
            signedByUserId: owner,
          ),
        ],
        membersSignedAt: 1735000000,
      );
    }

    test('a pre-migration roster signature verifies via the transition', () {
      final oldFp = crypto.rsaFingerprintPublic(
        publicKeyPem: oldRsa.publicKeyPem,
      );
      final newFp = crypto.spkiFingerprint(publicPem: newCurve.publicPem);

      // Owner signs the roster committing to their OLD fingerprint.
      final signed = rsaSigner.signFolderMemberList(servedList(oldFp));

      // The client is handed the served roster (new fingerprint) and the
      // owner's current curve key. Only the transition fallback can verify.
      final served = servedList(newFp);
      expect(
        shareCrypto.verifyFolderMemberListSignature(
          list: served,
          signature: signed.signature,
          signerPubkey: newCurve.publicPem,
          signerKeyType: 'curve25519',
          signerId: owner,
          signerTransition: transition,
        ),
        isTrue,
      );

      // Without the transition it cannot verify (current key is the wrong one
      // and the served fingerprint is not what was signed).
      expect(
        shareCrypto.verifyFolderMemberListSignature(
          list: served,
          signature: signed.signature,
          signerPubkey: newCurve.publicPem,
          signerKeyType: 'curve25519',
          signerId: owner,
        ),
        isFalse,
      );
    });

    test('a bogus transition does not make an invalid roster pass', () {
      final newFp = crypto.spkiFingerprint(publicPem: newCurve.publicPem);
      final served = servedList(newFp);

      // A signature by an unrelated RSA key can never verify, even when a
      // transition pointing at yet another key is supplied.
      final impostor = ShareCrypto(
        privateKeyPem: rust.generateRsaKeypair().privateKeyPem,
      );
      final forged = impostor.signFolderMemberList(
        servedList(
          crypto.rsaFingerprintPublic(publicKeyPem: oldRsa.publicKeyPem),
        ),
      );

      expect(
        shareCrypto.verifyFolderMemberListSignature(
          list: served,
          signature: forged.signature,
          signerPubkey: newCurve.publicPem,
          signerKeyType: 'curve25519',
          signerId: owner,
          signerTransition: transition,
        ),
        isFalse,
      );
    });

    AuditEventSigInput auditInput() => AuditEventSigInput(
      senderId: owner,
      recipientId: member,
      fileId: _uuid(0xCC),
      action: AuditEventAction.grant,
      shareRoleBefore: null,
      shareRoleAfter: ShareRole.reader,
      timestamp: 1735689900,
    );

    test('a pre-migration event signature verifies via the transition', () {
      final input = auditInput();
      final sig = rsaSigner.signAuditEvent(input);

      // The sender's current key is curve; only the transition resolves it.
      expect(
        shareCrypto.verifyAuditEvent(
          input: input,
          signature: sig,
          senderPubkey: newCurve.publicPem,
          senderKeyType: 'curve25519',
          senderTransition: transition,
        ),
        isTrue,
      );
      expect(
        shareCrypto.verifyAuditEvent(
          input: input,
          signature: sig,
          senderPubkey: newCurve.publicPem,
          senderKeyType: 'curve25519',
        ),
        isFalse,
      );
    });

    test('a bogus transition does not make an invalid event pass', () {
      final input = auditInput();
      final forged = ShareCrypto(
        privateKeyPem: rust.generateRsaKeypair().privateKeyPem,
      ).signAuditEvent(input);

      expect(
        shareCrypto.verifyAuditEvent(
          input: input,
          signature: forged,
          senderPubkey: newCurve.publicPem,
          senderKeyType: 'curve25519',
          senderTransition: transition,
        ),
        isFalse,
      );
    });

    // The attack the certificate check closes: a hostile server attaches an
    // unsigned transition naming an attacker key as the "old" one, so a
    // signature genuinely made under that key would otherwise be accepted.
    test('an unsigned transition never unlocks the old-key fallback', () {
      final fabricated = KeyTransition(
        oldKeyPem: oldRsa.publicKeyPem,
        oldKeyType: 'rsa',
        oldFingerprint: crypto.rsaFingerprintPublic(
          publicKeyPem: oldRsa.publicKeyPem,
        ),
        newIdentityKeyPem: newCurve.publicPem,
        newWrappingKeyPem: newWrapping.publicPem,
        newFingerprint: crypto.spkiFingerprint(publicPem: newCurve.publicPem),
        oldSignature: '',
        newSignature: '',
        issuedAt: 1736000000,
      );

      final input = auditInput();
      final sig = rsaSigner.signAuditEvent(input);
      expect(
        shareCrypto.verifyAuditEvent(
          input: input,
          signature: sig,
          senderPubkey: newCurve.publicPem,
          senderKeyType: 'curve25519',
          senderTransition: fabricated,
        ),
        isFalse,
      );

      final oldFp = crypto.rsaFingerprintPublic(
        publicKeyPem: oldRsa.publicKeyPem,
      );
      final signedRoster = rsaSigner.signFolderMemberList(servedList(oldFp));
      expect(
        shareCrypto.verifyFolderMemberListSignature(
          list: servedList(
            crypto.spkiFingerprint(publicPem: newCurve.publicPem),
          ),
          signature: signedRoster.signature,
          signerPubkey: newCurve.publicPem,
          signerKeyType: 'curve25519',
          signerId: owner,
          signerTransition: fabricated,
        ),
        isFalse,
      );
    });

    test('a dual-signed certificate naming another key\'s fingerprint '
        'fails the binding check', () {
      // The attacker controls both keys and signs honestly — but claims the
      // victim's old fingerprint. Both signatures verify; the fingerprint↔key
      // binding is what must reject it.
      final attackerOld = rust.generateRsaKeypair();
      final attackerCurve = crypto.generateEd25519KeyPair();
      final attackerSigner = ShareCrypto(
        privateKeyPem: attackerOld.privateKeyPem,
      );
      final forgedTransition = signedTransition(
        old: attackerOld,
        identity: attackerCurve,
        wrapping: newWrapping,
        userId: _repeat(0x11, 16),
        claimedOldFingerprint: crypto.rsaFingerprintPublic(
          publicKeyPem: oldRsa.publicKeyPem,
        ),
      );

      final input = auditInput();
      final sig = attackerSigner.signAuditEvent(input);
      expect(
        shareCrypto.verifyAuditEvent(
          input: input,
          signature: sig,
          senderPubkey: newCurve.publicPem,
          senderKeyType: 'curve25519',
          senderTransition: forgedTransition,
        ),
        isFalse,
      );
    });

    test('a certificate issued for a different account fails', () {
      // The canonical binds the signer's user id; replaying another account's
      // genuine certificate must not link this sender's chain.
      final replayed = signedTransition(
        old: oldRsa,
        identity: newCurve,
        wrapping: newWrapping,
        userId: _repeat(0x33, 16),
      );

      final input = auditInput();
      final sig = rsaSigner.signAuditEvent(input);
      expect(
        shareCrypto.verifyAuditEvent(
          input: input,
          signature: sig,
          senderPubkey: newCurve.publicPem,
          senderKeyType: 'curve25519',
          senderTransition: replayed,
        ),
        isFalse,
      );
    });
  });
}
