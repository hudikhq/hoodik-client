import 'package:drift/drift.dart';

import 'database.dart';

/// Data-access helpers for the `pending_downloads` table.
///
/// Split out of [AppDatabase] for the same reason as the uploads DAO: the
/// core database class is already at its file-size ceiling.
extension PendingDownloadsDao on AppDatabase {
  /// Record a download as in flight, or update the record if this file is
  /// already being downloaded.
  ///
  /// Upsert rather than insert because a user who taps download again on a
  /// transfer already running should end up with one row, not two rows racing
  /// each other into the same output directory.
  Future<void> recordPendingDownload({
    required String accountId,
    required String fileId,
    required int chunkCount,
    required int fileSize,
    required String outputDir,
    String? outputPath,
  }) async {
    await into(pendingDownloads).insert(
      PendingDownloadsCompanion.insert(
        accountId: accountId,
        fileId: fileId,
        chunkCount: chunkCount,
        fileSize: Value(fileSize),
        outputDir: outputDir,
        outputPath: Value(outputPath),
      ),
      onConflict: DoUpdate(
        (_) => PendingDownloadsCompanion(
          chunkCount: Value(chunkCount),
          fileSize: Value(fileSize),
          outputDir: Value(outputDir),
          outputPath: Value(outputPath),
        ),
        target: [pendingDownloads.accountId, pendingDownloads.fileId],
      ),
    );
  }

  /// Downloads this account still expects to finish, oldest first.
  Future<List<PendingDownload>> getPendingDownloads(String accountId) {
    return (select(pendingDownloads)
          ..where((d) => d.accountId.equals(accountId))
          ..orderBy([(d) => OrderingTerm.asc(d.createdAt)]))
        .get();
  }

  /// Forget one download, once its chunks are all on disk or the user has
  /// cancelled it.
  Future<void> clearPendingDownload({
    required String accountId,
    required String fileId,
  }) async {
    await (delete(pendingDownloads)
          ..where((d) => d.accountId.equals(accountId))
          ..where((d) => d.fileId.equals(fileId)))
        .go();
  }

  /// Forget every download belonging to accounts other than this one.
  ///
  /// Used when signing in: the OS transfer queue is process-wide and outlives
  /// any single session, so a cold start has to tell this account's unfinished
  /// work from another account's leftovers before it adopts anything.
  Future<void> clearPendingDownloadsForOtherAccounts(String accountId) async {
    await (delete(
      pendingDownloads,
    )..where((d) => d.accountId.equals(accountId).not())).go();
  }
}
