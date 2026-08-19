import '../migration.dart';

/// Retry budget and backoff deadline for a queued upload.
class AddPendingUploadsRetryColumns extends Migration {
  const AddPendingUploadsRetryColumns();

  @override
  int get version => 12;

  @override
  String get name => 'add_pending_uploads_retry_columns';

  @override
  Future<void> up(MigrationContext db) => () async {
    await db.addColumn(
      'pending_uploads',
      'retry_count',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await db.addColumn('pending_uploads', 'next_retry_at', 'INTEGER NULL');
  }();
}
