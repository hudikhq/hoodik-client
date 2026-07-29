import 'dart:convert';
import 'dart:typed_data';

import 'package:hoodik_app/core/utils/hex.dart' as hex_utils;
import 'package:hoodik_app/src/rust/api.dart' as rust;

/// Fabricates a legacy PIN-derived (Ascon-128a, PIN padded to 32 bytes) blob
/// the way the app produced them before the device-key vault landed. Only tests
/// need this now — production sealing goes through `DeviceKeyVault.wrapBundle`;
/// this exists to exercise the vault's legacy-migration branch and to stand in
/// for the server's password-encrypted `encrypted_private_key` field.
String legacyPinEncrypt(String plaintext, String pin) {
  final padded = pin.length >= 32
      ? pin.substring(0, 32)
      : pin.padRight(32, '0');
  final ciphertext = rust.cipherEncrypt(
    cipher: 'ascon128a',
    key: Uint8List.fromList(utf8.encode(padded)),
    plaintext: Uint8List.fromList(utf8.encode(plaintext)),
  );
  return hex_utils.hexEncode(ciphertext);
}
