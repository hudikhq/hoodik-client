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
/// (`upload-multikey`) path because its destination folder carries a member
/// roster the new file's key has to be wrapped for.
///
/// The predicate mirrors the web browser's upload routing
/// (`web/.../LayoutFileBrowserInner.vue`): a folder is a multi-key destination
/// when it is shared *with* the caller (`!isOwner`) or is an owned folder the
/// caller has already shared (`membersSignedAt != null`). The caller's own,
/// never-shared folders keep the unchanged owner-only create path.
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

  /// The roster predicate, applied to a parent folder the caller already holds.
  static bool isMultiKeyTarget(FileItem parent) =>
      parent.isDir && (!parent.isOwner || parent.membersSignedAt != null);

  /// Whether a create into [parentDirId] must fan its key out to a folder
  /// roster. Returns false whenever sharing is off (kill-switch or an older
  /// server) and for the account root ([parentDirId] null), so an unsupported
  /// or disabled server never engages the multi-key path.
  ///
  /// [parentItem] is used directly when the caller holds it; otherwise the
  /// parent's share status is read from one `metadata` fetch, acceptable
  /// because a multi-key upload needs a live roster fetch anyway.
  Future<bool> isSharedDestination(
    String? parentDirId, {
    FileItem? parentItem,
  }) async {
    if (!_sharingEnabled || parentDirId == null) return false;
    if (parentItem != null) return isMultiKeyTarget(parentItem);
    final meta = await _files.getFileMetadata(parentDirId);
    return isMultiKeyTarget(FileItem.fromJson(meta));
  }
}

/// Route a create whose destination might be a shared folder.
///
/// When [parentDirId] (optionally pre-resolved via [parentItem]) is a shared
/// folder, [fileKey] is wrapped for every member and the file is created via
/// `upload-multikey` under a freshly minted id, which is returned and which the
/// caller reuses as the chunk-upload id so the audit signature binds to it. A
/// destination the caller owns outright returns null, signalling the caller to
/// run its normal owner-only create.
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
  List<String>? digestTokensRoot,
  List<String>? digestTokensFile,
  String? encryptedThumbnail,
}) async {
  if (resolver == null ||
      !await resolver.isSharedDestination(
        parentDirId,
        parentItem: parentItem,
      )) {
    return null;
  }
  if (upload == null) {
    throw const SharingUnavailableException();
  }
  return upload.uploadIntoSharedFolder(
    folderId: parentDirId!,
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
    digestTokensRoot: digestTokensRoot,
    digestTokensFile: digestTokensFile,
    encryptedThumbnail: encryptedThumbnail,
  );
}
