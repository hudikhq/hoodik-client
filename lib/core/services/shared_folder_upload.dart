import 'dart:typed_data';

import '../api/shares_client.dart';
import '../api/shares_models.dart';
import '../crypto/share_crypto.dart';
import '../../features/shares/services/folder_membership.dart';

/// Produces and POSTs the multi-key create for a file landing in a shared
/// folder. Given an already-encrypted file's key plus its metadata, it fetches
/// the destination folder's signed roster, verifies it, reconciles each
/// member's fingerprint (TOFU), wraps the file key once per member, signs the
/// `shared_folder_upload` audit event, and submits the body.
///
/// Mirrors `web/services/shares/editable.ts` (`uploadIntoSharedFolder`) so a
/// mobile-issued upload is indistinguishable from a web-issued one on the wire:
/// the server reconstructs the same `AuditEventSigInputV1` and re-derives every
/// per-member σ from the destination's existing rows, so the client supplies
/// only wrapped keys plus the single audit signature — never per-member
/// signatures.
///
/// The roster verification is the security boundary. A tampered member list
/// ([FolderMemberListInvalid]) or a changed fingerprint
/// ([FolderMemberFingerprintChanged]) is a hard stop: the exception propagates
/// and nothing is wrapped or uploaded. A `409 share_membership_changed` is the
/// one recoverable case — the roster raced a membership edit, so the fresh
/// roster from the conflict is re-verified, re-reconciled, re-wrapped, and
/// re-submitted exactly once; a second conflict propagates.
class SharedFolderUpload {
  SharedFolderUpload({
    required this.client,
    required this.folderMembership,
    required this.shareCrypto,
    required this.callerUserId,
  });

  final SharesClient client;
  final FolderMembership folderMembership;
  final ShareCrypto shareCrypto;

  /// The caller's server-assigned UUID — the file's owner and the audit
  /// event's sender. Must be [activeServerUserIdProvider], never the local
  /// composite account id.
  final String callerUserId;

  /// Wrap [fileKey] for every current member of [folderId], sign the audit
  /// event, and create the file via `POST /api/storage/upload-multikey`.
  /// Returns the assigned `file_id` (always [newFileId], so the audit
  /// signature binds to it). The caller mints [newFileId] before encrypting so
  /// the same id seeds the chunk-upload pipeline.
  ///
  /// Throws [FolderMemberListInvalid] or [FolderMemberFingerprintChanged]
  /// without uploading; [ShareMembershipChangedError] only if the roster races
  /// a change twice in a row; any other error from the wrap/sign/POST chain
  /// propagates as-is.
  Future<String> uploadIntoSharedFolder({
    required String folderId,
    required String newFileId,
    required Uint8List fileKey,
    required String nameHash,
    required String encryptedName,
    required String mime,
    required int chunks,
    int? size,
    String? sha256,
    String? cipher,
    bool? editable,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    String? encryptedThumbnail,
    int? fileModifiedAt,
  }) async {
    var roster = await _verifiedRoster(folderId);

    Future<String> submit(FolderMembersResponse snapshot) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final memberKeys = snapshot.members
          .map(
            (m) => MemberKey(
              userId: m.userId,
              encryptedKey: shareCrypto.wrapForRecipient(
                fileKey: fileKey,
                recipientPubkey: m.pubkey,
                recipientKeyType: m.keyType,
                recipientWrappingPubkey: m.wrappingPubkey,
              ),
              isOwnerOfFile: m.userId == callerUserId,
            ),
          )
          .toList();

      final eventSignature = shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: callerUserId,
          recipientId: null,
          fileId: newFileId,
          action: AuditEventAction.sharedFolderUpload,
          shareRoleBefore: null,
          shareRoleAfter: null,
          timestamp: timestamp,
        ),
      );

      final body = <String, dynamic>{
        'new_file_id': newFileId,
        'parent_file_id': folderId,
        'name_hash': nameHash,
        'encrypted_name': encryptedName,
        'encrypted_thumbnail': ?encryptedThumbnail,
        'mime': mime,
        'size': ?size,
        'chunks': chunks,
        'sha256': ?sha256,
        'cipher': ?cipher,
        'editable': ?editable,
        'file_modified_at': ?fileModifiedAt,
        'search_tokens_root': ?searchTokensRoot,
        'search_tokens_file': ?searchTokensFile,
        'member_keys': memberKeys.map((k) => k.toJson()).toList(),
        'members_list_snapshot': MembersListSnapshot(
          membersSignedAt: snapshot.membersSignedAt,
          membersListSignature: snapshot.membersListSignature,
        ).toJson(),
        'event_signature': eventSignature,
        'timestamp': timestamp,
      };

      return client.uploadMultikey(body);
    }

    try {
      return await submit(roster);
    } on ShareMembershipChangedError catch (e) {
      roster = await _verifiedRoster(folderId, fresh: e.currentMembers);
      return submit(roster);
    }
  }

  /// Fetch (or take a server-supplied fresh) roster, verify its signatures, and
  /// reconcile fingerprints. Both verification and reconciliation throw on
  /// failure, so a returned roster is always safe to wrap keys against.
  Future<FolderMembersResponse> _verifiedRoster(
    String folderId, {
    FolderMembersResponse? fresh,
  }) async {
    final response = fresh ?? await client.getFolderMembers(folderId);
    final verified = folderMembership.verifyFolderMemberList(response);
    await folderMembership.reconcileFingerprints(verified);
    return response;
  }
}
