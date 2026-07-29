import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/hex.dart';

void main() {
  group('hexEncode', () {
    test('encodes empty bytes', () {
      expect(hexEncode(Uint8List(0)), '');
    });

    test('encodes single byte', () {
      expect(hexEncode(Uint8List.fromList([0])), '00');
      expect(hexEncode(Uint8List.fromList([255])), 'ff');
      expect(hexEncode(Uint8List.fromList([15])), '0f');
      expect(hexEncode(Uint8List.fromList([16])), '10');
    });

    test('encodes multiple bytes', () {
      expect(
        hexEncode(Uint8List.fromList([0xde, 0xad, 0xbe, 0xef])),
        'deadbeef',
      );
    });

    test('output is lowercase', () {
      expect(hexEncode(Uint8List.fromList([0xAB, 0xCD])), 'abcd');
    });
  });

  group('hexDecode', () {
    test('decodes empty string', () {
      expect(hexDecode(''), Uint8List(0));
    });

    test('decodes single byte', () {
      expect(hexDecode('00'), Uint8List.fromList([0]));
      expect(hexDecode('ff'), Uint8List.fromList([255]));
      expect(hexDecode('0f'), Uint8List.fromList([15]));
    });

    test('decodes uppercase', () {
      expect(hexDecode('FF'), Uint8List.fromList([255]));
      expect(
        hexDecode('DEADBEEF'),
        Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]),
      );
    });

    test('decodes mixed case', () {
      expect(
        hexDecode('dEaDbEeF'),
        Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]),
      );
    });

    test('throws on odd length', () {
      expect(() => hexDecode('abc'), throwsArgumentError);
      expect(() => hexDecode('a'), throwsArgumentError);
    });
  });

  group('roundtrip', () {
    test('encode then decode returns original bytes', () {
      final original = Uint8List.fromList(
        List.generate(256, (i) => i),
      ); // all byte values
      final encoded = hexEncode(original);
      final decoded = hexDecode(encoded);
      expect(decoded, original);
    });

    test('decode then encode returns lowercase hex', () {
      const hex = 'deadbeef01234567890abcde';
      final bytes = hexDecode(hex);
      expect(hexEncode(bytes), hex);
    });
  });
}
