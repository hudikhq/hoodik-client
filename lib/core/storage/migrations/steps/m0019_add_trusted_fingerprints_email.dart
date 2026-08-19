import '../migration.dart';

/// The address a fingerprint was last seen under, for the recipient picker.
class AddTrustedFingerprintsEmail extends Migration {
  const AddTrustedFingerprintsEmail();

  @override
  int get version => 19;

  @override
  String get name => 'add_trusted_fingerprints_email';

  @override
  Future<void> up(MigrationContext db) =>
      db.addColumn('trusted_fingerprints', 'email', 'TEXT NULL');
}
