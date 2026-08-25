import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../services/client_identity.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'admin_client.dart';
import 'api_models.dart';
import 'auth_client.dart';
import 'files_client.dart';
import 'links_client.dart';
import 'search_client.dart';
import 'share_events_client.dart';
import 'share_groups_client.dart';
import 'shares_client.dart';
import 'storage_client.dart';
import 'versions_client.dart';

export 'admin_client.dart';
export 'api_models.dart';
export 'auth_client.dart';
export 'files_client.dart';
export 'links_client.dart';
export 'search_client.dart';
export 'share_group_add_member_models.dart';
export 'share_group_models.dart';
export 'share_groups_client.dart';
export 'share_to_group_models.dart';
export 'shares_client.dart';
export 'server_settings.dart';
export 'storage_client.dart';
export 'versions_client.dart';
export 'transfer_token.dart';

const _log = Logger('ApiClient');
const _apiLog = Logger('API');

/// HTTP client for talking to a Hoodik server.
///
/// Owns the shared [Dio], cookie jar, session-refresh timer, and auth
/// interceptors — and exposes per-resource sub-clients (see [auth],
/// [files], [storage], [search], [versions], [links], [shares], [shareGroups],
/// [admin]) for every endpoint group. The sub-clients all operate on the same
/// [Dio], so a session refresh anywhere propagates everywhere.
class ApiClient implements FilesClientAuth {
  final Dio _dio;
  final String baseUrl;
  final CookieJar _cookieJar;

  /// Raw authenticated Dio instance — exposed for integration tests that
  /// need to probe routes the sub-clients don't cover (e.g. the compat
  /// gate verifying an old server's reject-shape for `?format=tar`).
  /// Not for production code paths — use the typed sub-clients instead.
  @visibleForTesting
  Dio get dio => _dio;

  /// The on-disk cookie directory for this client (null for in-memory jars).
  /// Workers need this to share cookies across isolates.
  final String? cookieDir;

  Timer? _refreshTimer;
  int? _expiresAt; // Unix timestamp (seconds) from session
  bool _refreshing = false;

  /// Whether this client operates in header auth mode (JWT in
  /// `Authorization` header) instead of cookie mode.
  @override
  bool useHeaderAuth = false;

  String? _jwtToken;
  String? _refreshTokenHeader;

  @override
  String? get jwtToken => _jwtToken;

  @override
  String? get refreshTokenHeader => _refreshTokenHeader;

  @override
  CookieJar get cookieJar => _cookieJar;

  /// Called when the session refresh fails — the UI layer should clear
  /// auth state and redirect to login.
  void Function()? onSessionExpired;

  /// Called when header-auth tokens are updated (login, refresh) so the
  /// caller can persist them for session restore across app restarts.
  void Function(String jwt, String refresh)? onTokensUpdated;

  late final AuthClient auth = AuthClient(_dio);
  late final FilesClient files = FilesClient(
    _dio,
    baseUrl: baseUrl,
    auth: this,
  );
  late final StorageClient storage = StorageClient(_dio);
  late final SearchClient search = SearchClient(_dio);
  late final VersionsClient versions = VersionsClient(_dio);
  late final LinksClient links = LinksClient(_dio);
  late final SharesClient shares = SharesClient(_dio);
  late final ShareEventsClient shareEvents = ShareEventsClient(_dio);
  late final SharesGroupsClient shareGroups = SharesGroupsClient(_dio);
  late final AdminClient admin = AdminClient(_dio);

  ApiClient._({
    required this.baseUrl,
    required CookieJar cookieJar,
    this.cookieDir,
  }) : _cookieJar = cookieJar,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 60),
           headers: {
             'Content-Type': 'application/json',
             clientIdentityHeader: clientIdentity,
           },
         ),
       ) {
    // Header-auth interceptor: inject Authorization + x-auth-refresh on
    // every request when operating in header mode. Must run BEFORE
    // CookieManager so the headers are present for the request.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (useHeaderAuth && _jwtToken != null) {
            options.headers['Authorization'] = 'Bearer $_jwtToken';
          }
          if (useHeaderAuth && _refreshTokenHeader != null) {
            options.headers['x-auth-refresh'] = _refreshTokenHeader;
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          captureAuthHeaders(response.headers);
          return handler.next(response);
        },
      ),
    );

    _dio.interceptors.add(CookieManager(_cookieJar));

    // Auto-refresh interceptor: on 401, try to refresh the session and retry.
    // NOTE: This does NOT retry if the original request used a stream body
    // (streams can only be consumed once). For those, use ensureFreshSession()
    // before the call instead.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            if (path == '/api/auth/login' ||
                path == '/api/auth/refresh' ||
                path == '/api/auth/register' ||
                path == '/api/auth/signature') {
              return handler.next(error);
            }

            try {
              final refreshResp = await _dio.post('/api/auth/refresh');
              final authResp = AuthResponse.fromResponse(refreshResp);
              updateSessionExpiry(authResp);

              final opts = error.requestOptions;
              if (opts.data is Stream) {
                return handler.next(error);
              }

              final response = await _dio.request(
                opts.path,
                data: opts.data,
                queryParameters: opts.queryParameters,
                options: Options(
                  method: opts.method,
                  headers: opts.headers,
                  responseType: opts.responseType,
                  contentType: opts.contentType,
                  extra: opts.extra,
                ),
              );
              return handler.resolve(response);
            } catch (retryError) {
              _log.warn(
                '401 retry failed',
                fields: {'error': describeError(retryError)},
              );
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _apiLog.debug(
            'request',
            fields: {'method': options.method, 'uri': redactUri(options.uri)},
          );
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _apiLog.debug(
            'response',
            fields: {
              'status': response.statusCode,
              'uri': redactUri(response.requestOptions.uri),
            },
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          // The response body is NEVER logged — it commonly contains server
          // metadata (emails, quotas, error messages with user content) that
          // would ride straight into an exported bug report.
          _apiLog.warn(
            'request error',
            fields: {
              'status': error.response?.statusCode,
              'uri': redactUri(error.requestOptions.uri),
              'error': describeError(error),
            },
          );
          return handler.next(error);
        },
      ),
    );
  }

  /// Create a client with a persistent cookie jar stored on disk.
  /// Each account gets its own cookie storage directory.
  static Future<ApiClient> create({
    required String baseUrl,
    String? accountId,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final cookieDir = p.join(dir.path, 'cookies', accountId ?? '_default');
    await Directory(cookieDir).create(recursive: true);
    final jar = PersistCookieJar(storage: FileStorage(cookieDir));
    return ApiClient._(baseUrl: baseUrl, cookieJar: jar, cookieDir: cookieDir);
  }

  /// Create a client with an in-memory cookie jar (for server validation etc.).
  static ApiClient createTemporary({required String baseUrl}) {
    return ApiClient._(baseUrl: baseUrl, cookieJar: CookieJar());
  }

  /// Load persisted tokens (from database) into the client for session
  /// restore on header-auth servers.
  void setTokens({required String jwt, required String refresh}) {
    _jwtToken = jwt;
    _refreshTokenHeader = refresh;
  }

  /// Extract and store auth tokens from response headers.
  /// Mirrors the web frontend's pattern of checking every response for
  /// `x-auth-jwt` and `x-auth-refresh` headers.
  @override
  void captureAuthHeaders(Headers headers) {
    final jwt = headers.value('x-auth-jwt');
    if (jwt != null && jwt.isNotEmpty) {
      _jwtToken = jwt;
      useHeaderAuth = true;
    }
    final refresh = headers.value('x-auth-refresh');
    if (refresh != null && refresh.isNotEmpty) {
      _refreshTokenHeader = refresh;
    }
    if (_jwtToken != null && _refreshTokenHeader != null) {
      onTokensUpdated?.call(_jwtToken!, _refreshTokenHeader!);
    }
  }

  /// Update the cached session expiry from an auth response.
  void updateSessionExpiry(AuthResponse authResp) {
    final exp = authResp.expiresAt;
    if (exp != null && exp > 0) {
      _expiresAt = exp;
    }
  }

  /// Proactively refresh the session. Call before long-running operations
  /// (upload / download) so individual chunk requests don't hit 401.
  Future<void> ensureFreshSession() async {
    try {
      final resp = await _dio.post('/api/auth/refresh');
      final authResp = AuthResponse.fromResponse(resp);
      updateSessionExpiry(authResp);
    } catch (e) {
      _log.warn(
        'proactive session refresh failed',
        fields: {'error': describeError(e)},
      );
    }
  }

  /// Read the current session cookie from the jar, formatted as a `Cookie`
  /// header value. Used by [WorkerManager] to send fresh cookies to worker
  /// isolates after a session refresh.
  Future<String> getCookieHeader() async {
    if (useHeaderAuth) return '';
    final uri = Uri.parse('$baseUrl/api/storage');
    final cookies = await _cookieJar.loadForRequest(uri);
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  /// Start a 1-second check timer that refreshes when < 60s remain.
  /// Matches the web frontend's `setInterval(() => setupRefresh(crypto), 1000)`.
  void startSessionRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAndRefresh(),
    );
  }

  /// Stop the periodic session refresh timer.
  void stopSessionRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _refreshing = false;
  }

  Future<void> _checkAndRefresh() async {
    if (_expiresAt == null) return;

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final untilExpire = _expiresAt! - nowSeconds;

    if (untilExpire > 60) return;
    if (_refreshing) return;

    try {
      _refreshing = true;
      _log.info(
        'refreshing session',
        fields: {'until_expire_seconds': untilExpire},
      );
      final resp = await _dio.post('/api/auth/refresh');
      final authResp = AuthResponse.fromResponse(resp);
      updateSessionExpiry(authResp);
      _refreshing = false;
      _log.info('session refreshed');
    } catch (e) {
      _refreshing = false;
      _log.warn('session refresh failed', fields: {'error': describeError(e)});
      onSessionExpired?.call();
    }
  }

  /// Whether this client has an active session (cookie or header token).
  Future<bool> get hasSession async {
    if (useHeaderAuth) {
      return _jwtToken != null && _jwtToken!.isNotEmpty;
    }
    final uri = Uri.parse(baseUrl);
    final cookies = await _cookieJar.loadForRequest(uri);
    return cookies.any((c) => c.name == 'hoodik_session');
  }

  /// Clear all cookies and header tokens (on logout).
  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
    _jwtToken = null;
    _refreshTokenHeader = null;
  }

  /// `POST /api/auth/logout` followed by a local cookie/token sweep.
  /// Kept on the coordinator so callers don't have to remember both
  /// `auth.logout()` and `clearCookies()` as a pair.
  Future<void> logout() async {
    await auth.logout();
    await clearCookies();
  }
}
