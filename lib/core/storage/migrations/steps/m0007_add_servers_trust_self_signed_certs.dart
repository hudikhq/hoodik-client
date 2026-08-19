import '../migration.dart';

/// Accept a self-signed certificate, for self-hosted instances on a local
/// network.
class AddServersTrustSelfSignedCerts extends Migration {
  const AddServersTrustSelfSignedCerts();

  @override
  int get version => 7;

  @override
  String get name => 'add_servers_trust_self_signed_certs';

  @override
  Future<void> up(MigrationContext db) => db.addColumn(
    'servers',
    'trust_self_signed_certs',
    'INTEGER NOT NULL DEFAULT 0 CHECK (trust_self_signed_certs IN (0, 1))',
  );
}
