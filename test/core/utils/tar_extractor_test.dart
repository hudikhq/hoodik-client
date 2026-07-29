import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/tar_extractor.dart';

/// Build a minimal POSIX ustar tar archive from entries for testing.
/// Mirrors the server's tar generation logic.
Uint8List buildTar(List<(String name, Uint8List data)> entries) {
  final archive = BytesBuilder(copy: false);

  for (final (name, data) in entries) {
    final header = Uint8List(512);

    // Filename (bytes 0..100).
    final nameBytes = name.codeUnits;
    final len = nameBytes.length.clamp(0, 100);
    header.setRange(0, len, nameBytes);

    // File mode (bytes 100..107).
    header.setRange(100, 107, '0000644'.codeUnits);

    // Owner/group IDs (bytes 108..123).
    header.setRange(108, 115, '0000000'.codeUnits);
    header.setRange(116, 123, '0000000'.codeUnits);

    // Size in octal (bytes 124..135).
    final sizeOctal = data.length.toRadixString(8).padLeft(11, '0');
    header.setRange(124, 135, sizeOctal.codeUnits);

    // Mtime (bytes 136..147).
    header.setRange(136, 147, '00000000000'.codeUnits);

    // Type flag (byte 156): '0' = regular file.
    header[156] = 0x30; // '0'

    // USTAR magic (bytes 257..263) and version (bytes 263..265).
    header.setRange(257, 263, 'ustar\x00'.codeUnits);
    header.setRange(263, 265, '00'.codeUnits);

    // Checksum placeholder: 8 spaces (bytes 148..156).
    header.setRange(148, 156, '        '.codeUnits);

    // Compute checksum.
    var checksum = 0;
    for (var i = 0; i < 512; i++) {
      checksum += header[i];
    }
    final checksumOctal = '${checksum.toRadixString(8).padLeft(6, '0')}\x00 ';
    header.setRange(148, 156, checksumOctal.codeUnits);

    archive.add(header);
    archive.add(data);

    // Padding to 512-byte boundary.
    final remainder = data.length % 512;
    if (remainder != 0) {
      archive.add(Uint8List(512 - remainder));
    }
  }

  // End-of-archive: two zero blocks.
  archive.add(Uint8List(1024));

  return archive.toBytes();
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tar_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('extracts empty archive', () async {
    final tarPath = '${tempDir.path}/empty.tar';
    await File(tarPath).writeAsBytes(Uint8List(1024));

    final outputDir = '${tempDir.path}/out';
    await Directory(outputDir).create();
    final count = await extractTarFile(tarPath, outputDir);

    expect(count, 0);
  });

  test('extracts single entry', () async {
    final data = Uint8List.fromList('hello world'.codeUnits);
    final tarBytes = buildTar([('test.enc', data)]);
    final tarPath = '${tempDir.path}/single.tar';
    await File(tarPath).writeAsBytes(tarBytes);

    final outputDir = '${tempDir.path}/out';
    await Directory(outputDir).create();
    final count = await extractTarFile(tarPath, outputDir);

    expect(count, 1);
    final extracted = await File('$outputDir/test.enc').readAsBytes();
    expect(extracted, data);
  });

  test('extracts multiple entries in order', () async {
    final data0 = Uint8List.fromList(List.filled(1024, 0xAA));
    final data1 = Uint8List.fromList(List.filled(2048, 0xBB));
    final data2 = Uint8List.fromList(List.filled(100, 0xCC));
    final tarBytes = buildTar([
      ('000000.enc', data0),
      ('000001.enc', data1),
      ('000002.enc', data2),
    ]);
    final tarPath = '${tempDir.path}/multi.tar';
    await File(tarPath).writeAsBytes(tarBytes);

    final outputDir = '${tempDir.path}/out';
    await Directory(outputDir).create();
    final count = await extractTarFile(tarPath, outputDir);

    expect(count, 3);
    expect(await File('$outputDir/000000.enc').readAsBytes(), data0);
    expect(await File('$outputDir/000001.enc').readAsBytes(), data1);
    expect(await File('$outputDir/000002.enc').readAsBytes(), data2);
  });

  test('handles exact 512-byte boundary data', () async {
    final data = Uint8List.fromList(List.filled(512, 0xFF));
    final tarBytes = buildTar([('aligned.enc', data)]);
    final tarPath = '${tempDir.path}/aligned.tar';
    await File(tarPath).writeAsBytes(tarBytes);

    final outputDir = '${tempDir.path}/out';
    await Directory(outputDir).create();
    final count = await extractTarFile(tarPath, outputDir);

    expect(count, 1);
    final extracted = await File('$outputDir/aligned.enc').readAsBytes();
    expect(extracted.length, 512);
    expect(extracted, data);
  });

  test('handles empty file entry', () async {
    final tarBytes = buildTar([('empty.enc', Uint8List(0))]);
    final tarPath = '${tempDir.path}/empty_entry.tar';
    await File(tarPath).writeAsBytes(tarBytes);

    final outputDir = '${tempDir.path}/out';
    await Directory(outputDir).create();
    final count = await extractTarFile(tarPath, outputDir);

    expect(count, 1);
    final extracted = await File('$outputDir/empty.enc').readAsBytes();
    expect(extracted.isEmpty, true);
  });

  test('throws on truncated archive', () async {
    final data = Uint8List.fromList(List.filled(1024, 0xAA));
    final tarBytes = buildTar([('test.enc', data)]);
    // Truncate in the middle of the data section.
    final truncated = tarBytes.sublist(0, 512 + 500);
    final tarPath = '${tempDir.path}/truncated.tar';
    await File(tarPath).writeAsBytes(truncated);

    final outputDir = '${tempDir.path}/out';
    await Directory(outputDir).create();

    expect(
      () => extractTarFile(tarPath, outputDir),
      throwsA(isA<FormatException>()),
    );
  });

  test('handles large 4 MB chunk', () async {
    final data = Uint8List.fromList(List.filled(4 * 1024 * 1024, 0x42));
    final tarBytes = buildTar([('000000.enc', data)]);
    final tarPath = '${tempDir.path}/large.tar';
    await File(tarPath).writeAsBytes(tarBytes);

    final outputDir = '${tempDir.path}/out';
    await Directory(outputDir).create();
    final count = await extractTarFile(tarPath, outputDir);

    expect(count, 1);
    final extracted = await File('$outputDir/000000.enc').readAsBytes();
    expect(extracted.length, 4 * 1024 * 1024);
    expect(extracted, data);
  });
}
