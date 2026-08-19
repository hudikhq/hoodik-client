import '../migration.dart';

/// The PIN kept for biometric unlock.
class AddAccountsBiometricPin extends Migration {
  const AddAccountsBiometricPin();

  @override
  int get version => 3;

  @override
  String get name => 'add_accounts_biometric_pin';

  @override
  Future<void> up(MigrationContext db) =>
      db.addColumn('accounts', 'biometric_pin', 'TEXT NULL');
}
