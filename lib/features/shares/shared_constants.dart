import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/crypto/share_crypto.dart' show ShareRole;
import '../../core/utils/l10n_lookup.dart';
import '../../core/widgets/app_icons.dart';

/// Synthetic directory id for the "Shared with me" virtual folder rendered at
/// the root of the files browser. Recipient-side incoming shares are mapped
/// into rows under this id so the browser can navigate them like any regular
/// folder. The server never sees this id — the listing branches on it before
/// any network call. Matches the web's `SHARED_WITH_ME_DIR_ID`.
const String sharedWithMeDirId = '__shared_with_me__';

/// Display label for the synthetic folder. The row carries no encrypted name,
/// so the decrypt pipeline skips it and the UI falls back to this string.
String get sharedWithMeDirName => ambientL10n.sharesSharedWithMe;

/// The synthetic root row injected at index 0 when the caller has at least one
/// incoming share. [FileItem.encryptedKey] is null so the name-decrypt path
/// skips it; callers special-case [sharedWithMeDirId] to render
/// [sharedWithMeDirName].
FileItem sharedWithMeFolder() {
  return FileItem(
    id: sharedWithMeDirId,
    encryptedName: '',
    mime: 'dir',
    isOwner: false,
  );
}

/// Whether the file "Share" action should appear for [file]. Covers owned
/// single files: the server must advertise sharing, the caller must own the
/// row, it must not be a directory (folders route to the members view via
/// [canShareFolder]), and the synthetic "Shared with me" root is never
/// sharable.
bool canShareFile(FileItem file, {required bool sharingEnabled}) {
  return sharingEnabled &&
      file.isOwner &&
      !file.isDir &&
      file.id != sharedWithMeDirId;
}

/// Whether the folder "Members" action should appear for [file]. A folder's
/// share surface is the dedicated members view, opened by the owner or a
/// current co-owner — the two roles the server's `can_reshare` gate lets
/// mutate a folder roster. The synthetic "Shared with me" root is excluded.
bool canShareFolder(FileItem file, {required bool sharingEnabled}) {
  if (!sharingEnabled || !file.isDir || file.id == sharedWithMeDirId) {
    return false;
  }
  return file.isOwner || file.shareRole == ShareRole.coOwner;
}

/// Whether the recipient-side "Leave" action should appear for [file]. A
/// recipient can remove their own access to any row shared with them — file or
/// folder — but not to rows they own, and never to the synthetic "Shared with
/// me" root, which is a client-only navigation aid the server doesn't know.
bool canLeaveFile(FileItem file, {required bool sharingEnabled}) {
  return sharingEnabled && !file.isOwner && file.id != sharedWithMeDirId;
}

/// Whether [file] can be picked in selection mode. The synthetic "Shared
/// with me" root is a client-only navigation aid the server has never heard
/// of, so nothing the selection bar offers — move, delete — can act on it.
/// Its checkbox still renders, disabled, so the rows stay aligned and the
/// column doesn't jump around one absent control.
bool canSelectFile(FileItem file) => file.id != sharedWithMeDirId;

/// Whether the "Save to my drive" (fork) action should appear for [file].
/// Mirrors the server's `can_fork` gate (`SharePermission::CoOwner`, files
/// only): the server must advertise sharing, the row must be shared *to* the
/// caller as a co-owner — readers and editors cannot fork — it must not be a
/// directory (`cannot_fork_directory`), and the synthetic "Shared with me"
/// root is never forkable. An owner has no reason to fork their own file, so
/// owned rows are excluded too.
bool canFork(FileItem file, {required bool sharingEnabled}) {
  return sharingEnabled &&
      !file.isOwner &&
      file.shareRole == ShareRole.coOwner &&
      !file.isDir &&
      file.id != sharedWithMeDirId;
}

/// Whether [file] should carry the recipient-side share indicator ("Owned by
/// X"): a row the caller received via a share that still names its owner. The
/// synthetic "Shared with me" root carries no owner email, so it falls through.
/// Single source of truth shared by the list, grid, and tree views so all three
/// agree on when the indicator shows.
bool showsRecipientShareIndicator(
  FileItem file, {
  required bool sharingEnabled,
}) {
  if (!sharingEnabled || file.isOwner) return false;
  final email = file.ownerEmail ?? file.sharedByEmail;
  return email != null && email.isNotEmpty;
}

/// Whether [file] should carry the owner-side share indicator ("Shared with
/// N"): a file the caller owns and has shared out to at least one recipient.
/// Shared by the list, grid, and tree views.
bool showsOwnerShareIndicator(FileItem file, {required bool sharingEnabled}) {
  return sharingEnabled && file.isOwner && (file.sharedWithCount ?? 0) > 0;
}

/// The compact share glyph for [file], or null when no indicator applies. The
/// list view pairs this with text; the icon and tree views render it bare. A
/// person glyph marks an incoming share, a group glyph an outgoing one — so
/// every view picks the same icon for the same row.
IconData? shareIndicatorIcon(FileItem file, {required bool sharingEnabled}) {
  if (showsRecipientShareIndicator(file, sharingEnabled: sharingEnabled)) {
    return Icons.account_circle_outlined;
  }
  if (showsOwnerShareIndicator(file, sharingEnabled: sharingEnabled)) {
    return AppIcons.members;
  }
  return null;
}
