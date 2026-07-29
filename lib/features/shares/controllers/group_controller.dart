import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart' show DiscoveredUser;
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../files/helpers/file_helpers.dart';
import 'folder_share_controller.dart' show FolderShareOutcome;

export 'folder_share_controller.dart'
    show FolderShareOutcome, FolderShareSuccess, FolderShareFailure;

/// Group lifecycle: create / delete / rename a group, set a member's group
/// role, remove a member, and add a member. A group is a saved recipient
/// selection — there is no server-side group→file tracking — so every one of
/// these is a thin REST call that moves no file key. Sharing a file *to* a
/// group is a separate client-side fan-out in [ShareToGroupController]. Mirrors
/// `web/services/shares/groups.ts`.
class GroupController {
  GroupController(this._ref);

  final Ref _ref;

  /// Create a group named [name]. The typed [GroupNameTakenError] surfaces as a
  /// dedicated message at the call site, which is why this rethrows rather than
  /// flattening it.
  Future<ShareGroup> createGroup(String name) {
    final client = _ref.read(apiClientProvider);
    if (client == null) {
      throw StateError('Not authenticated');
    }
    return client.shareGroups.createGroup(name);
  }

  Future<GroupsResponse> listGroups() {
    final client = _ref.read(apiClientProvider);
    if (client == null) {
      throw StateError('Not authenticated');
    }
    return client.shareGroups.listGroups();
  }

  Future<void> deleteGroup(String groupId) {
    final client = _ref.read(apiClientProvider);
    if (client == null) {
      throw StateError('Not authenticated');
    }
    return client.shareGroups.deleteGroup(groupId);
  }

  Future<void> removeMember(String groupId, String userId) {
    final client = _ref.read(apiClientProvider);
    if (client == null) {
      throw StateError('Not authenticated');
    }
    return client.shareGroups.removeGroupMember(groupId, userId);
  }

  /// Rename [groupId] to [name] (co-owner+). Rethrows the typed conflict so the
  /// dialog shows a precise message.
  Future<void> renameGroup(String groupId, String name) {
    final client = _ref.read(apiClientProvider);
    if (client == null) {
      throw StateError('Not authenticated');
    }
    return client.shareGroups.renameGroup(groupId, name);
  }

  /// Set [memberId]'s *group* role in [groupId] to [groupRole] (co-owner+, with
  /// the server's privilege-escalation guard).
  Future<void> setMemberRole(
    String groupId,
    String memberId,
    GroupRole groupRole,
  ) {
    final client = _ref.read(apiClientProvider);
    if (client == null) {
      throw StateError('Not authenticated');
    }
    return client.shareGroups.setGroupMemberRole(
      groupId,
      memberId,
      SetGroupMemberRoleBody(groupRole: groupRole),
    );
  }

  /// Add [recipient] to [groupId] at the *group* role [groupRole]. A plain
  /// roster insert: no file keys move, so there is no wrap or signature to
  /// build — just the identity, the group role, and a timestamp + nonce for
  /// replay protection.
  Future<FolderShareOutcome> addMember({
    required String groupId,
    required DiscoveredUser recipient,
    required GroupRole groupRole,
  }) async {
    final client = _ref.read(apiClientProvider);
    final shareCrypto = _ref.read(shareCryptoProvider);
    final callerId = _ref.read(activeServerUserIdProvider);
    if (client == null || shareCrypto == null || callerId == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }
    if (recipient.userId == callerId) {
      return FolderShareOutcome.failure(ambientL10n.sharesCannotAddSelfToGroup);
    }

    try {
      await client.shareGroups.addGroupMember(
        groupId,
        AddGroupMemberBody(
          userId: recipient.userId,
          pubkeyFingerprint: recipient.fingerprint,
          groupRole: groupRole,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          nonce: shareCrypto.randomNonceBase64(),
        ),
      );
      return const FolderShareOutcome.success();
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesAddMemberFailed(formatErrorMessage(e)),
      );
    }
  }
}

final groupControllerProvider = Provider<GroupController>((ref) {
  return GroupController(ref);
});
