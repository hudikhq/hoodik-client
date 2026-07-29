import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Binary fixtures used by the Patrol E2E suite (spec §4).
///
/// Files are generated on-disk in a temp directory so the repo stays lean
/// — no LFS, no binary blobs in git. Call [Fixtures.prepare] once from
/// `setUpAll` and [Fixtures.cleanup] from `tearDownAll`.
class Fixtures {
  Fixtures._(this.rootDir);

  final Directory rootDir;

  late final File png2mb;
  late final File text500kb;
  late final File pdf10mb;
  late final File video30s;
  late final File binary100mb;

  /// True when a real video asset is bundled; false when the 30s.mp4
  /// fixture only exists as a tiny synthetic placeholder. Preview-video
  /// tests should `skip` unless this is true.
  bool videoIsReal = false;

  static Future<Fixtures> prepare() async {
    final root = await Directory.systemTemp.createTemp('hoodik_e2e_');
    final f = Fixtures._(root);
    await f._write();
    return f;
  }

  Future<void> cleanup() async {
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
  }

  Future<void> _write() async {
    png2mb = File('${rootDir.path}/2mb.png');
    text500kb = File('${rootDir.path}/500kb.txt');
    pdf10mb = File('${rootDir.path}/10mb.pdf');
    video30s = File('${rootDir.path}/30s.mp4');
    binary100mb = File('${rootDir.path}/100mb.bin');

    await png2mb.writeAsBytes(_synthesizePng(targetBytes: 2 * 1024 * 1024));
    await text500kb.writeAsString(_randomAscii(500 * 1024));
    await pdf10mb.writeAsBytes(_synthesizePdf(targetBytes: 10 * 1024 * 1024));
    await _writeRandomBytes(video30s, 64 * 1024);
    await _writeRandomBytes(binary100mb, 100 * 1024 * 1024);
  }

  /// Builds a valid 8-bit RGBA PNG with an IDAT chunk padded by random
  /// pixel data until the encoded file crosses [targetBytes]. Uses
  /// uncompressed zlib blocks so the payload bytes equal the pixel bytes
  /// plus a small constant overhead.
  static Uint8List _synthesizePng({required int targetBytes}) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    // Square-ish canvas: 4 bytes per pixel + 1 filter byte per row.
    final side = max(1, sqrt(targetBytes / 4).floor());
    final rgba = Uint8List(side * side * 4);
    Random.secure().fillBytes(rgba);
    final filtered = Uint8List(side * (1 + side * 4));
    for (int y = 0; y < side; y++) {
      filtered[y * (1 + side * 4)] = 0;
      filtered.setRange(
        y * (1 + side * 4) + 1,
        (y + 1) * (1 + side * 4),
        rgba,
        y * side * 4,
      );
    }
    final zlibBlock = _zlibUncompressed(filtered);

    final bytes = BytesBuilder();
    bytes.add(signature);
    bytes.add(_chunk('IHDR', _ihdr(side, side)));
    bytes.add(_chunk('IDAT', zlibBlock));
    bytes.add(_chunk('IEND', const []));
    return bytes.toBytes();
  }

  /// Builds a PDF that a renderer will accept: a single page referencing
  /// a stream padded to reach [targetBytes]. Random filler keeps the
  /// bytes incompressible for realistic transfer timing.
  static Uint8List _synthesizePdf({required int targetBytes}) {
    final pad = Uint8List(max(0, targetBytes - 1024));
    Random.secure().fillBytes(pad);

    final out = BytesBuilder();
    void write(String s) => out.add(s.codeUnits);

    write('%PDF-1.4\n');
    final offsets = <int>[0];
    offsets.add(out.length);
    write('1 0 obj <</Type/Catalog/Pages 2 0 R>> endobj\n');
    offsets.add(out.length);
    write('2 0 obj <</Type/Pages/Kids[3 0 R]/Count 1>> endobj\n');
    offsets.add(out.length);
    write(
      '3 0 obj <</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]/Contents 4 0 R>> endobj\n',
    );
    offsets.add(out.length);
    write('4 0 obj <</Length ${pad.length}>>\nstream\n');
    out.add(pad);
    write('\nendstream\nendobj\n');

    final xrefOffset = out.length;
    write('xref\n0 ${offsets.length}\n');
    write('0000000000 65535 f \n');
    for (int i = 1; i < offsets.length; i++) {
      write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
    }
    write(
      'trailer <</Size ${offsets.length}/Root 1 0 R>>\nstartxref\n$xrefOffset\n%%EOF\n',
    );
    return out.toBytes();
  }

  static String _randomAscii(int length) {
    final rnd = Random.secure();
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n';
    final buf = StringBuffer();
    for (int i = 0; i < length; i++) {
      buf.write(alphabet[rnd.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }

  /// Streams random bytes in 1 MB chunks to avoid an OOM spike on the
  /// 100 MB fixture. `RandomAccessFile.writeFrom` is used because a raw
  /// `writeAsBytes` holds the full buffer in memory.
  static Future<void> _writeRandomBytes(File file, int totalBytes) async {
    final rnd = Random.secure();
    final chunk = Uint8List(1024 * 1024);
    final sink = await file.open(mode: FileMode.write);
    try {
      int written = 0;
      while (written < totalBytes) {
        rnd.fillBytes(chunk);
        final toWrite = (totalBytes - written) < chunk.length
            ? totalBytes - written
            : chunk.length;
        await sink.writeFrom(chunk, 0, toWrite);
        written += toWrite;
      }
    } finally {
      await sink.close();
    }
  }

  static List<int> _ihdr(int w, int h) {
    final b = ByteData(13);
    b.setUint32(0, w);
    b.setUint32(4, h);
    b.setUint8(8, 8);
    b.setUint8(9, 6);
    b.setUint8(10, 0);
    b.setUint8(11, 0);
    b.setUint8(12, 0);
    return b.buffer.asUint8List();
  }

  /// Packs [payload] into a single uncompressed deflate block wrapped in
  /// a zlib header + adler32 checksum. Avoids pulling in a zlib package.
  static List<int> _zlibUncompressed(List<int> payload) {
    final out = BytesBuilder();
    out.add([0x78, 0x01]);
    int offset = 0;
    while (offset < payload.length) {
      final remaining = payload.length - offset;
      final take = remaining > 65535 ? 65535 : remaining;
      final last = (offset + take) >= payload.length ? 1 : 0;
      out.addByte(last);
      out.addByte(take & 0xff);
      out.addByte((take >> 8) & 0xff);
      out.addByte((~take) & 0xff);
      out.addByte(((~take) >> 8) & 0xff);
      out.add(payload.sublist(offset, offset + take));
      offset += take;
    }
    final adler = _adler32(payload);
    out.addByte((adler >> 24) & 0xff);
    out.addByte((adler >> 16) & 0xff);
    out.addByte((adler >> 8) & 0xff);
    out.addByte(adler & 0xff);
    return out.toBytes();
  }

  static int _adler32(List<int> data) {
    int a = 1, b = 0;
    for (final byte in data) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }
    return (b << 16) | a;
  }

  static List<int> _chunk(String type, List<int> data) {
    final out = BytesBuilder();
    final len = data.length;
    out.addByte((len >> 24) & 0xff);
    out.addByte((len >> 16) & 0xff);
    out.addByte((len >> 8) & 0xff);
    out.addByte(len & 0xff);
    out.add(type.codeUnits);
    out.add(data);
    final crc = _crc32([...type.codeUnits, ...data]);
    out.addByte((crc >> 24) & 0xff);
    out.addByte((crc >> 16) & 0xff);
    out.addByte((crc >> 8) & 0xff);
    out.addByte(crc & 0xff);
    return out.toBytes();
  }

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      c = ((c & 1) != 0) ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(List<int> data) {
    int c = 0xFFFFFFFF;
    for (final b in data) {
      c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }
}

extension _RandomBytes on Random {
  void fillBytes(Uint8List buf) {
    for (int i = 0; i < buf.length; i++) {
      buf[i] = nextInt(256);
    }
  }
}
