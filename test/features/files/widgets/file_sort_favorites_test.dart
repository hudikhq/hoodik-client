import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/files/widgets/file_sort_controls.dart';

FileItem _file(String id, {bool dir = false, bool favorite = false}) =>
    FileItem(
      id: id,
      encryptedName: 'enc-$id',
      mime: dir ? 'dir' : 'text/plain',
      favorite: favorite,
    );

void main() {
  group('sortFiles by name', () {
    test('orders numbers naturally', () {
      final names = {
        'a': '1.jpg',
        'b': '10.jpg',
        'c': '2.jpg',
        'd': 'img02.jpg',
        'e': 'IMG1.jpg',
      };
      final sorted = sortFiles(
        files: names.keys.map(_file).toList(),
        field: SortField.name,
        order: SortOrder.asc,
        displayName: (f) => names[f.id]!,
      );

      expect(sorted.map((f) => names[f.id]), [
        '1.jpg',
        '2.jpg',
        '10.jpg',
        'IMG1.jpg',
        'img02.jpg',
      ]);
    });
  });

  group('pinFavoritesFirst', () {
    test('lifts favourites above the rest, preserving within-group order', () {
      final files = [
        _file('dir-a', dir: true),
        _file('file-b'),
        _file('dir-fav', dir: true, favorite: true),
        _file('file-fav', favorite: true),
      ];

      expect(pinFavoritesFirst(files).map((f) => f.id), [
        'dir-fav',
        'file-fav',
        'dir-a',
        'file-b',
      ]);
    });

    test('is a no-op when nothing is favourited', () {
      final files = [_file('a'), _file('b')];
      expect(pinFavoritesFirst(files), same(files));
    });
  });

  group('FileItem.favorite', () {
    test('defaults to false and parses the wire flag', () {
      final plain = FileItem.fromJson({
        'id': 'x',
        'encrypted_name': 'e',
        'mime': 'text/plain',
      });
      expect(plain.favorite, isFalse);

      final starred = FileItem.fromJson({
        'id': 'y',
        'encrypted_name': 'e',
        'mime': 'text/plain',
        'favorite': true,
      });
      expect(starred.favorite, isTrue);
    });

    test('copyWith can flip the flag and keeps the rest', () {
      final file = _file('z');
      final starred = file.copyWith(favorite: true);
      expect(starred.id, 'z');
      expect(starred.favorite, isTrue);
      expect(starred.copyWith(favorite: false).favorite, isFalse);
    });
  });
}
