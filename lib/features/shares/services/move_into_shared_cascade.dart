import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/crypto/file_crypto.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../files/helpers/file_helpers.dart';
import '../controllers/folder_relocation_controller.dart';
import '../controllers/folder_share_controller.dart' show FolderShareOutcome;
import 'folder_membership.dart';
import 'folder_share_subtree.dart';

/// What a folder cascade is about to do, handed to the confirm gate before any
/// key is wrapped: how many descendants travel ([itemCount] excludes the moved
/// root itself) and the people who will actually receive keys — the destination
/// roster minus the caller, who already owns the keys ([members], matching the
/// fan-out in [FolderShareSubtree.buildCascadeEntries]).
class MoveCascadePreview {
  MoveCascadePreview({required this.itemCount, required this.members});

  final int itemCount;
  final List<FolderMember> members;
}

/// Relocating an *owned folder* (and everything under it) into a shared folder,
/// and the inverse move of an owned node back out of a shared scope.
///
/// The single-file move into a shared folder already lives in
/// [FolderRelocationController.moveIntoShared]; this service covers the two
/// cases that don't: the folder cascade (one wrap per node per member, sent as
/// `entries`) and the owner's move-out (no wraps — the nodes revert to private
/// files the owner already holds keys for). Mirrors the server contract in
/// `shares/src/repository/move_subtree.rs`.
class MoveIntoSharedCascade {
  MoveIntoSharedCascade(this._ref);

  final Ref _ref;

  /// Move an owned [folder] and its whole subtree into the shared folder
  /// [destinationFolderId]. Verifies and reconciles the destination roster
  /// once before any key is wrapped (hard stop on failure — nothing is sent),
  /// re-wraps every node's key for every current member, signs one
  /// `SharedFolderUpload` audit event bound to the moved root, and POSTs the
  /// cascade body. A `409 share_membership_changed` re-verifies the fresh
  /// roster and re-wraps once; a second conflict surfaces as a failure.
  ///
  /// [onProgress] reports per-node re-wrap progress (done, total) so a large
  /// subtree can show a determinate bar. [confirm] is invoked once after the
  /// destination roster is verified and the subtree is counted, but before any
  /// key is wrapped; returning false aborts the move with nothing sent.
  Future<FolderShareOutcome> moveFolderIntoShared({
    required FileItem folder,
    required String destinationFolderId,
    void Function(int done, int total)? onProgress,
    Future<bool> Function(MoveCascadePreview preview)? confirm,
  }) async {
    final deps = _resolve();
    if (deps == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }

    try {
      final subtree = FolderShareSubtree(
        client: deps.client,
        fileCrypto: deps.fileCrypto,
        shareCrypto: deps.shareCrypto,
      );
      final nodes = await subtree.collect(folder);

      var initialRoster = await _verifiedRoster(deps, destinationFolderId);
      if (confirm != null) {
        final verified = deps.membership.verifyFolderMemberList(initialRoster);
        final proceed = await confirm(
          MoveCascadePreview(
            itemCount: nodes.length - 1,
            members: verified.where((m) => m.userId != deps.callerId).toList(),
          ),
        );
        if (!proceed) {
          return const FolderShareOutcome.failure('');
        }
      }

      Future<void> submit(FolderMembersResponse roster) {
        final verified = deps.membership.verifyFolderMemberList(roster);
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final entries = subtree.buildCascadeEntries(
          nodes,
          verified,
          callerId: deps.callerId,
          onProgress: onProgress,
        );
        final eventSignature = deps.shareCrypto.signAuditEvent(
          AuditEventSigInput(
            senderId: deps.callerId,
            recipientId: null,
            fileId: folder.id,
            action: AuditEventAction.sharedFolderUpload,
            shareRoleBefore: null,
            shareRoleAfter: null,
            timestamp: timestamp,
          ),
        );
        return deps.client.shares.moveIntoShared({
          'file_id': folder.id,
          'destination_folder_id': destinationFolderId,
          'entries': entries.map((e) => e.toJson()).toList(),
          'members_list_snapshot': MembersListSnapshot(
            membersSignedAt: roster.membersSignedAt,
            membersListSignature: roster.membersListSignature,
          ).toJson(),
          'event_signature': eventSignature,
          'timestamp': timestamp,
        });
      }

      try {
        await submit(initialRoster);
      } on ShareMembershipChangedError catch (e) {
        initialRoster = await _verifiedRoster(
          deps,
          destinationFolderId,
          fresh: e.currentMembers,
        );
        await submit(initialRoster);
      }
      return const FolderShareOutcome.success();
    } on SubtreeTooLarge {
      return FolderShareOutcome.failure(
        ambientL10n.sharesSubtreeTooLargeMove(subtreeHardCap),
      );
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesMoveFailed(formatErrorMessage(e)),
      );
    }
  }

  /// The file's owner detaches [file] (and its subtree, if a folder) from the
  /// shared folder it currently lives in: the nodes revert to private files in
  /// the owner's drive. No keys are wrapped — the owner already holds them, and
  /// the server drops every other member's rows across the subtree. Signs one
  /// `SharedFolderMoveOut` event bound to the moved root and POSTs the body.
  /// [destinationFolderId] is the new private parent (null = the owner's root).
  Future<FolderShareOutcome> moveOutOfShared({
    required FileItem file,
    required String? destinationFolderId,
  }) async {
    final deps = _resolve();
    if (deps == null) {
      return FolderShareOutcome.failure(ambientL10n.sharesNotAuthenticated);
    }
    if (!file.isOwner) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesOnlyOwnerCanMoveThisOut,
      );
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final eventSignature = deps.shareCrypto.signAuditEvent(
        AuditEventSigInput(
          senderId: deps.callerId,
          recipientId: null,
          fileId: file.id,
          action: AuditEventAction.sharedFolderMoveOut,
          shareRoleBefore: null,
          shareRoleAfter: null,
          timestamp: timestamp,
        ),
      );
      await deps.client.shares.moveOutOfShared({
        'file_id': file.id,
        'destination_folder_id': ?destinationFolderId,
        'event_signature': eventSignature,
        'timestamp': timestamp,
      });
      return const FolderShareOutcome.success();
    } on MoveOutRejected catch (e) {
      return FolderShareOutcome.failure(_moveOutMessage(e.reason));
    } catch (e) {
      return FolderShareOutcome.failure(
        ambientL10n.sharesMoveFailed(formatErrorMessage(e)),
      );
    }
  }

  /// Fetch (or take a server-supplied fresh) destination roster and hard-verify
  /// its signatures plus reconcile fingerprints — both throw on failure, so a
  /// returned roster is safe to wrap keys against. Mirrors
  /// [FolderRelocationController]'s `_verifiedRoster`.
  Future<FolderMembersResponse> _verifiedRoster(
    _CascadeDeps deps,
    String folderId, {
    FolderMembersResponse? fresh,
  }) async {
    final response =
        fresh ?? await deps.client.shares.getFolderMembers(folderId);
    final verified = deps.membership.verifyFolderMemberList(response);
    await deps.membership.reconcileFingerprints(verified);
    return response;
  }

  static String _moveOutMessage(MoveOutRejection reason) {
    switch (reason) {
      case MoveOutRejection.notOwner:
        return ambientL10n.sharesOnlyOwnerCanMoveThisOut;
      case MoveOutRejection.destinationShared:
        return ambientL10n.sharesDestinationIsShared;
    }
  }

  _CascadeDeps? _resolve() {
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
      return null;
    }
    return _CascadeDeps(
      client: client,
      shareCrypto: shareCrypto,
      membership: membership,
      fileCrypto: fileCrypto,
      callerId: callerId,
    );
  }
}

class _CascadeDeps {
  _CascadeDeps({
    required this.client,
    required this.shareCrypto,
    required this.membership,
    required this.fileCrypto,
    required this.callerId,
  });

  final ApiClient client;
  final ShareCrypto shareCrypto;
  final FolderMembership membership;
  final FileCrypto fileCrypto;
  final String callerId;
}

final moveIntoSharedCascadeProvider = Provider<MoveIntoSharedCascade>((ref) {
  return MoveIntoSharedCascade(ref);
});
