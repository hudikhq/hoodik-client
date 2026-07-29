import 'dart:isolate';
import 'dart:typed_data';

import '../../src/rust/api.dart' as rust;
import '../../src/rust/frb_generated.dart';
import '../utils/hex.dart' as hex_utils;
import 'crypto_service.dart';

/// Client-side crypto for the Curve25519 + OPAQUE migration: the OPAQUE
/// handshake, the private-key envelope, and the key-transition certificate.
/// All thin passthroughs to the shared Rust crate.
extension CryptoServiceMigration on CryptoService {
  /// Begin an OPAQUE registration. Returns the opaque client state to carry
  /// into [opaqueClientRegistrationFinish] and the base64 message to POST.
  rust.OpaqueClientStart opaqueClientRegistrationStart({
    required Uint8List password,
  }) {
    return rust.opaqueClientRegistrationStart(password: password);
  }

  /// Finish an OPAQUE registration against the server's `registrationResponse`.
  /// Returns the message to POST and the export key used to seal the key bundle.
  rust.OpaqueRegisterFinish opaqueClientRegistrationFinish({
    required String registrationState,
    required String registrationResponse,
    required Uint8List password,
  }) {
    return rust.opaqueClientRegistrationFinish(
      registrationState: registrationState,
      registrationResponse: registrationResponse,
      password: password,
    );
  }

  /// Begin an OPAQUE login. Returns the opaque client state to carry into
  /// [opaqueClientLoginFinish] and the base64 message to POST.
  rust.OpaqueClientStart opaqueClientLoginStart({required Uint8List password}) {
    return rust.opaqueClientLoginStart(password: password);
  }

  /// Finish an OPAQUE login against the server's `credentialResponse`. Returns
  /// the finalization message, the shared session key, and the export key. The
  /// KSF parameters are the account's own from `login/start` — the `export_key`
  /// only unseals the envelope when stretched with the same values registration
  /// used.
  rust.OpaqueLoginFinish opaqueClientLoginFinish({
    required String loginState,
    required String credentialResponse,
    required Uint8List password,
    required int mCost,
    required int tCost,
    required int pCost,
  }) {
    return rust.opaqueClientLoginFinish(
      loginState: loginState,
      credentialResponse: credentialResponse,
      password: password,
      mCost: mCost,
      tCost: tCost,
      pCost: pCost,
    );
  }

  /// Derive the 32-byte key-encryption key from an OPAQUE export key.
  Uint8List envelopeDeriveKek({required Uint8List exportKey}) {
    return rust.envelopeDeriveKek(exportKey: exportKey);
  }

  /// Seal a key bundle under a KEK. Returns the base64 envelope.
  String envelopeSeal({required Uint8List kek, required Uint8List bundle}) {
    return rust.envelopeSeal(kek: kek, bundle: bundle);
  }

  /// Open a base64 envelope with a KEK. Returns the plaintext key bundle.
  Uint8List envelopeOpen({required Uint8List kek, required String envelope}) {
    return rust.envelopeOpen(kek: kek, envelope: envelope);
  }

  /// Re-seal an envelope under a new KEK without exposing the plaintext bundle
  /// — the password-change path.
  String envelopeRewrap({
    required Uint8List oldKek,
    required Uint8List newKek,
    required String envelope,
  }) {
    return rust.envelopeRewrap(
      oldKek: oldKek,
      newKek: newKek,
      envelope: envelope,
    );
  }

  /// Sign a key-transition certificate binding the old identity key to the new
  /// Curve25519 identity + wrapping keys. `oldKeyType` is `"rsa"` or
  /// `"curve25519"`. Returns the two detached signatures the server records.
  rust.TransitionSignatures transitionSign({
    required Uint8List userId,
    required String oldKeyType,
    required String oldKeyPem,
    required String oldFingerprint,
    required String newIdentityKeyPem,
    required String newWrappingKeyPem,
    required String newFingerprint,
    required int issuedAt,
    required String oldPrivateKey,
    required String newIdentityPrivateKey,
  }) {
    return rust.transitionSign(
      userId: userId,
      oldKeyType: oldKeyType,
      oldKeyPem: oldKeyPem,
      oldFingerprint: oldFingerprint,
      newIdentityKeyPem: newIdentityKeyPem,
      newWrappingKeyPem: newWrappingKeyPem,
      newFingerprint: newFingerprint,
      issuedAt: issuedAt,
      oldPrivateKey: oldPrivateKey,
      newIdentityPrivateKey: newIdentityPrivateKey,
    );
  }

  /// Sign the key-rotation audit event with the new identity key. `userId` is
  /// the 16 raw UUID bytes; the fingerprints are the hex strings from the
  /// `users` row. Returns the base64 signature submitted as
  /// `auditEventSignature`.
  String signKeyRotationAudit({
    required Uint8List userId,
    required String oldFingerprint,
    required String newFingerprint,
    required int rotatedAt,
    required String newIdentityPrivateKey,
  }) {
    return rust.signKeyRotationAudit(
      userId: userId,
      oldFingerprint: oldFingerprint,
      newFingerprint: newFingerprint,
      rotatedAt: rotatedAt,
      newIdentityPrivateKey: newIdentityPrivateKey,
    );
  }
}

/// The private-key material sealed inside the OPAQUE envelope, encoded as
/// `v1|rsa:<PEM>|ed:<PEM>|x:<PEM>`. A migrated legacy account keeps its old RSA
/// key in [legacyRsa] so pre-migration ciphertext and the recovery path stay
/// decryptable; a natively registered v2 account has no [legacyRsa]. Each field
/// is null when its segment is absent.
class KeyBundle {
  const KeyBundle({this.identity, this.wrapping, this.legacyRsa});

  final String? identity;
  final String? wrapping;
  final String? legacyRsa;
}

/// Encode the envelope key bundle. [legacyRsa] is emitted only for a migrated
/// account; a fresh v2 account omits it.
String encodeKeyBundle({
  required String identity,
  required String wrapping,
  String? legacyRsa,
}) {
  final rsa = legacyRsa == null ? '' : 'rsa:$legacyRsa|';
  return 'v1|${rsa}ed:$identity|x:$wrapping';
}

/// Decode the bundle produced by [encodeKeyBundle]. Segments are prefix-tagged
/// and PEM bodies never contain `|`, so splitting on it is unambiguous. This is
/// the single decode site: the login path lost the `rsa:` segment when three
/// separate hand-rolled parsers each re-derived this format.
KeyBundle decodeKeyBundle(Uint8List bundle) {
  final s = String.fromCharCodes(bundle);
  String? identity;
  String? wrapping;
  String? legacyRsa;
  for (final part in s.split('|')) {
    if (part.startsWith('ed:')) {
      identity = part.substring(3);
    } else if (part.startsWith('x:')) {
      wrapping = part.substring(2);
    } else if (part.startsWith('rsa:')) {
      legacyRsa = part.substring(4);
    }
  }
  return KeyBundle(
    identity: identity,
    wrapping: wrapping,
    legacyRsa: legacyRsa,
  );
}

/// The file- and link-key wraps re-encrypted under the new wrapping key during
/// migration, plus one sample of each so the ceremony can prove a round-trip
/// under the new key before it commits. Link samples also carry the file_id and
/// re-signature so the ceremony can verify the signature under the new identity.
/// Sample fields are null when the account holds no keys of that kind.
class MigrationRewrap {
  MigrationRewrap({
    required this.fileKeys,
    required this.linkKeys,
    this.sampleFileBlob,
    this.sampleFileKey,
    this.sampleLinkBlob,
    this.sampleLinkKey,
    this.sampleLinkFileId,
    this.sampleLinkSignature,
  });

  final List<Map<String, dynamic>> fileKeys;
  final List<Map<String, dynamic>> linkKeys;
  final String? sampleFileBlob;
  final Uint8List? sampleFileKey;
  final String? sampleLinkBlob;
  final Uint8List? sampleLinkKey;
  final String? sampleLinkFileId;
  final String? sampleLinkSignature;
}

/// Re-wrap every file and public-link key the migrating user holds, from the
/// legacy RSA wrap to a hybrid wrap under [newXPub].
///
/// Runs in a one-shot isolate ([Isolate.run] at the call site): the RSA-decrypt
/// + hybrid-wrap work is O(keys) and CPU-bound, enough to ANR a large account
/// on the UI thread. FFI bindings are per-isolate, so [RustLib.init] must run
/// here before the first Rust call — it is idempotent once the library loads.
///
/// Throws (propagating out of [Isolate.run]) on the first key that fails to
/// re-wrap, so the caller aborts the migration without a partial commit. The
/// old RSA key is discarded after migration; a silently skipped key would be
/// permanently unreadable — link keys included, or the owner loses access to
/// every public link they created before migrating.
Future<MigrationRewrap> rewrapMigrationKeys({
  required List<Map<String, dynamic>> fileKeys,
  required List<Map<String, dynamic>> linkKeys,
  required String oldRsaPrivPem,
  required String newXPub,
  required String newEdPriv,
}) async {
  await RustLib.init();

  final rewrappedFiles = <Map<String, dynamic>>[];
  String? sampleFileBlob;
  Uint8List? sampleFileKey;
  for (final k in fileKeys) {
    final keyBytes = _rsaUnwrapKeyBytes(
      k['encrypted_key'] as String,
      oldRsaPrivPem,
    );
    final blob = rust.wrappingWrap(
      fileKey: keyBytes,
      recipientPublicPem: newXPub,
    );
    rewrappedFiles.add({
      'file_id': k['file_id'] as String,
      'encrypted_key': blob,
    });
    sampleFileBlob ??= blob;
    sampleFileKey ??= keyBytes;
  }

  final rewrappedLinks = <Map<String, dynamic>>[];
  String? sampleLinkBlob;
  Uint8List? sampleLinkKey;
  String? sampleLinkFileId;
  String? sampleLinkSignature;
  for (final lk in linkKeys) {
    final keyBytes = _rsaUnwrapKeyBytes(
      lk['encrypted_link_key'] as String,
      oldRsaPrivPem,
    );
    final blob = rust.wrappingWrap(
      fileKey: keyBytes,
      recipientPublicPem: newXPub,
    );
    // Re-sign the link's file_id under the new identity. The stored signature
    // was the owner's old RSA-PSS one; once the account is Ed25519 the server
    // verifies it against the new key, so an un-migrated signature reads as
    // invalid. The canonical is the file UUID string — the same value link
    // creation signs.
    final fileId = lk['file_id'] as String;
    final signature = rust.ed25519Sign(message: fileId, privatePem: newEdPriv);
    rewrappedLinks.add({
      'link_id': lk['link_id'] as String,
      'encrypted_link_key': blob,
      'signature': signature,
    });
    sampleLinkBlob ??= blob;
    sampleLinkKey ??= keyBytes;
    sampleLinkFileId ??= fileId;
    sampleLinkSignature ??= signature;
  }

  return MigrationRewrap(
    fileKeys: rewrappedFiles,
    linkKeys: rewrappedLinks,
    sampleFileBlob: sampleFileBlob,
    sampleFileKey: sampleFileKey,
    sampleLinkBlob: sampleLinkBlob,
    sampleLinkKey: sampleLinkKey,
    sampleLinkFileId: sampleLinkFileId,
    sampleLinkSignature: sampleLinkSignature,
  );
}

/// Legacy file and link keys are both stored as an RSA-encrypted hex string of
/// the raw key bytes; recover the raw bytes the new hybrid wrap expects.
Uint8List _rsaUnwrapKeyBytes(String encrypted, String oldRsaPrivPem) {
  final hex = rust.rsaDecrypt(
    ciphertextB64: encrypted,
    privateKeyPem: oldRsaPrivPem,
  );
  return hex_utils.hexDecode(hex);
}
