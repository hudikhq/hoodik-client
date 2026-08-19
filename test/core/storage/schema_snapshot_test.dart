@Tags(['migration'])
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/database.dart';

import '../../generated/migrations/schema.dart';

/// The schema of every released version, checked against what the code builds.
///
/// `drift_schemas/` holds one JSON snapshot per version, exported at release
/// time. That is what makes "any shipped version can reach the current one" a
/// property the machine checks rather than one somebody remembers: from the
/// next release on, a snapshot exists for the version before it, and the
/// migration between them can be run and verified.
///
/// History starts at v21. Snapshots cannot be recovered after the fact, and
/// v1–v20 were never exported — those paths stay covered by the targeted tests
/// in `database_test.dart`, which walk each step that creates a table and
/// later extends it.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // Every version with a snapshot has to reach the current one. Today that is
  // only v21 to itself; the loop is what makes adding v22 a one-line change
  // rather than a new test somebody has to think to write.
  for (final from in GeneratedHelper.versions) {
    test('v$from migrates to v${AppDatabase.currentSchemaVersion}', () async {
      final connection = await verifier.startAt(from);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(
        db,
        AppDatabase.currentSchemaVersion,
      );
    });
  }
}
