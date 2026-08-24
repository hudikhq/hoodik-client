import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/plaintext_temp.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hoodik_plain_test_');
    plaintextTempRootOverride = root;
  });

  tearDown(() async {
    plaintextTempRootOverride = null;
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('paths live under hoodik_plaintext/', () async {
    final path = await plaintextTempPath(fileId: 'abc', basename: 'note.md');
    expect(p.basename(p.dirname(path)), plaintextTempDirName);
    expect(p.basename(path), 'abc_note.md');
  });

  test('two exports with the same display name do not overwrite', () async {
    final a = await plaintextTempPath(fileId: 'id-a', basename: 'photo.jpg');
    final b = await plaintextTempPath(fileId: 'id-b', basename: 'photo.jpg');
    expect(a, isNot(b));
    expect(p.basename(a), 'id-a_photo.jpg');
    expect(p.basename(b), 'id-b_photo.jpg');
  });

  test('sweep removes files in the dir and leaves others alone', () async {
    final inside = await plaintextTempPath(fileId: 'x', basename: 'a.txt');
    await File(inside).writeAsString('plain');
    final outside = File(p.join(root.path, 'keep.txt'));
    await outside.writeAsString('stay');

    await sweepPlaintextTemp();

    expect(File(inside).existsSync(), isFalse);
    expect(outside.existsSync(), isTrue);
    final dir = await plaintextTempDirectory();
    expect(dir.existsSync(), isTrue);
  });
}
