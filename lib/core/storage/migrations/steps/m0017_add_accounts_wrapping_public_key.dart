import '../migration.dart';

/// The hybrid wrapping key of a curve account, whose identity key cannot do
/// RSA.
class AddAccountsWrappingPublicKey extends Migration {
  const AddAccountsWrappingPublicKey();

  @override
  int get version => 17;

  @override
  String get name => 'add_accounts_wrapping_public_key';

  @override
  Future<void> up(MigrationContext db) =>
      db.addColumn('accounts', 'wrapping_public_key', 'TEXT NULL');
}
