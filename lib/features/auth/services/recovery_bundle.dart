import 'dart:convert';
import 'dart:typed_data';

import '../../../core/crypto/crypto_service_migration.dart';
import '../../../core/utils/l10n_lookup.dart';

/// Private-key material recovered from a pasted recovery key — either a v2
/// curve bundle (`v1|rsa:<PEM>|ed:<PEM>|x:<PEM>`) or a legacy account's bare
/// RSA private-key PEM. Mirrors the web client's `keyPairFromMaterial` so the
/// two clients accept the same recovery credential.
class ParsedRecoveryKey {
  const ParsedRecoveryKey({
    required this.identity,
    this.wrapping,
    this.legacyRsa,
  });

  final String identity;
  final String? wrapping;
  final String? legacyRsa;

  bool get isCurve => wrapping != null;
}

/// The recovery credential to show the user. A curve account's is the full
/// bundle (identity + wrapping, plus the retained RSA key for a migrated
/// account); a legacy RSA account's is its private-key PEM. Returns null when
/// no identity key is in memory — there is nothing to export.
String? recoveryKeyOf({String? identity, String? wrapping, String? legacyRsa}) {
  if (identity == null || identity.isEmpty) return null;
  if (wrapping == null || wrapping.isEmpty) return identity;
  return encodeKeyBundle(
    identity: identity,
    wrapping: wrapping,
    legacyRsa: legacyRsa,
  );
}

/// Parse pasted recovery material into its keys.
///
/// Throws [FormatException] with a user-presentable message when the input is
/// neither a curve bundle nor a private-key PEM.
ParsedRecoveryKey parseRecoveryKey(String material) {
  final trimmed = material.trim();
  if (trimmed.isEmpty) {
    throw FormatException(ambientL10n.authRecoveryKeyEmpty);
  }
  if (trimmed.contains('ed:') && trimmed.contains('x:')) {
    final bundle = decodeKeyBundle(Uint8List.fromList(trimmed.codeUnits));
    final identity = bundle.identity;
    final wrapping = bundle.wrapping;
    if (identity == null ||
        identity.isEmpty ||
        wrapping == null ||
        wrapping.isEmpty) {
      throw FormatException(ambientL10n.authRecoveryKeyMissingKeys);
    }
    return ParsedRecoveryKey(
      identity: identity,
      wrapping: wrapping,
      legacyRsa: bundle.legacyRsa,
    );
  }
  if (trimmed.contains('BEGIN') && trimmed.contains('PRIVATE KEY')) {
    return ParsedRecoveryKey(identity: trimmed);
  }
  throw FormatException(ambientL10n.authRecoveryKeyUnrecognized);
}

/// SPKI header for an Ed25519 public key (RFC 8410): SEQUENCE { SEQUENCE {
/// OID 1.3.101.112 }, BIT STRING (32 bytes, no unused bits) }.
const _ed25519SpkiPrefix = [
  0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00, //
];

/// Trailer preceding the embedded public key in a PKCS#8 v2 Ed25519 private
/// key as Rust's `pkcs8` crate writes it: primitive context tag [1] holding a
/// 33-byte BIT STRING body (a zero unused-bits octet, then the 32 key bytes).
const _pkcs8V2PublicMarker = [0x81, 0x21, 0x00];

/// Derive the Ed25519 public key (SPKI PEM) from a PKCS#8 private-key PEM.
///
/// The Rust bindings expose no public-from-private derivation, but every
/// Ed25519 key this codebase generates is a PKCS#8 v2 `OneAsymmetricKey`
/// with the public key embedded as its final 32 bytes, so it can be lifted
/// out without any curve math. Callers must still prove the pairing with a
/// sign/verify probe before trusting the result. Returns null when the PEM
/// carries no embedded public key.
String? ed25519PublicPemFromPrivate(String privatePem) {
  final der = _pemBody(privatePem);
  if (der == null) return null;
  final markerAt = der.length - 32 - _pkcs8V2PublicMarker.length;
  if (markerAt < 0) return null;
  for (var i = 0; i < _pkcs8V2PublicMarker.length; i++) {
    if (der[markerAt + i] != _pkcs8V2PublicMarker[i]) return null;
  }
  final spki = [..._ed25519SpkiPrefix, ...der.sublist(der.length - 32)];
  final body = base64Encode(spki);
  final lines = <String>[];
  for (var i = 0; i < body.length; i += 64) {
    lines.add(body.substring(i, i + 64 > body.length ? body.length : i + 64));
  }
  return '-----BEGIN PUBLIC KEY-----\n${lines.join('\n')}\n-----END PUBLIC KEY-----\n';
}

Uint8List? _pemBody(String pem) {
  final base64Body = pem
      .split('\n')
      .where((line) => line.isNotEmpty && !line.startsWith('-----'))
      .join();
  if (base64Body.isEmpty) return null;
  try {
    return base64Decode(base64Body);
  } on FormatException {
    return null;
  }
}
