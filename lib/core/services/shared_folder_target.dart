import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../api/api_models.dart';
import '../api/files_client.dart';
import 'shared_folder_upload.dart';

/// Thrown when a create targets a shared folder but the session can't wrap the
/// roster — no private key or no server UUID yet. Surfaced rather than falling
/// back to an owner-only create, which would strand the file in the shared
/// folder visible to no other member.
class SharingUnavailableException implements Exception {
  const SharingUnavailableException();

  @override
  String toString() =>
      'SharingUnavailableException: sharing is unavailable for this session';
}

/// Decides whether a create operation must take the multi-key
/// (`upload-multikey`) path because its destination sits inside a shared
/// tree, and which folder's signed member list authorises the wraps.
///
/// Mirrors the web's roster resolution (`Storage.writeRosterId`): a folder is
/// a multi-key destination when it — or any ancestor — carries a signed
/// member list, or when it is shared *with* the caller (the legacy fallback).
/// The caller's own, never-shared trees keep the owner-only create path.
class SharedFolderTargetResolver {
  SharedFolderTargetResolver({
    required FilesClient files,
    required bool sharingEnabled,
  }) : _files = files,
       _sharingEnabled = sharingEnabled;

  final FilesClient _files;

  /// Whether sharing is switched on for this server — `sharing.enabled` from
  /// `GET /api/capabilities`, the same master gate the rest of the sharing UI
  /// uses. An older server (no capabilities endpoint) fails closed to off, and
  /// an admin can flip the kill-switch off at runtime. When off, no metadata
  /// fetch happens and every destination resolves to the owner-only path, so a
  /// server that isn't running sharing is never routed through multi-key.
  final bool _sharingEnabled;

  /// Nearest ancestor-or-self folder of [parentDirId] carrying a signed
  /// member list — the folder whose list authorises a multi-key write
  /// anywhere in its subtree. Folders below a share root hold the root's
  /// roster (fan-out, cascade moves and multi-key creates all copy it) but
  /// no signature of their own, and the server rejects any write whose wrap
  /// set doesn't match the actual target's rows, so resolving at the root is
  /// exactly as strong as writing into the root itself.
  ///
  /// Walks one metadata fetch per unsigned level; [parentItem] spares the
  /// first when the caller already holds it. Returns null for a private
  /// tree; a metadata fetch failure propagates so callers can distinguish
  /// "unreadable" from "not shared".
  Future<String?> resolveRosterFolderId(
    String? parentDirId, {
    FileItem? parentItem,
  }) async {
    if (!_sharingEnabled || parentDirId == null) return null;
    final seen = <String>{};
    String? cursor = parentDirId;
    var item = parentItem;
    while (cursor != null && seen.add(cursor)) {
      item ??= FileItem.fromJson(await _files.getFileMetadata(cursor));
      if (!item.isDir) return null;
      if (item.membersSignedAt != null) return item.id;
      cursor = item.fileId;
      item = null;
    }
    return null;
  }

  /// Roster source for a write into [parentDirId], or null for a plain
  /// owner-only write. A non-owned folder with no signed list anywhere in
  /// its chain (a pre-signature legacy share) falls back to the folder
  /// itself, so those writes keep today's verification error instead of
  /// silently producing an owner-only row.
  Future<String?> resolveWriteRosterId(
    String? parentDirId, {
    FileItem? parentItem,
  }) async {
    if (!_sharingEnabled || parentDirId == null) return null;
    final item =
        parentItem ??
        FileItem.fromJson(await _files.getFileMetadata(parentDirId));
    final resolved = await resolveRosterFolderId(parentDirId, parentItem: item);
    if (resolved != null) return resolved;
    return item.isDir && !item.isOwner ? item.id : null;
  }
}

/// Route a create whose destination might sit inside a shared tree.
///
/// When [parentDirId] (optionally pre-resolved via [parentItem]) is a shared
/// folder — or any folder below a share root — [fileKey] is wrapped for every
/// member of the resolved roster and the file is created via `upload-multikey`
/// under a freshly minted id, which is returned and which the caller reuses as
/// the chunk-upload id so the audit signature binds to it. A destination in a
/// private tree returns null, signalling the caller to run its normal
/// owner-only create.
///
/// A shared destination with no [upload] available throws rather than silently
/// owner-only-wrapping — this is the single place that guard is enforced for
/// binary, note, and folder creates alike, so a file can never land in a shared
/// folder wrapped for the owner only.
Future<String?> multiKeyCreateOrNull({
  required SharedFolderTargetResolver? resolver,
  required SharedFolderUpload? upload,
  required String? parentDirId,
  required FileItem? parentItem,
  required Uint8List fileKey,
  required String nameHash,
  required String encryptedName,
  required String mime,
  required String cipher,
  required int chunks,
  int? size,
  String? sha256,
  bool? editable,
  List<String>? searchTokensRoot,
  List<String>? searchTokensFile,
  List<String>? contentTokensRoot,
  List<String>? contentTokensFile,
  List<String>? digestTokensRoot,
  List<String>? digestTokensFile,
  String? encryptedThumbnail,
}) async {
  if (resolver == null || parentDirId == null) return null;
  final rosterFolderId = await resolver.resolveWriteRosterId(
    parentDirId,
    parentItem: parentItem,
  );
  if (rosterFolderId == null) return null;
  if (upload == null) {
    throw const SharingUnavailableException();
  }
  return upload.uploadIntoSharedFolder(
    folderId: parentDirId,
    rosterFolderId: rosterFolderId,
    newFileId: const Uuid().v4(),
    fileKey: fileKey,
    nameHash: nameHash,
    encryptedName: encryptedName,
    mime: mime,
    chunks: chunks,
    size: size,
    sha256: sha256,
    cipher: cipher,
    editable: editable,
    searchTokensRoot: searchTokensRoot,
    searchTokensFile: searchTokensFile,
    contentTokensRoot: contentTokensRoot,
    contentTokensFile: contentTokensFile,
    digestTokensRoot: digestTokensRoot,
    digestTokensFile: digestTokensFile,
    encryptedThumbnail: encryptedThumbnail,
  );
}
