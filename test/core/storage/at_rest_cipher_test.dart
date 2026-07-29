import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/storage/at_rest_cipher.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/core/storage/hardware_key_store.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

class _MemKeyStore extends HardwareKeyStore {
  _MemKeyStore() : super.withStorage(const FlutterSecureStorage());
  final Map<String, String> entries = {};
  @override
  Future<String?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, String value) async => entries[key] = value;
  @override
  Future<void> delete(String key) async => entries.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  final cipher = AtRestCipher.instance;

  group('AtRestCipher', () {
    setUp(() => cipher.resetForTesting());
    tearDown(() => cipher.resetForTesting());

    test(
      'seals and opens a value; the stored form is not the plaintext',
      () async {
        await cipher.ensureInitialized(keychain: _MemKeyStore());

        const name = 'Quarterly report.pdf';
        final sealedName = cipher.seal(name);
        expect(sealedName, isNotNull);
        expect(sealedName, isNot(name));
        expect(sealedName!.contains(name), isFalse);
        expect(
          sealedName,
          startsWith('01'),
        ); // version marker of the sealed form
        expect(cipher.open(sealedName), name);

        const token = 'a1b2c3d4-e5f6-7890-abcd-ef0123456789';
        final sealedToken = cipher.seal(token);
        expect(sealedToken, isNotNull);
        expect(sealedToken, isNot(token));
        expect(sealedToken!.contains(token), isFalse);
        expect(cipher.open(sealedToken), token);
      },
    );

    test('a fresh nonce per seal yields distinct ciphertext', () async {
      await cipher.ensureInitialized(keychain: _MemKeyStore());
      expect(cipher.seal('same value'), isNot(cipher.seal('same value')));
    });

    test('a legacy plaintext value reads back unchanged', () async {
      await cipher.ensureInitialized(keychain: _MemKeyStore());
      expect(cipher.open('legacy-name.txt'), 'legacy-name.txt');
      expect(
        cipher.open('11112222-3333-4444-5555-666677778888'),
        '11112222-3333-4444-5555-666677778888',
      );
    });

    test('an unopenable sealed value degrades to null, never throws', () async {
      await cipher.ensureInitialized(keychain: _MemKeyStore());
      final sealed = cipher.seal('secret.txt');
      expect(sealed, isNotNull);

      // The key is wiped: the sealed blob can no longer be opened.
      cipher.resetForTesting();
      expect(cipher.open(sealed!), isNull);
    });

    test('without a key, seal fails closed (drops to null, no plaintext)', () {
      // Unkeyed: a write must not be persisted in plaintext — it drops to null.
      // Reading a legacy plaintext row still works without a key.
      expect(cipher.seal('name.txt'), isNull);
      expect(cipher.open('name.txt'), 'name.txt');
    });

    test('a key loss cannot downgrade a sealed value to plaintext', () async {
      await cipher.ensureInitialized(keychain: _MemKeyStore());
      const token = 'refresh-uuid-secret';
      final sealed = cipher.seal(token);
      expect(sealed, isNotNull);

      // Keychain becomes unreadable (pre-first-unlock background launch): the
      // sealed value can no longer be opened, so a caller re-fetches/re-logins…
      cipher.resetForTesting();
      expect(cipher.open(sealed!), isNull);
      // …and the still-unkeyed re-write must NOT land in plaintext.
      expect(cipher.seal(token), isNull);
    });
  });

  group('through the Drift converter', () {
    late AppDatabase db;

    setUp(() async {
      cipher.resetForTesting();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.insertServer(
        ServersCompanion(
          id: const Value('s1'),
          url: const Value('https://example.com'),
          name: const Value('Test'),
        ),
      );
      await db.insertAccount(
        AccountsCompanion(
          id: const Value('s1_u1'),
          serverId: const Value('s1'),
          userId: const Value('u1'),
          email: const Value('u1@test.io'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
      cipher.resetForTesting();
    });

    test(
      'a refresh token is sealed on disk but reads back in the clear',
      () async {
        await cipher.ensureInitialized(keychain: _MemKeyStore());
        const token = 'refresh-uuid-abc';
        await db.updateHeaderTokens('s1_u1', 'jwt', token);

        final raw = await db
            .customSelect(
              'SELECT header_refresh_token AS t FROM accounts WHERE id = ?',
              variables: [Variable<String>('s1_u1')],
            )
            .getSingle();
        final onDisk = raw.read<String>('t');
        expect(onDisk, isNot(token));
        expect(onDisk.contains(token), isFalse);

        final account = await db.getAccountById('s1_u1');
        expect(account!.headerRefreshToken, token);
      },
    );

    test('a pre-existing plaintext token row still reads correctly', () async {
      await cipher.ensureInitialized(keychain: _MemKeyStore());
      // Write the token raw, bypassing the converter — a row from before the
      // column was sealed.
      await db.customStatement(
        'UPDATE accounts SET header_refresh_token = ? WHERE id = ?',
        ['plaintext-refresh-uuid', 's1_u1'],
      );
      final account = await db.getAccountById('s1_u1');
      expect(account!.headerRefreshToken, 'plaintext-refresh-uuid');
    });

    test('deleting the device key does not brick account load', () async {
      await cipher.ensureInitialized(keychain: _MemKeyStore());
      await db.updateHeaderTokens('s1_u1', 'jwt', 'refresh-uuid-xyz');

      // Next launch with a wiped keychain: the at-rest key is gone.
      cipher.resetForTesting();

      final account = await db.getAccountById('s1_u1');
      expect(account, isNotNull);
      expect(account!.email, 'u1@test.io');
      // The unreadable token degrades to null rather than throwing.
      expect(account.headerRefreshToken, isNull);
    });
  });
}
