import '../migration.dart';

/// The app went free; the IAP and trial cache is gone for good.
class DropSubscriptions extends Migration {
  const DropSubscriptions();

  @override
  int get version => 18;

  @override
  String get name => 'drop_subscriptions';

  @override
  Future<void> up(MigrationContext db) =>
      db.execute('DROP TABLE IF EXISTS subscriptions');
}
