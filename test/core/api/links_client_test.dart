import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/links_client.dart';

/// In-memory Dio adapter that records every request and replies with
/// scripted responses. Lets us assert URL, query, body, and headers
/// without any real network I/O.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<_Reply> replies;
  int _index = 0;

  _RecordingAdapter(this.replies);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final captured = options.copyWith();
    if (requestStream != null) {
      final chunks = <int>[];
      await for (final c in requestStream) {
        chunks.addAll(c);
      }
      final bytes = Uint8List.fromList(chunks);
      final contentType = options.contentType ?? '';
      if (contentType.contains('application/json')) {
        captured.data = jsonDecode(utf8.decode(bytes));
      } else {
        captured.data = bytes;
      }
    }
    requests.add(captured);

    if (_index >= replies.length) {
      throw StateError(
        'Unexpected request ${options.method} ${options.path} — '
        'no reply scripted',
      );
    }
    final reply = replies[_index++];
    return ResponseBody.fromBytes(
      reply.bytes,
      reply.statusCode,
      headers: reply.headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Reply {
  final int statusCode;
  final List<int> bytes;
  final Map<String, List<String>> headers;

  _Reply._(this.statusCode, this.bytes, this.headers);

  factory _Reply.json(Map<String, dynamic> body, {int status = 200}) {
    final encoded = utf8.encode(jsonEncode(body));
    return _Reply._(status, encoded, {
      'content-type': ['application/json'],
    });
  }

  factory _Reply.jsonList(List<dynamic> body, {int status = 200}) {
    final encoded = utf8.encode(jsonEncode(body));
    return _Reply._(status, encoded, {
      'content-type': ['application/json'],
    });
  }

  factory _Reply.empty({int status = 200}) {
    return _Reply._(status, const [], {
      'content-type': ['application/json'],
    });
  }
}

/// Build a Dio with the given scripted replies so we can exercise
/// [LinksClient] against a known server fixture.
({Dio dio, _RecordingAdapter adapter}) _buildDio(List<_Reply> replies) {
  final adapter = _RecordingAdapter(replies);
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test',
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

void main() {
  group('LinksClient.list', () {
    test('GET /api/links without withExpired param by default', () async {
      final env = _buildDio([
        _Reply.jsonList([
          {'id': 'link-1', 'file_id': 'f1'},
          {'id': 'link-2', 'file_id': 'f2'},
        ]),
      ]);
      final client = LinksClient(env.dio);

      final result = await client.list();

      expect(result.length, 2);
      expect(env.adapter.requests.single.method, 'GET');
      expect(env.adapter.requests.single.path, '/api/links');
      expect(
        env.adapter.requests.single.queryParameters.containsKey('with_expired'),
        isFalse,
      );
    });

    test('GET /api/links?with_expired=true when withExpired is true', () async {
      final env = _buildDio([_Reply.jsonList([])]);
      final client = LinksClient(env.dio);

      await client.list(withExpired: true);

      expect(env.adapter.requests.single.queryParameters['with_expired'], true);
    });

    test('returns empty list when server returns non-list payload', () async {
      final env = _buildDio([
        _Reply.json({'unexpected': true}),
      ]);
      final client = LinksClient(env.dio);

      final result = await client.list();

      expect(result, isEmpty);
    });
  });

  group('LinksClient.create', () {
    test('POST /api/links forwards body and returns response map', () async {
      final env = _buildDio([
        _Reply.json({'id': 'new-link', 'file_id': 'f1'}),
      ]);
      final client = LinksClient(env.dio);

      final payload = <String, dynamic>{
        'file_id': 'f1',
        'signature': 'sig-hex',
        'encrypted_name': 'enc-name',
        'encrypted_link_key': 'enc-link-key',
        'encrypted_file_key': 'enc-file-key',
      };

      final result = await client.create(payload);

      expect(result['id'], 'new-link');
      final req = env.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/links');
      expect(req.data, payload);
    });
  });

  group('LinksClient.delete', () {
    test('DELETE /api/links/{id}', () async {
      final env = _buildDio([_Reply.empty()]);
      final client = LinksClient(env.dio);

      await client.delete('link-abc');

      final req = env.adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/links/link-abc');
    });

    test('propagates 404 as DioException', () async {
      final env = _buildDio([_Reply.empty(status: 404)]);
      final client = LinksClient(env.dio);

      await expectLater(
        client.delete('does-not-exist'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('LinksClient.updateExpiry', () {
    test('PUT /api/links/{id} with expires_at unix seconds', () async {
      final env = _buildDio([
        _Reply.json({'id': 'link-xyz', 'expires_at': 1800000000}),
      ]);
      final client = LinksClient(env.dio);

      final result = await client.updateExpiry(
        linkId: 'link-xyz',
        expiresAt: 1800000000,
      );

      expect(result['expires_at'], 1800000000);
      final req = env.adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/links/link-xyz');
      expect(req.data, {'expires_at': 1800000000});
    });

    test(
      'PUT /api/links/{id} with expires_at null when clearing expiry',
      () async {
        final env = _buildDio([
          _Reply.json({'id': 'link-xyz'}),
        ]);
        final client = LinksClient(env.dio);

        await client.updateExpiry(linkId: 'link-xyz');

        expect(env.adapter.requests.single.data, {'expires_at': null});
      },
    );

    test('propagates 401 as DioException', () async {
      final env = _buildDio([_Reply.empty(status: 401)]);
      final client = LinksClient(env.dio);

      await expectLater(
        client.updateExpiry(linkId: 'any', expiresAt: 0),
        throwsA(isA<DioException>()),
      );
    });
  });
}
