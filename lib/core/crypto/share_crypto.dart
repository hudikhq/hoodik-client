import 'dart:convert';
import 'dart:typed_data';

import '../api/key_transition.dart';
import '../utils/hex.dart' as hex_utils;
import 'crypto_service.dart';
import 'file_crypto.dart';
import 'pem_key_type.dart';

part 'share_crypto_chain.dart';
part 'share_crypto_types.dart';

/// Orchestrates the sharing v1 signed-payload protocol on top of the
/// `cryptfns` FFI. Every byte operation — DER encoding, hashing, signing,
/// verifying, fingerprinting, PEM→DER — goes through [CryptoService]; this
/// layer only sequences those calls and compares their results, mirroring
/// `web/services/shares/crypto.ts` so a mobile-signed payload verifies on the
/// server identically to a web-signed one. The audit hash-chain walk lives in
/// `share_crypto_chain.dart`; the payload model types in
/// `share_crypto_types.dart`.
class ShareCrypto {
  ShareCrypto({
    required this.privateKeyPem,
    this.wrappingPrivateKeyPem,
    CryptoService? crypto,
  }) : _crypto = crypto ?? const CryptoService(),
       _fileCrypto = FileCrypto(
         privateKeyPem: privateKeyPem,
         wrappingPrivateKeyPem: wrappingPrivateKeyPem,
         crypto: crypto ?? const CryptoService(),
       );

  final String privateKeyPem;

  /// Hybrid wrapping key on migrated curve25519 accounts; null on legacy RSA
  /// accounts. Signing always uses [privateKeyPem]; only own file-key unwraps
  /// need this.
  final String? wrappingPrivateKeyPem;
  final CryptoService _crypto;
  final FileCrypto _fileCrypto;

  static final Uint8List _shareRequestPrefix = _prefix('hoodik-share-v1\x00');
  static final Uint8List _memberSigPrefix = _prefix('hoodik-folder-mem-v1\x00');
  static final Uint8List _folderListPrefix = _prefix(
    'hoodik-folder-list-v1\x00',
  );
  static final Uint8List _auditEventPrefix = _prefix('hoodik-audit-v1\x00');
  static final Uint8List _auditEventSigPrefix = _prefix(
    'hoodik-audit-sig-v1\x00',
  );

  static const int _wireRoleAbsent = 0xff;

  /// 16 random bytes for the `nonce` field of `ShareRequestPayloadV1`.
  Uint8List randomNonce() {
    final key = _crypto.generateSymmetricKey(cipher: 'aegis128l');
    return Uint8List.fromList(key.sublist(0, 16));
  }

  /// 16 random bytes base64-encoded for the standalone `nonce` field the group
  /// write bodies carry (the single-share path folds the nonce into its DER, so
  /// it never needs the encoded form).
  String randomNonceBase64() => base64.encode(randomNonce());

  /// Decrypt the caller's own wrap of a file key, returning the hex key.
  /// Dispatches RSA vs hybrid by key type through [FileCrypto].
  String decryptOwnFileKey(String encryptedKeyBase64) =>
      hex_utils.hexEncode(_fileCrypto.decryptFileKey(encryptedKeyBase64));

  /// Wrap a file key (raw bytes) for a share recipient. RSA recipients get the
  /// historical wire format — the key's hex string RSA-encrypted under their
  /// pubkey; curve25519 recipients get the raw key bytes hybrid-wrapped under
  /// their wrapping key. Returns base64 — the form stored in
  /// `user_files.encrypted_key`.
  String wrapForRecipient({
    required Uint8List fileKey,
    required String recipientPubkey,
    String recipientKeyType = 'rsa',
    String? recipientWrappingPubkey,
  }) {
    if (recipientKeyType == 'curve25519') {
      final wrappingPubkey = recipientWrappingPubkey;
      if (wrappingPubkey == null || wrappingPubkey.isEmpty) {
        throw StateError(
          'Recipient has a curve25519 identity but no wrapping key — '
          'refusing to wrap the file key.',
        );
      }
      return _crypto.wrappingWrap(
        fileKey: fileKey,
        recipientPublicPem: wrappingPubkey,
      );
    }
    // Encrypt the file key's hex directly under the recipient's RSA key. Not
    // FileCrypto.encryptFileKey — that dispatches on the SENDER's key type, so
    // a curve25519 sender would hybrid-wrap an RSA recipient's key and produce
    // a blob the recipient can never open.
    return _crypto.rsaEncrypt(
      plaintext: hex_utils.hexEncode(fileKey),
      publicKeyPem: recipientPubkey,
    );
  }

  /// `sha256(der(sorted_entries))` — the bytes `entries_hash` commits to.
  /// Sorting and DER encoding happen in the FFI so Dart and Rust agree.
  Uint8List computeEntriesHash(List<ShareEntryInput> entries) {
    if (entries.isEmpty) {
      throw ArgumentError('Cannot hash an empty entries list');
    }

    final fileIds = Uint8List(entries.length * 16);
    final encryptedKeys = <Uint8List>[];
    final lengths = <int>[];
    for (var i = 0; i < entries.length; i++) {
      fileIds.setRange(i * 16, (i + 1) * 16, _uuidToBytes(entries[i].fileId));
      final keyBytes = base64.decode(entries[i].encryptedKey);
      encryptedKeys.add(keyBytes);
      lengths.add(keyBytes.length);
    }

    final flat = Uint8List(lengths.fold(0, (sum, n) => sum + n));
    var cursor = 0;
    for (final key in encryptedKeys) {
      flat.setRange(cursor, cursor + key.length, key);
      cursor += key.length;
    }

    final der = _crypto.entriesEncodeV1(
      fileIds: fileIds,
      encryptedKeysFlat: flat,
      encryptedKeyLengths: lengths,
    );
    return hex_utils.hexDecode(_crypto.sha256(data: der));
  }

  /// DER-encode `ShareRequestPayloadV1` and sign `prefix ‖ der`. Returns the
  /// base64 payload DER and signature for the JSON envelope.
  ({String payloadDer, String signature}) signSharePayload({
    required String senderId,
    required String recipientId,
    required Uint8List recipientPubkeyFingerprint,
    required ShareRole shareRole,
    required String rootFileId,
    required Uint8List entriesHash,
    required int timestamp,
    required Uint8List nonce,
  }) {
    final der = _crypto.sharePayloadEncodeV1(
      senderId: _uuidToBytes(senderId),
      recipientId: _uuidToBytes(recipientId),
      recipientPubkeyFingerprint: recipientPubkeyFingerprint,
      shareRole: shareRole.wire,
      rootFileId: _uuidToBytes(rootFileId),
      entriesHash: entriesHash,
      timestamp: timestamp,
      nonce: nonce,
    );
    final signature = _signBytes(_shareRequestPrefix, der);
    return (payloadDer: base64.encode(der), signature: signature);
  }

  /// DER-encode an `AuditEventSigInputV1` and sign with the audit-sig prefix.
  String signAuditEvent(AuditEventSigInput input) {
    return _signBytes(_auditEventSigPrefix, _encodeAuditEventSigInput(input));
  }

  /// Verify an `AuditEventSigInputV1` signature against a sender pubkey.
  ///
  /// The audit canonical does not embed the sender's fingerprint, so a
  /// signature made before the sender rotated keys verifies against the
  /// [senderTransition] `old_key_pem` with no substitution — after the
  /// transition certificate itself verifies for the sender the event names.
  /// A supplied transition that fails either check is rejected — it never
  /// falls through to accept.
  bool verifyAuditEvent({
    required AuditEventSigInput input,
    required String signature,
    required String senderPubkey,
    String senderKeyType = 'rsa',
    KeyTransition? senderTransition,
  }) {
    final payload = _encodeAuditEventSigInput(input);
    if (_verifyBytes(
      _auditEventSigPrefix,
      payload,
      signature,
      senderPubkey,
      senderKeyType,
    )) {
      return true;
    }
    if (senderTransition == null) return false;
    if (!_verifyTransitionCertificate(input.senderId, senderTransition)) {
      return false;
    }
    return _verifyBytes(
      _auditEventSigPrefix,
      payload,
      signature,
      senderTransition.oldKeyPem,
      senderTransition.oldKeyType,
    );
  }

  /// Sign one folder-member record. The granting actor commits to the
  /// recipient's pubkey, fingerprint, and role; the result populates
  /// `user_files.member_signature`.
  String signMember({
    required String userId,
    required String pubkeyPem,
    String keyType = 'rsa',
    required String pubkeyFingerprintHex,
    required ShareRole shareRole,
    required int signedAt,
  }) {
    return _signBytes(
      _memberSigPrefix,
      _encodeMemberSig(
        userId: userId,
        pubkeyPem: pubkeyPem,
        keyType: keyType,
        pubkeyFingerprintHex: pubkeyFingerprintHex,
        shareRole: shareRole,
        signedAt: signedAt,
      ),
    );
  }

  /// Verify a single member's signature against the named signer's pubkey.
  /// [keyType] is the *member's* — it selects the `pubkey_der` canonical the
  /// granter committed to; [signerKeyType] selects the verification algorithm.
  bool verifyMemberSignature({
    required String userId,
    required String pubkeyPem,
    String keyType = 'rsa',
    required String pubkeyFingerprintHex,
    required ShareRole shareRole,
    required int signedAt,
    required String signature,
    required String signerPubkey,
    String signerKeyType = 'rsa',
  }) {
    return _verifyBytes(
      _memberSigPrefix,
      _encodeMemberSig(
        userId: userId,
        pubkeyPem: pubkeyPem,
        keyType: keyType,
        pubkeyFingerprintHex: pubkeyFingerprintHex,
        shareRole: shareRole,
        signedAt: signedAt,
      ),
      signature,
      signerPubkey,
      signerKeyType,
    );
  }

  /// DER-encode the folder member list and sign `prefix ‖ der`. Returns the
  /// canonical DER plus the base64 signature so callers submit both.
  ({Uint8List payloadDer, String signature}) signFolderMemberList(
    FolderMemberList list,
  ) {
    final der = _encodeFolderMemberList(list);
    return (payloadDer: der, signature: _signBytes(_folderListPrefix, der));
  }

  /// Verify a `members_list_signature` against the canonical DER of [list].
  /// Returns false on encoding failure so callers treat it as a verification
  /// failure rather than propagating a low-level error.
  ///
  /// The roster canonical embeds each member's own fingerprint, which rotated
  /// with the signer's key. So when the current key fails and a
  /// [signerTransition] is supplied — and its certificate verifies for
  /// [signerId] — re-encode the list substituting the signer's *pre-migration*
  /// fingerprint — derived from the transition's `old_key_pem` the same way
  /// any fingerprint is computed — and verify against the old key. A supplied
  /// transition that fails either check is rejected; verification never falls
  /// through to accept.
  bool verifyFolderMemberListSignature({
    required FolderMemberList list,
    required String signature,
    required String signerPubkey,
    String signerKeyType = 'rsa',
    String? signerId,
    KeyTransition? signerTransition,
  }) {
    try {
      if (_verifyBytes(
        _folderListPrefix,
        _encodeFolderMemberList(list),
        signature,
        signerPubkey,
        signerKeyType,
      )) {
        return true;
      }
      if (signerTransition == null || signerId == null) return false;
      if (!_verifyTransitionCertificate(signerId, signerTransition)) {
        return false;
      }
      final oldFingerprint = computeFingerprint(
        signerTransition.oldKeyPem,
        keyType: signerTransition.oldKeyType,
      );
      return _verifyBytes(
        _folderListPrefix,
        _encodeFolderMemberList(
          _withMemberFingerprint(list, signerId, oldFingerprint),
        ),
        signature,
        signerTransition.oldKeyPem,
        signerTransition.oldKeyType,
      );
    } catch (_) {
      return false;
    }
  }

  static FolderMemberList _withMemberFingerprint(
    FolderMemberList list,
    String userId,
    String fingerprintHex,
  ) {
    return FolderMemberList(
      folderId: list.folderId,
      folderOwnerId: list.folderOwnerId,
      membersSignedAt: list.membersSignedAt,
      members: list.members
          .map(
            (m) => m.userId == userId
                ? FolderMemberListMember(
                    userId: m.userId,
                    pubkeyFingerprintHex: fingerprintHex,
                    shareRole: m.shareRole,
                    isOwner: m.isOwner,
                    signedByUserId: m.signedByUserId,
                  )
                : m,
          )
          .toList(),
    );
  }

  /// Verify a server-supplied transition certificate before its old key is
  /// trusted for anything — without this check, a hostile server could attach
  /// a fabricated transition naming any key as the "old" one and have forged
  /// signatures accepted. [signerId] must be the id the caller resolved the
  /// signer as: the canonical binds it, so a certificate replayed from another
  /// account fails. Returns false on any decoding failure so a malformed
  /// certificate reads exactly like an invalid one.
  bool _verifyTransitionCertificate(String signerId, KeyTransition transition) {
    try {
      return _crypto.transitionVerify(
        userId: _uuidToBytes(signerId),
        oldKeyType: transition.oldKeyType,
        oldKeySpki: _pemBodyDer(transition.oldKeyPem),
        oldFingerprint: transition.oldFingerprint,
        newIdentityKeyPem: transition.newIdentityKeyPem,
        newWrappingKeyPem: transition.newWrappingKeyPem,
        newFingerprint: transition.newFingerprint,
        issuedAt: transition.issuedAt,
        oldSignature: transition.oldSignature,
        newSignature: transition.newSignature,
      );
    } catch (_) {
      return false;
    }
  }

  /// The DER body of a PEM block — the member-SPKI form the certificate
  /// canonical commits the old key as.
  static Uint8List _pemBodyDer(String pem) {
    final body = pem
        .split('\n')
        .where((line) => !line.startsWith('-----'))
        .join()
        .replaceAll(RegExp(r'\s'), '');
    return base64.decode(body);
  }

  /// Fingerprint of a recipient's identity key — `sha256(hex(modulus))` for
  /// RSA, the SPKI hash for curve25519 — the identity the client verifies
  /// before trusting a share.
  String computeFingerprint(String pubkey, {String keyType = 'rsa'}) {
    if (keyType == 'curve25519') {
      return _crypto.spkiFingerprint(publicPem: pubkey);
    }
    return _crypto.rsaFingerprintPublic(publicKeyPem: pubkey);
  }

  /// Quad-group rendering for fingerprint display, byte-aligned so the output
  /// is stable for any fingerprint length: `abcd1234` → `ABCD-1234`.
  String formatFingerprint(String hexFp) {
    final upper = hexFp.toUpperCase();
    final chunks = <String>[];
    for (var i = 0; i < upper.length; i += 4) {
      chunks.add(
        upper.substring(i, i + 4 > upper.length ? upper.length : i + 4),
      );
    }
    return chunks.join('-');
  }

  Uint8List _encodeAuditEventSigInput(AuditEventSigInput input) {
    return _crypto.auditEventSigInputEncodeV1(
      senderId: _uuidToBytes(input.senderId),
      recipientId: input.recipientId != null
          ? _uuidToBytes(input.recipientId!)
          : Uint8List(0),
      fileId: _uuidToBytes(input.fileId),
      action: input.action.wire,
      shareRoleBefore: input.shareRoleBefore?.wire ?? _wireRoleAbsent,
      shareRoleAfter: input.shareRoleAfter?.wire ?? _wireRoleAbsent,
      timestamp: input.timestamp,
    );
  }

  Uint8List _encodeMemberSig({
    required String userId,
    required String pubkeyPem,
    required String keyType,
    required String pubkeyFingerprintHex,
    required ShareRole shareRole,
    required int signedAt,
  }) {
    return _crypto.memberSigEncodeV1(
      userId: _uuidToBytes(userId),
      pubkeyDer: _crypto.memberPubkeyDer(
        keyType: keyType,
        publicKeyPem: pubkeyPem,
      ),
      fingerprint: hex_utils.hexDecode(pubkeyFingerprintHex),
      shareRole: shareRole.wire,
      signedAt: signedAt,
    );
  }

  Uint8List _encodeFolderMemberList(FolderMemberList list) {
    if (list.members.isEmpty) {
      throw ArgumentError('Cannot encode an empty folder member list');
    }
    final count = list.members.length;
    final userIds = Uint8List(count * 16);
    final signedBy = Uint8List(count * 16);
    final fingerprints = Uint8List(count * 32);
    final shareRoles = Uint8List(count);
    final isOwnerFlags = Uint8List(count);
    for (var i = 0; i < count; i++) {
      final m = list.members[i];
      userIds.setRange(i * 16, (i + 1) * 16, _uuidToBytes(m.userId));
      signedBy.setRange(i * 16, (i + 1) * 16, _uuidToBytes(m.signedByUserId));
      fingerprints.setRange(
        i * 32,
        (i + 1) * 32,
        hex_utils.hexDecode(m.pubkeyFingerprintHex),
      );
      shareRoles[i] = m.shareRole.wire;
      isOwnerFlags[i] = m.isOwner ? 1 : 0;
    }
    return _crypto.folderMemberListEncodeV1(
      folderId: _uuidToBytes(list.folderId),
      folderOwnerId: _uuidToBytes(list.folderOwnerId),
      userIds: userIds,
      pubkeyFingerprints: fingerprints,
      shareRoles: shareRoles,
      isOwnerFlags: isOwnerFlags,
      signedByUserIds: signedBy,
      membersSignedAt: list.membersSignedAt,
    );
  }

  String _signBytes(Uint8List prefix, Uint8List payload) {
    final msg = _concatPrefixed(prefix, payload);
    if (pemIsCurve(privateKeyPem)) {
      return _crypto.ed25519SignBytes(message: msg, privatePem: privateKeyPem);
    }
    return _crypto.rsaSignBytes(message: msg, privateKeyPem: privateKeyPem);
  }

  bool _verifyBytes(
    Uint8List prefix,
    Uint8List payload,
    String signature,
    String pubkey,
    String keyType,
  ) {
    final message = _concatPrefixed(prefix, payload);
    if (keyType == 'curve25519') {
      return _crypto.ed25519VerifyBytes(
        message: message,
        signature: signature,
        publicPem: pubkey,
      );
    }
    return _crypto.rsaVerifyBytes(
      message: message,
      signature: signature,
      publicKeyPem: pubkey,
    );
  }

  static Uint8List _concatPrefixed(Uint8List prefix, Uint8List payload) {
    final out = Uint8List(prefix.length + payload.length);
    out.setRange(0, prefix.length, prefix);
    out.setRange(prefix.length, out.length, payload);
    return out;
  }

  static Uint8List _prefix(String s) => Uint8List.fromList(utf8.encode(s));

  static Uint8List _uuidToBytes(String uuid) {
    final hex = uuid.replaceAll('-', '');
    if (hex.length != 32) {
      throw ArgumentError('Invalid UUID: $uuid');
    }
    return hex_utils.hexDecode(hex);
  }
}
