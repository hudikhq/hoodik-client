import 'dart:typed_data';

/// Decode a hex-encoded string to bytes.
///
/// Throws [ArgumentError] if the string has odd length (invalid hex).
Uint8List hexDecode(String hex) {
  final length = hex.length;
  if (length % 2 != 0) {
    throw ArgumentError('Hex string must have even length, got $length');
  }
  final result = Uint8List(length ~/ 2);
  for (var i = 0; i < length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

/// Encode bytes to a lowercase hex string.
String hexEncode(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
