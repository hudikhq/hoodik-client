import '../migration.dart';

/// Size, pin state and last access, for LRU eviction of the offline cache.
///
/// Written as a copy-rebuild rather than three `ALTER TABLE`s because sqlite
/// refuses to add a `NOT NULL` column whose default is an expression to a
/// table that already has rows, and `last_accessed_at` defaults to the current
/// time. Adding it succeeds on an empty table and fails on every device that
/// actually has offline files, which is the only kind of device reaching this
/// migration with anything to lose.
class RebuildOfflineFilesCacheColumns extends Migration {
  const RebuildOfflineFilesCacheColumns();

  @override
  int get version => 4;

  @override
  String get name => 'rebuild_offline_files_cache_columns';

  @override
  Future<void> up(MigrationContext db) => db.rebuildPreserving(
    'offline_files',
    '''
          CREATE TABLE offline_files (
            account_id TEXT NOT NULL,
            file_id TEXT NOT NULL,
            local_path TEXT NOT NULL,
            downloaded_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            size_on_disk INTEGER NOT NULL DEFAULT 0,
            pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0, 1)),
            last_accessed_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            PRIMARY KEY (account_id, file_id)
          )
        ''',
    carry: const ['account_id', 'file_id', 'local_path', 'downloaded_at'],
  );
}
