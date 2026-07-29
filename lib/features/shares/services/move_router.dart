import '../../../core/api/api_client.dart';
import '../../../core/services/shared_folder_target.dart';
import '../../../core/utils/l10n_lookup.dart';

/// Where a requested move should be routed once source and destination
/// share-state are known. The funnel (`FilesMutationController.move`) maps each
/// case to an action: [PlainMove] runs the unchanged `moveMany`; [BlockedMove]
/// aborts with a message; the three shared cases hand off to the cascade
/// service, which owns the per-member key wrapping.
sealed class MoveDecision {
  const MoveDecision();
}

/// Destination is private (or the drive root) and the items don't leave a
/// shared scope — the normal owner-only relocation.
class PlainMove extends MoveDecision {
  const PlainMove();
}

/// The whole move is refused before any key is wrapped, per the user's
/// "block the whole move on any ineligible item" decision — e.g. a non-owned
/// item bound for a shared folder, or a non-owner trying to move an item out
/// of a shared folder.
class BlockedMove extends MoveDecision {
  const BlockedMove(this.message);

  final String message;
}

/// Owned items moving into a shared destination. Each item is routed
/// individually by the caller: a non-directory goes through
/// `FolderRelocationController.moveIntoShared`; a directory goes through the
/// cascade that re-wraps every descendant for the destination roster. Carrying
/// the whole list (not one root) keeps the no-partial guarantee — every item
/// is owned, so the batch either all moves or was blocked up front.
class MoveIntoShared extends MoveDecision {
  const MoveIntoShared(this.sources, this.destinationFolderId);

  final List<FileItem> sources;
  final String destinationFolderId;
}

/// Owned items leaving a shared scope for a private destination — the move-out
/// path that drops the other members' rows across each moved subtree.
class MoveOutOfShared extends MoveDecision {
  const MoveOutOfShared(this.sources, this.destinationFolderId);

  final List<FileItem> sources;
  final String? destinationFolderId;
}

/// A private-destination batch whose items come from folders of differing
/// share-state — only reachable from the tree, where a selection can span
/// expanded folders. Each item takes the route its own parent dictates:
/// [outSources] (parent is a shared folder) leave via move-out, [plainSources]
/// (parent private or root) take the plain relocation. Splitting is what keeps
/// a shared item off the plain path, which would relocate it without dropping
/// the other members' rows and strand their access.
class SplitMove extends MoveDecision {
  const SplitMove(this.plainSources, this.outSources, this.destinationFolderId);

  final List<FileItem> plainSources;
  final List<FileItem> outSources;
  final String? destinationFolderId;
}

/// Classifies a move from the source items, each item's own parent, and the
/// destination — the single place the funnel's decision tree lives. Detection
/// mirrors the upload path's [SharedFolderTargetResolver.isMultiKeyTarget]
/// predicate (`dir && (!is_owner || members_signed_at != null)`) for both the
/// destination and each item's parent folder.
///
/// The classifier never wraps a key or hits a mutation endpoint; it only reads
/// share-state (one metadata fetch per distinct source parent) and returns the
/// route. All hard server rules (ownership, dest-is-shared, folder-requires-
/// cascade) are still enforced server-side — this is the client-side routing
/// and the early "block the whole move" guard.
class MoveRouter {
  MoveRouter({required this.files, required this.sharingEnabled});

  final FilesClient files;

  /// The `sharing.enabled` master gate. When off (kill-switch or an older
  /// server), every destination resolves to a plain move and no metadata is
  /// fetched, so a server that doesn't speak sharing never engages these paths.
  final bool sharingEnabled;

  Future<MoveDecision> classify({
    required List<FileItem> sources,
    required FileItem? destination,
  }) async {
    if (sources.isEmpty) return const PlainMove();

    final destShared =
        sharingEnabled &&
        destination != null &&
        SharedFolderTargetResolver.isMultiKeyTarget(destination);

    if (destShared) {
      // Moving INTO a shared folder: every selected item must be owned by the
      // caller, or the whole move is blocked (the user's no-partial decision).
      if (sources.any((f) => !f.isOwner)) {
        return BlockedMove(ambientL10n.sharesOnlyOwnedIntoShared);
      }
      return MoveIntoShared(sources, destination.id);
    }

    // Destination is private (or root). Route each item by its OWN parent's
    // share-state, read off the item rather than the screen's directory: an
    // item leaving a shared folder is a move-out, the rest are plain
    // relocations. A single selection mixes the two only from the tree.
    final probe = await _probeParents(sources);
    if (probe.unresolved) {
      // A parent we couldn't read might be a shared folder. Routing its item to
      // the plain path would relocate it without dropping the other members'
      // rows — stranding their access — and forcing it through move-out would
      // 400 a genuinely private one. Neither is safe to guess, so block and let
      // the user retry once the folder's state can be read.
      return BlockedMove(ambientL10n.sharesMoveCheckFailed);
    }
    final sharedParents = probe.shared;
    if (sharedParents.isEmpty) return const PlainMove();

    final destId = destination?.id;
    final outSources = sources
        .where((f) => sharedParents.contains(f.fileId))
        .toList();
    final plainSources = sources
        .where((f) => !sharedParents.contains(f.fileId))
        .toList();

    // Only the owner can detach an item from a shared folder; a single
    // ineligible item blocks the whole move (no partial).
    if (outSources.any((f) => !f.isOwner)) {
      return BlockedMove(ambientL10n.sharesOnlyOwnerCanMoveOut);
    }

    if (plainSources.isEmpty) return MoveOutOfShared(outSources, destId);
    return SplitMove(plainSources, outSources, destId);
  }

  /// Probes each distinct source parent once, concurrently, for whether it is a
  /// shared folder (the same roster predicate the destination uses). The account
  /// root (a null parent) is never shared and isn't probed. A parent whose
  /// metadata can't be read is reported as `unresolved` rather than guessed — the
  /// caller blocks on that, because guessing "not shared" could strand a shared
  /// item on the plain path.
  Future<({Set<String> shared, bool unresolved})> _probeParents(
    List<FileItem> sources,
  ) async {
    if (!sharingEnabled) return (shared: const <String>{}, unresolved: false);
    final parents = sources.map((f) => f.fileId).whereType<String>().toSet();
    final shared = <String>{};
    var unresolved = false;
    await Future.wait(
      parents.map((id) async {
        try {
          final meta = await files.getFileMetadata(id);
          if (SharedFolderTargetResolver.isMultiKeyTarget(
            FileItem.fromJson(meta),
          )) {
            shared.add(id);
          }
        } catch (_) {
          unresolved = true;
        }
      }),
    );
    return (shared: shared, unresolved: unresolved);
  }
}
