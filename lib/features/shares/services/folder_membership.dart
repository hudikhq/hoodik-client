import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/storage/database.dart';
import 'folder_membership_errors.dart';
import 'trusted_fingerprint_dao.dart';

export 'folder_membership_errors.dart';

/// Crypto orchestration for shared-folder membership. Verifies the signed
/// roster before any upload key is wrapped, reconciles per-member fingerprints
/// against the trust-on-first-use store, and signs a post-mutation member set.
///
/// Mirrors `web/services/shares/editable.ts` (`verifyFolderMemberList`,
/// `reconcileFingerprints`, `buildListInputFromResponse`) byte-for-byte so a
/// roster the mobile client accepts is exactly the roster the web client and
/// the server (`shares/src/repository/members_list_sig.rs`) accept. The
/// verifier is the security boundary that stops a malicious member list from
/// tricking the uploader into wrapping a file key for an attacker's key.
class FolderMembership {
  FolderMembership({
    required this.crypto,
    required this.db,
    required this.ownerUserId,
  });

  /// The active session's crypto, holding the caller's private key for signing.
  final ShareCrypto crypto;

  /// The trust-on-first-use store, accessed through [TrustedFingerprintDao].
  final AppDatabase db;

  /// The caller's own server UUID — the trust set is scoped to this owner so
  /// one account's recorded peers are invisible to another's.
  final String ownerUserId;

  /// Verify the list signature plus every per-member signature against the
  /// authorized-signer set (the folder owner plus every current co-owner whose
  /// own per-member σ verifies against the owner). Returns the verified
  /// [FolderMember] list on success; throws [FolderMemberListInvalid] on any
  /// failure. Every failure path is a HARD STOP on the upload — there are no
  /// soft warnings.
  ///
  /// Legacy rows with a null `memberSignature` predate per-member signatures
  /// and carry no σ on the recipient row, so the per-member check skips them
  /// (matching `verifySingleMember` in the web verifier, which also returns
  /// false when `added_at` is null). The TOFU step in [reconcileFingerprints]
  /// then bears the trust decision for those rows. The list signature itself is
  /// mandatory regardless.
  List<FolderMember> verifyFolderMemberList(FolderMembersResponse response) {
    final owner = _verifiedOwner(response);
    final signers = <String, FolderMember>{owner.userId: owner};
    _promoteCoOwnerSigners(response, owner, signers);
    _verifyListSignature(response, signers);
    _verifyMemberSignatures(response, signers);
    return response.members;
  }

  FolderMember _verifiedOwner(FolderMembersResponse response) {
    final owner = response.members
        .where((m) => m.userId == response.folderOwnerId)
        .firstOrNull;
    if (owner == null) {
      throw FolderMemberListInvalid(
        FolderMemberListInvalidReason.ownerMissing,
        'Folder owner is not present in the member list — refusing to upload.',
        response.folderOwnerId,
      );
    }
    if (owner.pubkey.isEmpty) {
      throw FolderMemberListInvalid(
        FolderMemberListInvalidReason.ownerMissing,
        'Folder owner pubkey is empty.',
        response.folderOwnerId,
      );
    }

    // The owner's fingerprint is self-signed by construction; verify the
    // server-returned fingerprint matches the pubkey before trusting it as the
    // signer-set root. The response-level owner fingerprint must agree with the
    // owner row's, since the server populates both from the same `users` row.
    final localFingerprint = crypto.computeFingerprint(
      owner.pubkey,
      keyType: owner.keyType,
    );
    if (!_fingerprintsEqual(localFingerprint, owner.pubkeyFingerprint) ||
        !_fingerprintsEqual(
          localFingerprint,
          response.folderOwnerPubkeyFingerprint,
        )) {
      throw FolderMemberListInvalid(
        FolderMemberListInvalidReason.fingerprintMismatch,
        'Folder owner fingerprint does not match the returned pubkey.',
        owner.userId,
      );
    }
    return owner;
  }

  void _promoteCoOwnerSigners(
    FolderMembersResponse response,
    FolderMember owner,
    Map<String, FolderMember> signers,
  ) {
    for (final m in response.members) {
      if (m.shareRole != ShareRole.coOwner) continue;
      if (m.signedByUserId != response.folderOwnerId) continue;
      if (m.pubkey.isEmpty) continue;
      final localFingerprint = crypto.computeFingerprint(
        m.pubkey,
        keyType: m.keyType,
      );
      if (!_fingerprintsEqual(localFingerprint, m.pubkeyFingerprint)) {
        throw FolderMemberListInvalid(
          FolderMemberListInvalidReason.fingerprintMismatch,
          'Co-owner ${m.userId} fingerprint does not match the returned pubkey.',
          m.userId,
        );
      }
      if (_verifySingleMember(m, owner)) {
        signers[m.userId] = m;
      }
      // A co-owner whose σ is missing is still a member, just not a delegated
      // signer — so they are not added to the signer set.
    }
  }

  void _verifyListSignature(
    FolderMembersResponse response,
    Map<String, FolderMember> signers,
  ) {
    final signature = response.membersListSignature;
    final signerId = response.membersListSignedByUserId;
    if (signature == null ||
        signerId == null ||
        response.membersSignedAt == null) {
      throw FolderMemberListInvalid(
        FolderMemberListInvalidReason.listSignatureMissing,
        'Folder member list has no signature — refusing to upload.',
      );
    }

    final signer = signers[signerId];
    if (signer == null) {
      throw FolderMemberListInvalid(
        FolderMemberListInvalidReason.listSignatureUnauthorizedSigner,
        'Member list signed by $signerId, who is not the owner or a verified '
        'co-owner.',
        signerId,
      );
    }

    final ok = crypto.verifyFolderMemberListSignature(
      list: _buildListFromResponse(response),
      signature: signature,
      signerPubkey: signer.pubkey,
      signerKeyType: signer.keyType,
      signerId: signer.userId,
      signerTransition: signer.keyTransition,
    );
    if (!ok) {
      throw FolderMemberListInvalid(
        FolderMemberListInvalidReason.listSignatureInvalid,
        'Folder member list signature failed verification.',
      );
    }
  }

  void _verifyMemberSignatures(
    FolderMembersResponse response,
    Map<String, FolderMember> signers,
  ) {
    for (final m in response.members) {
      if (m.pubkey.isEmpty) {
        throw FolderMemberListInvalid(
          FolderMemberListInvalidReason.unknownSigner,
          'Member ${m.userId} has no pubkey — refusing to upload.',
          m.userId,
        );
      }
      final localFingerprint = crypto.computeFingerprint(
        m.pubkey,
        keyType: m.keyType,
      );
      if (!_fingerprintsEqual(localFingerprint, m.pubkeyFingerprint)) {
        throw FolderMemberListInvalid(
          FolderMemberListInvalidReason.fingerprintMismatch,
          'Member ${m.userId} fingerprint does not match the returned pubkey.',
          m.userId,
        );
      }
      if (m.memberSignature == null) continue;
      if (m.signedByUserId == null) {
        throw FolderMemberListInvalid(
          FolderMemberListInvalidReason.unknownSigner,
          'Member ${m.userId} carries a signature but no signer id.',
          m.userId,
        );
      }
      final signer = signers[m.signedByUserId];
      if (signer == null) {
        throw FolderMemberListInvalid(
          FolderMemberListInvalidReason.unknownSigner,
          'Member ${m.userId} signed by an unknown actor.',
          m.userId,
        );
      }
      if (!_verifySingleMember(m, signer)) {
        throw FolderMemberListInvalid(
          FolderMemberListInvalidReason.memberSignatureInvalid,
          'Member ${m.userId} signature did not verify.',
          m.userId,
        );
      }
    }
  }

  /// Verify one member's per-member σ against the supplied signer.
  /// Returns false (rather than throwing) for a missing signature or a null
  /// `addedAt`, so the caller decides whether the absence is fatal in context.
  /// The signed `signedAt` is the member's `addedAt` (the server's
  /// `user_files.shared_at`), matching what the granter committed to at issue
  /// time — see `share.rs` per-member verification.
  bool _verifySingleMember(FolderMember member, FolderMember signer) {
    final signature = member.memberSignature;
    final addedAt = member.addedAt;
    if (signature == null || addedAt == null) return false;
    return crypto.verifyMemberSignature(
      userId: member.userId,
      pubkeyPem: member.pubkey,
      keyType: member.keyType,
      pubkeyFingerprintHex: member.pubkeyFingerprint,
      shareRole: member.shareRole,
      signedAt: addedAt,
      signature: signature,
      signerPubkey: signer.pubkey,
      signerKeyType: signer.keyType,
    );
  }

  FolderMemberList _buildListFromResponse(FolderMembersResponse response) {
    return FolderMemberList(
      folderId: response.folderId,
      folderOwnerId: response.folderOwnerId,
      members: response.members
          .map(
            (m) => FolderMemberListMember(
              userId: m.userId,
              pubkeyFingerprintHex: m.pubkeyFingerprint,
              shareRole: m.shareRole,
              isOwner: m.isOwner,
              signedByUserId: m.signedByUserId ?? response.folderOwnerId,
            ),
          )
          .toList(),
      membersSignedAt: response.membersSignedAt ?? 0,
    );
  }

  /// Walk the verified member list and apply trust-on-first-use per member,
  /// scoped to [ownerUserId]. The caller is skipped. A fingerprint never seen
  /// before is recorded silently — never warned on (the
  /// warn-only-when-verified rule). A fingerprint that matches the cached one
  /// passes. A fingerprint that differs from the cached one throws
  /// [FolderMemberFingerprintChanged]. Mirrors the web's `reconcileFingerprints`
  /// minus the interactive TOFU prompt (the mobile UI slice owns the prompt).
  Future<void> reconcileFingerprints(List<FolderMember> members) async {
    for (final m in members) {
      if (m.userId == ownerUserId) continue;
      final cached = await db.getTrustedFingerprint(ownerUserId, m.userId);
      if (cached == null) {
        await db.upsertTrustedFingerprint(
          ownerUserId: ownerUserId,
          userId: m.userId,
          fingerprint: m.pubkeyFingerprint,
          email: m.email,
        );
        continue;
      }
      if (_fingerprintsEqual(cached.fingerprint, m.pubkeyFingerprint)) continue;
      throw FolderMemberFingerprintChanged(
        m,
        cached.fingerprint,
        m.pubkeyFingerprint,
      );
    }
  }

  /// Sign a given post-mutation member set and return the snapshot the client
  /// submits on a folder share or revoke. The caller builds the set (current
  /// members plus the added recipient, or current minus the removed one); this
  /// just signs what it is handed. The signer must be the owner or a co-owner
  /// present in [members]. Mirrors the web's post-mutation signing path
  /// (`buildFolderMemberListInput` + `signFolderMemberList`).
  MemberListSignature signMemberList({
    required String folderId,
    required String folderOwnerId,
    required List<FolderMemberListMember> members,
    required String signedByUserId,
    required int signedAt,
  }) {
    final signed = crypto.signFolderMemberList(
      FolderMemberList(
        folderId: folderId,
        folderOwnerId: folderOwnerId,
        members: members,
        membersSignedAt: signedAt,
      ),
    );
    return MemberListSignature(
      signature: signed.signature,
      signedAt: signedAt,
      signedByUserId: signedByUserId,
    );
  }

  /// Fingerprints are SHA-256 hex; compare case-insensitively because the
  /// server stores lowercase hex while [ShareCrypto.computeFingerprint] and the
  /// trust store may round-trip either case.
  static bool _fingerprintsEqual(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();
}

/// Fetch the signed roster of [rosterFolderId], verify it, and reconcile
/// fingerprints — the one safe way to obtain a member list to wrap keys
/// against. Refuses a response whose `folder_id` differs from the id it asked
/// about: the list signature only authenticates the roster for the folder
/// named inside the canonical, so any other validly signed roster of the same
/// owner must not authorise the wraps.
///
/// [rosterFolderId] is the folder whose signed list authorises the write. For
/// a write below a share root that is the root, not the direct parent —
/// folders under a root carry the root's roster (fan-out, cascade moves and
/// multi-key creates all copy it) but no signature of their own, and the
/// server rejects any wrap set that doesn't match the actual target's rows.
Future<FolderMembersResponse> fetchVerifiedRoster({
  required Future<FolderMembersResponse> Function(String folderId) fetch,
  required FolderMembership membership,
  required String rosterFolderId,
}) async {
  final response = await fetch(rosterFolderId);
  if (response.folderId != rosterFolderId) {
    throw FolderMemberListInvalid(
      FolderMemberListInvalidReason.folderMismatch,
      'Member list is for folder ${response.folderId}, '
      'not the requested $rosterFolderId.',
    );
  }
  final verified = membership.verifyFolderMemberList(response);
  await membership.reconcileFingerprints(verified);
  return response;
}
