import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/frb_safe_decode.dart';

/// The iOS note-save crash was a Dart AOT field deref at 0xf while
/// decoding a rust Vec<u8> / optional struct. These helpers exist so a
/// null or missing wire value throws (or returns null) instead of
/// SIGSEGV-ing the isolate. The tests feed the bad shapes directly —
/// we cannot SIGSEGV on the host VM, but we can prove the decoder
/// never assumes the value is the generated type.
void main() {
  group('safeDecodeUint8List', () {
    test('null throws rather than deref', () {
      expect(
        () => safeDecodeUint8List(null, what: 'cipherEncryptChunk'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('null'),
          ),
        ),
      );
    });

    test('a Uint8List round-trips', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(safeDecodeUint8List(bytes), bytes);
    });

    test('a List<int> is copied into a Uint8List', () {
      expect(safeDecodeUint8List(<int>[9, 8]), Uint8List.fromList([9, 8]));
    });

    test('an unexpected type throws', () {
      expect(
        () => safeDecodeUint8List('not-bytes'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('safeDecodeU64Pair', () {
    test('null is missing, not a crash', () {
      expect(safeDecodeU64Pair(null), isNull);
    });

    test('a non-list is missing', () {
      expect(safeDecodeU64Pair(15), isNull);
      expect(safeDecodeU64Pair('progress'), isNull);
    });

    test('a short list is missing', () {
      expect(safeDecodeU64Pair(<dynamic>[1]), isNull);
      expect(safeDecodeU64Pair(<dynamic>[]), isNull);
    });

    test('a pair of ints decodes', () {
      final pair = safeDecodeU64Pair(<dynamic>[4, 10]);
      expect(pair, isNotNull);
      expect(pair!.transferred, BigInt.from(4));
      expect(pair.total, BigInt.from(10));
    });

    test('a pair of BigInts decodes', () {
      final pair = safeDecodeU64Pair(<dynamic>[BigInt.from(1), BigInt.from(2)]);
      expect(pair, isNotNull);
      expect(pair!.transferred, BigInt.one);
      expect(pair.total, BigInt.two);
    });

    test('a pair with a null field is missing', () {
      expect(safeDecodeU64Pair(<dynamic>[null, 1]), isNull);
      expect(safeDecodeU64Pair(<dynamic>[1, null]), isNull);
    });
  });
}
