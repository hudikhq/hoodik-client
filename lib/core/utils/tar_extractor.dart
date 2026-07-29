import 'dart:io';
import 'dart:typed_data';

/// Extract an uncompressed POSIX/ustar tar archive from disk, writing each
/// entry to [outputDir] as an individual file.
///
/// Reads entry-by-entry (512-byte header + data + padding) to avoid loading
/// the entire archive into memory. The server names chunks `000000.enc`,
/// `000001.enc`, etc.
///
/// Returns the number of entries extracted.
Future<int> extractTarFile(String tarPath, String outputDir) async {
  final file = File(tarPath);
  final raf = await file.open(mode: FileMode.read);
  final headerBuf = Uint8List(512);
  var entriesExtracted = 0;

  try {
    while (true) {
      // Read 512-byte header.
      final headerRead = await raf.readInto(headerBuf);
      if (headerRead < 512) break;

      // Two consecutive zero blocks signal end-of-archive.
      if (_isZeroBlock(headerBuf)) break;

      final name = _parseName(headerBuf);
      final size = _parseSize(headerBuf);

      // Read file data and write to output.
      final outPath = '$outputDir/$name';
      final outFile = File(outPath);
      final sink = outFile.openWrite();

      var remaining = size;
      const bufSize = 64 * 1024; // 64 KB read buffer
      while (remaining > 0) {
        final toRead = remaining < bufSize ? remaining : bufSize;
        final buf = Uint8List(toRead);
        final read = await raf.readInto(buf);
        if (read == 0) {
          await sink.close();
          throw FormatException(
            'Tar archive truncated: entry "$name" needs $size bytes, '
            'got ${size - remaining} before EOF',
          );
        }
        sink.add(Uint8List.view(buf.buffer, 0, read));
        remaining -= read;
      }
      await sink.close();

      // Skip padding to next 512-byte boundary.
      final remainder = size % 512;
      if (remainder != 0) {
        final padding = 512 - remainder;
        await raf.setPosition(await raf.position() + padding);
      }

      entriesExtracted++;
    }
  } finally {
    await raf.close();
  }

  return entriesExtracted;
}

/// Parse the entry filename from header bytes 0..100 (null-terminated).
String _parseName(Uint8List header) {
  var end = 0;
  while (end < 100 && header[end] != 0) {
    end++;
  }
  return String.fromCharCodes(header, 0, end);
}

/// Parse the entry size from header bytes 124..135 (octal, null-terminated).
int _parseSize(Uint8List header) {
  var start = 124;
  var end = 135;

  // Trim trailing nulls and spaces.
  while (end > start && (header[end - 1] == 0 || header[end - 1] == 0x20)) {
    end--;
  }
  // Trim leading spaces.
  while (start < end && header[start] == 0x20) {
    start++;
  }

  final sizeStr = String.fromCharCodes(header, start, end);
  return int.parse(sizeStr, radix: 8);
}

/// Check if a 512-byte block is all zeros (end-of-archive marker).
bool _isZeroBlock(Uint8List block) {
  for (var i = 0; i < 512; i++) {
    if (block[i] != 0) return false;
  }
  return true;
}
