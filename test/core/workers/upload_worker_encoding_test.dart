import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// Guards against a regression where chunk-upload error bodies were decoded
/// with [SystemEncoding] — which on Windows falls back to a legacy code page
/// (cp1252/mbcs) and corrupts any non-ASCII character. Hoodik servers always
/// emit UTF-8, so we must decode as UTF-8 regardless of host locale.
///
/// The live code path lives in `lib/core/workers/upload_worker.dart` inside
/// the isolate entry point (cannot be imported here without spinning up the
/// whole isolate). This test pins the decoder contract instead.
void main() {
  group('upload worker response body decoding', () {
    test(
      'utf8.decoder preserves multi-byte characters in error bodies',
      () async {
        // Server response fragment the upload worker would see on a 422 /
        // validation error: `chunk_already_exists` plus a human-readable
        // message containing multi-byte characters (e.g. a filename).
        const json = '{"code":"chunk_already_exists","name":"résumé—日本語"}';
        final bytes = utf8.encode(json);

        final stream = Stream<List<int>>.fromIterable([bytes]);
        final decoded = await stream.transform(utf8.decoder).join();

        expect(decoded, json);
        expect(decoded.contains('résumé'), isTrue);
        expect(decoded.contains('日本語'), isTrue);
        expect(decoded.contains('chunk_already_exists'), isTrue);
      },
    );

    test('utf8.decoder handles split chunks without losing bytes', () async {
      // HTTP bodies arrive in arbitrary-sized chunks. The worker uses a
      // streaming transform + join, so a multi-byte code point split across
      // two chunks must still decode correctly — SystemEncoding on Windows
      // would have returned mojibake for this case.
      const full = 'chunk_already_exists—α';
      final bytes = utf8.encode(full);
      // Split the em dash (0xE2 0x80 0x94) across the boundary.
      final a = bytes.sublist(0, 22);
      final b = bytes.sublist(22);

      final stream = Stream<List<int>>.fromIterable([a, b]);
      final decoded = await stream.transform(utf8.decoder).join();

      expect(decoded, full);
    });
  });
}
