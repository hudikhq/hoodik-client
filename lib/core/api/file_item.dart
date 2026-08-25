import '../crypto/share_crypto.dart' show ShareRole;
import 'shares_models.dart';

class StorageResponse {
  final List<FileItem> children;

  StorageResponse({required this.children});

  factory StorageResponse.fromJson(Map<String, dynamic> json) {
    final items =
        (json['children'] as List?)
            ?.map((e) => FileItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return StorageResponse(children: items);
  }
}

class FileItem {
  final String id;
  final String? fileId; // parent dir
  final String encryptedName;
  final String? encryptedKey;
  final String? encryptedThumbnail;
  final String mime;
  final int? size;
  final int? chunks;
  final int? chunksStored;
  final String cipher;
  final bool editable;
  final int? fileModifiedAt;
  final int? createdAt;
  final int? finishedUploadAt;
  final String? sha256;
  final String? md5;
  final String? sha1;
  final String? blake2b;

  /// Chunk indexes the server can prove it holds, listed live from the
  /// storage provider. Only the name-hash and metadata routes fill this;
  /// listings leave it null. Drives upload resume: these are the chunks a
  /// retry may skip.
  final List<int>? uploadedChunks;

  /// Version readers should fetch — always set; defaults to 1.
  final int activeVersion;

  /// Set while a save is in flight; chunks are landing into v{pending_version}/.
  final int? pendingVersion;

  /// Total chunks expected for the in-flight upload.
  final int? pendingChunks;

  /// Total bytes expected for the in-flight upload.
  final int? pendingSize;

  /// Whether the active session owns this row. Rows from `/api/storage` are
  /// always owned, so this defaults to true; only [FileItem.fromIncomingShare]
  /// flips it false. Drives the share/leave/fork/delete action gates and the
  /// multi-key upload predicate.
  final bool isOwner;

  /// The caller's role on a shared row (null when [isOwner]). Gates fork
  /// (co-owner only) and the editor surface for shared files.
  final ShareRole? shareRole;

  /// Set on an owned folder once a signed member list exists for it; null
  /// otherwise. Combined with [isOwner], it is the second half of the
  /// "upload here must be multi-key" predicate.
  final int? membersSignedAt;

  /// Email of the file's owner, surfaced on shared rows for the "Owned by X"
  /// pill. Null on owned rows.
  final String? ownerEmail;

  /// Email of whoever granted the share to the caller — the owner for a
  /// direct grant, a co-owner for a re-share. Null on owned rows.
  final String? sharedByEmail;

  /// Recipient count for an owned, shared file, surfaced as the "shared with
  /// N" badge. Null when the file isn't shared or the count is unknown.
  final int? sharedWithCount;

  /// Whether a thumbnail exists for this file, even when a `compact`
  /// listing withheld the blob itself.
  final bool hasThumbnail;

  bool get isDir => mime == 'dir';
  bool get isUploading => finishedUploadAt == null && !isDir;
  bool get hasPendingEdit => pendingVersion != null;

  /// True when a thumbnail can be shown for this file — either the row
  /// carries the ciphertext inline (older servers, cached rows) or the
  /// server advertised one to fetch lazily.
  bool get thumbnailAvailable => encryptedThumbnail != null || hasThumbnail;

  FileItem({
    required this.id,
    this.fileId,
    required this.encryptedName,
    this.encryptedKey,
    this.encryptedThumbnail,
    required this.mime,
    this.size,
    this.chunks,
    this.chunksStored,
    this.cipher = 'aegis128l',
    this.editable = false,
    this.fileModifiedAt,
    this.createdAt,
    this.finishedUploadAt,
    this.sha256,
    this.md5,
    this.sha1,
    this.blake2b,
    this.uploadedChunks,
    this.activeVersion = 1,
    this.pendingVersion,
    this.pendingChunks,
    this.pendingSize,
    this.isOwner = true,
    this.shareRole,
    this.membersSignedAt,
    this.ownerEmail,
    this.sharedByEmail,
    this.sharedWithCount,
    this.hasThumbnail = false,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    final shareRoleWire = json['share_role'] as String?;
    return FileItem(
      id: json['id'] as String,
      fileId: json['file_id'] as String?,
      encryptedName: json['encrypted_name'] as String? ?? '',
      encryptedKey: json['encrypted_key'] as String?,
      encryptedThumbnail: json['encrypted_thumbnail'] as String?,
      mime: json['mime'] as String? ?? 'unknown',
      size: json['size'] as int?,
      chunks: json['chunks'] as int?,
      chunksStored: json['chunks_stored'] as int?,
      cipher: json['cipher'] as String? ?? 'aegis128l',
      editable: json['editable'] as bool? ?? false,
      fileModifiedAt: json['file_modified_at'] as int?,
      createdAt: json['created_at'] as int?,
      finishedUploadAt: json['finished_upload_at'] as int?,
      sha256: json['sha256'] as String?,
      md5: json['md5'] as String?,
      sha1: json['sha1'] as String?,
      blake2b: json['blake2b'] as String?,
      uploadedChunks: (json['uploaded_chunks'] as List?)?.cast<int>(),
      activeVersion: json['active_version'] as int? ?? 1,
      pendingVersion: json['pending_version'] as int?,
      pendingChunks: json['pending_chunks'] as int?,
      pendingSize: json['pending_size'] as int?,
      isOwner: json['is_owner'] as bool? ?? true,
      shareRole: shareRoleWire == null
          ? null
          : ShareRole.fromWire(shareRoleWire),
      membersSignedAt: json['members_signed_at'] as int?,
      ownerEmail: json['owner_email'] as String?,
      sharedByEmail: json['shared_by_email'] as String?,
      sharedWithCount: json['shared_with_count'] as int?,
      hasThumbnail:
          json['has_thumbnail'] as bool? ?? json['encrypted_thumbnail'] != null,
    );
  }

  FileItem copyWith({int? sharedWithCount}) {
    return FileItem(
      id: id,
      fileId: fileId,
      encryptedName: encryptedName,
      encryptedKey: encryptedKey,
      encryptedThumbnail: encryptedThumbnail,
      mime: mime,
      size: size,
      chunks: chunks,
      chunksStored: chunksStored,
      cipher: cipher,
      editable: editable,
      fileModifiedAt: fileModifiedAt,
      createdAt: createdAt,
      finishedUploadAt: finishedUploadAt,
      sha256: sha256,
      uploadedChunks: uploadedChunks,
      activeVersion: activeVersion,
      pendingVersion: pendingVersion,
      pendingChunks: pendingChunks,
      pendingSize: pendingSize,
      isOwner: isOwner,
      shareRole: shareRole,
      membersSignedAt: membersSignedAt,
      ownerEmail: ownerEmail,
      sharedByEmail: sharedByEmail,
      sharedWithCount: sharedWithCount ?? this.sharedWithCount,
      hasThumbnail: hasThumbnail,
    );
  }

  /// Render an incoming share as a regular file row. The encrypted
  /// name/thumbnail/cipher/size/chunk fields are copied verbatim so the
  /// existing decrypt and thumbnail pipeline treats it like any owned file,
  /// and [finishedUploadAt] carries over so a complete share doesn't read as
  /// perpetually "Uploading…". [isOwner] is false and [shareRole] is the
  /// caller's granted role.
  factory FileItem.fromIncomingShare(IncomingShare s) {
    return FileItem(
      id: s.fileId,
      encryptedName: s.encryptedName,
      encryptedKey: s.encryptedKey,
      encryptedThumbnail: s.encryptedThumbnail,
      mime: s.mime,
      size: s.size,
      chunks: s.chunks,
      chunksStored: s.chunksStored,
      cipher: s.cipher,
      editable: s.editable,
      createdAt: s.createdAt,
      finishedUploadAt: s.finishedUploadAt,
      sha256: s.sha256,
      isOwner: false,
      shareRole: s.shareRole,
      ownerEmail: s.ownerEmail,
      sharedByEmail: s.sharedByEmail,
      hasThumbnail: s.hasThumbnail,
    );
  }
}
