/// Response from `POST /api/auth/transfer-token`.
///
/// Transfer tokens are long-lived JWTs scoped to a single file and action
/// (upload or download). They use `Authorization: Bearer` instead of cookies,
/// making them safe for background transfers that outlive the session.
class TransferToken {
  final String token;
  final int expiresAt;
  final String fileId;
  final String action; // "upload" | "download"

  TransferToken({
    required this.token,
    required this.expiresAt,
    required this.fileId,
    required this.action,
  });

  factory TransferToken.fromJson(Map<String, dynamic> json) {
    return TransferToken(
      token: json['token'] as String,
      expiresAt: json['expires_at'] as int,
      fileId: json['file_id'] as String,
      action: json['action'] as String,
    );
  }
}
