import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/preview/services/chunked_preview_source.dart';
import 'package:hoodik_app/features/preview/services/preview_stream_server.dart';

class _MemorySource implements PreviewRangeSource {
  _MemorySource(this.bytes);

  final Uint8List bytes;

  @override
  int get length => bytes.length;

  @override
  Stream<Uint8List> read(int start, int end) {
    if (length == 0 || start < 0 || start > end || start >= length) {
      return const Stream.empty();
    }
    final last = end >= length ? length - 1 : end;
    return Stream.value(Uint8List.sublistView(bytes, start, last + 1));
  }

  @override
  Future<void> close() async {}
}

class _Reply {
  _Reply(this.status, this.body, this.headers, this.contentLength);

  final int status;
  final Uint8List body;
  final HttpHeaders headers;
  final int contentLength;

  String? get contentRange => headers.value(HttpHeaders.contentRangeHeader);
  String? get acceptRanges => headers.value(HttpHeaders.acceptRangesHeader);
  String? get contentType => headers.value(HttpHeaders.contentTypeHeader);
}

Future<Uint8List> _readAll(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final part in response) {
    builder.add(part);
  }
  return builder.toBytes();
}

Future<_Reply> _get(HttpClient client, Uri uri, {String? range}) async {
  final request = await client.getUrl(uri);
  if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
  final response = await request.close();
  final length = response.contentLength;
  final body = await _readAll(response);
  return _Reply(response.statusCode, body, response.headers, length);
}

Future<_Reply> _head(HttpClient client, Uri uri) async {
  final request = await client.headUrl(uri);
  final response = await request.close();
  final length = response.contentLength;
  await response.drain<void>();
  return _Reply(response.statusCode, Uint8List(0), response.headers, length);
}

Future<List<int>> _collect(Stream<List<int>> stream) async {
  final out = <int>[];
  await for (final part in stream) {
    out.addAll(part);
  }
  return out;
}

void main() {
  group('parseHttpRange', () {
    test('absent or malformed headers mean "serve the whole resource"', () {
      expect(parseHttpRange(null, 100), isA<ServeFull>());
      expect(parseHttpRange('', 100), isA<ServeFull>());
      expect(parseHttpRange('items=0-9', 100), isA<ServeFull>());
      expect(parseHttpRange('bytes=0-9,20-29', 100), isA<ServeFull>());
    });

    test('parses closed, open-ended and suffix ranges', () {
      final closed = parseHttpRange('bytes=10-19', 100);
      expect(closed, isA<ServeRange>());
      expect((closed as ServeRange).start, 10);
      expect(closed.end, 19);

      final open = parseHttpRange('bytes=90-', 100) as ServeRange;
      expect(open.start, 90);
      expect(open.end, 99);

      final suffix = parseHttpRange('bytes=-5', 100) as ServeRange;
      expect(suffix.start, 95);
      expect(suffix.end, 99);
    });

    test('clamps an oversized end and rejects an unsatisfiable start', () {
      final clamped = parseHttpRange('bytes=0-9999', 100) as ServeRange;
      expect(clamped.start, 0);
      expect(clamped.end, 99);

      expect(parseHttpRange('bytes=100-', 100), isA<RangeUnsatisfiable>());
      expect(parseHttpRange('bytes=50-40', 100), isA<RangeUnsatisfiable>());
      expect(parseHttpRange('bytes=-0', 100), isA<RangeUnsatisfiable>());
    });
  });

  group('ChunkedPreviewSource', () {
    test('assembles ranges across chunk boundaries', () async {
      final chunks = {
        0: Uint8List.fromList([1, 2, 3, 4]),
        1: Uint8List.fromList([5, 6, 7, 8]),
        2: Uint8List.fromList([9, 10]),
      };
      var fetches = 0;
      final source = ChunkedPreviewSource(
        length: 10,
        chunkSize: 4,
        fetchChunk: (index) async {
          fetches++;
          return chunks[index]!;
        },
      );

      expect(await _collect(source.read(0, 9)), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      expect(await _collect(source.read(3, 4)), [4, 5]);
      expect(await _collect(source.read(2, 5)), [3, 4, 5, 6]);
      expect(await _collect(source.read(8, 9)), [9, 10]);
      expect(await _collect(source.read(10, 12)), isEmpty);

      expect(fetches, 3);
    });

    test('deduplicates concurrent reads of the same chunk', () async {
      var fetches = 0;
      final source = ChunkedPreviewSource(
        length: 4,
        chunkSize: 4,
        fetchChunk: (index) async {
          fetches++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return Uint8List.fromList([1, 2, 3, 4]);
        },
      );

      final results = await Future.wait([
        _collect(source.read(0, 3)),
        _collect(source.read(0, 3)),
      ]);
      expect(results[0], [1, 2, 3, 4]);
      expect(results[1], [1, 2, 3, 4]);
      expect(fetches, 1);
    });
  });

  group('PreviewStreamServer', () {
    test('serves full, ranged, suffix, head and 416 responses', () async {
      final server = PreviewStreamServer();
      addTearDown(server.stop);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final bytes = Uint8List.fromList(
        List<int>.generate(1000, (i) => i % 256),
      );
      final uri = await server.register(
        source: _MemorySource(bytes),
        contentType: 'video/mp4',
        fileName: 'clip.mp4',
      );

      final full = await _get(client, uri);
      expect(full.status, 200);
      expect(full.acceptRanges, 'bytes');
      expect(full.contentType, 'video/mp4');
      expect(full.body, bytes);

      final ranged = await _get(client, uri, range: 'bytes=10-19');
      expect(ranged.status, 206);
      expect(ranged.contentRange, 'bytes 10-19/1000');
      expect(ranged.body, bytes.sublist(10, 20));

      final tail = await _get(client, uri, range: 'bytes=990-');
      expect(tail.status, 206);
      expect(tail.body, bytes.sublist(990, 1000));

      final suffix = await _get(client, uri, range: 'bytes=-5');
      expect(suffix.status, 206);
      expect(suffix.body, bytes.sublist(995, 1000));

      final unsatisfiable = await _get(client, uri, range: 'bytes=5000-');
      expect(unsatisfiable.status, 416);
      expect(unsatisfiable.contentRange, 'bytes */1000');

      final head = await _head(client, uri);
      expect(head.status, 200);
      expect(head.contentLength, 1000);
    });

    test('rejects unknown tokens and stops serving after unregister', () async {
      final server = PreviewStreamServer();
      addTearDown(server.stop);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final uri = await server.register(
        source: _MemorySource(Uint8List.fromList([1, 2, 3])),
        contentType: 'video/mp4',
      );

      final unknown = await _get(client, uri.replace(path: '/nope/clip.mp4'));
      expect(unknown.status, 404);

      await server.unregister(uri);
      final afterUnregister = await _get(client, uri);
      expect(afterUnregister.status, 404);
    });
  });
}
