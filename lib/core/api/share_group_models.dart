import '../crypto/share_crypto.dart' show ShareRole;

/// A member's standing *in a group* — a different axis from the file-level
/// [ShareRole], even though both name their tiers reader/editor/co-owner. A
/// group co-owner manages the *group* (add/remove/rename/set-role); a file
/// co-owner reshares the *file*. The two never mix: this enum gates group
/// management and the right to initiate a share-to-group, nothing about file
/// access. [owner] is implicit (the `share_groups.owner_id` row has no
/// membership row); the server reports it as the caller's `group_role` on a
/// group they own. The kebab string is the form the HTTP API speaks.
enum GroupRole {
  reader('reader'),
  editor('editor'),
  coOwner('co-owner'),
  owner('owner');

  const GroupRole(this.wireString);

  final String wireString;

  /// Fail closed to [reader] — the least-privileged tier — for any
  /// unrecognized wire string, so a newer server's role this build doesn't
  /// know degrades to view-only rather than unlocking management.
  static GroupRole fromWire(String value) => values.firstWhere(
    (r) => r.wireString == value,
    orElse: () => GroupRole.reader,
  );

  /// May share a file/folder to the group (forward cascade to members) and
  /// leave the group. Editor and above; the file ACL is still enforced
  /// independently server-side.
  bool get canShareToGroup =>
      this == editor || this == coOwner || this == owner;

  /// May manage the roster: add/remove members, rename, set member roles.
  /// Co-owner and above.
  bool get canManageGroup => this == coOwner || this == owner;

  /// May delete the group. Owner only — destructive and asymmetric with the
  /// co-owner tier, mirroring a file co-owner's inability to delete the file.
  bool get canDeleteGroup => this == owner;

  /// Whether this actor may move a member from [targetCurrent] to
  /// [targetNew]. The owner may set any role including co-owner. A co-owner
  /// may set reader/editor but never grant co-owner (no privilege-equal
  /// escalation), and never act on the owner or another co-owner (no demoting
  /// a peer or superior) — both the new and the current role are checked, so a
  /// co-owner can't strip another co-owner. Reader/editor can set nothing.
  /// Mirrors the server's `GroupRole::can_set_role`.
  bool canSetRoleTo(GroupRole targetCurrent, GroupRole targetNew) {
    if (targetNew == owner) return false;
    if (this == owner) return true;
    if (this == coOwner) {
      return targetNew != coOwner &&
          targetCurrent != owner &&
          targetCurrent != coOwner;
    }
    return false;
  }
}

/// One member row of a group the caller owns, from `GET /api/shares/groups`.
/// The roster is carried inline on owned groups so the UI renders members
/// without a second round-trip; member-of groups don't expose a peer roster.
class ShareGroupMember {
  ShareGroupMember({
    required this.userId,
    required this.email,
    required this.fingerprint,
    required this.addedAt,
    required this.groupRole,
  });

  final String userId;
  final String email;
  final String fingerprint;
  final int addedAt;

  /// The member's role *in the group* — distinct from any file-level share
  /// role those words also name.
  final GroupRole groupRole;

  factory ShareGroupMember.fromJson(Map<String, dynamic> json) {
    return ShareGroupMember(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      addedAt: json['added_at'] as int? ?? 0,
      groupRole: GroupRole.fromWire(json['group_role'] as String? ?? ''),
    );
  }
}

/// A group the caller owns, with its current member roster. Returned both by
/// `POST /api/shares/groups` (members empty on a fresh group) and in the
/// `owned` slice of `GET /api/shares/groups`.
class ShareGroup {
  ShareGroup({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.createdAt,
    this.members = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final int createdAt;
  final List<ShareGroupMember> members;

  factory ShareGroup.fromJson(Map<String, dynamic> json) {
    final memberList =
        (json['members'] as List?)
            ?.map((e) => ShareGroupMember.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <ShareGroupMember>[];
    return ShareGroup(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      members: memberList,
    );
  }
}

/// A group someone else owns that the caller belongs to, from the `member_of`
/// slice of `GET /api/shares/groups`. The server deliberately omits the peer
/// roster — a member has no business enumerating a group they don't own — so
/// this carries only the group identity plus the owner's email.
class ShareGroupAsMember {
  ShareGroupAsMember({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.name,
    required this.createdAt,
    required this.addedAt,
    required this.groupRole,
  });

  final String id;
  final String ownerId;
  final String ownerEmail;
  final String name;
  final int createdAt;
  final int addedAt;

  /// The caller's own role in this group — drives which actions the UI offers
  /// (share-to-group for editors, manage for co-owners).
  final GroupRole groupRole;

  factory ShareGroupAsMember.fromJson(Map<String, dynamic> json) {
    return ShareGroupAsMember(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      ownerEmail: json['owner_email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      addedAt: json['added_at'] as int? ?? 0,
      groupRole: GroupRole.fromWire(json['group_role'] as String? ?? ''),
    );
  }
}

/// The two pre-split slices of `GET /api/shares/groups`: groups the caller
/// owns (with rosters) and groups they're a member of (identity only).
class GroupsResponse {
  GroupsResponse({required this.owned, required this.memberOf});

  final List<ShareGroup> owned;
  final List<ShareGroupAsMember> memberOf;

  factory GroupsResponse.fromJson(Map<String, dynamic> json) {
    final owned =
        (json['owned'] as List?)
            ?.map((e) => ShareGroup.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <ShareGroup>[];
    final memberOf =
        (json['member_of'] as List?)
            ?.map((e) => ShareGroupAsMember.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <ShareGroupAsMember>[];
    return GroupsResponse(owned: owned, memberOf: memberOf);
  }
}
