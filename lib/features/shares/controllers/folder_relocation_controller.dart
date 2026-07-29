import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../files/helpers/file_helpers.dart';
import '../services/folder_membership.dart';
import 'folder_share_controller.dart' show FolderShareOutcome;

/// Relocating files relative to a shared folder, at the service layer — there
/// is no dedicated UI (decision §7.2; the web surfaces neither in a component).
///
/// Both operations mirror the existing crypto: [moveIntoShared] re-wraps an
/// owned file's key for the destination roster exactly as a multi-key upload
/// does (`SharedFolderUpload`), and [evictFromFolder] signs the same shape of
/// audit event a revoke does. Mirrors `web/services/shares/editable.ts`
/// (`moveIntoSharedFolder`, `evictFromFolder`).
class FolderRelocationController {
  FolderRelocationController(this._ref);

  final Ref _ref;

  /// Move an owned [file] into the shared folder [destinationFolderId]: verify
  /// the destination roster, wrap the file's key once per member, sign the
  /// `shared_folder_upload` audit event (the server inherits each member's σ),
  /// and POST `move-into-shared`. A `409 share_membership_changed` re-verifies
  /// the fresh roster and retries once; a second conflict surfaces as a
  /// failure. The caller must own the file — its key is unwrapped from the
  /// owner row's `encrypted_key`.
  Future<FolderShareOutcome> moveIntoShared({
    required FileItem file,
    required String destinationFolderId,
  }) async {
    final client = _ref.read(apiClientProvider);
    final shareCrypto = _ref.read(shareCryptoProvider);
    final membership = _ref.read(folderMembershipProvider);
    final fileCrypto = _ref.read(fileCryptoProvider);
    final callerId = _ref.read(activeServerUserIdProvider);
    if (client == null ||
        shareCrypto == null ||
        membership == null ||
        fileCrypto == null ||
        callerId == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }
    final encryptedKey = file.encryptedKey;
    if (encryptedKey == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesCannotDecryptFileKey);
    }

    try {
      final fileKey = fileCrypto.decryptFileKey(encryptedKey);

      Future<String> submit(FolderMembersResponse roster) {
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final memberKeys = roster.members
            .map(
              (m) => MemberKey(
                userId: m.userId,
                encryptedKey: shareCrypto.wrapForRecipient(
                  fileKey: fileKey,
                  recipientPubkey: m.pubkey,
                  recipientKeyType: m.keyType,
                  recipientWrappingPubkey: m.wrappingPubkey,
                ),
                isOwnerOfFile: m.userId == callerId,
              ),
            )
            .toList();
        final eventSignature = shareCrypto.signAuditEvent(
          AuditEventSigInput(
            senderId: callerId,
            recipientId: null,
            fileId: file.id,
            action: AuditEventAction.sharedFolderUpload,
            shareRoleBefore: null,
            shareRoleAfter: null,
            timestamp: timestamp,
          ),
        );
        return client.shares.moveIntoShared({
          'file_id': file.id,
          'destination_folder_id': destinationFolderId,
          'member_keys': memberKeys.map((k) => k.toJson()).toList(),
          'members_list_snapshot': MembersListSnapshot(
            membersSignedAt: roster.membersSignedAt,
            membersListSignature: roster.membersListSignature,
          ).toJson(),
          'event_signature': eventSignature,
          'timestamp': timestamp,
        });
      }

      var roster = await _verifiedRoster(
        membership,
        client.shares,
        destinationFolderId,
      );
      try {
        await submit(roster);
      } on ShareMembershipChangedError catch (e) {
        roster = await _verifiedRoster(
          membership,
          client.shares,
          destinationFolderId,
          fresh: e.currentMembers,
        );
        await submit(roster);
      }
      return const FolderShareOutcome.success();
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesMoveFailed(formatErrorMessage(e)),
      );
    }
  }

  /// The folder owner detaches a contributor's file from the folder; the file
  /// persists in the contributor's own drive at root. Signs a
  /// `shared_folder_evict` audit event naming the file's owner as recipient —
  /// the same id the server reconstructs from the file's owner row.
  Future<FolderShareOutcome> evictFromFolder({
    required String fileId,
    required String fileOwnerUserId,
  }) async {
    final client = _ref.read(apiClientProvider);
    final shareCrypto = _ref.read(shareCryptoProvider);
    final callerId = _ref.read(activeServerUserIdProvider);
    if (client == null || shareCrypto == null || callerId == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final eventSignature = shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: callerId,
          recipientId: fileOwnerUserId,
          fileId: fileId,
          action: AuditEventAction.sharedFolderEvict,
          shareRoleBefore: null,
          shareRoleAfter: null,
          timestamp: timestamp,
        ),
      );
      await client.shares.evictFromFolder(fileId, {
        'event_signature': eventSignature,
        'timestamp': timestamp,
      });
      return const FolderShareOutcome.success();
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesEvictFailed(formatErrorMessage(e)),
      );
    }
  }

  /// Fetch (or take a server-supplied fresh) destination roster, hard-verify
  /// its signatures, and reconcile fingerprints — both throw on failure, so a
  /// returned roster is safe to wrap keys against.
  Future<FolderMembersResponse> _verifiedRoster(
    FolderMembership membership,
    SharesClient shares,
    String folderId, {
    FolderMembersResponse? fresh,
  }) async {
    final response = fresh ?? await shares.getFolderMembers(folderId);
    final verified = membership.verifyFolderMemberList(response);
    await membership.reconcileFingerprints(verified);
    return response;
  }
}

final folderRelocationControllerProvider = Provider<FolderRelocationController>(
  (ref) {
    return FolderRelocationController(ref);
  },
);
