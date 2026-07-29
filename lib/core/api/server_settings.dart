/// Platform-wide configuration from `GET /api/admin/settings`, the same payload
/// `PUT /api/admin/settings` accepts back. Flat view over the server's nested
/// `users` and `sharing` blocks so the admin UI binds to plain fields.
class ServerSettings {
  final int? quotaBytes;
  final bool allowRegister;
  final bool enforceEmailActivation;
  final bool sharingEnabled;

  /// Whether the server's settings payload carried a `sharing` block at all.
  /// Servers older than the sharing kill-switch don't, so the admin UI hides
  /// the toggle on them rather than offering a control the server can't honour,
  /// and [toJson] omits the block so a save never injects an unknown field into
  /// a PUT those servers would otherwise round-trip back as a flipped default.
  final bool sharingSupported;

  ServerSettings({
    this.quotaBytes,
    required this.allowRegister,
    required this.enforceEmailActivation,
    this.sharingEnabled = true,
    this.sharingSupported = false,
  });

  factory ServerSettings.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>? ?? {};
    final sharing = json['sharing'] as Map<String, dynamic>?;
    return ServerSettings(
      quotaBytes: users['quota_bytes'] as int?,
      allowRegister: users['allow_register'] as bool? ?? false,
      enforceEmailActivation:
          users['enforce_email_activation'] as bool? ?? false,
      // Server default is enabled, so a present-but-incomplete block reads as on.
      sharingEnabled: sharing?['enabled'] as bool? ?? true,
      sharingSupported: sharing != null,
    );
  }

  ServerSettings copyWith({
    int? quotaBytes,
    bool clearQuota = false,
    bool? allowRegister,
    bool? enforceEmailActivation,
    bool? sharingEnabled,
  }) {
    return ServerSettings(
      quotaBytes: clearQuota ? null : (quotaBytes ?? this.quotaBytes),
      allowRegister: allowRegister ?? this.allowRegister,
      enforceEmailActivation:
          enforceEmailActivation ?? this.enforceEmailActivation,
      sharingEnabled: sharingEnabled ?? this.sharingEnabled,
      sharingSupported: sharingSupported,
    );
  }

  Map<String, dynamic> toJson() => {
    'users': {
      'quota_bytes': quotaBytes,
      'allow_register': allowRegister,
      'enforce_email_activation': enforceEmailActivation,
    },
    if (sharingSupported) 'sharing': {'enabled': sharingEnabled},
  };
}
