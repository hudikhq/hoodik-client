import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import 'api_models.dart';
import 'chunk_urls_models.dart';

/// Minimum surface the [FilesClient] needs from the owning [ApiClient] to
/// authenticate raw-bytes requests. Binary chunk uploads bypass the shared
/// Dio interceptors (stream bodies + a non-JSON content type), so the
/// request has to build its own auth headers — either a `Cookie` header
/// from the cookie jar or an `Authorization: Bearer` pair.
abstract class FilesClientAuth {
  bool get useHeaderAuth;
  String? get jwtToken;
  String? get refreshTokenHeader;
  CookieJar get cookieJar;

  /// Lets the dedicated upload Dio feed captured `x-auth-jwt` and
  /// `x-auth-refresh` response headers back into the owning client.
  void captureAuthHeaders(Headers headers);
}

/// HTTP client scoped to file and folder routes under `/api/storage/*` —
/// CRUD, chunk upload/download, and metadata lookups. Shares the [Dio]
/// instance owned by [ApiClient] for everything except raw-bytes uploads.
class FilesClient {
  final Dio _dio;
  final String _baseUrl;
  final FilesClientAuth _auth;

  FilesClient(
    this._dio, {
    required String baseUrl,
    required FilesClientAuth auth,
  }) : _baseUrl = baseUrl,
       _auth = auth;

  /// `GET /api/storage` — list files in a directory.
  ///
  /// When [editable] is true the server returns editable files from *all*
  /// folders (not just [dirId]) — used by the Notes tab to flat-list every
  /// note across the account.
  ///
  /// [orderBy] accepts `modified_at` or `size`; [order] accepts `asc` or
  /// `desc`. When omitted the server uses its default ordering.
  Future<StorageResponse> listFiles({
    String? dirId,
    bool? editable,
    String? orderBy,
    String? order,
  }) async {
    final params = <String, dynamic>{'compact': true};
    if (dirId != null) params['dir_id'] = dirId;
    if (editable != null) params['editable'] = editable;
    if (orderBy != null) params['order_by'] = orderBy;
    if (order != null) params['order'] = order;

    final resp = await _dio.get('/api/storage', queryParameters: params);
    return StorageResponse.fromJson(resp.data);
  }

  /// `GET /api/storage/{fileId}/chunk-urls` — presigned URLs letting this
  /// device read the file's chunks straight from the storage bucket.
  ///
  /// Returns null whenever the server cannot serve them: local-disk
  /// deployments have no URLs to give, and an S3 deployment whose bucket
  /// failed its startup checks withholds them deliberately (400). Callers
  /// fall back to downloading through the server.
  Future<ChunkUrlsResponse?> fetchChunkUrls(String fileId) async {
    try {
      final resp = await _dio.get('/api/storage/$fileId/chunk-urls');
      final data = resp.data;
      if (data is! Map<String, dynamic>) return null;
      return ChunkUrlsResponse.fromJson(data);
    } on DioException {
      return null;
    }
  }

  /// `GET /api/storage/{fileId}/thumbnail` — the encrypted thumbnail of a
  /// single file. Listings ask for `compact` rows without the blob; this
  /// route serves it on demand. Returns null when the file has no
  /// thumbnail or the server predates the route (404).
  Future<String?> fetchThumbnail(String fileId) async {
    try {
      final resp = await _dio.get('/api/storage/$fileId/thumbnail');
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        return data['encrypted_thumbnail'] as String?;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `POST /api/storage` with `mime=dir` — create a directory entry.
  Future<Map<String, dynamic>> createDirectory({
    required String encryptedKey,
    required String nameHash,
    required String encryptedName,
    String? parentDirId,
    String? cipher,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
  }) async {
    final data = <String, dynamic>{
      'encrypted_key': encryptedKey,
      'name_hash': nameHash,
      'encrypted_name': encryptedName,
      'mime': 'dir',
    };
    if (parentDirId != null) data['file_id'] = parentDirId;
    if (cipher != null) data['cipher'] = cipher;
    if (searchTokensRoot != null) {
      data['search_tokens_root'] = searchTokensRoot;
    }
    if (searchTokensFile != null) {
      data['search_tokens_file'] = searchTokensFile;
    }

    final resp = await _dio.post('/api/storage', data: data);
    return resp.data;
  }

  /// `POST /api/storage` — create a file metadata entry before uploading
  /// chunks.
  Future<Map<String, dynamic>> createFileEntry({
    required String encryptedKey,
    required String nameHash,
    required String encryptedName,
    required String mime,
    required int size,
    required int chunks,
    String? parentDirId,
    String? cipher,
    String? encryptedThumbnail,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
    String? fileModifiedAt,
    String? sha256,
    bool? editable,
  }) async {
    final data = <String, dynamic>{
      'encrypted_key': encryptedKey,
      'name_hash': nameHash,
      'encrypted_name': encryptedName,
      'mime': mime,
      'size': size,
      'chunks': chunks,
    };
    if (parentDirId != null) data['file_id'] = parentDirId;
    if (cipher != null) data['cipher'] = cipher;
    if (editable != null) data['editable'] = editable;
    if (encryptedThumbnail != null) {
      data['encrypted_thumbnail'] = encryptedThumbnail;
    }
    if (searchTokensRoot != null) {
      data['search_tokens_root'] = searchTokensRoot;
    }
    if (searchTokensFile != null) {
      data['search_tokens_file'] = searchTokensFile;
    }
    if (fileModifiedAt != null) data['file_modified_at'] = fileModifiedAt;
    if (sha256 != null) data['sha256'] = sha256;

    final resp = await _dio.post('/api/storage', data: data);
    return resp.data;
  }

  /// `PUT /api/storage/{fileId}` — rename a file or directory.
  Future<Map<String, dynamic>> renameFile({
    required String fileId,
    required String nameHash,
    required String encryptedName,
    List<String>? searchTokensRoot,
    List<String>? searchTokensFile,
  }) async {
    final data = <String, dynamic>{
      'name_hash': nameHash,
      'encrypted_name': encryptedName,
    };
    if (searchTokensRoot != null) {
      data['search_tokens_root'] = searchTokensRoot;
    }
    if (searchTokensFile != null) {
      data['search_tokens_file'] = searchTokensFile;
    }

    final resp = await _dio.put('/api/storage/$fileId', data: data);
    return resp.data;
  }

  /// `POST /api/storage/move-many` — reparent files or directories.
  Future<void> moveMany({
    required List<String> ids,
    String? targetDirId,
  }) async {
    await _dio.post(
      '/api/storage/move-many',
      data: {'ids': ids, 'file_id': targetDirId},
    );
  }

  /// `DELETE /api/storage/{fileId}` — delete a single file or directory.
  Future<void> deleteFile(String fileId) async {
    await _dio.delete('/api/storage/$fileId');
  }

  /// `POST /api/storage/delete-many` — bulk delete.
  Future<void> deleteMany(List<String> fileIds) async {
    await _dio.post('/api/storage/delete-many', data: {'ids': fileIds});
  }

  /// `GET /api/storage/{fileId}/metadata`
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    final resp = await _dio.get('/api/storage/$fileId/metadata');
    return resp.data;
  }

  /// `GET /api/storage/{fileId}?chunk=N` — download a single encrypted
  /// chunk. Returns raw bytes; caller decrypts.
  Future<Uint8List> downloadChunk({
    required String fileId,
    required int chunk,
  }) async {
    final resp = await _dio.get(
      '/api/storage/$fileId',
      queryParameters: {'chunk': chunk},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data as List<int>);
  }

  /// `POST /api/storage/{fileId}?chunk=N&checksum=X&...` — upload a single
  /// encrypted chunk. Uses a dedicated [Dio] to avoid the shared JSON
  /// content-type and cookie-interceptor issues with stream bodies.
  Future<Map<String, dynamic>> uploadChunk({
    required String fileId,
    required int chunk,
    required Uint8List data,
    String? checksum,
    String? checksumFunction,
  }) async {
    final params = <String, dynamic>{'chunk': chunk};
    if (checksum != null) params['checksum'] = checksum;
    if (checksumFunction != null) {
      params['checksum_function'] = checksumFunction;
    }

    final uri = Uri.parse('$_baseUrl/api/storage/$fileId');

    final Map<String, dynamic> authHeaders = {'Content-Length': data.length};
    final useHeader = _auth.useHeaderAuth;
    final jwt = _auth.jwtToken;
    final refresh = _auth.refreshTokenHeader;
    if (useHeader && jwt != null) {
      authHeaders['Authorization'] = 'Bearer $jwt';
      if (refresh != null) {
        authHeaders['x-auth-refresh'] = refresh;
      }
    } else {
      final cookies = await _auth.cookieJar.loadForRequest(uri);
      authHeaders['Cookie'] = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
    }

    final uploadDio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    try {
      final resp = await uploadDio.post(
        '/api/storage/$fileId',
        data: data,
        queryParameters: params,
        options: Options(
          contentType: 'application/octet-stream',
          headers: authHeaders,
          responseType: ResponseType.json,
        ),
      );

      _auth.captureAuthHeaders(resp.headers);

      if (!useHeader) {
        final setCookies = resp.headers['set-cookie'];
        if (setCookies != null) {
          await _auth.cookieJar.saveFromResponse(
            uri,
            setCookies.map((s) => Cookie.fromSetCookieValue(s)).toList(),
          );
        }
      }

      return resp.data is Map<String, dynamic>
          ? resp.data
          : <String, dynamic>{};
    } finally {
      uploadDio.close();
    }
  }

  /// `PUT /api/storage/{fileId}/hashes` — session-auth variant used after
  /// an interactive upload finishes.
  Future<void> updateFileHashes({
    required String fileId,
    required String sha256,
    String? md5,
    String? sha1,
    String? blake2b,
  }) async {
    final data = <String, dynamic>{'sha256': sha256};
    if (md5 != null) data['md5'] = md5;
    if (sha1 != null) data['sha1'] = sha1;
    if (blake2b != null) data['blake2b'] = blake2b;
    await _dio.put('/api/storage/$fileId/hashes', data: data);
  }

  /// `PUT /api/storage/{fileId}/hashes` with a transfer-token bearer
  /// instead of session cookies. Used by the upload worker pipeline
  /// because transfer tokens survive session refreshes.
  Future<void> updateFileHashesWithToken({
    required String fileId,
    required String transferToken,
    required String sha256,
    String? md5,
    String? sha1,
    String? blake2b,
  }) async {
    final data = <String, dynamic>{'sha256': sha256};
    if (md5 != null) data['md5'] = md5;
    if (sha1 != null) data['sha1'] = sha1;
    if (blake2b != null) data['blake2b'] = blake2b;

    final tokenDio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $transferToken',
        },
      ),
    );

    try {
      await tokenDio.put('/api/storage/$fileId/hashes', data: data);
    } finally {
      tokenDio.close();
    }
  }

  /// `GET /api/storage/{nameHash}/name-hash` — look up a file by its
  /// server-side name hash. Returns the JSON entry or `null` on 404.
  Future<Map<String, dynamic>?> checkNameHash(
    String nameHash, {
    String? parentId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (parentId != null) params['parent_id'] = parentId;
      final resp = await _dio.get(
        '/api/storage/$nameHash/name-hash',
        queryParameters: params,
      );
      return resp.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
