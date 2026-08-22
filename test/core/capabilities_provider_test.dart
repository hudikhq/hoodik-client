import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';

/// What the app decides when the capability probe does not come back cleanly.
///
/// Failing closed is right — a server that cannot answer must not have its
/// sharing UI shown — but this provider outlives the session, so the answer it
/// caches is the answer for as long as the user stays logged in. A phone
/// changing networks at launch is exactly the kind of thing that loses one
/// request, and paying for it with a session of hidden sharing and relayed
/// chunks would be invisible: nothing fails, everything is just quietly worse.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.replies);

  /// One entry per expected request: a status and a body, or null to fail the
  /// request the way an unreachable server does.
  final List<(int, Map<String, dynamic>)?> replies;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reply = replies[calls.clamp(0, replies.length - 1)];
    calls += 1;

    if (reply == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'nothing answered',
      );
    }

    final (status, body) = reply;

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._shares);

  final SharesClient _shares;

  @override
  SharesClient get shares => _shares;
}

ProviderContainer _containerFor(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://server.test'))
    ..httpClientAdapter = adapter;

  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(_FakeApiClient(SharesClient(dio))),
    ],
  );
}

const _advertisement = {
  'sharing': {
    'enabled': true,
    'roles': ['reader'],
  },
  'editable_folders': true,
  'share_groups': true,
  'audit_log': false,
  'fork': true,
  'direct_transfer': true,
};

void main() {
  test('reads the advertisement the server sends', () async {
    final container = _containerFor(_Adapter([(200, _advertisement)]));
    addTearDown(container.dispose);

    final caps = await container.read(shareCapabilitiesProvider.future);

    expect(caps.sharingEnabled, isTrue);
    expect(caps.directTransfer, isTrue);
  });

  test('a server that answered is taken at its word', () async {
    // A pre-1.16 server 404s, which is an answer: it does not speak this
    // protocol, and asking again would only produce the same 404.
    final adapter = _Adapter([(404, const {})]);
    final container = _containerFor(adapter);
    addTearDown(container.dispose);

    final caps = await container.read(shareCapabilitiesProvider.future);

    expect(caps.sharingEnabled, isFalse);
    expect(caps.directTransfer, isFalse);
    expect(adapter.calls, 1, reason: 'a 404 is settled; do not re-ask');
  });

  test('a request that never landed fails closed and is asked again', () async {
    final adapter = _Adapter([null, (200, _advertisement)]);
    final container = _containerFor(adapter);
    addTearDown(container.dispose);

    final first = await container.read(shareCapabilitiesProvider.future);
    expect(
      first.sharingEnabled,
      isFalse,
      reason: 'nothing answered, so nothing is advertised',
    );

    // The retry is scheduled rather than immediate; drive it by hand instead
    // of waiting out the delay.
    container.invalidate(shareCapabilitiesProvider);
    final second = await container.read(shareCapabilitiesProvider.future);

    expect(
      second.sharingEnabled,
      isTrue,
      reason: 'the session must not stay pinned to a probe that was lost',
    );
    expect(second.directTransfer, isTrue);
  });
}
