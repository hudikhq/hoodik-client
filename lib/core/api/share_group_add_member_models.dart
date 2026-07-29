import 'share_group_models.dart' show GroupRole;

/// Request body for `POST /api/shares/groups/{id}/members`. A group is a saved
/// recipient selection, so adding a member is a plain roster insert — no file
/// keys move. [timestamp] + [nonce] guard the write against replay.
///
/// [groupRole] lands in `share_group_members.role` (what the member may do *to
/// the group*); it has nothing to do with any file role a later share-to-group
/// fan-out grants.
class AddGroupMemberBody {
  AddGroupMemberBody({
    required this.userId,
    required this.pubkeyFingerprint,
    required this.groupRole,
    required this.timestamp,
    required this.nonce,
  });

  final String userId;
  final String pubkeyFingerprint;
  final GroupRole groupRole;
  final int timestamp;
  final String nonce;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'pubkey_fingerprint': pubkeyFingerprint,
    'group_role': groupRole.wireString,
    'timestamp': timestamp,
    'nonce': nonce,
  };
}
