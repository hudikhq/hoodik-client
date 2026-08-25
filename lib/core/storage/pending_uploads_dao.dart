import 'package:drift/drift.dart';

import '../services/pending_upload_status.dart';
import 'database.dart';

/// Data-access helpers for the `pending_uploads` table.
///
/// Split out of [AppDatabase] so the queue-with-backoff schema can grow
/// without pushing the core database class further over the file-size
/// ceiling.
extension PendingUploadsDao on AppDatabase {
  /// Insert a new pending upload and return the persisted row.
  Future<PendingUpload> insertPendingUpload(
    PendingUploadsCompanion upload,
  ) async {
    final id = await into(pendingUploads).insert(upload);
    return (select(pendingUploads)..where((u) => u.id.equals(id))).getSingle();
  }

  /// Hand every upload still marked in-flight back to the retry queue, and
  /// return how many were revived.
  ///
  /// A row in that state was left there by a process that died mid-upload —
  /// nothing else clears it, and the retry pass skips it for as long as it
  /// stands. [startedByThisProcess] holds the rows this process is genuinely
  /// uploading right now, which must be left alone: reviving one would start
  /// a second upload of the same file alongside the first, and the user would
  /// end up with the file twice.
  Future<int> reviveInterruptedUploads(
    String accountId, {
    Set<int> startedByThisProcess = const {},
  }) {
    return (update(pendingUploads)
          ..where((u) => u.accountId.equals(accountId))
          ..where((u) => u.status.equals(PendingUploadStatus.uploading))
          ..where((u) => u.id.isNotIn(startedByThisProcess)))
        .write(
          PendingUploadsCompanion(
            status: const Value(PendingUploadStatus.pending),
            nextRetryAt: const Value(null),
          ),
        );
  }

  /// All pending uploads for an account, oldest first.
  Future<List<PendingUpload>> getPendingUploads(String accountId) {
    return (select(pendingUploads)
          ..where((u) => u.accountId.equals(accountId))
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
        .get();
  }

  /// Pending uploads with a specific status, oldest first.
  Future<List<PendingUpload>> getPendingUploadsByStatus(
    String accountId,
    String status,
  ) {
    return (select(pendingUploads)
          ..where((u) => u.accountId.equals(accountId))
          ..where((u) => u.status.equals(status))
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
        .get();
  }

  /// Count of uploads that still need user visibility — pending,
  /// in-flight, legacy-failed, and permanently-failed.
  Future<int> getPendingUploadCount(String accountId) async {
    final rows =
        await (select(pendingUploads)
              ..where((u) => u.accountId.equals(accountId))
              ..where(
                (u) => u.status.isIn([
                  'pending',
                  'uploading',
                  'failed',
                  'failed_permanent',
                ]),
              ))
            .get();
    return rows.length;
  }

  /// Rows eligible for a retry this pass: pending status and either no
  /// cooldown set or the cooldown has elapsed.
  ///
  /// `failed_permanent` rows are deliberately excluded — they only leave
  /// that state via [resetPendingUploadForRetry] (user taps "Retry").
  Future<List<PendingUpload>> getPendingUploadsEligibleForRetry(
    String accountId,
    DateTime now,
  ) {
    return (select(pendingUploads)
          ..where((u) => u.accountId.equals(accountId))
          ..where((u) => u.status.isIn(['pending', 'failed']))
          ..where(
            (u) =>
                u.nextRetryAt.isNull() |
                u.nextRetryAt.isSmallerOrEqualValue(now),
          )
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
        .get();
  }

  /// Uploads that gave up after exhausting the retry budget.
  Future<List<PendingUpload>> getPermanentlyFailedUploads(String accountId) {
    return (select(pendingUploads)
          ..where((u) => u.accountId.equals(accountId))
          ..where((u) => u.status.equals('failed_permanent'))
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
        .get();
  }

  /// Update the status of a pending upload.
  Future<void> updatePendingUploadStatus(int id, String status) async {
    await (update(pendingUploads)..where((u) => u.id.equals(id))).write(
      PendingUploadsCompanion(status: Value(status)),
    );
  }

  /// Record a failed attempt and schedule the next try.
  Future<void> scheduleNextUploadRetry(
    int id, {
    required int retryCount,
    required DateTime nextRetryAt,
  }) async {
    await (update(pendingUploads)..where((u) => u.id.equals(id))).write(
      PendingUploadsCompanion(
        status: const Value('pending'),
        retryCount: Value(retryCount),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
  }

  /// Mark an upload as permanently failed: retry budget exhausted.
  /// Clears `next_retry_at` so it stops showing up as eligible.
  Future<void> markPendingUploadPermanentlyFailed(
    int id,
    int retryCount,
  ) async {
    await (update(pendingUploads)..where((u) => u.id.equals(id))).write(
      PendingUploadsCompanion(
        status: const Value('failed_permanent'),
        retryCount: Value(retryCount),
        nextRetryAt: const Value(null),
      ),
    );
  }

  /// Reset a permanently-failed upload back to pending, restoring the
  /// full retry budget. Called from a user-initiated retry action.
  Future<void> resetPendingUploadForRetry(int id) async {
    await (update(pendingUploads)..where((u) => u.id.equals(id))).write(
      const PendingUploadsCompanion(
        status: Value('pending'),
        retryCount: Value(0),
        nextRetryAt: Value(null),
      ),
    );
  }

  /// Delete a pending upload by ID.
  Future<void> deletePendingUpload(int id) async {
    await (delete(pendingUploads)..where((u) => u.id.equals(id))).go();
  }

  /// Delete all completed pending uploads for an account.
  Future<void> clearCompletedPendingUploads(String accountId) async {
    await (delete(pendingUploads)
          ..where((u) => u.accountId.equals(accountId))
          ..where((u) => u.status.equals('completed')))
        .go();
  }
}
