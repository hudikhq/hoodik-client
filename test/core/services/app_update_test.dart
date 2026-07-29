import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/app_update.dart';

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

Map<String, dynamic> _lookup(String version, {String? trackViewUrl}) => {
  'resultCount': 1,
  'results': [
    {'version': version, 'trackViewUrl': ?trackViewUrl},
  ],
};

void main() {
  group('AppStoreVersionFetcher', () {
    test('parses version and trackViewUrl from a lookup response', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody(
          _lookup('2.0.1', trackViewUrl: 'https://apps.apple.com/app/id123'),
        ),
      );
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      final result = await fetcher.fetch();

      expect(result, isNotNull);
      expect(result!.version, '2.0.1');
      expect(result.storeUrl, 'https://apps.apple.com/app/id123');
    });

    test('queries the iTunes lookup endpoint with the bundle id', () async {
      final adapter = _ScriptedAdapter((_) => _jsonBody(_lookup('1.0.0')));
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      await fetcher.fetch();

      final uri = adapter.requests.single.uri;
      expect(uri.path, '/lookup');
      expect(uri.host, 'itunes.apple.com');
      expect(uri.queryParameters['bundleId'], 'com.hudikhq.hoodik');
    });

    test('empty storeUrl when trackViewUrl is absent', () async {
      final adapter = _ScriptedAdapter((_) => _jsonBody(_lookup('3.1.4')));
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      final result = await fetcher.fetch();
      expect(result!.version, '3.1.4');
      expect(result.storeUrl, '');
    });

    test('returns null when results is empty (app not found)', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({'resultCount': 0, 'results': <dynamic>[]}),
      );
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null on non-200 status', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({'results': <dynamic>[]}, status: 503),
      );
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null when version is missing', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({
          'resultCount': 1,
          'results': [
            {'trackViewUrl': 'https://apps.apple.com/app/id123'},
          ],
        }),
      );
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null when version is the wrong type', () async {
      final adapter = _ScriptedAdapter(
        (_) => _jsonBody({
          'resultCount': 1,
          'results': [
            {'version': 201},
          ],
        }),
      );
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

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
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });

    test('returns null when the body is not a JSON object', () async {
      final adapter = _ScriptedAdapter(
        (_) => ResponseBody.fromBytes(
          utf8.encode('[]'),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      final fetcher = AppStoreVersionFetcher(dio: _dioWith(adapter));

      expect(await fetcher.fetch(), isNull);
    });
  });

  group('appUpdateAvailable', () {
    const store = AppStoreVersion(version: '2.0.1', storeUrl: '');

    test('true when the store version is strictly newer', () {
      expect(appUpdateAvailable(current: '2.0.0', store: store), isTrue);
    });

    test('false when running the same version as the store', () {
      expect(appUpdateAvailable(current: '2.0.1', store: store), isFalse);
    });

    test('false when running ahead of the store (unreleased build)', () {
      expect(appUpdateAvailable(current: '2.1.0', store: store), isFalse);
    });

    test('false when the running version is unknown', () {
      expect(appUpdateAvailable(current: null, store: store), isFalse);
    });

    test('false when the store version is unknown (Android / offline)', () {
      expect(appUpdateAvailable(current: '2.0.0', store: null), isFalse);
    });
  });
}
