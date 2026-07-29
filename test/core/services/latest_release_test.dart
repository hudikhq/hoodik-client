import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/latest_release.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._reply);
  final FutureOr<ResponseBody> Function(RequestOptions) _reply;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Map<String, dynamic> body, {int status = 200}) {
  return ResponseBody.fromBytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

Dio _dioWith(_ScriptedAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('LatestReleaseFetcher', () {
    test('parses tag_name and html_url from a 200 response', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({
          'tag_name': 'v1.15.0',
          'html_url': 'https://github.com/hudikhq/hoodik/releases/tag/v1.15.0',
          'name': 'Release v1.15.0',
        }),
      );
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      final release = await fetcher.fetch();

      expect(release, isNotNull);
      expect(release!.version, '1.15.0');
      expect(
        release.htmlUrl,
        'https://github.com/hudikhq/hoodik/releases/tag/v1.15.0',
      );
    });

    test('targets the hudikhq/hoodik repo by default', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({'tag_name': 'v1.0.0', 'html_url': ''}),
      );
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      await fetcher.fetch();

      expect(
        adapter.requests.single.uri.toString(),
        'https://api.github.com/repos/hudikhq/hoodik/releases/latest',
      );
    });

    test('strips leading v from the tag name', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({'tag_name': 'V2.0.0', 'html_url': ''}),
      );
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      final release = await fetcher.fetch();
      expect(release!.version, '2.0.0');
    });

    test('returns null on non-200 status', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({'message': 'Not Found'}, status: 404),
      );
      // Dio raises by default on non-2xx; the fetcher's catch-all swallows it.
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null when tag_name is missing', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({'html_url': 'https://example.com'}),
      );
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null when tag_name is the wrong type', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({'tag_name': 42, 'html_url': ''}),
      );
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null on transport failure', () async {
      final adapter = _ScriptedAdapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'no network',
        ),
      );
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null when the response body is not a JSON object', () async {
      final adapter = _ScriptedAdapter(
        (_) => ResponseBody.fromBytes(
          utf8.encode('"a bare string"'),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      final fetcher = LatestReleaseFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });
  });
}
