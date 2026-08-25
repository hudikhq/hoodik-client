import '../migration.dart';

/// The private key encrypted with the user's PIN, for unlock without the
/// password.
class AddAccountsPinEncryptedPrivateKey extends Migration {
  const AddAccountsPinEncryptedPrivateKey();

  @override
  int get version => 2;

  @override
  String get name => 'add_accounts_pin_encrypted_private_key';

  @override
  Future<void> up(MigrationContext db) =>
      db.addColumn('accounts', 'pin_encrypted_private_key', 'TEXT NULL');
}
