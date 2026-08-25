import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_models.dart';

/// HTTP client scoped to editable-file version history:
/// `/api/storage/{fileId}/versions*`. Powers the A2 markdown versioning
/// feature — list, download, restore, fork, and purge historical
/// snapshots of an editable file.
///
/// Shares the [Dio] instance owned by [ApiClient].
class VersionsClient {
  final Dio _dio;

  VersionsClient(this._dio);

  /// `GET /api/storage/{fileId}/versions` — newest-first list of
  /// historical snapshots. The active version is NOT included (it lives
  /// on the file row itself).
  Future<List<FileVersion>> list(String fileId) async {
    final resp = await _dio.get('/api/storage/$fileId/versions');
    final raw = resp.data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FileVersion.fromJson)
        .toList();
  }

  /// `GET /api/storage/{fileId}/versions/{version}?chunk=N` — fetch one
  /// encrypted chunk of a historical version. Caller decrypts locally.
  Future<Uint8List> downloadChunk({
    required String fileId,
    required int version,
    required int chunk,
  }) async {
    final resp = await _dio.get<List<int>>(
      '/api/storage/$fileId/versions/$version',
      queryParameters: {'chunk': chunk},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data ?? const []);
  }

  /// `PUT /api/storage/{fileId}/content-tokens` — replace the note-body
  /// search tags, leaving the name and extra sources alone.
  ///
  /// Sent after a restore. That request names a version and carries no body,
  /// and the server holds only ciphertext, so it cannot index the text it
  /// just restored — it clears the body tags and enrols the file in the
  /// owner's sweep. Having already decrypted the restored version to show it,
  /// the client holds exactly what the server could not derive.
  Future<void> replaceContentTokens({
    required String fileId,
    required List<String> rootTokens,
    required List<String> fileTokens,
  }) async {
    await _dio.put(
      '/api/storage/$fileId/content-tokens',
      data: {
        'content_tokens_root': rootTokens,
        'content_tokens_file': fileTokens,
      },
    );
  }

  /// `POST /api/storage/{fileId}/versions/{version}/restore` — pointer
  /// flip plus chunk copy, server-side. Returns the file with the new
  /// active version slot already swapped in.
  Future<Map<String, dynamic>> restore({
    required String fileId,
    required int version,
  }) async {
    final resp = await _dio.post(
      '/api/storage/$fileId/versions/$version/restore',
    );
    return resp.data;
  }

  /// `POST /api/storage/{fileId}/versions/{version}/fork` —
  /// restore-as-new-note. Body uses the same shape as
  /// [FilesClient.createFileEntry]; server overrides chunks/size/sha256
  /// from the source's recorded values and copies the chunks into the
  /// new file's v1.
  Future<Map<String, dynamic>> fork({
    required String fileId,
    required int version,
    required Map<String, dynamic> newFile,
  }) async {
    final resp = await _dio.post(
      '/api/storage/$fileId/versions/$version/fork',
      data: newFile,
    );
    return resp.data;
  }

  /// `DELETE /api/storage/{fileId}/versions/{version}` — drop a single
  /// historical snapshot. Server rejects deleting the active version.
  Future<void> delete({required String fileId, required int version}) async {
    await _dio.delete('/api/storage/$fileId/versions/$version');
  }

  /// `DELETE /api/storage/{fileId}/versions` — wipe every historical
  /// snapshot, keeping only the current active version.
  Future<void> purgeAll(String fileId) async {
    await _dio.delete('/api/storage/$fileId/versions');
  }
}
