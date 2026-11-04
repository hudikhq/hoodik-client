import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/files_client.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';

/// Counts requests so a test can assert none left the client.
class _CountingAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests += 1;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeAuth extends Fake implements FilesClientAuth {}

void main() {
  late _CountingAdapter adapter;
  late FilesClient client;

  setUp(() {
    adapter = _CountingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    client = FilesClient(
      dio,
      baseUrl: 'https://example.test',
      auth: _FakeAuth(),
    );
  });

  test('metadata for the Shared with me id never reaches the server', () {
    expect(
      () => client.getFileMetadata(sharedWithMeDirId),
      throwsArgumentError,
    );
    expect(adapter.requests, 0);
  });

  test('creating a folder inside a client-only id is refused', () {
    expect(
      () => client.createDirectory(
        encryptedKey: 'k',
        nameHash: 'h',
        encryptedName: 'n',
        parentDirId: sharedWithMeDirId,
      ),
      throwsArgumentError,
    );
    expect(adapter.requests, 0);
  });

  test('a real id still goes out', () async {
    await client.getFileMetadata('0b9a5c3e-1f2d-4e6a-9b8c-7d6e5f4a3b2c');
    expect(adapter.requests, 1);
  });
}
