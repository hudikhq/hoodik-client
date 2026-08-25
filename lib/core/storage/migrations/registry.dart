import 'migration.dart';
import 'steps/m0002_add_accounts_pin_encrypted_private_key.dart';
import 'steps/m0003_add_accounts_biometric_pin.dart';
import 'steps/m0004_rebuild_offline_files_cache_columns.dart';
import 'steps/m0006_add_accounts_cache_limit_bytes.dart';
import 'steps/m0007_add_servers_trust_self_signed_certs.dart';
import 'steps/m0008_add_header_auth_columns.dart';
import 'steps/m0009_create_mcp_settings.dart';
import 'steps/m0010_rebuild_mcp_settings_per_account.dart';
import 'steps/m0012_add_pending_uploads_retry_columns.dart';
import 'steps/m0013_create_mcp_audit_log.dart';
import 'steps/m0014_add_mcp_settings_rate_limits.dart';
import 'steps/m0015_add_mcp_settings_audit_retention.dart';
import 'steps/m0016_create_trusted_fingerprints.dart';
import 'steps/m0017_add_accounts_wrapping_public_key.dart';
import 'steps/m0018_drop_subscriptions.dart';
import 'steps/m0019_add_trusted_fingerprints_email.dart';
import 'steps/m0020_create_pending_downloads.dart';
import 'steps/m0021_rebuild_pending_downloads_output_path.dart';
import 'steps/m0022_rebuild_pending_downloads_file_size.dart';

/// Every migration, in the order they apply.
///
/// A schema change means one new file under `steps/` and one line here. The
/// database's `schemaVersion` is the last entry's version, so a migration
/// cannot be added without the version moving, and the version cannot move
/// without a migration. Versions are not contiguous: v5 and v11 belonged to
/// the subscriptions table, which went out with the paid app.
const List<Migration> migrations = [
  AddAccountsPinEncryptedPrivateKey(),
  AddAccountsBiometricPin(),
  RebuildOfflineFilesCacheColumns(),
  AddAccountsCacheLimitBytes(),
  AddServersTrustSelfSignedCerts(),
  AddHeaderAuthColumns(),
  CreateMcpSettings(),
  RebuildMcpSettingsPerAccount(),
  AddPendingUploadsRetryColumns(),
  CreateMcpAuditLog(),
  AddMcpSettingsRateLimits(),
  AddMcpSettingsAuditRetention(),
  CreateTrustedFingerprints(),
  AddAccountsWrappingPublicKey(),
  DropSubscriptions(),
  AddTrustedFingerprintsEmail(),
  CreatePendingDownloads(),
  RebuildPendingDownloadsOutputPath(),
  RebuildPendingDownloadsFileSize(),
];
