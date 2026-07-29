import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';

/// Predicts the post-mutation folder roster the server will commit, so the
/// client can sign the exact `FolderMemberListV1` the server reconstructs in
/// `verify_post_mutation_signature` (`shares/src/repository/members_list_sig.rs`).
/// A mismatch — wrong member, role, or `signed_by_user_id` — is rejected as
/// `members_list_signature_invalid`, so these builders are the load-bearing
/// mirror of the server's reconstruction.
///
/// Order is irrelevant here: the FFI encoder sorts members by `user_id` before
/// signing (`cryptfns::asn1::encode_folder_member_list_v1`), so the client and
/// server agree on the byte sequence regardless of the list order.
///
/// Mirrors the web's `buildPostShareListSignature` (`SharingPeopleAdd.vue`) and
/// `buildPostRevokeListSignature` (`FolderMembersView.vue`).
class FolderMemberSet {
  const FolderMemberSet._();

  /// The roster after granting (or role-changing) [targetUserId] to [newRole],
  /// signed by [signerUserId] (the folder owner on a fresh share, a co-owner on
  /// a reshare).
  ///
  /// The target is dropped from the carried-forward members and re-appended
  /// with the new role and `signed_by_user_id = signerUserId` — matching the
  /// server, which sets `user_files.shared_by_user_id = caller` on both insert
  /// and role-change. An existing target keeps its `is_owner` flag (always
  /// false for a sharable target). Every other member carries its current role
  /// and `signed_by_user_id`, defaulting an absent signer to the folder owner
  /// exactly as `prospective_from_db` does (`row.shared_by_user_id ?? owner`).
  static List<FolderMemberListMember> afterGrant({
    required FolderMembersResponse current,
    required String targetUserId,
    required String targetFingerprintHex,
    required ShareRole newRole,
    required String signerUserId,
  }) {
    final next = <FolderMemberListMember>[];
    FolderMember? existing;
    for (final m in current.members) {
      if (m.userId == targetUserId) {
        existing = m;
        continue;
      }
      next.add(_carryForward(m, current.folderOwnerId));
    }
    next.add(
      FolderMemberListMember(
        userId: targetUserId,
        pubkeyFingerprintHex: targetFingerprintHex,
        shareRole: newRole,
        isOwner: existing?.isOwner ?? false,
        signedByUserId: signerUserId,
      ),
    );
    return next;
  }

  /// The roster left after revoking [revokedUserId]. When the revoked member is
  /// a co-owner, the server cascade-drops every member they granted — every row
  /// whose `signed_by_user_id == revokedUserId` (`revoke_share` in
  /// `share.rs` §7.5). A non-co-owner revoke drops only the revoked row, so the
  /// cascade set is empty. The remaining members are carried forward unchanged.
  static List<FolderMemberListMember> afterRevoke({
    required FolderMembersResponse current,
    required FolderMember revoked,
  }) {
    final dropped = <String>{revoked.userId};
    if (revoked.shareRole == ShareRole.coOwner) {
      for (final m in current.members) {
        if (m.signedByUserId == revoked.userId) dropped.add(m.userId);
      }
    }
    return current.members
        .where((m) => !dropped.contains(m.userId))
        .map((m) => _carryForward(m, current.folderOwnerId))
        .toList();
  }

  /// The roster after sharing a folder to a whole group at [newRole]: every
  /// current member of the folder *not* in [granted] carried forward, plus
  /// every group member in [granted] (re)appended at [newRole] signed by
  /// [signerUserId]. A group member who was already a folder member is dropped
  /// from the carried-forward set and re-appended at the new role — matching the
  /// server, which upserts each member's `user_files` row to the group's role
  /// before reconstructing the roster in `prospective_from_db`. The owner is
  /// never in [granted] (the server rejects sharing the owner row), so its
  /// `is_owner` flag is preserved by the carry-forward path.
  ///
  /// This is the multi-member counterpart of [afterGrant]: add-member appends
  /// one new member, share-to-group appends the whole roster at once, so the
  /// per-folder list signature must cover all of them in a single canonical.
  static List<FolderMemberListMember> afterGroupShare({
    required FolderMembersResponse current,
    required List<({String userId, String fingerprintHex})> granted,
    required ShareRole newRole,
    required String signerUserId,
  }) {
    final grantedIds = {for (final g in granted) g.userId};
    final next = <FolderMemberListMember>[
      for (final m in current.members)
        if (!grantedIds.contains(m.userId))
          _carryForward(m, current.folderOwnerId),
    ];
    for (final g in granted) {
      next.add(
        FolderMemberListMember(
          userId: g.userId,
          pubkeyFingerprintHex: g.fingerprintHex,
          shareRole: newRole,
          isOwner: false,
          signedByUserId: signerUserId,
        ),
      );
    }
    return next;
  }

  static FolderMemberListMember _carryForward(
    FolderMember m,
    String folderOwnerId,
  ) {
    return FolderMemberListMember(
      userId: m.userId,
      pubkeyFingerprintHex: m.pubkeyFingerprint,
      shareRole: m.shareRole,
      isOwner: m.isOwner,
      signedByUserId: m.signedByUserId ?? folderOwnerId,
    );
  }
}
