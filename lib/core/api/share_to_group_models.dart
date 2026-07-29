import 'share_group_models.dart' show GroupRole;

/// One member of a group with the pubkey material needed to wrap a file key,
/// from `GET /api/shares/groups/{id}/members`. A share-to-group fan-out reads
/// the whole roster from one response and runs the single-share path once per
/// member.
class GroupMemberWithKey {
  GroupMemberWithKey({
    required this.userId,
    required this.email,
    required this.pubkey,
    required this.fingerprint,
    required this.groupRole,
    this.keyType = 'rsa',
    this.wrappingPubkey,
  });

  final String userId;
  final String email;
  final String pubkey;
  final String fingerprint;
  final GroupRole groupRole;

  /// `"rsa"` or `"curve25519"`; pre-upgrade servers omit the field.
  final String keyType;

  /// Hybrid wrapping key (PEM) file keys are wrapped under — curve25519 accounts only.
  final String? wrappingPubkey;

  factory GroupMemberWithKey.fromJson(Map<String, dynamic> json) {
    return GroupMemberWithKey(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      groupRole: GroupRole.fromWire(json['group_role'] as String? ?? ''),
      keyType: json['key_type'] as String? ?? 'rsa',
      wrappingPubkey: json['wrapping_pubkey'] as String?,
    );
  }
}

/// Request body for `PUT /api/shares/groups/{id}/members/{userId}/role`. Pure
/// roster metadata — changing a member's *group* role moves no file key, so
/// there is no crypto payload.
class SetGroupMemberRoleBody {
  SetGroupMemberRoleBody({required this.groupRole});

  final GroupRole groupRole;

  Map<String, dynamic> toJson() => {'group_role': groupRole.wireString};
}
