import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/files/helpers/selection_batch.dart';

FileItem _file(
  String id, {
  bool dir = false,
  bool uploading = false,
  int size = 10,
}) {
  return FileItem(
    id: id,
    encryptedName: 'enc-$id',
    mime: dir ? 'dir' : 'text/plain',
    size: size,
    finishedUploadAt: uploading ? null : 1,
  );
}

void main() {
  test('drops folders and unfinished uploads', () {
    final batch = SelectionBatch.resolve(
      [
        _file('a'),
        _file('folder', dir: true),
        _file('up', uploading: true),
        _file('b', size: 20),
      ],
      {'a', 'folder', 'up', 'b', 'missing'},
    );

    expect(batch.files.map((f) => f.id), ['a', 'b']);
    expect(batch.folderCount, 1);
    expect(batch.uploadCount, 1);
    expect(batch.totalBytes, 30);
  });

  test('n = 1 does not need confirm; n >= 2 does', () {
    expect(SelectionBatch.resolve([_file('a')], {'a'}).needsConfirm, isFalse);
    expect(
      SelectionBatch.resolve([_file('a'), _file('b')], {'a', 'b'}).needsConfirm,
      isTrue,
    );
  });

  test('large when over 50 files or 500 MB', () {
    final many = [for (var i = 0; i < 51; i++) _file('$i')];
    expect(
      SelectionBatch.resolve(many, {for (final f in many) f.id}).isLarge,
      isTrue,
    );

    final heavy = _file('big', size: 500 * 1024 * 1024 + 1);
    expect(SelectionBatch.resolve([heavy], {'big'}).isLarge, isTrue);
    expect(SelectionBatch.resolve([_file('s')], {'s'}).isLarge, isFalse);
  });

  test('folders-only is empty', () {
    final batch = SelectionBatch.resolve([_file('d', dir: true)], {'d'});
    expect(batch.isEmpty, isTrue);
    expect(batch.folderCount, 1);
  });
}
