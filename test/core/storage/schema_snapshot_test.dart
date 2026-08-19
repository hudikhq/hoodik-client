@Tags(['migration'])
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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

      await verifier.migrateAndValidate(db, AppDatabase.currentSchemaVersion);
    });
  }

  // The loop above only proves what it has snapshots for, so a version bumped
  // without one is a version nobody will ever be able to test the upgrade from
  // — and the omission is invisible, because the loop just keeps passing on
  // the versions it does have. Failing here is what keeps that from happening
  // quietly ten releases from now.
  test(
    'every version since v$_firstSnapshot has a snapshot to migrate from',
    () {
      for (
        var version = _firstSnapshot;
        version <= AppDatabase.currentSchemaVersion;
        version++
      ) {
        expect(
          File('drift_schemas/drift_schema_v$version.json').existsSync(),
          isTrue,
          reason: 'run `just schema-snapshot` after bumping to v$version',
        );
        expect(
          GeneratedHelper.versions,
          contains(version),
          reason: 'run `just schema-snapshot` to regenerate the helper',
        );
      }
    },
  );

  // The check the whole registry hangs on: walking every migration from the
  // first shipped schema has to land on exactly what the current definitions
  // declare. It needs no snapshot — drift builds the reference with
  // `createAll` — so it covers the versions whose snapshots were never taken,
  // and it fails on any migration whose SQL and Dart definition disagree.
  //
  // This is what the shipped bug looked like from the outside: a step that
  // created `pending_downloads` complete, followed by a step adding a column
  // it already had.
  test(
    'walking every migration from v1 lands on the declared schema',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Strip the current schema back to what v1 shipped: every table and every
      // column a migration went on to add.
      await db.customStatement('DROP TABLE schema_migrations');
      for (final table in const [
        'mcp_settings',
        'mcp_audit_log',
        'trusted_fingerprints',
        'pending_downloads',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final column in const [
        'accounts DROP COLUMN pin_encrypted_private_key',
        'accounts DROP COLUMN biometric_pin',
        'accounts DROP COLUMN cache_limit_bytes',
        'accounts DROP COLUMN header_jwt',
        'accounts DROP COLUMN header_refresh_token',
        'accounts DROP COLUMN wrapping_public_key',
        'offline_files DROP COLUMN size_on_disk',
        'offline_files DROP COLUMN pinned',
        'offline_files DROP COLUMN last_accessed_at',
        'servers DROP COLUMN trust_self_signed_certs',
        'servers DROP COLUMN use_header_auth',
        'pending_uploads DROP COLUMN retry_count',
        'pending_uploads DROP COLUMN next_retry_at',
      ]) {
        await db.customStatement('ALTER TABLE $column');
      }

      await db.migration.onUpgrade(
        Migrator(db),
        1,
        AppDatabase.currentSchemaVersion,
      );

      await db.validateDatabaseSchema();
    },
  );
}

/// v1–v20 shipped before snapshots were exported and cannot be recovered.
const _firstSnapshot = 21;
