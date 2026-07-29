import 'package:dio/dio.dart';

export 'file_item.dart';

class SessionInfo {
  final String id;
  final String userId;
  final String ip;
  final String userAgent;
  final int createdAt;
  final int updatedAt;
  final int expiresAt; // Unix timestamp in seconds

  SessionInfo({
    required this.id,
    required this.userId,
    required this.ip,
    required this.userAgent,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      userAgent: json['user_agent'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
      expiresAt: json['expires_at'] as int? ?? 0,
    );
  }
}

class AuthResponse {
  final Map<String, dynamic> user;
  final SessionInfo? session;

  /// JWT from `x-auth-jwt` response header (null in cookie mode).
  final String? headerJwt;

  /// Refresh token from `x-auth-refresh` response header (null in cookie mode).
  final String? headerRefresh;

  AuthResponse({
    required this.user,
    this.session,
    this.headerJwt,
    this.headerRefresh,
  });

  factory AuthResponse.fromResponse(Response resp) {
    final data = resp.data;
    final headerJwt = resp.headers.value('x-auth-jwt');
    final headerRefresh = resp.headers.value('x-auth-refresh');

    if (data is Map<String, dynamic>) {
      final sessionData = data['session'] as Map<String, dynamic>?;
      return AuthResponse(
        user: data['user'] ?? data,
        session: sessionData != null ? SessionInfo.fromJson(sessionData) : null,
        headerJwt: headerJwt,
        headerRefresh: headerRefresh,
      );
    }
    return AuthResponse(
      user: {},
      headerJwt: headerJwt,
      headerRefresh: headerRefresh,
    );
  }

  /// Whether this response came from a server using header-based auth.
  bool get isHeaderAuth => headerJwt != null && headerJwt!.isNotEmpty;

  String? get email => user['email'] as String?;
  String? get id => user['id'] as String?;
  String? get pubkey => user['pubkey'] as String?;

  /// Hybrid wrapping public key (PEM) for curve accounts; null for legacy
  /// RSA accounts, which wrap file keys against [pubkey] instead.
  String? get wrappingPubkey => user['wrapping_pubkey'] as String?;
  String? get fingerprint => user['fingerprint'] as String?;
  String? get encryptedPrivateKey => user['encrypted_private_key'] as String?;
  int? get quota => user['quota'] as int?;
  String? get role => user['role'] as String?;
  bool get hasTfa => user['secret'] == true;
  int? get expiresAt => session?.expiresAt;

  // Crypto upgrade fields
  int get securityVersion => (user['security_version'] as num?)?.toInt() ?? 0;
  String get keyType => (user['key_type'] as String?) ?? 'rsa';
}

/// Historical snapshot of an editable file. Returned by
/// `GET /api/storage/{file_id}/versions`. The active version is NOT here —
/// it lives on the file row.
class FileVersion {
  final String id;
  final String fileId;
  final int version;

  /// Saver UUID, or null for anonymous link saves (A4).
  final String? userId;
  final bool isAnonymous;
  final int size;
  final int chunks;

  /// Per-version sha256 for exact restore. Null for early versions
  /// committed before update_hashes ran.
  final String? sha256;

  /// Unix seconds — time the version was archived (when the next edit
  /// pushed it into history).
  final int createdAt;

  FileVersion({
    required this.id,
    required this.fileId,
    required this.version,
    required this.userId,
    required this.isAnonymous,
    required this.size,
    required this.chunks,
    required this.sha256,
    required this.createdAt,
  });

  factory FileVersion.fromJson(Map<String, dynamic> json) {
    return FileVersion(
      id: json['id'] as String,
      fileId: json['file_id'] as String,
      version: json['version'] as int,
      userId: json['user_id'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      size: json['size'] as int? ?? 0,
      chunks: json['chunks'] as int? ?? 0,
      sha256: json['sha256'] as String?,
      createdAt: json['created_at'] as int? ?? 0,
    );
  }
}

class Paginated<T> {
  final List<T> data;
  final int total;

  Paginated({required this.data, required this.total});
}

class AdminUser {
  final String id;
  final String? role;
  final String email;
  final bool hasTfa;
  final int? quota;
  final String? fingerprint;
  final int? emailVerifiedAt;
  final int createdAt;
  final int updatedAt;
  final AdminSession? lastSession;

  AdminUser({
    required this.id,
    this.role,
    required this.email,
    required this.hasTfa,
    this.quota,
    this.fingerprint,
    this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastSession,
  });

  bool get isAdmin => role == 'admin';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final lastSession = json['last_session'] as Map<String, dynamic>?;
    return AdminUser(
      id: json['id'] as String,
      role: json['role'] as String?,
      email: json['email'] as String,
      hasTfa: json['secret'] == true,
      quota: json['quota'] as int?,
      fingerprint: json['fingerprint'] as String?,
      emailVerifiedAt: json['email_verified_at'] as int?,
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
      lastSession: lastSession != null
          ? AdminSession.fromJson(lastSession)
          : null,
    );
  }
}

class AdminUserDetail {
  final AdminUser user;
  final List<StorageStats> stats;

  AdminUserDetail({required this.user, required this.stats});

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    final stats =
        (json['stats'] as List?)
            ?.map((e) => StorageStats.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AdminUserDetail(
      user: AdminUser.fromJson(json['user'] as Map<String, dynamic>),
      stats: stats,
    );
  }

  int get totalSize => stats.fold(0, (sum, s) => sum + s.size);
  int get totalFiles => stats.fold(0, (sum, s) => sum + s.count);
}

class StorageStats {
  final String mime;
  final int size;
  final int count;

  StorageStats({required this.mime, required this.size, required this.count});

  factory StorageStats.fromJson(Map<String, dynamic> json) {
    return StorageStats(
      mime: json['mime'] as String? ?? 'unknown',
      size: json['size'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class AdminSession {
  final String id;
  final String userId;
  final String email;
  final String ip;
  final String userAgent;
  final int createdAt;
  final int updatedAt;
  final int expiresAt;
  final bool active;

  AdminSession({
    required this.id,
    required this.userId,
    required this.email,
    required this.ip,
    required this.userAgent,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.active,
  });

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      userAgent: json['user_agent'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
      expiresAt: json['expires_at'] as int? ?? 0,
      active: json['active'] as bool? ?? false,
    );
  }
}

class Invitation {
  final String id;
  final String? userId;
  final String email;
  final String? role;
  final int? quota;
  final int createdAt;
  final int expiresAt;

  Invitation({
    required this.id,
    this.userId,
    required this.email,
    this.role,
    this.quota,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.fromMillisecondsSinceEpoch(
    expiresAt * 1000,
  ).isBefore(DateTime.now());

  bool get isRedeemed => userId != null;

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      email: json['email'] as String? ?? '',
      role: json['role'] as String?,
      quota: json['quota'] as int?,
      createdAt: json['created_at'] as int? ?? 0,
      expiresAt: json['expires_at'] as int? ?? 0,
    );
  }
}
