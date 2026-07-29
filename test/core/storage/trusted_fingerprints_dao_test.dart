import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/shares/services/trusted_fingerprint_dao.dart';

AppDatabase _createTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('upsert and get', () {
    test('records a fingerprint and reads it back', () async {
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer-1',
        fingerprint: 'aabbcc',
      );

      final row = await db.getTrustedFingerprint('owner-1', 'peer-1');
      expect(row, isNotNull);
      expect(row!.fingerprint, 'aabbcc');
      expect(row.verificationMethod, 'tofu');
      expect(row.lastVerifiedAt, isNull);
    });

    test('upsert overwrites an existing peer fingerprint', () async {
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer-1',
        fingerprint: 'aabbcc',
      );
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer-1',
        fingerprint: 'ddeeff',
      );

      final row = await db.getTrustedFingerprint('owner-1', 'peer-1');
      expect(row!.fingerprint, 'ddeeff');

      final all = await db.getTrustedFingerprintsForOwner('owner-1');
      expect(all.length, 1, reason: 'composite PK collapses the two upserts');
    });

    test('honours an explicit manual verification method', () async {
      final now = DateTime.now();
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer-1',
        fingerprint: 'aabbcc',
        verificationMethod: 'manual',
        lastVerifiedAt: now,
      );

      final row = await db.getTrustedFingerprint('owner-1', 'peer-1');
      expect(row!.verificationMethod, 'manual');
      expect(row.lastVerifiedAt, isNotNull);
    });
  });

  group('owner scoping', () {
    test('peers are invisible across owners', () async {
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'shared-peer',
        fingerprint: 'owner1fp',
      );
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-2',
        userId: 'shared-peer',
        fingerprint: 'owner2fp',
      );

      final fromOne = await db.getTrustedFingerprint('owner-1', 'shared-peer');
      final fromTwo = await db.getTrustedFingerprint('owner-2', 'shared-peer');
      expect(fromOne!.fingerprint, 'owner1fp');
      expect(fromTwo!.fingerprint, 'owner2fp');
    });

    test('getTrustedFingerprintsForOwner returns only that owner', () async {
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer-a',
        fingerprint: 'a',
      );
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer-b',
        fingerprint: 'b',
      );
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-2',
        userId: 'peer-c',
        fingerprint: 'c',
      );

      final forOne = await db.getTrustedFingerprintsForOwner('owner-1');
      expect(forOne.map((r) => r.userId).toSet(), {'peer-a', 'peer-b'});
    });
  });

  group('markFingerprintVerified', () {
    test('stamps verification time and promotes to manual', () async {
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer-1',
        fingerprint: 'aabbcc',
      );

      await db.markFingerprintVerified('owner-1', 'peer-1');

      final row = await db.getTrustedFingerprint('owner-1', 'peer-1');
      expect(row!.verificationMethod, 'manual');
      expect(row.lastVerifiedAt, isNotNull);
      expect(
        row.fingerprint,
        'aabbcc',
        reason: 'verification must not alter the recorded fingerprint',
      );
    });

    test('is a no-op when the peer has no row', () async {
      await db.markFingerprintVerified('owner-1', 'absent-peer');
      final row = await db.getTrustedFingerprint('owner-1', 'absent-peer');
      expect(row, isNull);
    });
  });

  group('warn-only-when-verified semantics', () {
    // The store never warns on its own; the caller decides. These cases
    // encode the three states the share flow branches on: absent (first
    // sight, record silently), present+same (no warning), present+different
    // (the only state that warrants a warning).

    test('absent peer reads as null — first sight, never a warning', () async {
      final row = await db.getTrustedFingerprint('owner-1', 'never-seen');
      expect(row, isNull);
    });

    test(
      'present row with the same fingerprint does not warrant a warning',
      () async {
        await db.upsertTrustedFingerprint(
          ownerUserId: 'owner-1',
          userId: 'peer-1',
          fingerprint: 'stablefp',
        );

        const advertised = 'stablefp';
        final row = await db.getTrustedFingerprint('owner-1', 'peer-1');
        final shouldWarn = row != null && row.fingerprint != advertised;
        expect(shouldWarn, isFalse);
      },
    );

    test(
      'present row with a different fingerprint warrants a warning',
      () async {
        await db.upsertTrustedFingerprint(
          ownerUserId: 'owner-1',
          userId: 'peer-1',
          fingerprint: 'trustedfp',
        );

        const advertised = 'rotatedfp';
        final row = await db.getTrustedFingerprint('owner-1', 'peer-1');
        final shouldWarn = row != null && row.fingerprint != advertised;
        expect(shouldWarn, isTrue);
      },
    );
  });

  group('deleteAccount purge', () {
    Future<void> seedAccount(String accountId, String userId) async {
      await db.insertServer(
        ServersCompanion(
          id: Value('srv-$accountId'),
          url: Value('https://$accountId.example'),
          name: Value(accountId),
        ),
      );
      await db.insertAccount(
        AccountsCompanion(
          id: Value(accountId),
          serverId: Value('srv-$accountId'),
          userId: Value(userId),
          email: Value('$accountId@example.test'),
        ),
      );
    }

    test('purges only the deleted account\'s trust rows', () async {
      await seedAccount('acct-1', 'owner-1');
      await seedAccount('acct-2', 'owner-2');
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-1',
        userId: 'peer',
        fingerprint: 'a',
      );
      await db.upsertTrustedFingerprint(
        ownerUserId: 'owner-2',
        userId: 'peer',
        fingerprint: 'b',
      );

      await db.deleteAccount('acct-1');

      expect(await db.getTrustedFingerprintsForOwner('owner-1'), isEmpty);
      expect(
        await db.getTrustedFingerprintsForOwner('owner-2'),
        hasLength(1),
        reason: 'a sibling account keeps its trust set',
      );
    });
  });
}
