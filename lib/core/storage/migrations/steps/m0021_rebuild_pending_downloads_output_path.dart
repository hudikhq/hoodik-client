import '../migration.dart';

/// Where a resumed download should land, rather than only which directory.
///
/// Rebuilt rather than altered. The table holds nothing but resume state for
/// interrupted downloads, so the worst a rebuild costs is one download
/// starting over, and beginning from a drop means no prior state, however
/// mangled, can stop the migration from completing.
class RebuildPendingDownloadsOutputPath extends Migration {
  const RebuildPendingDownloadsOutputPath();

  @override
  int get version => 21;

  @override
  String get name => 'rebuild_pending_downloads_output_path';

  @override
  Future<void> up(MigrationContext db) => db.rebuild('pending_downloads', '''
          CREATE TABLE pending_downloads (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            account_id TEXT NOT NULL,
            file_id TEXT NOT NULL,
            chunk_count INTEGER NOT NULL,
            output_dir TEXT NOT NULL,
            output_path TEXT NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            UNIQUE (account_id, file_id)
          )
        ''');
}
