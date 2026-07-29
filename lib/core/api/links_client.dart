import 'package:dio/dio.dart';

/// HTTP client scoped to the `/api/links/*` routes.
///
/// Instantiated with the [Dio] instance owned by [ApiClient], so it shares
/// the same auth interceptors, cookie jar, and refresh handling. Keeping
/// link calls out of [ApiClient] keeps that class closer to its 500-line
/// ceiling and groups related endpoints together.
class LinksClient {
  final Dio _dio;

  LinksClient(this._dio);

  /// `GET /api/links` — list the current user's shared links.
  ///
  /// Each entry is a raw JSON map matching the server's `AppLink`
  /// serialization; callers decrypt the link key locally (RSA) to obtain
  /// the symmetric link key, then decrypt names etc. Content for public
  /// links is always fetched as raw ciphertext and decrypted client-side.
  Future<List<dynamic>> list({bool withExpired = false}) async {
    final resp = await _dio.get(
      '/api/links',
      queryParameters: {if (withExpired) 'with_expired': true, 'compact': true},
    );
    return resp.data is List ? resp.data : const [];
  }

  /// `GET /api/links/{linkId}/metadata` — full metadata for one link,
  /// including the encrypted thumbnail a `compact` listing withholds.
  Future<Map<String, dynamic>> metadata(String linkId) async {
    final resp = await _dio.get('/api/links/$linkId/metadata');
    return resp.data as Map<String, dynamic>;
  }

  /// `POST /api/links` — create a shared link.
  ///
  /// The body is assembled client-side because link creation requires
  /// local RSA + AES operations (file key, link key, signature). See
  /// `files_screen.dart::_createLink` for the full assembly.
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final resp = await _dio.post('/api/links', data: data);
    return resp.data as Map<String, dynamic>;
  }

  /// `DELETE /api/links/{linkId}` — permanently remove a link.
  Future<void> delete(String linkId) async {
    await _dio.delete('/api/links/$linkId');
  }

  /// `PUT /api/links/{linkId}` — update a link's expiry.
  ///
  /// [expiresAt] is a Unix timestamp in seconds, or `null` to clear the
  /// expiry (the link becomes permanent).
  Future<Map<String, dynamic>> updateExpiry({
    required String linkId,
    int? expiresAt,
  }) async {
    final resp = await _dio.put(
      '/api/links/$linkId',
      data: {'expires_at': expiresAt},
    );
    return resp.data as Map<String, dynamic>;
  }
}
