/// A signer's single RSA→curve25519 (or future curve→curve) key rotation,
/// attached to any response carrying a signature the signer may have produced
/// before rotating. Mirrors the server's `KeyTransitionRef`
/// (`shares/src/data/key_transition.rs`). Absent means the signer never
/// rotated — verify against the current key only. Every field is load-bearing:
/// the certificate is verified — both signatures plus each fingerprint against
/// the key it names — before [oldKeyPem] is trusted for anything, so a hostile
/// server cannot substitute an identity by fabricating a transition.
class KeyTransition {
  KeyTransition({
    required this.oldKeyPem,
    required this.oldKeyType,
    required this.oldFingerprint,
    required this.newIdentityKeyPem,
    required this.newWrappingKeyPem,
    required this.newFingerprint,
    required this.oldSignature,
    required this.newSignature,
    required this.issuedAt,
  });

  /// The superseded public key, PEM-armored exactly like `pubkey`.
  final String oldKeyPem;

  /// `"rsa"` or `"curve25519"` — selects the verification algorithm and the
  /// fingerprint derivation for the superseded key.
  final String oldKeyType;

  final String oldFingerprint;
  final String newIdentityKeyPem;
  final String newWrappingKeyPem;
  final String newFingerprint;
  final String oldSignature;
  final String newSignature;
  final int issuedAt;

  static KeyTransition? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return KeyTransition(
      oldKeyPem: json['old_key_pem'] as String? ?? '',
      oldKeyType: json['old_key_type'] as String? ?? 'rsa',
      oldFingerprint: json['old_fingerprint'] as String? ?? '',
      newIdentityKeyPem: json['new_identity_key_pem'] as String? ?? '',
      newWrappingKeyPem: json['new_wrapping_key_pem'] as String? ?? '',
      newFingerprint: json['new_fingerprint'] as String? ?? '',
      oldSignature: json['old_signature'] as String? ?? '',
      newSignature: json['new_signature'] as String? ?? '',
      issuedAt: json['issued_at'] as int? ?? 0,
    );
  }
}
