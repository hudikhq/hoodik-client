import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart' show DiscoveredUser;
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../files/controllers/files_share_controller.dart';
import '../../files/helpers/file_helpers.dart';
import '../services/trusted_fingerprint_dao.dart';
import 'folder_share_controller.dart';

export 'folder_share_controller.dart'
    show FolderShareOutcome, FolderShareSuccess, FolderShareFailure;

/// Hard stop raised when a group member's server-returned pubkey does not hash
/// to the fingerprint the server claims for it, or disagrees with a fingerprint
/// the caller already trusts. Either case refuses to wrap the file key under the
/// unverified pubkey, so a malicious server can't substitute its own key to read
/// a share fanned out to the group. Mirrors the web `GroupMemberFingerprintMismatch`.
class GroupMemberFingerprintMismatch implements Exception {
  GroupMemberFingerprintMismatch(this.email);

  final String email;

  @override
  String toString() =>
      "A group member's key could not be verified — refusing to share. ($email)";
}

/// Shares one file or folder to every member of a group as a **client-side
/// fan-out**: fetch the roster, drop the caller and the file owner, then run
/// the existing single-share path once per remaining member. A group is a saved
/// recipient selection — there is no server-side group→file tracking, so this
/// is exactly N independent single shares. Mirrors the web `shareToGroup`.
///
/// A co-owner can re-share a file they don't own into a group that contains the
/// true owner; the owner already holds the file, so the server would reject a
/// share back to them. Dropping the owner up front (by [FileItem.ownerEmail],
/// the only owner identity a shared row carries) keeps the fan-out clean.
///
/// E2E is preserved per recipient: before any key is wrapped, each member's
/// returned pubkey is re-hashed and reconciled against the trust-on-first-use
/// store ([_verifyMemberFingerprint]) — a key/fingerprint mismatch or a changed
/// trusted fingerprint hard-stops the whole fan-out. The wrap, signatures, and
/// member list are produced by the same single-share controllers the share
/// dialog and folder-members screen use, so there is exactly one crypto path.
class ShareToGroupController {
  ShareToGroupController(this._ref);

  final Ref _ref;

  /// Fan [file] out to every current member of [groupId] at the file role
  /// [role]. [onProgress] reports completed recipients out of the total. The
  /// single-share path is an idempotent upsert, so a mid-fan-out failure is
  /// safe to retry — already-shared recipients short-circuit.
  Future<FolderShareOutcome> shareToGroup({
    required String groupId,
    required FileItem file,
    required ShareRole role,
    void Function(int done, int total)? onProgress,
  }) async {
    final deps = _resolve();
    if (deps == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }

    try {
      final roster = await deps.client.shareGroups.groupMembers(groupId);
      // The caller is dropped because the server rejects a share-to-self; the
      // owner is dropped because they already hold the file and a co-owner can
      // reach this fan-out for a file they don't own (see class docs).
      final ownerEmail = file.ownerEmail?.toLowerCase();
      final recipients = roster
          .where(
            (m) =>
                m.userId != deps.callerId &&
                (ownerEmail == null || m.email.toLowerCase() != ownerEmail),
          )
          .toList(growable: false);
      if (recipients.isEmpty) {
        return FolderShareOutcome.failure(ambientL10n.sharesGroupNoOneElse);
      }

      final total = recipients.length;
      onProgress?.call(0, total);
      for (var i = 0; i < recipients.length; i++) {
        final target = await _verifyMemberFingerprint(deps, recipients[i]);
        final outcome = await _shareOne(file, target, role);
        if (outcome is FolderShareFailure) return outcome;
        onProgress?.call(i + 1, total);
      }
      return const FolderShareOutcome.success();
    } on GroupMemberFingerprintMismatch catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesGroupMemberKeyUnverified(e.email),
      );
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesShareToGroupFailed(formatErrorMessage(e)),
      );
    }
  }

  /// Run one recipient through the existing single-share path: a folder goes
  /// through [FolderShareController.shareFolder] (subtree walk + member list
  /// signature), a regular file through [FilesShareController.shareFile]. Both
  /// already wrap, sign, and record TOFU; this controller only adds the
  /// per-recipient fingerprint reconciliation up front.
  Future<FolderShareOutcome> _shareOne(
    FileItem file,
    DiscoveredUser target,
    ShareRole role,
  ) async {
    if (file.isDir) {
      return _ref
          .read(folderShareControllerProvider)
          .shareFolder(folder: file, recipient: target, role: role);
    }
    final outcome = await _ref
        .read(filesShareControllerProvider(null))
        .shareFile(file: file, recipient: target, role: role);
    return switch (outcome) {
      ShareSuccess() => const FolderShareOutcome.success(),
      ShareFailure(:final message) => FolderShareOutcome.failure(message),
    };
  }

  /// Recompute the member's fingerprint from the returned pubkey and reconcile
  /// it against the trust store. The local fingerprint — never the
  /// server-supplied one — is what the share will bind to, so a server that
  /// lies about a member's key is caught here before any key is wrapped. First
  /// sight is silent; a disagreement with a trusted entry hard-stops. Returns
  /// the verified recipient the single-share path then wraps for.
  Future<DiscoveredUser> _verifyMemberFingerprint(
    _Deps deps,
    GroupMemberWithKey member,
  ) async {
    final local = deps.shareCrypto.computeFingerprint(
      member.pubkey,
      keyType: member.keyType,
    );
    if (local.toLowerCase() != member.fingerprint.toLowerCase()) {
      throw GroupMemberFingerprintMismatch(member.email);
    }
    final trusted = await _ref
        .read(databaseProvider)
        .getTrustedFingerprint(deps.callerId, member.userId);
    if (trusted != null &&
        trusted.fingerprint.toLowerCase() != local.toLowerCase()) {
      throw GroupMemberFingerprintMismatch(member.email);
    }
    return DiscoveredUser(
      userId: member.userId,
      email: member.email,
      pubkey: member.pubkey,
      fingerprint: local,
      keyType: member.keyType,
      wrappingPubkey: member.wrappingPubkey,
    );
  }

  _Deps? _resolve() {
    final client = _ref.read(apiClientProvider);
    final shareCrypto = _ref.read(shareCryptoProvider);
    final callerId = _ref.read(activeServerUserIdProvider);
    if (client == null || shareCrypto == null || callerId == null) {
      return null;
    }
    return _Deps(client: client, shareCrypto: shareCrypto, callerId: callerId);
  }
}

class _Deps {
  _Deps({
    required this.client,
    required this.shareCrypto,
    required this.callerId,
  });

  final ApiClient client;
  final ShareCrypto shareCrypto;
  final String callerId;
}

final shareToGroupControllerProvider = Provider<ShareToGroupController>((ref) {
  return ShareToGroupController(ref);
});
