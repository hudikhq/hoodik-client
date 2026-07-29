import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/features/files/helpers/decrypt_name.dart';

class _FakeCrypto extends Fake implements FileCrypto {
  @override
  Uint8List decryptFileKey(String encryptedKeyBase64) => Uint8List(16);

  @override
  String decryptFileName({
    required String encryptedNameHex,
    required Uint8List fileKey,
    required String cipher,
  }) => 'Plain Name';
}

class _ThrowingCrypto extends Fake implements FileCrypto {
  @override
  Uint8List decryptFileKey(String encryptedKeyBase64) =>
      throw StateError('bad key');
}

FileItem _file({String? encryptedKey = 'k', String encryptedName = 'enc'}) =>
    FileItem(
      id: 'd1',
      mime: 'dir',
      encryptedKey: encryptedKey,
      encryptedName: encryptedName,
    );

void main() {
  test('decrypts the row\'s own name when the key and crypto are present', () {
    expect(decryptOwnName(_FakeCrypto(), _file()), 'Plain Name');
  });

  test('null when fileCrypto is unavailable', () {
    expect(decryptOwnName(null, _file()), isNull);
  });

  test('null when the row carries no wrapped key', () {
    expect(decryptOwnName(_FakeCrypto(), _file(encryptedKey: null)), isNull);
    expect(decryptOwnName(_FakeCrypto(), _file(encryptedKey: '')), isNull);
  });

  test('null when the encrypted name is empty', () {
    expect(decryptOwnName(_FakeCrypto(), _file(encryptedName: '')), isNull);
  });

  test('null when decryption throws — falls back rather than blocking', () {
    expect(decryptOwnName(_ThrowingCrypto(), _file()), isNull);
  });
}
