import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/utils/hex.dart' as hex_utils;
import '../../../core/utils/l10n_lookup.dart';
import '../../files/helpers/file_helpers.dart';
import '../services/folder_member_set.dart';
import '../services/folder_membership.dart';
import '../services/folder_share_subtree.dart';
import '../services/trusted_fingerprint_dao.dart';

/// Outcome of a folder grant/role-change/revoke. The failure branch carries a
/// UI-ready message.
sealed class FolderShareOutcome {
  const FolderShareOutcome();

  const factory FolderShareOutcome.success() = FolderShareSuccess;
  const factory FolderShareOutcome.failure(String message) = FolderShareFailure;
}

class FolderShareSuccess extends FolderShareOutcome {
  const FolderShareSuccess();
}

class FolderShareFailure extends FolderShareOutcome {
  const FolderShareFailure(this.message);

  final String message;
}

/// Crypto orchestration for sharing, role-changing, and revoking on a folder.
///
/// A folder mutation is the single-file share flow plus a freshly-signed
/// roster: the server reconstructs the post-mutation `FolderMemberListV1` from
/// its own state and verifies the client's `members_list_signature` against it
/// (`shares/src/repository/members_list_sig.rs`). So the client must predict
/// the exact member set the server will commit, build the canonical list, and
/// sign it. Mirrors `SharingPeopleAdd.vue` (`submitShare` +
/// `buildPostShareListSignature`) and `FolderMembersView.vue` (`performRevoke`
/// + `buildPostRevokeListSignature`).
///
/// Both owner and co-owner act through this controller; the acting signer is
/// always the caller, and the predicted audit action follows the server's rule
/// in `create_share`: `role_change` when the recipient already holds a
/// different role, `shared_by_co_owner` on a co-owner reshare, else `grant`.
class FolderShareController {
  FolderShareController(this._ref);

  final Ref _ref;

  /// Share [folder] with [recipient] at [role], or change their existing role.
  /// Walks the folder subtree to build the full `entries` array the server
  /// requires, signs the share payload, the recipient's per-member σ, the audit
  /// event, and the post-mutation roster, then POSTs the envelope. [onProgress]
  /// reports subtree re-wrap progress (done, total).
  Future<FolderShareOutcome> shareFolder({
    required FileItem folder,
    required DiscoveredUser recipient,
    required ShareRole role,
    void Function(int done, int total)? onProgress,
  }) async {
    final deps = _resolve();
    if (deps == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }
    final fileCrypto = _ref.read(fileCryptoProvider);
    if (fileCrypto == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }

    try {
      final response = await deps.client.shares.getFolderMembers(folder.id);
      // No roster hard-verify here (unlike the multi-key upload path): a grant
      // wraps the subtree only for the one TOFU-verified recipient, the server
      // re-verifies the fresh list signature against its own state, and a
      // first-ever share has no prior signature. Mirrors the web's
      // buildPostShareListSignature.
      final existing = _existingMember(response.members, recipient.userId);
      // Re-sharing an existing member at their current role is a no-op: the
      // server skips the row (`share.rs` `previous_role == requested_role`),
      // so there is nothing to wrap or sign. Short-circuit before the subtree
      // walk — and before predicting an audit action the server wouldn't emit.
      if (existing != null && !existing.isOwner && existing.shareRole == role) {
        return const FolderShareOutcome.success();
      }

      final subtree = FolderShareSubtree(
        client: deps.client,
        fileCrypto: fileCrypto,
        shareCrypto: deps.shareCrypto,
      );
      final files = await subtree.collect(folder);
      final entries = subtree.buildEntries(
        files,
        recipient,
        onProgress: onProgress,
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nonce = deps.shareCrypto.randomNonce();
      final entriesHash = deps.shareCrypto.computeEntriesHash(entries);

      final payload = deps.shareCrypto.signSharePayload(
        senderId: deps.callerId,
        recipientId: recipient.userId,
        recipientPubkeyFingerprint: hex_utils.hexDecode(recipient.fingerprint),
        shareRole: role,
        rootFileId: folder.id,
        entriesHash: entriesHash,
        timestamp: timestamp,
        nonce: nonce,
      );

      final action = _resolveAction(
        current: response,
        existing: existing,
        callerId: deps.callerId,
        newRole: role,
      );
      final eventSignature = deps.shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: deps.callerId,
          recipientId: recipient.userId,
          fileId: folder.id,
          action: action,
          shareRoleBefore: action == AuditEventAction.roleChange
              ? existing!.shareRole
              : null,
          shareRoleAfter: role,
          timestamp: timestamp,
        ),
      );

      final memberSignature = deps.shareCrypto.signMember(
        userId: recipient.userId,
        pubkeyPem: recipient.pubkey,
        keyType: recipient.keyType,
        pubkeyFingerprintHex: recipient.fingerprint,
        shareRole: role,
        signedAt: timestamp,
      );

      final listSignature = deps.membership.signMemberList(
        folderId: folder.id,
        folderOwnerId: response.folderOwnerId,
        members: FolderMemberSet.afterGrant(
          current: response,
          targetUserId: recipient.userId,
          targetFingerprintHex: recipient.fingerprint,
          newRole: role,
          signerUserId: deps.callerId,
        ),
        signedByUserId: deps.callerId,
        signedAt: timestamp,
      );

      await deps.client.shares.createShare({
        'payload_der': payload.payloadDer,
        'signature': payload.signature,
        'entries': [
          for (final e in entries)
            {'file_id': e.fileId, 'encrypted_key': e.encryptedKey},
        ],
        'event_signature': eventSignature,
        'member_signature': memberSignature,
        'member_signed_at': timestamp,
        'members_list_signature': {
          'signature': listSignature.signature,
          'signed_at': listSignature.signedAt,
          'signed_by_user_id': listSignature.signedByUserId,
        },
      });

      await _ref
          .read(databaseProvider)
          .upsertTrustedFingerprint(
            ownerUserId: deps.callerId,
            userId: recipient.userId,
            fingerprint: recipient.fingerprint,
          );

      return const FolderShareOutcome.success();
    } on SubtreeTooLarge {
      return FolderShareOutcome.failure(
        ambientL10n.sharesSubtreeTooLargeShare(subtreeHardCap),
      );
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesShareFailed(formatErrorMessage(e)),
      );
    }
  }

  /// Revoke [member] from [folder], cascading a co-owner's downstream grants
  /// exactly as the server does. Signs the revoke audit event and the
  /// post-revoke roster, then DELETEs the recipient row.
  Future<FolderShareOutcome> revokeMember({
    required FileItem folder,
    required FolderMembersResponse roster,
    required FolderMember member,
  }) async {
    final deps = _resolve();
    if (deps == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }
    if (member.isOwner) {
      return FolderShareOutcome.failure(ambientL10n.sharesOwnerCannotBeRemoved);
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final eventSignature = deps.shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: deps.callerId,
          recipientId: member.userId,
          fileId: folder.id,
          action: AuditEventAction.revoke,
          shareRoleBefore: member.shareRole,
          shareRoleAfter: null,
          timestamp: timestamp,
        ),
      );

      final listSignature = deps.membership.signMemberList(
        folderId: folder.id,
        folderOwnerId: roster.folderOwnerId,
        members: FolderMemberSet.afterRevoke(current: roster, revoked: member),
        signedByUserId: deps.callerId,
        signedAt: timestamp,
      );

      await deps.client.shares.revokeShare(folder.id, member.userId, {
        'event_signature': eventSignature,
        'timestamp': timestamp,
        'members_list_signature': {
          'signature': listSignature.signature,
          'signed_at': listSignature.signedAt,
          'signed_by_user_id': listSignature.signedByUserId,
        },
      });

      return const FolderShareOutcome.success();
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesRevokeFailed(formatErrorMessage(e)),
      );
    }
  }

  /// Number of grants [member] issued under this folder — the blast radius of a
  /// co-owner revoke, surfaced in the confirmation prompt. Counts members whose
  /// `signed_by_user_id` is the co-owner, mirroring the server cascade.
  static int cascadeImpact(FolderMembersResponse roster, FolderMember member) {
    if (member.shareRole != ShareRole.coOwner) return 0;
    return roster.members
        .where(
          (m) => m.userId != member.userId && m.signedByUserId == member.userId,
        )
        .length;
  }

  FolderMember? _existingMember(List<FolderMember> members, String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  /// Predict the audit action the server reconstructs in `create_share`. A
  /// recipient who already holds a non-owner row at a different role is a
  /// `role_change`; a caller who isn't the folder owner is doing a co-owner
  /// reshare; everything else is a fresh `grant`. The action and before-role
  /// must match or the server rejects the event signature.
  AuditEventAction _resolveAction({
    required FolderMembersResponse current,
    required FolderMember? existing,
    required String callerId,
    required ShareRole newRole,
  }) {
    if (existing != null &&
        !existing.isOwner &&
        existing.shareRole != newRole) {
      return AuditEventAction.roleChange;
    }
    if (callerId != current.folderOwnerId) {
      return AuditEventAction.sharedByCoOwner;
    }
    return AuditEventAction.grant;
  }

  _FolderShareDeps? _resolve() {
    final client = _ref.read(apiClientProvider);
    final shareCrypto = _ref.read(shareCryptoProvider);
    final membership = _ref.read(folderMembershipProvider);
    final callerId = _ref.read(activeServerUserIdProvider);
    if (client == null ||
        shareCrypto == null ||
        membership == null ||
        callerId == null) {
      return null;
    }
    return _FolderShareDeps(
      client: client,
      shareCrypto: shareCrypto,
      membership: membership,
      callerId: callerId,
    );
  }
}

class _FolderShareDeps {
  _FolderShareDeps({
    required this.client,
    required this.shareCrypto,
    required this.membership,
    required this.callerId,
  });

  final ApiClient client;
  final ShareCrypto shareCrypto;
  final FolderMembership membership;
  final String callerId;
}

final folderShareControllerProvider = Provider<FolderShareController>((ref) {
  return FolderShareController(ref);
});
