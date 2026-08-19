import '../migration.dart';

/// Trust-on-first-use record of a share recipient's key.
class CreateTrustedFingerprints extends Migration {
  const CreateTrustedFingerprints();

  @override
  int get version => 16;

  @override
  String get name => 'create_trusted_fingerprints';

  @override
  Future<void> up(MigrationContext db) => db.execute('''
        CREATE TABLE IF NOT EXISTS trusted_fingerprints (
          owner_user_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          fingerprint TEXT NOT NULL,
          last_verified_at INTEGER NULL,
          verification_method TEXT NOT NULL DEFAULT 'tofu',
          created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
          PRIMARY KEY (owner_user_id, user_id)
        )
      ''');
}
