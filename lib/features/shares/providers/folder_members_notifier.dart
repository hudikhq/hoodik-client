import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/share_crypto.dart' show ShareRole;
import '../../../core/providers.dart';
import '../../../core/services/shared_folder_target.dart';
import '../services/folder_membership.dart';

/// Per-row signature outcome for the members view. Derived from
/// [FolderMembership.verifyFolderMemberList]: a roster with a verified list
/// signature marks every member [verified]; a verification failure carrying a
/// `userId` marks that one [failed] and the rest by the list-signature
/// fallback. A folder below a share root has no list signature of its own, so
/// its roster verifies against the nearest signed ancestor's — members the
/// ancestor's list covers are [viaRoot], deviations are [failed]. A roster
/// with no signed ancestor at all is [legacy] (a pre-protocol folder).
/// Mirrors the web `FolderMembersView.verifySignatures` badge logic.
enum MemberSignatureStatus { verified, viaRoot, failed, legacy }

/// Loaded state of a folder's roster: the server response plus the per-member
/// signature verdicts and the caller's own permission to mutate it.
class FolderMembersState {
  const FolderMembersState({
    required this.response,
    required this.signatureStatus,
    required this.callerCanReshare,
  });

  final FolderMembersResponse response;
  final Map<String, MemberSignatureStatus> signatureStatus;

  /// True when the caller may change roles or revoke — the folder owner or a
  /// current co-owner, mirroring the server's `can_reshare` gate.
  final bool callerCanReshare;

  List<FolderMember> get members => response.members;
}

/// Loads, verifies, and exposes a folder's signed roster, keyed by folder id.
/// Re-fetched after every mutation so the view reflects the committed server
/// state. autoDispose so the cached roster is dropped once the members screen
/// is closed — reopening then loads live from the server, never a stale roster
/// from an earlier visit (a member added elsewhere must show up). Cleared on
/// logout alongside the other share providers.
class FolderMembersNotifier
    extends AutoDisposeFamilyAsyncNotifier<FolderMembersState, String> {
  @override
  Future<FolderMembersState> build(String folderId) => _load(folderId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(arg));
  }

  Future<FolderMembersState> _load(String folderId) async {
    final client = ref.read(apiClientProvider);
    final membership = ref.read(folderMembershipProvider);
    if (client == null || membership == null) {
      throw StateError('Not authenticated');
    }
    final response = await client.shares.getFolderMembers(folderId);
    final callerId = ref.read(activeServerUserIdProvider);
    var statuses = _classify(membership, response);
    if (response.membersListSignature == null) {
      statuses =
          await _classifyViaAncestor(client, membership, folderId, response) ??
          statuses;
    }
    return FolderMembersState(
      response: response,
      signatureStatus: statuses,
      callerCanReshare: _canReshare(response, callerId),
    );
  }

  /// Verify a signature-less roster against the nearest signed ancestor: a
  /// member is covered when the ancestor's verified list names the same user
  /// with the same key fingerprint and role — rosters below a share root are
  /// copies of the root's, so any deviation earns a failed badge. Returns
  /// null when there is no signed ancestor (a true legacy share) or its list
  /// cannot be fetched and verified, leaving the plain legacy state.
  Future<Map<String, MemberSignatureStatus>?> _classifyViaAncestor(
    ApiClient client,
    FolderMembership membership,
    String folderId,
    FolderMembersResponse response,
  ) async {
    try {
      final capabilities = ref.read(shareCapabilitiesProvider).valueOrNull;
      final resolver = SharedFolderTargetResolver(
        files: client.files,
        sharingEnabled: capabilities?.sharingEnabled ?? false,
      );
      final sourceId = await resolver.resolveRosterFolderId(folderId);
      if (sourceId == null || sourceId == folderId) return null;
      final roster = await fetchVerifiedRoster(
        fetch: client.shares.getFolderMembers,
        membership: membership,
        rosterFolderId: sourceId,
      );
      final covered = {
        for (final m in roster.members)
          '${m.userId}|${m.pubkeyFingerprint}|${m.shareRole}',
      };
      return {
        for (final m in response.members)
          m.userId:
              covered.contains(
                '${m.userId}|${m.pubkeyFingerprint}|${m.shareRole}',
              )
              ? MemberSignatureStatus.viaRoot
              : MemberSignatureStatus.failed,
      };
    } catch (_) {
      return null;
    }
  }

  /// Run the hard-stop verifier once and translate its single outcome into a
  /// per-row map. A list signature present + verify-pass marks all rows
  /// verified; a [FolderMemberListInvalid] with a userId pins the failure to
  /// that row; no list signature at all is the legacy case.
  Map<String, MemberSignatureStatus> _classify(
    FolderMembership membership,
    FolderMembersResponse response,
  ) {
    final hasListSignature = response.membersListSignature != null;
    final fallback = hasListSignature
        ? MemberSignatureStatus.verified
        : MemberSignatureStatus.legacy;
    try {
      membership.verifyFolderMemberList(response);
      return {for (final m in response.members) m.userId: fallback};
    } on FolderMemberListInvalid catch (e) {
      if (e.userId != null) {
        return {
          for (final m in response.members)
            m.userId: m.userId == e.userId
                ? MemberSignatureStatus.failed
                : fallback,
        };
      }
      final status = hasListSignature
          ? MemberSignatureStatus.failed
          : MemberSignatureStatus.legacy;
      return {for (final m in response.members) m.userId: status};
    }
  }

  static bool _canReshare(FolderMembersResponse response, String? callerId) {
    if (callerId == null) return false;
    if (callerId == response.folderOwnerId) return true;
    for (final m in response.members) {
      if (m.userId == callerId) return m.shareRole == ShareRole.coOwner;
    }
    return false;
  }
}

final folderMembersNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<FolderMembersNotifier, FolderMembersState, String>(
      FolderMembersNotifier.new,
    );
