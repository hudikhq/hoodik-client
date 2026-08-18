import 'package:dio/dio.dart';

import 'api_models.dart';

/// HTTP client scoped to the search endpoint.
///
/// The plaintext query never leaves the device. Callers tokenize it and tag
/// each token with a key the server never sees, then send only the tags.
///
/// Two scopes go out. [rootTags] cover everything the caller owns and cost one
/// tag per query word however large the drive is. [fileTags] cover files
/// shared *with* the caller, one per (word, file), because those are keyed on
/// each file's own key. Callers never send file tags for files they own, so a
/// file can only match through one scope and the ranking stays honest.
///
/// Shares the [Dio] instance owned by [ApiClient].
class SearchClient {
  final Dio _dio;

  SearchClient(this._dio);

  /// `POST /api/storage/search` — match keyed tags against the index.
  ///
  /// [hash] is an optional content digest matched verbatim against the
  /// stored hash columns — see [hashLookup].
  Future<List<FileItem>> searchFiles({
    required List<String> rootTags,
    List<String> fileTags = const [],
    String? hash,
    String? dirId,
    int limit = 10,
    int skip = 0,
    bool? editable,
  }) async {
    final data = <String, dynamic>{
      'root_tags': rootTags,
      'file_tags': fileTags,
      'limit': limit,
      'skip': skip,
      'compact': true,
    };
    if (hash != null) data['hash'] = hash;
    if (dirId != null) data['dir_id'] = dirId;
    if (editable != null) data['editable'] = editable;

    final resp = await _dio.post('/api/storage/search', data: data);
    final list = resp.data is List ? resp.data as List : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => FileItem.fromJson(json))
        .toList();
  }

  /// A query that is itself a content digest is sent verbatim so the server
  /// can match it against the stored hash columns — the way to check whether
  /// a file already lives here. The digest comes from the file's own bytes
  /// and the server already stores all four, so it carries nothing the
  /// server does not have. Anything else must stay on the device.
  ///
  /// Lengths are hex characters: MD5, SHA1, SHA256, BLAKE2b.
  static String? hashLookup(String query) {
    const hexHashLengths = {32, 40, 64, 128};
    final candidate = query.trim();

    if (hexHashLengths.contains(candidate.length) &&
        RegExp(r'^[0-9a-fA-F]+$').hasMatch(candidate)) {
      return candidate;
    }

    return null;
  }
}
