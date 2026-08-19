import '../migration.dart';

/// Resume state for a download interrupted by the app closing.
class CreatePendingDownloads extends Migration {
  const CreatePendingDownloads();

  @override
  int get version => 20;

  @override
  String get name => 'create_pending_downloads';

  @override
  Future<void> up(MigrationContext db) => db.rebuild('pending_downloads', '''
          CREATE TABLE pending_downloads (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            account_id TEXT NOT NULL,
            file_id TEXT NOT NULL,
            chunk_count INTEGER NOT NULL,
            output_dir TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            UNIQUE (account_id, file_id)
          )
        ''');
}
