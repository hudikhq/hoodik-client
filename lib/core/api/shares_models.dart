import '../crypto/share_crypto.dart' show ShareRole;
import 'key_transition.dart';

/// A verified recipient resolved from `GET /api/users/discover`. Carries
/// just enough to compute a fingerprint and wrap a file key for them — the
/// server deliberately omits role, quota, and the encrypted private key.
class DiscoveredUser {
  DiscoveredUser({
    required this.userId,
    required this.email,
    required this.pubkey,
    required this.fingerprint,
    this.keyType = 'rsa',
    this.wrappingPubkey,
  });

  final String userId;
  final String email;
  final String pubkey;
  final String fingerprint;

  /// `"rsa"` or `"curve25519"`; pre-upgrade servers omit the field.
  final String keyType;

  /// Hybrid wrapping key (PEM) file keys are wrapped under — curve25519 accounts only.
  final String? wrappingPubkey;

  factory DiscoveredUser.fromJson(Map<String, dynamic> json) {
    return DiscoveredUser(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      keyType: json['key_type'] as String? ?? 'rsa',
      wrappingPubkey: json['wrapping_pubkey'] as String?,
    );
  }
}

/// Owner/co-owner view of one recipient row on a shared file. Returned by
/// `GET /api/shares/{file_id}` and as the per-entry result of
/// `POST /api/shares`. [sharedByEmail] is null for owner-issued grants where
/// the joined sender row wasn't resolved.
class AppShare {
  AppShare({
    required this.fileId,
    required this.recipientId,
    required this.recipientEmail,
    required this.recipientPubkeyFingerprint,
    required this.shareRole,
    required this.createdAt,
    this.sharedAt,
    this.sharedByUserId,
    this.sharedByEmail,
  });

  final String fileId;
  final String recipientId;
  final String recipientEmail;
  final String recipientPubkeyFingerprint;
  final ShareRole shareRole;
  final int createdAt;
  final int? sharedAt;
  final String? sharedByUserId;
  final String? sharedByEmail;

  factory AppShare.fromJson(Map<String, dynamic> json) {
    return AppShare(
      fileId: json['file_id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      recipientEmail: json['recipient_email'] as String? ?? '',
      recipientPubkeyFingerprint:
          json['recipient_pubkey_fingerprint'] as String? ?? '',
      shareRole: ShareRole.fromWire(json['share_role'] as String? ?? ''),
      createdAt: json['created_at'] as int? ?? 0,
      sharedAt: json['shared_at'] as int?,
      sharedByUserId: json['shared_by_user_id'] as String?,
      sharedByEmail: json['shared_by_email'] as String?,
    );
  }
}

/// Unwraps the `{shares: [...]}` envelope `POST /api/shares` returns.
class CreateShareResponse {
  CreateShareResponse({required this.shares});

  final List<AppShare> shares;

  factory CreateShareResponse.fromJson(Map<String, dynamic> json) {
    final list =
        (json['shares'] as List?)
            ?.map((e) => AppShare.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return CreateShareResponse(shares: list);
  }
}

/// Recipient-facing view of one incoming share, from `GET /api/shares/mine`
/// (and `/mine/by/{user_id}`). The recipient unwraps [encryptedKey] with their
/// RSA private key, then decrypts [encryptedName] (and [encryptedThumbnail])
/// with [cipher] — the server never sees the plaintext name or content.
class IncomingShare {
  IncomingShare({
    required this.fileId,
    required this.mime,
    required this.encryptedName,
    this.encryptedThumbnail,
    this.hasThumbnail = false,
    required this.cipher,
    required this.editable,
    this.size,
    this.chunks,
    this.chunksStored,
    this.finishedUploadAt,
    this.md5,
    this.sha1,
    this.sha256,
    this.blake2b,
    required this.shareRole,
    required this.encryptedKey,
    required this.createdAt,
    this.sharedAt,
    required this.ownerId,
    required this.ownerEmail,
    required this.ownerPubkey,
    required this.ownerPubkeyFingerprint,
    this.sharedByUserId,
    this.sharedByEmail,
  });

  final String fileId;
  final String mime;
  final String encryptedName;
  final String? encryptedThumbnail;

  /// Whether the file has a thumbnail, even when a `compact` listing
  /// withheld the blob itself.
  final bool hasThumbnail;

  final String cipher;
  final bool editable;
  final int? size;
  final int? chunks;
  final int? chunksStored;
  final int? finishedUploadAt;
  final String? md5;
  final String? sha1;
  final String? sha256;
  final String? blake2b;
  final ShareRole shareRole;
  final String encryptedKey;
  final int createdAt;
  final int? sharedAt;
  final String ownerId;
  final String ownerEmail;
  final String ownerPubkey;
  final String ownerPubkeyFingerprint;
  final String? sharedByUserId;
  final String? sharedByEmail;

  bool get isDir => mime == 'dir';

  factory IncomingShare.fromJson(Map<String, dynamic> json) {
    return IncomingShare(
      fileId: json['file_id'] as String? ?? '',
      mime: json['mime'] as String? ?? 'unknown',
      encryptedName: json['encrypted_name'] as String? ?? '',
      encryptedThumbnail: json['encrypted_thumbnail'] as String?,
      hasThumbnail:
          json['has_thumbnail'] as bool? ?? json['encrypted_thumbnail'] != null,
      cipher: json['cipher'] as String? ?? 'aegis128l',
      editable: json['editable'] as bool? ?? false,
      size: json['size'] as int?,
      chunks: json['chunks'] as int?,
      chunksStored: json['chunks_stored'] as int?,
      finishedUploadAt: json['finished_upload_at'] as int?,
      md5: json['md5'] as String?,
      sha1: json['sha1'] as String?,
      sha256: json['sha256'] as String?,
      blake2b: json['blake2b'] as String?,
      shareRole: ShareRole.fromWire(json['share_role'] as String? ?? ''),
      encryptedKey: json['encrypted_key'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      sharedAt: json['shared_at'] as int?,
      ownerId: json['owner_id'] as String? ?? '',
      ownerEmail: json['owner_email'] as String? ?? '',
      ownerPubkey: json['owner_pubkey'] as String? ?? '',
      ownerPubkeyFingerprint: json['owner_pubkey_fingerprint'] as String? ?? '',
      sharedByUserId: json['shared_by_user_id'] as String?,
      sharedByEmail: json['shared_by_email'] as String?,
    );
  }
}

/// One page of incoming shares from `GET /api/shares/mine`.
class IncomingSharePage {
  IncomingSharePage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<IncomingShare> items;
  final int total;
  final int limit;
  final int offset;

  factory IncomingSharePage.fromJson(Map<String, dynamic> json) {
    final list =
        (json['items'] as List?)
            ?.map((e) => IncomingShare.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return IncomingSharePage(
      items: list,
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
    );
  }
}

/// Public capability advertisement from `GET /api/capabilities`. Every
/// sharing surface gates on [sharingEnabled]; a missing or erroring response
/// must collapse to [Capabilities.disabled] so old servers degrade cleanly
/// instead of surfacing errors.
class Capabilities {
  Capabilities({
    required this.sharingEnabled,
    required this.roles,
    required this.editableFolders,
    required this.shareGroups,
    required this.auditLog,
    required this.fork,
    this.defaultCipher = 'aegis128l',
  });

  /// Fail-closed sentinel: everything off. Returned whenever the capability
  /// probe can't be trusted (no client, network error, pre-1.16 server's
  /// 404, unparseable body).
  const Capabilities.disabled()
    : sharingEnabled = false,
      roles = const [],
      editableFolders = false,
      shareGroups = false,
      auditLog = false,
      fork = false,
      defaultCipher = 'aegis128l';

  final bool sharingEnabled;
  final List<ShareRole> roles;
  final bool editableFolders;
  final bool shareGroups;
  final bool auditLog;
  final bool fork;

  /// Cipher for newly-created files and folders. Servers that predate the
  /// admin-configurable default omit the field and fall back to the
  /// historical `aegis128l`.
  final String defaultCipher;

  factory Capabilities.fromJson(Map<String, dynamic> json) {
    final sharing = json['sharing'] as Map<String, dynamic>?;
    final roleList =
        (sharing?['roles'] as List?)
            ?.map((e) => ShareRole.fromWire(e as String? ?? ''))
            .toList() ??
        const <ShareRole>[];
    return Capabilities(
      sharingEnabled: sharing?['enabled'] as bool? ?? false,
      roles: roleList,
      editableFolders: json['editable_folders'] as bool? ?? false,
      shareGroups: json['share_groups'] as bool? ?? false,
      auditLog: json['audit_log'] as bool? ?? false,
      fork: json['fork'] as bool? ?? false,
      defaultCipher: json['default_cipher'] as String? ?? 'aegis128l',
    );
  }
}

/// One row of a shared folder's roster, from
/// `GET /api/shares/folder/{folder_id}/members`. Every member sees every
/// other member's email and pubkey — sharing a folder shares the roster.
/// [memberSignature] is the granting actor's σ over this member's
/// `MemberSigPayloadV1`, verbatim from the recipient's `user_files` row; it
/// is null for the owner row and for legacy grants made before per-member
/// signatures existed.
class FolderMember {
  FolderMember({
    required this.userId,
    this.email,
    required this.pubkey,
    required this.pubkeyFingerprint,
    required this.shareRole,
    required this.isOwner,
    this.keyType = 'rsa',
    this.wrappingPubkey,
    this.addedAt,
    this.signedByUserId,
    this.memberSignature,
    this.keyTransition,
  });

  final String userId;
  final String? email;
  final String pubkey;
  final String pubkeyFingerprint;
  final ShareRole shareRole;
  final bool isOwner;

  /// `"rsa"` or `"curve25519"`; pre-upgrade servers omit the field.
  final String keyType;

  /// Hybrid wrapping key (PEM) file keys are wrapped under — curve25519 accounts only.
  final String? wrappingPubkey;

  final int? addedAt;
  final String? signedByUserId;
  final String? memberSignature;

  /// Present when this member rotated keys, so the roster / per-member
  /// signature they produced pre-migration can fall back to their old key.
  final KeyTransition? keyTransition;

  factory FolderMember.fromJson(Map<String, dynamic> json) {
    return FolderMember(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String?,
      pubkey: json['pubkey'] as String? ?? '',
      pubkeyFingerprint: json['pubkey_fingerprint'] as String? ?? '',
      shareRole: ShareRole.fromWire(json['share_role'] as String? ?? ''),
      isOwner: json['is_owner'] as bool? ?? false,
      keyType: json['key_type'] as String? ?? 'rsa',
      wrappingPubkey: json['wrapping_pubkey'] as String?,
      addedAt: json['added_at'] as int?,
      signedByUserId: json['signed_by_user_id'] as String?,
      memberSignature: json['member_signature'] as String?,
      keyTransition: KeyTransition.fromJsonOrNull(json['key_transition']),
    );
  }
}

/// The signed roster of an editable folder, from
/// `GET /api/shares/folder/{folder_id}/members`. [membersListSignature] is
/// the owner's (or current co-owner's) RSA-PSS signature over the
/// `FolderMemberListV1` built from [members]; the client re-encodes that
/// list and verifies the signature before trusting the roster to wrap upload
/// keys. [signatureAlgorithm] is `"rsa-pss-sha256"` for v1 and exists so a
/// later protocol version can swap primitives without a new endpoint.
class FolderMembersResponse {
  FolderMembersResponse({
    required this.folderId,
    required this.folderOwnerId,
    required this.folderOwnerPubkeyFingerprint,
    required this.signatureAlgorithm,
    required this.members,
    this.membersSignedAt,
    this.membersListSignature,
    this.membersListSignedByUserId,
  });

  final String folderId;
  final String folderOwnerId;
  final String folderOwnerPubkeyFingerprint;
  final String signatureAlgorithm;
  final List<FolderMember> members;
  final int? membersSignedAt;
  final String? membersListSignature;
  final String? membersListSignedByUserId;

  factory FolderMembersResponse.fromJson(Map<String, dynamic> json) {
    final memberList =
        (json['members'] as List?)
            ?.map((e) => FolderMember.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <FolderMember>[];
    return FolderMembersResponse(
      folderId: json['folder_id'] as String? ?? '',
      folderOwnerId: json['folder_owner_id'] as String? ?? '',
      folderOwnerPubkeyFingerprint:
          json['folder_owner_pubkey_fingerprint'] as String? ?? '',
      signatureAlgorithm: json['signature_algorithm'] as String? ?? '',
      members: memberList,
      membersSignedAt: json['members_signed_at'] as int?,
      membersListSignature: json['members_list_signature'] as String?,
      membersListSignedByUserId:
          json['members_list_signed_by_user_id'] as String?,
    );
  }
}

/// One member's wrap of a file key for the multi-key upload and
/// move-into-shared endpoints. [isOwnerOfFile] marks the row whose member is
/// the uploader/owner of the new file; it is omitted from the wire when null
/// so the server's `#[serde(default)]` treats it as absent rather than a
/// false flag.
class MemberKey {
  MemberKey({
    required this.userId,
    required this.encryptedKey,
    this.isOwnerOfFile,
  });

  final String userId;
  final String encryptedKey;
  final bool? isOwnerOfFile;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'encrypted_key': encryptedKey,
    if (isOwnerOfFile != null) 'is_owner_of_file': isOwnerOfFile,
  };
}

/// One node of a folder cascade for `POST /api/storage/move-into-shared`:
/// a file id (the moved root or any descendant) and that node's file key
/// wrapped once per destination member. The server recomputes the subtree
/// from its own state and rejects the request with `entries_do_not_match_subtree`
/// unless [entries] covers exactly the root plus every descendant.
class CascadeEntry {
  CascadeEntry({required this.fileId, required this.memberKeys});

  final String fileId;
  final List<MemberKey> memberKeys;

  Map<String, dynamic> toJson() => {
    'file_id': fileId,
    'member_keys': memberKeys.map((k) => k.toJson()).toList(),
  };
}

/// The destination folder's member-list snapshot at the moment the uploader
/// verified signatures, echoed back so the server can reject a stale upload
/// with `409 share_membership_changed`. Both fields are null when the folder
/// has never had a signed roster (legacy folder); the server tolerates that.
class MembersListSnapshot {
  MembersListSnapshot({this.membersSignedAt, this.membersListSignature});

  final int? membersSignedAt;
  final String? membersListSignature;

  Map<String, dynamic> toJson() => {
    'members_signed_at': membersSignedAt,
    'members_list_signature': membersListSignature,
  };
}
