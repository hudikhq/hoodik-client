part of 'share_crypto.dart';

/// Three-tier share permission. The integer is the ASN.1 ENUMERATED wire
/// value; the kebab string is the form the HTTP API speaks.
enum ShareRole {
  reader(0, 'reader'),
  editor(1, 'editor'),
  coOwner(2, 'co-owner');

  const ShareRole(this.wire, this.wireString);

  final int wire;
  final String wireString;

  /// Fail closed to [reader] for any unrecognized wire string.
  static ShareRole fromWire(String value) => values.firstWhere(
    (r) => r.wireString == value,
    orElse: () => ShareRole.reader,
  );
}

/// Action recorded on a `share_events` row. The integer is the ENUMERATED
/// wire value used in `AuditEventSigInputV1`; the string is the octet-string
/// value stored in the chained `AuditEventRowV1`.
enum AuditEventAction {
  grant(0, 'grant'),
  revoke(1, 'revoke'),
  roleChange(2, 'role_change'),
  sharedFolderUpload(3, 'shared_folder_upload'),
  fork(4, 'fork'),
  sharedByCoOwner(5, 'shared_by_co_owner'),
  sharedFolderEdit(6, 'shared_folder_edit'),
  sharedFolderRestore(7, 'shared_folder_restore'),
  sharedFolderEvict(8, 'shared_folder_evict'),

  /// Owner detaches a file (or folder subtree) from a shared folder. The
  /// ENUMERATED [wire] 9 is signed into `AuditEventSigInputV1` for the
  /// `move-out-of-shared` event, matching the server's
  /// `AuditEventActionEnum::SharedFolderMoveOut`.
  sharedFolderMoveOut(9, 'shared_folder_move_out'),

  /// Cascade-revoke fan-out written by the server when a co-owner's grant is
  /// pulled (revocation, account deletion). These are system rows: NULL sender,
  /// no signature — so this action is never fed to `AuditEventSigInputV1` and
  /// its [wire] is never encoded as an ENUMERATED. [wire] is therefore a
  /// deliberate non-ENUMERATED sentinel (`-1`): if it ever reached the
  /// signed-canonical encoder the `u8` conversion would fail loud rather than
  /// collide with a real action. Only [wireString] is load-bearing — it
  /// byte-matches the octet-string the server chained into the row hash, so
  /// [ShareCryptoChain.recomputeChainHash] verifies. The server's signed
  /// `AuditEventActionEnum` runs 0–9; 9 is move-out (above), not this marker.
  sharedByCoOwnerRevoked(-1, 'shared_by_co_owner_revoked'),

  /// Account-level event the server appends to the owner's own per-sender chain
  /// after an RSA→curve25519 migration. It carries a NULL recipient and NULL
  /// file (the row hash encodes both as 16 zero bytes) and is signed under a
  /// *different* scheme — `KeyRotationAuditV1`, which the account itself
  /// verifies — so it is never fed to `AuditEventSigInputV1`. [wire] is a
  /// deliberate non-ENUMERATED sentinel (`-2`, distinct from
  /// [sharedByCoOwnerRevoked]'s `-1`): reaching the signed-canonical encoder
  /// would fail the `u8` conversion rather than collide with a real action.
  /// Only [wireString] is load-bearing — it byte-matches the octet-string the
  /// server chained into the row hash. [fromWire] resolving `'key_rotation'`
  /// here instead of falling back to [grant] is what lets
  /// [ShareCryptoChain.recomputeChainHash] reproduce that hash.
  keyRotation(-2, 'key_rotation');

  const AuditEventAction(this.wire, this.wireString);

  final int wire;
  final String wireString;

  /// Fail closed for forward compatibility: a newer server may add an action
  /// this build doesn't know. Defaulting to [grant] keeps the page parsing
  /// instead of throwing and blanking the whole log. A signed row carrying an
  /// unknown action then can't reconcile its canonical and badges as a
  /// mismatch (the honest "can't verify" verdict); a system row (NULL sender)
  /// badges as system regardless, since its signature is never checked.
  static AuditEventAction fromWire(String value) => values.firstWhere(
    (a) => a.wireString == value,
    orElse: () => AuditEventAction.grant,
  );
}

/// Per-row classification of an audit-chain walk. `linked` and `pageBoundary`
/// both pass; the two mismatch states distinguish content tampering from a
/// forged link between two visible rows.
enum ChainRowStatus { linked, pageBoundary, selfHashMismatch, linkBroken }

/// One audit-log row as returned by `GET /api/shares/events`, carrying the
/// fields the client needs to recompute and verify the per-sender hash chain.
class ShareEventRow {
  ShareEventRow({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.fileId,
    required this.action,
    required this.shareRoleBefore,
    required this.shareRoleAfter,
    required this.createdAt,
    required this.prevEventHash,
    required this.thisEventHash,
    required this.senderSignature,
  });

  final String id;
  final String? senderId;
  final String? recipientId;
  final String fileId;
  final AuditEventAction action;
  final ShareRole? shareRoleBefore;
  final ShareRole? shareRoleAfter;
  final int createdAt;
  final String? prevEventHash;
  final String thisEventHash;
  final String? senderSignature;
}

/// Result of walking the per-sender chain over a page of events. Indexes map
/// 1:1 to the input list; verification is order-aware within each sender
/// bucket.
class ChainVerification {
  ChainVerification({
    required this.chainOk,
    required this.rowStatus,
    required this.firstBreakIndex,
  });

  final List<bool> chainOk;
  final List<ChainRowStatus> rowStatus;
  final int firstBreakIndex;
}

/// Inputs to `entries_hash`: a file UUID and the base64 wrap of its key.
class ShareEntryInput {
  ShareEntryInput({required this.fileId, required this.encryptedKey});

  final String fileId;
  final String encryptedKey;
}

/// Typed inputs for an `AuditEventSigInputV1` signature.
class AuditEventSigInput {
  AuditEventSigInput({
    required this.senderId,
    required this.recipientId,
    required this.fileId,
    required this.action,
    required this.shareRoleBefore,
    required this.shareRoleAfter,
    required this.timestamp,
  });

  final String senderId;
  final String? recipientId;
  final String fileId;
  final AuditEventAction action;
  final ShareRole? shareRoleBefore;
  final ShareRole? shareRoleAfter;
  final int timestamp;
}

/// One member of a folder's canonical member list.
class FolderMemberListMember {
  FolderMemberListMember({
    required this.userId,
    required this.pubkeyFingerprintHex,
    required this.shareRole,
    required this.isOwner,
    required this.signedByUserId,
  });

  final String userId;
  final String pubkeyFingerprintHex;
  final ShareRole shareRole;
  final bool isOwner;
  final String signedByUserId;
}

/// Typed inputs for a `FolderMemberListV1` signature.
class FolderMemberList {
  FolderMemberList({
    required this.folderId,
    required this.folderOwnerId,
    required this.members,
    required this.membersSignedAt,
  });

  final String folderId;
  final String folderOwnerId;
  final List<FolderMemberListMember> members;
  final int membersSignedAt;
}
