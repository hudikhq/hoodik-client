import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/api/search_client.dart';

class _FakeDio extends Fake implements Dio {
  Object? postResponse = <dynamic>[];
  String? lastPostPath;
  Object? lastPostData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: postResponse as T?,
    );
  }
}

void main() {
  group('SearchClient wire privacy', () {
    test(
      'sends keyed tags only — the body has no plaintext field',
      () async {
        final dio = _FakeDio();
        final client = SearchClient(dio);

        final tags = ['a' * 32, 'b' * 32];
        await client.searchFiles(rootTags: tags);

        expect(dio.lastPostPath, '/api/storage/search');
        final body = dio.lastPostData as Map<String, dynamic>;
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
      },
    );

    test('forwards content hash, dir scope and editable filter', () async {
      final dio = _FakeDio();
      final client = SearchClient(dio);

      final sha256 = 'c' * 64;
      await client.searchFiles(
        rootTags: const [],
        hash: sha256,
        dirId: 'dir-1',
        editable: true,
        limit: 50,
        skip: 5,
      );

      final body = dio.lastPostData as Map<String, dynamic>;
      expect(body['hash'], sha256);
      expect(body['dir_id'], 'dir-1');
      expect(body['editable'], true);
      expect(body['limit'], 50);
      expect(body['skip'], 5);
      expect(body.containsKey('search'), isFalse);
    });

    test('returns an empty list when the response is not a list', () async {
      final dio = _FakeDio()..postResponse = {'unexpected': true};
      final client = SearchClient(dio);

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
}
