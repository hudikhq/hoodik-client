import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/device_key_vault.dart';
import 'package:hoodik_app/core/storage/hardware_key_store.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

import '../../helpers/legacy_pin.dart';

/// In-memory keychain that mirrors the platform store's semantics without a
/// method channel, so the vault's crypto and key lifecycle run under `flutter
/// test`. Follows the `SecurePinStorage.forTesting` fake pattern.
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

  const crypto = CryptoService();
  const account = 'acc-1';
  const pin = '135790';
  const bundle =
      'v1|id:-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----'
      '|wrap:-----BEGIN PRIVATE KEY-----\nxyz\n-----END PRIVATE KEY-----';

  late _MemKeyStore store;
  late DeviceKeyVault vault;

  setUp(() {
    store = _MemKeyStore();
    vault = DeviceKeyVault(keychain: store, crypto: crypto);
  });

  test('wraps and unwraps the bundle under the device key', () async {
    final blob = await vault.wrapBundle(account, bundle, pin);
    final result = await vault.unwrapBundle(account, pin, blob);

    expect(result.plaintext, bundle);
    expect(result.wasLegacy, isFalse);
  });

  test('generates the device key once and reuses it on later wraps', () async {
    await vault.wrapBundle(account, bundle, pin);
    final deviceKey = store.entries['hoodik_devkey_$account'];
    expect(deviceKey, isNotNull);

    await vault.wrapBundle(account, 'a different bundle', pin);
    expect(store.entries['hoodik_devkey_$account'], deviceKey);
  });

  test('a fresh random nonce per wrap yields distinct ciphertext', () async {
    final a = await vault.wrapBundle(account, bundle, pin);
    final b = await vault.wrapBundle(account, bundle, pin);
    expect(a, isNot(b));
  });

  test('deleting the device key removes it and blocks later unwrap', () async {
    final blob = await vault.wrapBundle(account, bundle, pin);
    await vault.deleteDeviceKey(account);

    expect(store.entries.containsKey('hoodik_devkey_$account'), isFalse);
    expect(() => vault.unwrapBundle(account, pin, blob), throwsA(anything));
  });

  test(
    'the PIN alone, without the keychain entry, cannot recover the key',
    () async {
      final blob = await vault.wrapBundle(account, bundle, pin);
      store.entries.clear(); // simulate an extracted app.db with no keychain

      expect(() => vault.unwrapBundle(account, pin, blob), throwsA(anything));
    },
  );

  test('a wrong PIN fails the AEAD tag cleanly', () async {
    final blob = await vault.wrapBundle(account, bundle, pin);
    expect(
      () => vault.unwrapBundle(account, '000000', blob),
      throwsA(anything),
    );
  });

  test('a wrong device key fails cleanly', () async {
    final blob = await vault.wrapBundle(account, bundle, pin);
    store.entries['hoodik_devkey_$account'] = crypto.hexEncode(
      crypto.generateSymmetricKey(cipher: 'aegis256'),
    );

    expect(() => vault.unwrapBundle(account, pin, blob), throwsA(anything));
  });

  test('the wrap key is the Argon2id fold, not the SHA-256 one', () async {
    final blob = crypto.hexDecode(await vault.wrapBundle(account, bundle, pin));
    final deviceKey = crypto.hexDecode(
      store.entries['hoodik_devkey_$account']!,
    );

    expect(blob[0], 0x03);
    final salt = blob.sublist(1, 17);
    final nonce = blob.sublist(17, 49);
    final ciphertext = blob.sublist(49);

    final argonKey = await rust.argon2IdDeriveKey(
      secret: [...deviceKey, ...utf8.encode(pin)],
      salt: salt,
    );
    final plaintext = crypto.symmetricDecrypt(
      cipher: 'aegis256',
      key: Uint8List.fromList([...argonKey, ...nonce]),
      ciphertext: ciphertext,
    );
    expect(utf8.decode(plaintext), bundle);

    final sha256Key = crypto.hexDecode(
      crypto.sha256(data: [...deviceKey, ...utf8.encode(pin)]),
    );
    expect(
      () => crypto.symmetricDecrypt(
        cipher: 'aegis256',
        key: Uint8List.fromList([...sha256Key, ...nonce]),
        ciphertext: ciphertext,
      ),
      throwsA(anything),
    );
  });

  group('v2 SHA-256-fold blobs', () {
    /// Builds a blob the way v2 wrapped them: `0x02 ‖ nonce ‖ ciphertext` with
    /// the wrap key a single SHA-256 over `deviceKey ‖ pin`.
    String v2Wrap(Uint8List deviceKey) {
      final wrapKey = crypto.hexDecode(
        crypto.sha256(data: [...deviceKey, ...utf8.encode(pin)]),
      );
      final nonce = crypto.generateSymmetricKey(cipher: 'aegis128l');
      final ciphertext = crypto.symmetricEncrypt(
        cipher: 'aegis256',
        key: Uint8List.fromList([...wrapKey, ...nonce]),
        plaintext: Uint8List.fromList(utf8.encode(bundle)),
      );
      return crypto.hexEncode(
        Uint8List.fromList([0x02, ...nonce, ...ciphertext]),
      );
    }

    Uint8List enrollDeviceKey() {
      final deviceKey = crypto.generateSymmetricKey(cipher: 'aegis256');
      store.entries['hoodik_devkey_$account'] = crypto.hexEncode(deviceKey);
      return deviceKey;
    }

    test('still unwrap and are flagged for re-sealing', () async {
      final blob = v2Wrap(enrollDeviceKey());
      final result = await vault.unwrapBundle(account, pin, blob);

      expect(result.plaintext, bundle);
      expect(result.wasLegacy, isTrue);
    });

    test('a wrong PIN still fails the AEAD tag', () async {
      final blob = v2Wrap(enrollDeviceKey());
      expect(
        () => vault.unwrapBundle(account, '000000', blob),
        throwsA(anything),
      );
    });
  });

  group('legacy PIN-derived blobs', () {
    test('unwrap and flag for migration', () async {
      final legacy = legacyPinEncrypt(bundle, pin);
      final result = await vault.unwrapBundle(account, pin, legacy);

      expect(result.plaintext, bundle);
      expect(result.wasLegacy, isTrue);
    });

    test('a wrong PIN throws and touches no keychain state', () async {
      final legacy = legacyPinEncrypt(bundle, pin);

      await expectLater(
        vault.unwrapBundle(account, '000000', legacy),
        throwsA(anything),
      );
      expect(store.entries, isEmpty);
    });
  });
}
