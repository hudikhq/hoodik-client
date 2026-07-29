import 'package:drift/drift.dart';

import '../../../core/storage/database.dart';

/// Data-access helpers for the [TrustedFingerprints] table — the per-account
/// trust-on-first-use store for peer public-key fingerprints.
///
/// Kept in its own extension so `database.dart` doesn't grow CRUD for every
/// table. Mirrors [McpAuditDao] in shape. Every method is scoped by
/// `ownerUserId` (the caller's own server UUID) so one account's trust set is
/// invisible to another's.
///
/// The store encodes the warn-only-when-verified rule: a missing row means the
/// peer has never been seen, so the share flow records it silently via
/// [upsertTrustedFingerprint] and must not warn. A warning is only justified
/// when [getTrustedFingerprint] returns a row whose [TrustedFingerprint.fingerprint]
/// differs from the one the server just advertised — never on the absence of a
/// row.
extension TrustedFingerprintDao on AppDatabase {
  /// The trusted fingerprint for one peer under one owner, or null if the
  /// caller has never recorded this peer. Null is the first-sight signal:
  /// callers record silently and never warn on it.
  Future<TrustedFingerprint?> getTrustedFingerprint(
    String ownerUserId,
    String userId,
  ) {
    return (select(trustedFingerprints)..where(
          (t) => t.ownerUserId.equals(ownerUserId) & t.userId.equals(userId),
        ))
        .getSingleOrNull();
  }

  /// Every peer the given owner has recorded, for surfacing the full trust set
  /// (e.g. a manage-trust screen) without leaking other accounts' peers.
  Future<List<TrustedFingerprint>> getTrustedFingerprintsForOwner(
    String ownerUserId,
  ) {
    return (select(
      trustedFingerprints,
    )..where((t) => t.ownerUserId.equals(ownerUserId))).get();
  }

  /// Record or overwrite the trusted fingerprint for one peer. Used both on
  /// first sight (TOFU) and when the user accepts a changed fingerprint.
  /// [verificationMethod] defaults to 'tofu'; pass 'manual' when the user
  /// confirmed it out of band.
  Future<void> upsertTrustedFingerprint({
    required String ownerUserId,
    required String userId,
    required String fingerprint,
    String verificationMethod = 'tofu',
    DateTime? lastVerifiedAt,
  }) async {
    await into(trustedFingerprints).insertOnConflictUpdate(
      TrustedFingerprintsCompanion.insert(
        ownerUserId: ownerUserId,
        userId: userId,
        fingerprint: fingerprint,
        verificationMethod: Value(verificationMethod),
        lastVerifiedAt: Value(lastVerifiedAt),
      ),
    );
  }

  /// Stamp an existing peer row as manually verified: set [lastVerifiedAt] to
  /// now and promote [verificationMethod] to 'manual'. A no-op if the peer has
  /// no row yet — verification only makes sense for a fingerprint already
  /// recorded by [upsertTrustedFingerprint].
  Future<void> markFingerprintVerified(
    String ownerUserId,
    String userId,
  ) async {
    await (update(trustedFingerprints)..where(
          (t) => t.ownerUserId.equals(ownerUserId) & t.userId.equals(userId),
        ))
        .write(
          TrustedFingerprintsCompanion(
            lastVerifiedAt: Value(DateTime.now()),
            verificationMethod: const Value('manual'),
          ),
        );
  }
}
