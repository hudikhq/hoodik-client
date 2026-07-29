import 'package:dio/dio.dart';

import 'api_models.dart';
import 'server_settings.dart';

/// HTTP client scoped to the admin API: user management, invitations,
/// session administration, and server-wide settings. Every route requires
/// an admin-role session; non-admin callers get 403 from the server.
///
/// Shares the [Dio] instance owned by [ApiClient].
class AdminClient {
  final Dio _dio;

  AdminClient(this._dio);

  /// `GET /api/admin/users` — paginated user list.
  Future<Paginated<AdminUser>> listUsers({
    String? search,
    int limit = 15,
    int offset = 0,
  }) async {
    final resp = await _dio.get(
      '/api/admin/users',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'sort': 'created_at',
        'order': 'desc',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final items =
        (data['data'] as List?)
            ?.map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Paginated(data: items, total: data['total'] as int? ?? 0);
  }

  /// `GET /api/admin/users/{id}` — single user with storage stats.
  Future<AdminUserDetail> getUser(String userId) async {
    final resp = await _dio.get('/api/admin/users/$userId');
    return AdminUserDetail.fromJson(resp.data);
  }

  /// `PUT /api/admin/users/{id}` — update role and/or quota.
  Future<AdminUserDetail> updateUser(
    String userId, {
    String? role,
    int? quota,
  }) async {
    final resp = await _dio.put(
      '/api/admin/users/$userId',
      data: {'role': ?role, 'quota': ?quota},
    );
    return AdminUserDetail.fromJson(resp.data);
  }

  /// `DELETE /api/admin/users/{id}` — delete a user and every file they
  /// own. Irreversible.
  Future<void> deleteUser(String userId) async {
    await _dio.delete('/api/admin/users/$userId');
  }

  /// `POST /api/admin/users/{id}/remove-tfa` — clear a user's 2FA secret,
  /// forcing them to re-enrol on next login.
  Future<void> disableTfa(String userId) async {
    await _dio.post('/api/admin/users/$userId/remove-tfa');
  }

  /// `GET /api/admin/invitations` — paginated invitation list.
  Future<Paginated<Invitation>> listInvitations({
    bool withExpired = false,
    String? search,
    int limit = 15,
    int offset = 0,
  }) async {
    final resp = await _dio.get(
      '/api/admin/invitations',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'sort': 'created_at',
        'order': 'desc',
        if (withExpired) 'with_expired': true,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final items =
        (data['data'] as List?)
            ?.map((e) => Invitation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Paginated(data: items, total: data['total'] as int? ?? 0);
  }

  /// `POST /api/admin/invitations` — create and email an invitation.
  Future<Invitation> createInvitation({
    required String email,
    String? role,
    int? quota,
  }) async {
    final resp = await _dio.post(
      '/api/admin/invitations',
      data: {'email': email, 'role': ?role, 'quota': ?quota},
    );
    return Invitation.fromJson(resp.data);
  }

  /// `DELETE /api/admin/invitations/{id}` — mark an invitation as
  /// expired so it can no longer be redeemed.
  Future<void> expireInvitation(String invitationId) async {
    await _dio.delete('/api/admin/invitations/$invitationId');
  }

  /// `GET /api/admin/sessions` — paginated active-session list.
  Future<Paginated<AdminSession>> listSessions({
    String? userId,
    bool withExpired = false,
    int limit = 15,
    int offset = 0,
  }) async {
    final resp = await _dio.get(
      '/api/admin/sessions',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'sort': 'updated_at',
        'order': 'desc',
        if (withExpired) 'with_expired': true,
        'user_id': ?userId,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final items =
        (data['data'] as List?)
            ?.map((e) => AdminSession.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Paginated(data: items, total: data['total'] as int? ?? 0);
  }

  /// `DELETE /api/admin/sessions/{id}` — terminate one session.
  Future<void> killSession(String sessionId) async {
    await _dio.delete('/api/admin/sessions/$sessionId');
  }

  /// `DELETE /api/admin/sessions/{user_id}/kill-for-user` — terminate
  /// every session owned by [userId].
  Future<void> killUserSessions(String userId) async {
    await _dio.delete('/api/admin/sessions/$userId/kill-for-user');
  }

  /// `GET /api/admin/settings` — fetch server-wide configuration.
  Future<ServerSettings> getSettings() async {
    final resp = await _dio.get('/api/admin/settings');
    return ServerSettings.fromJson(resp.data);
  }

  /// `PUT /api/admin/settings` — persist updated configuration.
  Future<ServerSettings> updateSettings(ServerSettings settings) async {
    final resp = await _dio.put('/api/admin/settings', data: settings.toJson());
    return ServerSettings.fromJson(resp.data);
  }

  /// `POST /api/admin/settings/test-email` — dispatch a test email via
  /// the configured SMTP settings and return the human-readable status
  /// message.
  Future<String> testEmail() async {
    final resp = await _dio.post('/api/admin/settings/test-email');
    return (resp.data as Map<String, dynamic>)['message'] as String? ??
        'Test email sent';
  }
}
