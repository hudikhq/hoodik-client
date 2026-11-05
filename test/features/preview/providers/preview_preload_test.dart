import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/preview/providers/preview_providers.dart';

FileItem _file(String id, {int? size = 1024, bool uploading = false}) =>
    FileItem(
      id: id,
      encryptedName: 'enc-$id',
      mime: 'image/png',
      size: size,
      chunks: 1,
      finishedUploadAt: uploading ? null : 1,
    );

void main() {
  group('previewPreloadCandidates', () {
    test('returns the previous then next entry', () {
      final files = [_file('a'), _file('b'), _file('c')];

      expect(previewPreloadCandidates(files, 1).map((f) => f.id), ['a', 'c']);
    });

    test('skips entries above the size cap', () {
      final files = [
        _file('a'),
        _file('big', size: 6 * 1024 * 1024),
        _file('b'),
        _file('c'),
      ];

      expect(previewPreloadCandidates(files, 2).map((f) => f.id), ['c']);
    });

    test('skips unknown-size and still-uploading entries', () {
      final files = [
        _file('a'),
        _file('uploading', uploading: true),
        _file('current'),
        _file('unknown', size: null),
      ];

      expect(previewPreloadCandidates(files, 2), isEmpty);
    });

    test('handles the ends of the list', () {
      final files = [_file('a'), _file('b')];

      expect(previewPreloadCandidates(files, 0).map((f) => f.id), ['b']);
      expect(previewPreloadCandidates(files, 1).map((f) => f.id), ['a']);
      expect(previewPreloadCandidates(const [], 0), isEmpty);
    });

    test('respects a custom cap', () {
      final files = [_file('a', size: 2048), _file('b', size: 2048)];

      expect(previewPreloadCandidates(files, 0, maxBytes: 1024), isEmpty);
      expect(
        previewPreloadCandidates(files, 0, maxBytes: 4096).map((f) => f.id),
        ['b'],
      );
    });
  });
}
