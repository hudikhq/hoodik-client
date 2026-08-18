import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';

/// Records every request and replies with an empty JSON object/list.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Object body;

  _RecordingAdapter({this.body = const <String, dynamic>{}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient client, _RecordingAdapter adapter}) build({
  Object body = const <String, dynamic>{},
}) {
  final adapter = _RecordingAdapter(body: body);
  final client = ApiClient.createTemporary(baseUrl: 'https://example.test');
  client.dio.httpClientAdapter = adapter;
  return (client: client, adapter: adapter);
}

/// Every listing call asks for `compact` rows — dropping the flag
/// silently reverts to megabyte listings, so pin the wiring here.
void main() {
  test('listFiles asks for compact rows', () async {
    final env = build(body: {'children': <dynamic>[]});
    await env.client.files.listFiles();

    expect(env.adapter.requests.single.queryParameters['compact'], true);
  });

  test('searchFiles asks for compact rows', () async {
    final env = build(body: const <dynamic>[]);
    await env.client.search.searchFiles(rootTags: ['${'a' * 64}:1']);

    final data = env.adapter.requests.single.data as Map<String, dynamic>;
    expect(data['compact'], true);
  });

  test('getSharesMine asks for compact rows', () async {
    final env = build(
      body: {'items': <dynamic>[], 'total': 0, 'limit': 20, 'offset': 0},
    );
    await env.client.shares.getSharesMine();

    expect(env.adapter.requests.single.queryParameters['compact'], true);
  });

  test('links list asks for compact rows', () async {
    final env = build(body: const <dynamic>[]);
    await env.client.links.list();

    expect(env.adapter.requests.single.queryParameters['compact'], true);
  });
}
