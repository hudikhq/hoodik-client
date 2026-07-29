import '../crypto/share_crypto.dart'
    show AuditEventAction, ShareEventRow, ShareRole;
import 'key_transition.dart';

/// One audit-log row from `GET /api/shares/events`, mirroring the server's
/// `AppShareEvent` (`shares/src/data/share_event.rs`). The chain-verification
/// fields ([prevEventHash], [thisEventHash], [senderSignature]) are base64;
/// the client walks the chain and verifies signatures locally before trusting
/// any single row.
///
/// [encryptedName] + [cipher] come from a LEFT JOIN to `files`, [encryptedKey]
/// from a LEFT JOIN to the caller's `user_files`. Any of the three may be null
/// — a deleted file or a revoked recipient — and any null collapses the
/// client-side name decrypt to the bare-id fallback.
class AppShareEvent {
  AppShareEvent({
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
    required this.encryptedName,
    required this.cipher,
    required this.encryptedKey,
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
  final String? encryptedName;
  final String? cipher;
  final String? encryptedKey;

  /// The fields needed to decrypt the file name are present together or not
  /// at all — a deleted file drops name+cipher, a revoked recipient drops the
  /// wrap. When false the row sentence shows the bare file id.
  bool get canDecryptName =>
      encryptedName != null && cipher != null && encryptedKey != null;

  /// Project onto the [ShareEventRow] the chain verifier consumes. The decrypt
  /// material is deliberately left off — `verifyChain` and
  /// `verifyEventSignature` only ever see the signed/chained columns.
  ShareEventRow toEventRow() => ShareEventRow(
    id: id,
    senderId: senderId,
    recipientId: recipientId,
    fileId: fileId,
    action: action,
    shareRoleBefore: shareRoleBefore,
    shareRoleAfter: shareRoleAfter,
    createdAt: createdAt,
    prevEventHash: prevEventHash,
    thisEventHash: thisEventHash,
    senderSignature: senderSignature,
  );

  factory AppShareEvent.fromJson(Map<String, dynamic> json) {
    final before = json['share_role_before'] as String?;
    final after = json['share_role_after'] as String?;
    return AppShareEvent(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String?,
      recipientId: json['recipient_id'] as String?,
      fileId: json['file_id'] as String? ?? '',
      action: AuditEventAction.fromWire(json['action'] as String? ?? 'grant'),
      shareRoleBefore: before == null ? null : ShareRole.fromWire(before),
      shareRoleAfter: after == null ? null : ShareRole.fromWire(after),
      createdAt: json['created_at'] as int? ?? 0,
      prevEventHash: json['prev_event_hash'] as String?,
      thisEventHash: json['this_event_hash'] as String? ?? '',
      senderSignature: json['sender_signature'] as String?,
      encryptedName: json['encrypted_name'] as String?,
      cipher: json['cipher'] as String?,
      encryptedKey: json['encrypted_key'] as String?,
    );
  }
}

/// Minimal identity record for a sender or recipient referenced in an audit
/// page, mirroring the server's `AuditUserRef`. Carries only what's already
/// public on `/api/users/discover` — the [pubkey] lets the client verify a
/// row's signature without a per-sender round-trip.
class AuditUserRef {
  AuditUserRef({
    required this.id,
    required this.email,
    required this.pubkey,
    required this.fingerprint,
    this.keyType = 'rsa',
    this.wrappingPubkey,
    this.keyTransition,
  });

  final String id;
  final String email;
  final String pubkey;
  final String fingerprint;

  /// `"rsa"` or `"curve25519"`; pre-upgrade servers omit the field.
  final String keyType;

  /// Hybrid wrapping key (PEM) file keys are wrapped under — curve25519 accounts only.
  final String? wrappingPubkey;

  /// Present when this account rotated keys, so a pre-rotation audit-event
  /// signature can fall back to their old key.
  final KeyTransition? keyTransition;

  factory AuditUserRef.fromJson(Map<String, dynamic> json) {
    return AuditUserRef(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      keyType: json['key_type'] as String? ?? 'rsa',
      wrappingPubkey: json['wrapping_pubkey'] as String?,
      keyTransition: KeyTransition.fromJsonOrNull(json['key_transition']),
    );
  }
}

/// One page of audit events from `GET /api/shares/events`. [users] maps every
/// sender / recipient UUID in [events] to its identity record so the client
/// labels rows and verifies signatures with no extra round-trip.
class ShareEventPage {
  ShareEventPage({
    required this.events,
    required this.users,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<AppShareEvent> events;
  final Map<String, AuditUserRef> users;
  final int total;
  final int limit;
  final int offset;

  factory ShareEventPage.fromJson(Map<String, dynamic> json) {
    final events =
        (json['events'] as List?)
            ?.map((e) => AppShareEvent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <AppShareEvent>[];
    final usersJson = json['users'] as Map<String, dynamic>? ?? const {};
    final users = <String, AuditUserRef>{
      for (final entry in usersJson.entries)
        entry.key: AuditUserRef.fromJson(entry.value as Map<String, dynamic>),
    };
    return ShareEventPage(
      events: events,
      users: users,
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
    );
  }
}

/// Filters for `GET /api/shares/events`. All optional; omitted fields fall to
/// the server defaults (no filter, `limit=100`, `offset=0`).
class ShareEventQuery {
  const ShareEventQuery({this.fileId, this.action, this.limit, this.offset});

  final String? fileId;
  final AuditEventAction? action;
  final int? limit;
  final int? offset;

  Map<String, dynamic> toQueryParameters() => {
    'file_id': ?fileId,
    'action': ?action?.wireString,
    'limit': ?limit,
    'offset': ?offset,
  };
}
