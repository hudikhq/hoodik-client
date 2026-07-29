/// Valid `PendingUpload.status` values, centralized to avoid typos.
///
/// The string values are stable — they're persisted in the on-device
/// Drift database (the `pending_uploads.status` column), so changing
/// one here means a migration.
abstract final class PendingUploadStatus {
  /// Queued and eligible for retry once its cooldown (if any) elapses.
  static const pending = 'pending';

  /// Currently being uploaded; used to guard against concurrent retries.
  static const uploading = 'uploading';

  /// Finished without success after the retry budget was exhausted.
  /// No auto-retries; only manual user action moves the row out of this state.
  static const failedPermanent = 'failed_permanent';
}
