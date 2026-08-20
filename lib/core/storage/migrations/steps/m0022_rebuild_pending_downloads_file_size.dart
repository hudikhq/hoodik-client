import '../migration.dart';

/// How large the file is, so a resumed download can draw a real progress bar.
///
/// Resume used to read the size off `cached_files`, which is a listing cache:
/// a file the user has not browsed to recently has no row there, and the
/// transfer then showed 0 % with no speed and no ETA for its whole run.
class RebuildPendingDownloadsFileSize extends Migration {
  const RebuildPendingDownloadsFileSize();

  @override
  int get version => 22;

  @override
  String get name => 'rebuild_pending_downloads_file_size';

  @override
  Future<void> up(MigrationContext db) => db.rebuild('pending_downloads', '''
          CREATE TABLE pending_downloads (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            account_id TEXT NOT NULL,
            file_id TEXT NOT NULL,
            chunk_count INTEGER NOT NULL,
            file_size INTEGER NOT NULL DEFAULT 0,
            output_dir TEXT NOT NULL,
            output_path TEXT NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            UNIQUE (account_id, file_id)
          )
        ''');
}
