import 'package:dio/dio.dart';

import 'file_item.dart';

/// Account-level usage figures from `POST /api/storage/stats`.
class StorageUsage {
  /// Bytes stored by files the caller owns, counted against [quota].
  final int usedSpace;

  /// Byte limit for the account; null means unlimited.
  final int? quota;

  const StorageUsage({required this.usedSpace, this.quota});

  factory StorageUsage.fromJson(Map<String, dynamic> json) {
    return StorageUsage(
      usedSpace: json['used_space'] as int? ?? 0,
      quota: json['quota'] as int?,
    );
  }
}

/// HTTP client scoped to storage-quota and editable-content routes —
/// everything under `/api/storage/*` that is NOT per-file CRUD (see
/// [FilesClient]), search (see [SearchClient]), or version history (see
/// [VersionsClient]).
///
/// Shares the [Dio] instance owned by [ApiClient].
class StorageClient {
  final Dio _dio;

  StorageClient(this._dio);

  /// `POST /api/storage/stats` — aggregated storage usage for the current
  /// account (used-space, quota, breakdown by mime).
  /// `GET /api/storage/reindex` — files that still need re-indexing against
  /// the keyed search scheme.
  ///
  /// Membership is derived, not tracked: a file is pending exactly while it
  /// has no root-scope tags, so writing its tags removes it from this list and
  /// an interrupted sweep resumes just by asking again.
  Future<List<FileItem>> pendingReindex() async {
    final resp = await _dio.get('/api/storage/reindex');
    final rows = resp.data is List ? resp.data as List : const [];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(FileItem.fromJson)
        .toList();
  }

  /// `PUT /api/storage/{id}/reindex` — replace one file's search tags and its
  /// re-keyed `name_hash`.
  Future<void> reindexFile({
    required String fileId,
    required String nameHash,
    required List<String> searchTokensRoot,
    required List<String> searchTokensFile,
  }) async {
    await _dio.put(
      '/api/storage/$fileId/reindex',
      data: {
        'name_hash': nameHash,
        'search_tokens_root': searchTokensRoot,
        'search_tokens_file': searchTokensFile,
      },
    );
  }

  Future<Map<String, dynamic>> getStats() async {
    final resp = await _dio.post('/api/storage/stats');
    return resp.data;
  }

  /// `PUT /api/storage/{fileId}/content` — allocate a pending version on
  /// the server and stage the in-flight upload. **Does not touch chunks
  /// on disk** — readers continue to see the previous content until the
  /// chunk re-upload finishes.
  ///
  /// Throws [DioException] with `response.statusCode == 409` when another
  /// edit is already in flight; pass `force: true` to abandon it and take
  /// over.
  Future<Map<String, dynamic>> replaceContent({
    required String fileId,
    required int size,
    required int chunks,
    String? encryptedName,
    String? encryptedThumbnail,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    bool force = false,
  }) async {
    final data = <String, dynamic>{'size': size, 'chunks': chunks};
    if (encryptedName != null) data['encrypted_name'] = encryptedName;
    if (encryptedThumbnail != null) {
      data['encrypted_thumbnail'] = encryptedThumbnail;
    }
    if (searchTokensRoot != null) {
      data['search_tokens_root'] = searchTokensRoot;
    }
    if (searchTokensFile != null) {
      data['search_tokens_file'] = searchTokensFile;
    }
    if (force) data['force'] = true;

    final resp = await _dio.put('/api/storage/$fileId/content', data: data);
    return resp.data;
  }

  /// `PUT /api/storage/{fileId}/editable` — toggle the editable flag on
  /// an existing file. Used to convert a regular `.md` upload into an
  /// editable note (or revert it).
  Future<Map<String, dynamic>> setEditable({
    required String fileId,
    required bool editable,
  }) async {
    final resp = await _dio.put(
      '/api/storage/$fileId/editable',
      data: {'editable': editable},
    );
    return resp.data;
  }
}
