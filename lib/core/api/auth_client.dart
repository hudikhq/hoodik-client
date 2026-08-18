import 'dart:io';

import 'package:dio/dio.dart';

import '../services/server_version.dart';
import 'api_models.dart';
import 'transfer_token.dart';

/// One page of the key sets a migrating account must re-wrap: `keys` are
/// file-key wraps ({file_id, encrypted_key}); `linkKeys` are public-link-key
/// wraps ({link_id, encrypted_link_key, file_id}, the file_id being the
/// canonical the owner re-signs). `nextOffset` is the cursor for the next page,
/// or null once the whole set has been returned.
typedef MigrationKeysResponse = ({
  List<Map<String, dynamic>> keys,
  List<Map<String, dynamic>> linkKeys,
  int? nextOffset,
});

/// HTTP client scoped to the `/api/auth/*` routes and the server liveness
/// probe. Shares the [Dio] instance owned by [ApiClient] so auth
/// interceptors, cookie jar, and refresh handling are identical across
/// every sub-client.
class AuthClient {
  final Dio _dio;

  AuthClient(this._dio);

  /// `GET /api/liveness` — best-effort reachability check. The returned
  /// [LivenessInfo.version] is populated for servers that ship the field
  /// (v1.16.0+) and `null` otherwise; the app uses that signal to warn
  /// self-hosters their server is predating features the app now relies on.
  Future<LivenessInfo> checkLiveness() async {
    try {
      final resp = await _dio.get('/api/liveness');
      if (resp.statusCode != 200) {
        return const LivenessInfo.offline();
      }
      return _readLiveness(resp.data);
    } catch (_) {
      return const LivenessInfo.offline();
    }
  }

  /// `GET /api/liveness` — throws a descriptive error on failure, returns
  /// the probe result on success. Used by the add-server flow where the
  /// user needs actionable diagnostics (TLS rejection, timeout, connection
  /// failure) and where the captured version feeds the outdated-server
  /// warning later in the login flow.
  Future<LivenessInfo> checkLivenessOrThrow() async {
    try {
      final resp = await _dio.get('/api/liveness');
      if (resp.statusCode != 200) {
        throw Exception('Server returned HTTP ${resp.statusCode}');
      }
      return _readLiveness(resp.data);
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is HandshakeException) {
        throw Exception(
          'TLS certificate rejected. '
          'Enable "Trust self-signed certificate" if this is expected.',
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Connection failed: ${inner ?? e.message}');
      }
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timed out — server may be unreachable');
      }
      throw Exception(e.message ?? 'Connection failed');
    }
  }

  /// Tolerate any payload shape — servers predating v1.16.0 return the
  /// `version` key unset (or a non-string), and we don't want a malformed
  /// field to prevent an otherwise-successful probe from reporting alive.
  static String? _readVersion(dynamic body) => _readString(body, 'version');

  static String? _readString(dynamic body, String key) {
    if (body is Map<String, dynamic>) {
      final raw = body[key];
      if (raw is String && raw.isNotEmpty) return raw;
    }
    return null;
  }

  /// Both compatibility fields arrived in 2.5.0, so their absence is itself
  /// evidence the server predates it.
  static LivenessInfo _readLiveness(dynamic body) => LivenessInfo(
        alive: true,
        version: _readVersion(body),
        minimumClientVersion: _readString(body, 'minimum_client_version'),
        recommendedClientVersion:
            _readString(body, 'recommended_client_version'),
      );

  /// `POST /api/auth/login` — email + password + optional 2FA token.
  /// The server sets session cookies automatically via the cookie jar.
  Future<AuthResponse> login({
    required String email,
    required String password,
    String? token,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (token != null && token.isNotEmpty) {
      body['token'] = token;
    }

    final resp = await _dio.post('/api/auth/login', data: body);
    return AuthResponse.fromResponse(resp);
  }

  /// `POST /api/auth/signature` — private-key auth. The signature covers the
  /// canonical `{fingerprint}:{timestamp}:{nonce}`; the server reconstructs it
  /// from these fields and refuses a reused `(fingerprint, nonce)` pair, so
  /// each login must send a freshly generated nonce.
  Future<AuthResponse> signatureLogin({
    required String fingerprint,
    required String signature,
    required int timestamp,
    required String nonce,
  }) async {
    final resp = await _dio.post(
      '/api/auth/signature',
      data: {
        'fingerprint': fingerprint,
        'signature': signature,
        'timestamp': timestamp,
        'nonce': nonce,
      },
    );
    return AuthResponse.fromResponse(resp);
  }

  /// `POST /api/auth/self` — return the currently authenticated user.
  Future<AuthResponse> getSelf() async {
    final resp = await _dio.post('/api/auth/self');
    return AuthResponse.fromResponse(resp);
  }

  /// `POST /api/auth/refresh` — extend the current session.
  Future<AuthResponse> refresh() async {
    final resp = await _dio.post('/api/auth/refresh');
    return AuthResponse.fromResponse(resp);
  }

  /// `POST /api/auth/logout` — best-effort server-side session teardown.
  /// Callers are still responsible for clearing local cookies / tokens.
  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (_) {
      // Best effort — the server may already have expired the session.
    }
  }

  /// `POST /api/auth/transfer-token` — request a long-lived JWT scoped to
  /// a single file and action (`upload` or `download`). Valid for up to
  /// 30 days, so background transfers can outlive the session.
  Future<TransferToken> requestTransferToken({
    required String fileId,
    required String action,
  }) async {
    final resp = await _dio.post(
      '/api/auth/transfer-token',
      data: {'file_id': fileId, 'action': action},
    );
    return TransferToken.fromJson(resp.data);
  }

  /// `POST /api/auth/login/start` — credential-request + email.
  /// Returns either {method: 'password'} or {method: 'opaque', login_id, credential_response},
  /// or null when the server has no /login/start route (predates OPAQUE).
  Future<Map<String, dynamic>?> loginStart({
    required String email,
    required String credentialRequest,
  }) async {
    try {
      final resp = await _dio.post(
        '/api/auth/login/start',
        data: {'email': email, 'credential_request': credentialRequest},
      );
      return (resp.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      // Servers predating the OPAQUE endpoints have no /login/start route;
      // returning null signals the caller to use the legacy password login.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `POST /api/auth/login/finish` — complete OPAQUE login.
  Future<AuthResponse> loginFinishOpaque({
    required String loginId,
    required String credentialFinalization,
    String? token,
  }) async {
    final resp = await _dio.post(
      '/api/auth/login/finish',
      data: {
        'login_id': loginId,
        'credential_finalization': credentialFinalization,
        'token': ?token,
      },
    );
    return AuthResponse.fromResponse(resp);
  }

  /// `POST /api/auth/pake/register/start` (during authenticated migration or pw change).
  Future<Map<String, dynamic>> pakeRegisterStart({
    required String registrationRequest,
  }) async {
    final resp = await _dio.post(
      '/api/auth/pake/register/start',
      data: {'registration_request': registrationRequest},
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// `POST /api/auth/register/pake/start` — unauthenticated OPAQUE start for a
  /// brand-new signup. The email keys the credential the account is created
  /// with, so it must match the one passed to [register]. Returns the server's
  /// `registration_response`.
  Future<String> signupRegisterStart({
    required String email,
    required String registrationRequest,
  }) async {
    final resp = await _dio.post(
      '/api/auth/register/pake/start',
      data: {'email': email, 'registration_request': registrationRequest},
    );
    final body = (resp.data as Map).cast<String, dynamic>();
    return body['registration_response'] as String;
  }

  /// `POST /api/auth/register` — create a Curve25519 + OPAQUE account. The
  /// response carries a session (201) unless the server enforces email
  /// activation, in which case it answers 204 with no body and no session.
  Future<AuthResponse?> register({
    required String email,
    required String pubkey,
    required String wrappingPubkey,
    required String fingerprint,
    required String encryptedPrivateKey,
    required String opaqueRegistrationUpload,
    String? secret,
    String? token,
    String? invitationId,
    String? locale,
  }) async {
    final resp = await _dio.post(
      '/api/auth/register',
      data: {
        'email': email,
        'pubkey': pubkey,
        'wrapping_pubkey': wrappingPubkey,
        'fingerprint': fingerprint,
        'key_type': 'curve25519',
        'encrypted_private_key': encryptedPrivateKey,
        'opaque_registration_upload': opaqueRegistrationUpload,
        'secret': ?secret,
        'token': ?token,
        'invitation_id': ?invitationId,
        'locale': ?locale,
      },
    );
    if (resp.statusCode == 204) return null;
    return AuthResponse.fromResponse(resp);
  }

  /// `GET /api/auth/migration/keys?offset=&limit=` — one page of the file keys
  /// ({file_id, encrypted_key}) and public-link keys
  /// ({link_id, encrypted_link_key, file_id}) the caller holds, each wrapped
  /// under the legacy RSA key. A migrating client walks every page, re-wraps
  /// both sets to the hybrid wrapping key, and re-signs each link over its file_id; missing the
  /// link keys permanently locks the owner out of links they created before
  /// migrating.
  Future<MigrationKeysResponse> migrationKeys({
    int offset = 0,
    int limit = 500,
  }) async {
    final resp = await _dio.get(
      '/api/auth/migration/keys',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    final data = resp.data;
    // ponytail: an earlier iteration answered with a bare file-key array;
    // tolerate it (no link keys, no cursor) so a mid-deploy server can't crash
    // the client.
    if (data is List) {
      return (
        keys: _mapList(data),
        linkKeys: const <Map<String, dynamic>>[],
        nextOffset: null,
      );
    }
    final map = (data as Map).cast<String, dynamic>();
    return (
      keys: _mapList(map['keys']),
      linkKeys: _mapList(map['link_keys']),
      nextOffset: (map['next_offset'] as num?)?.toInt(),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    final list = (raw as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// `POST /api/auth/migration/rewrap` — stage one batch of re-wrapped file and
  /// link keys ahead of `migrationComplete`. The client sends the whole re-wrap
  /// across several of these so no single body carries every key.
  Future<void> migrationRewrap({
    required List<Map<String, dynamic>> keys,
    required List<Map<String, dynamic>> linkKeys,
  }) async {
    await _dio.post(
      '/api/auth/migration/rewrap',
      data: {'keys': keys, 'link_keys': linkKeys},
    );
  }

  /// `POST /api/auth/migration/complete` — one-shot legacy -> curve + OPAQUE.
  /// The re-wrapped keys were staged through [migrationRewrap]; the server
  /// applies them from staging inside this call's transaction.
  Future<Map<String, dynamic>> migrationComplete({
    required String newIdentityPubkey,
    required String newWrappingPubkey,
    required String newFingerprint,
    required String transitionOldSignature,
    required String transitionNewSignature,
    required int transitionIssuedAt,
    required String opaqueRegistrationUpload,
    required String encryptedPrivateKey,
    required String auditEventSignature,
  }) async {
    final resp = await _dio.post(
      '/api/auth/migration/complete',
      data: {
        'new_identity_pubkey': newIdentityPubkey,
        'new_wrapping_pubkey': newWrappingPubkey,
        'new_fingerprint': newFingerprint,
        'transition_old_signature': transitionOldSignature,
        'transition_new_signature': transitionNewSignature,
        'transition_issued_at': transitionIssuedAt,
        'opaque_registration_upload': opaqueRegistrationUpload,
        'encrypted_private_key': encryptedPrivateKey,
        'audit_event_signature': auditEventSignature,
      },
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// `GET /api/auth/key-transitions?user_id=...` — the transition chain for
  /// a user (or self) so clients can verify historical fingerprints.
  Future<List<Map<String, dynamic>>> keyTransitions({String? userId}) async {
    final query = userId != null ? {'user_id': userId} : <String, dynamic>{};
    final resp = await _dio.get(
      '/api/auth/key-transitions',
      queryParameters: query,
    );
    final list = (resp.data as List?) ?? [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
