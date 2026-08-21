import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/api/search_client.dart';

/// Records each request's raw serialized body — the bytes that actually go on
/// the wire — rather than the Dart object handed to Dio. A wire-privacy
/// assertion is only worth anything against what was serialized.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Uint8List lastBody = Uint8List(0);
  Object? nextResponse = <dynamic>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final chunks = <int>[];
      await for (final c in requestStream) {
        chunks.addAll(c);
      }
      lastBody = Uint8List.fromList(chunks);
    }
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(nextResponse)),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Map<String, dynamic> get lastJson =>
      jsonDecode(utf8.decode(lastBody)) as Map<String, dynamic>;
}

({Dio dio, _RecordingAdapter adapter}) _buildDio() {
  final adapter = _RecordingAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://example.test',
      headers: {'Content-Type': 'application/json'},
    ),
  )..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

void main() {
  group('SearchClient wire privacy', () {
    test('sends keyed tags only — the raw body has no plaintext field', () async {
      final env = _buildDio();
      final client = SearchClient(env.dio);

      final tags = ['a' * 32, 'b' * 32];
      await client.searchFiles(rootTags: tags);

      expect(env.adapter.requests.single.path, '/api/storage/search');
      final body = env.adapter.lastJson;
      expect(body['root_tags'], tags);
      expect(body['file_tags'], isEmpty);
      // The legacy shapes are refused by the server with 426; this build
      // must not send them at all.
      expect(body.containsKey('search'), isFalse);
      expect(body.containsKey('search_tokens_hashed'), isFalse);
      expect(body.containsKey('hash'), isFalse);
      expect(body['limit'], 10);
      expect(body['skip'], 0);
      expect(body['compact'], isTrue);
    });

    test('forwards content hash, dir scope and editable filter', () async {
      final env = _buildDio();
      final client = SearchClient(env.dio);

      final sha256 = 'c' * 64;
      await client.searchFiles(
        rootTags: const [],
        hash: sha256,
        dirId: 'dir-1',
        editable: true,
        limit: 50,
        skip: 5,
      );

      final body = env.adapter.lastJson;
      expect(body['hash'], sha256);
      expect(body['dir_id'], 'dir-1');
      expect(body['editable'], true);
      expect(body['limit'], 50);
      expect(body['skip'], 5);
      expect(body.containsKey('search'), isFalse);
    });

    test('returns an empty list when the response is not a list', () async {
      final env = _buildDio()..adapter.nextResponse = {'unexpected': true};
      final client = SearchClient(env.dio);

      final results = await client.searchFiles(rootTags: const []);

      expect(results, isEmpty);
    });
  });

  group('SearchClient.hashLookup', () {
    test('recognizes every digest length the file rows carry', () {
      expect(SearchClient.hashLookup('d' * 32), 'd' * 32); // MD5
      expect(SearchClient.hashLookup('A' * 40), 'A' * 40); // SHA1, uppercase
      expect(SearchClient.hashLookup('0' * 64), '0' * 64); // SHA256
      expect(SearchClient.hashLookup('f' * 128), 'f' * 128); // BLAKE2b
      expect(SearchClient.hashLookup('  ${'a' * 64}  '), 'a' * 64);
    });

    test('rejects everything that is not digest-shaped', () {
      expect(SearchClient.hashLookup('holiday photos'), isNull);
      expect(SearchClient.hashLookup('f' * 63), isNull);
      expect(SearchClient.hashLookup('g' * 64), isNull);
      expect(SearchClient.hashLookup(''), isNull);
    });

    test('a file id is not a content hash', () {
      expect(
        SearchClient.hashLookup('01234567-89ab-cdef-0123-456789abcdef'),
        isNull,
      );
    });
  });

  group('SearchClient scopes', () {
    // Both surfaces that search — the search screen and the MCP tool — have to
    // send file tags, not just root tags. Without them a query silently covers
    // only what the user owns and reports everything shared with them as
    // absent, which looks identical to the files not existing.
    test('carries both scopes when the caller has incoming shares', () async {
      final env = _buildDio();
      final client = SearchClient(env.dio);

      await client.searchFiles(
        rootTags: ['a' * 32],
        fileTags: ['b' * 32, 'c' * 32],
      );

      final body = env.adapter.lastJson;
      expect(body['root_tags'], ['a' * 32]);
      expect(body['file_tags'], ['b' * 32, 'c' * 32]);
    });

    test('sends an empty file scope rather than omitting it', () async {
      // The server treats a missing list and an empty one the same, but an
      // explicit empty makes "this caller has no incoming shares" visible on
      // the wire instead of ambiguous with "this client forgot to send them".
      final env = _buildDio();
      final client = SearchClient(env.dio);

      await client.searchFiles(rootTags: ['a' * 32]);

      final body = env.adapter.lastJson;
      expect(body.containsKey('file_tags'), isTrue);
      expect(body['file_tags'], isEmpty);
    });
  });
}
