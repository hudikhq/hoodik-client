import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/utils/hex.dart' as hex_utils;
import '../../../core/utils/l10n_lookup.dart';
import '../../shares/services/trusted_fingerprint_dao.dart';
import '../helpers/file_helpers.dart';
import '../providers/files_notifier.dart';

/// Outcome of a share grant or revoke. Exactly one branch is taken; the
/// failure branch carries a UI-ready message.
sealed class ShareOutcome {
  const ShareOutcome();

  const factory ShareOutcome.success() = ShareSuccess;
  const factory ShareOutcome.failure(String message) = ShareFailure;
}

class ShareSuccess extends ShareOutcome {
  const ShareSuccess();
}

class ShareFailure extends ShareOutcome {
  const ShareFailure(this.message);

  final String message;
}

/// Crypto orchestration for granting and revoking a single-file account-to-
/// account share. Mirrors the web `submitShare` flow in
/// `web/src/components/shares/SharingPeopleAdd.vue` for the one-file case: the
/// sender wraps the file key under the recipient's RSA public key, signs the
/// `ShareRequestPayloadV1` and the grant audit event, and posts the
/// `{payload_der, signature, entries, event_signature}` envelope. The server
/// re-encodes both canonicals from its own state and verifies the signatures,
/// so every signed field here must match the server's reconstruction exactly.
///
/// Folder sharing is a separate milestone — this controller never walks a
/// subtree, signs a member list, or emits a per-member signature.
class FilesShareController {
  FilesShareController(this._ref, this._dirId);

  final Ref _ref;
  final String? _dirId;

  Future<ShareOutcome> shareFile({
    required FileItem file,
    required DiscoveredUser recipient,
    required ShareRole role,
  }) async {
    final shareCrypto = _ref.read(shareCryptoProvider);
    final client = _ref.read(apiClientProvider);
    final senderId = _ref.read(activeServerUserIdProvider);

    if (shareCrypto == null || client == null) {
      return ShareOutcome.failure(ambientL10n.filesNotAuthenticated);
    }
    if (senderId == null) {
      return ShareOutcome.failure(ambientL10n.filesAccountNotInitialized);
    }

    final fileKey = _resolveFileKey(file);
    if (fileKey == null) {
      return ShareOutcome.failure(ambientL10n.filesCannotDecryptKey);
    }

    try {
      final existingRole = await _existingRole(
        client,
        file.id,
        recipient.userId,
      );
      // The server skips a same-role grant (`share.rs` `previous_role ==
      // requested_role`, and rejects a co-owner's with `cannot_grant_equal_role`),
      // so there is nothing to wrap or sign. Short-circuit before predicting an
      // audit action the server wouldn't emit.
      if (existingRole == role) {
        return const ShareOutcome.success();
      }

      final wrap = shareCrypto.wrapForRecipient(
        fileKey: fileKey,
        recipientPubkey: recipient.pubkey,
        recipientKeyType: recipient.keyType,
        recipientWrappingPubkey: recipient.wrappingPubkey,
      );
      final entries = [ShareEntryInput(fileId: file.id, encryptedKey: wrap)];
      final entriesHash = shareCrypto.computeEntriesHash(entries);

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nonce = shareCrypto.randomNonce();

      final payload = shareCrypto.signSharePayload(
        senderId: senderId,
        recipientId: recipient.userId,
        recipientPubkeyFingerprint: hex_utils.hexDecode(recipient.fingerprint),
        shareRole: role,
        rootFileId: file.id,
        entriesHash: entriesHash,
        timestamp: timestamp,
        nonce: nonce,
      );

      final action = _resolveAction(existingRole: existingRole, file: file);
      final eventSignature = shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: senderId,
          recipientId: recipient.userId,
          fileId: file.id,
          action: action,
          shareRoleBefore: action == AuditEventAction.roleChange
              ? existingRole
              : null,
          shareRoleAfter: role,
          timestamp: timestamp,
        ),
      );

      final envelope = {
        'payload_der': payload.payloadDer,
        'signature': payload.signature,
        'entries': [
          {'file_id': file.id, 'encrypted_key': wrap},
        ],
        'event_signature': eventSignature,
      };

      await client.shares.createShare(envelope);

      await _ref
          .read(databaseProvider)
          .upsertTrustedFingerprint(
            ownerUserId: senderId,
            userId: recipient.userId,
            fingerprint: recipient.fingerprint,
          );

      return const ShareOutcome.success();
    } catch (e) {
      return ShareOutcome.failure(
        ambientL10n.filesShareFailed(formatErrorMessage(e)),
      );
    }
  }

  Future<ShareOutcome> revokeRecipient({
    required String fileId,
    required String userId,
    required ShareRole currentRole,
  }) async {
    final shareCrypto = _ref.read(shareCryptoProvider);
    final client = _ref.read(apiClientProvider);
    final senderId = _ref.read(activeServerUserIdProvider);

    if (shareCrypto == null || client == null) {
      return ShareOutcome.failure(ambientL10n.filesNotAuthenticated);
    }
    if (senderId == null) {
      return ShareOutcome.failure(ambientL10n.filesAccountNotInitialized);
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final eventSignature = shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: senderId,
          recipientId: userId,
          fileId: fileId,
          action: AuditEventAction.revoke,
          shareRoleBefore: currentRole,
          shareRoleAfter: null,
          timestamp: timestamp,
        ),
      );

      await client.shares.revokeShare(fileId, userId, {
        'event_signature': eventSignature,
        'timestamp': timestamp,
      });

      return const ShareOutcome.success();
    } catch (e) {
      return ShareOutcome.failure(
        ambientL10n.filesRevokeFailed(formatErrorMessage(e)),
      );
    }
  }

  /// The recipient removes their own access to [file]: a self-targeted revoke
  /// where sender and recipient are both the active user. The signed audit
  /// event drops the caller's role to null at the current role, mirroring the
  /// web `confirmLeave` flow in `LayoutFileBrowserInner.vue`. Owned rows have no
  /// role to leave, so they are rejected before signing.
  Future<ShareOutcome> leaveShare(FileItem file) async {
    final selfId = _ref.read(activeServerUserIdProvider);
    if (selfId == null) {
      return ShareOutcome.failure(ambientL10n.filesAccountNotInitialized);
    }
    final role = file.shareRole;
    if (file.isOwner || role == null) {
      return ShareOutcome.failure(ambientL10n.filesNoAccessToLeave);
    }

    return revokeRecipient(fileId: file.id, userId: selfId, currentRole: role);
  }

  Future<List<AppShare>> listRecipients(String fileId) {
    final client = _ref.read(apiClientProvider);
    if (client == null) return Future.value(const []);
    return client.shares.getShareRecipients(fileId);
  }

  /// The role [userId] already holds on [fileId], or null if not yet a
  /// recipient. The roster is recipient-only, so any matching row is a
  /// non-owner share.
  Future<ShareRole?> _existingRole(
    ApiClient client,
    String fileId,
    String userId,
  ) async {
    final roster = await client.shares.getShareRecipients(fileId);
    for (final r in roster) {
      if (r.recipientId == userId) return r.shareRole;
    }
    return null;
  }

  /// Predict the audit action the server reconstructs in `create_share`
  /// (`share.rs` resolves `role_change` when a different role already exists,
  /// `shared_by_co_owner` for a co-owner's grant, else `grant`). The signed
  /// action and before-role must match or the server rejects the signature.
  AuditEventAction _resolveAction({
    required ShareRole? existingRole,
    required FileItem file,
  }) {
    if (existingRole != null) return AuditEventAction.roleChange;
    if (!file.isOwner && file.shareRole == ShareRole.coOwner) {
      return AuditEventAction.sharedByCoOwner;
    }
    return AuditEventAction.grant;
  }

  /// Prefer the file key already decrypted by [FilesNotifier]; fall back to a
  /// fresh RSA-decrypt of the row's own wrap when this directory's listing
  /// hasn't populated the cache (e.g. the recipient grid was opened directly).
  Uint8List? _resolveFileKey(FileItem file) {
    final cached = _ref
        .read(filesNotifierProvider(_dirId))
        .decryptedKeys[file.id];
    if (cached != null) return cached;

    final fileCrypto = _ref.read(fileCryptoProvider);
    final encryptedKey = file.encryptedKey;
    if (fileCrypto == null || encryptedKey == null || encryptedKey.isEmpty) {
      return null;
    }
    try {
      return fileCrypto.decryptFileKey(encryptedKey);
    } catch (_) {
      return null;
    }
  }
}

final filesShareControllerProvider =
    Provider.family<FilesShareController, String?>((ref, dirId) {
      return FilesShareController(ref, dirId);
    });
