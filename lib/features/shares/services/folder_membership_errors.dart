import '../../../core/api/shares_models.dart';

/// A tampered or unauthorized member list. Every case maps onto a specific
/// upload-blocking condition: either the server tampered with the roster, or
/// the trust chain doesn't cover the claimed signer. Mirrors the web verifier's
/// `FolderMemberListInvalid` (`web/services/shares/editable.ts`).
enum FolderMemberListInvalidReason {
  listSignatureMissing,
  listSignatureInvalid,
  listSignatureUnauthorizedSigner,
  memberSignatureInvalid,
  fingerprintMismatch,
  unknownSigner,
  ownerMissing,
  folderMismatch,
}

/// Raised by `FolderMembership.verifyFolderMemberList` on any verification
/// failure. A HARD STOP — the caller must not wrap an upload key once this
/// throws.
class FolderMemberListInvalid implements Exception {
  FolderMemberListInvalid(this.reason, this.message, [this.userId]);

  final FolderMemberListInvalidReason reason;
  final String message;
  final String? userId;

  @override
  String toString() => 'FolderMemberListInvalid($reason): $message';
}

/// Raised when a cached fingerprint disagrees with the one the server returned
/// for a known member. A HARD STOP with no automatic recovery — the user has to
/// re-verify out of band. Mirrors the web's `FolderMemberFingerprintChanged`.
class FolderMemberFingerprintChanged implements Exception {
  FolderMemberFingerprintChanged(this.member, this.cached, this.observed);

  final FolderMember member;
  final String cached;
  final String observed;

  @override
  String toString() =>
      'FolderMemberFingerprintChanged(${member.userId}): $cached -> $observed';
}

/// The signed-roster snapshot a membership mutation submits: the base64
/// `members_list_signature`, the unix `members_signed_at` it covers, and the
/// `members_list_signed_by_user_id` that produced it.
class MemberListSignature {
  MemberListSignature({
    required this.signature,
    required this.signedAt,
    required this.signedByUserId,
  });

  final String signature;
  final int signedAt;
  final String signedByUserId;
}
