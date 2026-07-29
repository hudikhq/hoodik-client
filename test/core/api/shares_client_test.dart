import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;

/// In-memory Dio adapter that records every request and replies with
/// scripted responses, so we can assert URL, query, and body without any
/// real network I/O. Same shape as the adapter in `links_client_test.dart`.
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
    return _Reply._(status, utf8.encode(jsonEncode(body)), {
      'content-type': ['application/json'],
    });
  }

  factory _Reply.jsonList(List<dynamic> body, {int status = 200}) {
    return _Reply._(status, utf8.encode(jsonEncode(body)), {
      'content-type': ['application/json'],
    });
  }

  factory _Reply.empty({int status = 200}) {
    return _Reply._(status, const [], {
      'content-type': ['application/json'],
    });
  }
}

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
  group('SharesClient.discoverUser', () {
    test('GET /api/users/discover with email and parses the row', () async {
      final env = _buildDio([
        _Reply.json({
          'user_id': 'u-1',
          'email': 'bob@example.test',
          'pubkey': 'PUB',
          'fingerprint': 'FP',
        }),
      ]);

      final user = await SharesClient(env.dio).discoverUser('bob@example.test');

      expect(user, isNotNull);
      expect(user!.userId, 'u-1');
      expect(user.email, 'bob@example.test');
      final req = env.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/api/users/discover');
      expect(req.queryParameters['email'], 'bob@example.test');
    });

    test('404 user_not_found returns null', () async {
      final env = _buildDio([
        _Reply.json({'message': 'user_not_found'}, status: 404),
      ]);

      final user = await SharesClient(env.dio).discoverUser('nobody@x.test');

      expect(user, isNull);
    });

    test('400 cannot_discover_self throws typed exception', () async {
      final env = _buildDio([
        _Reply.json({'message': 'cannot_discover_self'}, status: 400),
      ]);

      await expectLater(
        SharesClient(env.dio).discoverUser('me@example.test'),
        throwsA(
          isA<DiscoverException>().having(
            (e) => e.kind,
            'kind',
            DiscoverErrorKind.cannotDiscoverSelf,
          ),
        ),
      );
    });

    test('429 rate_limited throws rateLimited with Retry-After', () async {
      final env = _buildDio([
        _Reply._(429, utf8.encode(jsonEncode({'message': 'rate_limited'})), {
          'content-type': ['application/json'],
          'retry-after': ['30'],
        }),
      ]);

      try {
        await SharesClient(env.dio).discoverUser('bob@example.test');
        fail('expected DiscoverException');
      } on DiscoverException catch (e) {
        expect(e.kind, DiscoverErrorKind.rateLimited);
        expect(e.retryAfter, const Duration(seconds: 30));
      }
    });

    test('429 without Retry-After header tolerates the absence', () async {
      final env = _buildDio([
        _Reply.json({'message': 'rate_limited'}, status: 429),
      ]);

      try {
        await SharesClient(env.dio).discoverUser('bob@example.test');
        fail('expected DiscoverException');
      } on DiscoverException catch (e) {
        expect(e.kind, DiscoverErrorKind.rateLimited);
        expect(e.retryAfter, isNull);
      }
    });

    test('503 sharing_disabled throws sharingDisabled', () async {
      final env = _buildDio([
        _Reply.json({'message': 'sharing_disabled'}, status: 503),
      ]);

      await expectLater(
        SharesClient(env.dio).discoverUser('bob@example.test'),
        throwsA(
          isA<DiscoverException>().having(
            (e) => e.kind,
            'kind',
            DiscoverErrorKind.sharingDisabled,
          ),
        ),
      );
    });

    test('unmapped status rethrows the raw DioException', () async {
      final env = _buildDio([_Reply.empty(status: 500)]);

      await expectLater(
        SharesClient(env.dio).discoverUser('bob@example.test'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('SharesClient.createShare', () {
    test('POST /api/shares forwards envelope and unwraps {shares}', () async {
      final env = _buildDio([
        _Reply.json({
          'shares': [
            {
              'file_id': 'f-1',
              'recipient_id': 'u-2',
              'recipient_email': 'bob@example.test',
              'recipient_pubkey_fingerprint': 'FP',
              'share_role': 'editor',
              'created_at': 100,
            },
          ],
        }, status: 201),
      ]);

      final envelope = <String, dynamic>{
        'payload_der': 'der',
        'signature': 'sig',
        'entries': [],
        'event_signature': 'evt',
      };

      final shares = await SharesClient(env.dio).createShare(envelope);

      expect(shares, hasLength(1));
      expect(shares.single.fileId, 'f-1');
      expect(shares.single.shareRole, ShareRole.editor);
      final req = env.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/shares');
      expect(req.data, envelope);
    });
  });

  group('SharesClient.revokeShare', () {
    test('DELETE /api/shares/{file}/{user} forwards the body', () async {
      final env = _buildDio([_Reply.empty(status: 204)]);

      final body = <String, dynamic>{'event_signature': 'sig', 'timestamp': 7};
      await SharesClient(env.dio).revokeShare('f-1', 'u-2', body);

      final req = env.adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/shares/f-1/u-2');
      expect(req.data, body);
    });
  });

  group('SharesClient.getShareRecipients', () {
    test('GET /api/shares/{file} maps the roster', () async {
      final env = _buildDio([
        _Reply.jsonList([
          {
            'file_id': 'f-1',
            'recipient_id': 'u-2',
            'recipient_email': 'bob@example.test',
            'recipient_pubkey_fingerprint': 'FP',
            'share_role': 'reader',
            'created_at': 1,
          },
        ]),
      ]);

      final roster = await SharesClient(env.dio).getShareRecipients('f-1');

      expect(roster, hasLength(1));
      expect(roster.single.recipientId, 'u-2');
      expect(env.adapter.requests.single.path, '/api/shares/f-1');
    });
  });

  group('SharesClient.getSharesMine', () {
    test('GET /api/shares/mine omits paging params when null', () async {
      final env = _buildDio([
        _Reply.json({'items': [], 'total': 0, 'limit': 0, 'offset': 0}),
      ]);

      await SharesClient(env.dio).getSharesMine();

      final req = env.adapter.requests.single;
      expect(req.path, '/api/shares/mine');
      expect(req.queryParameters.containsKey('limit'), isFalse);
      expect(req.queryParameters.containsKey('offset'), isFalse);
    });

    test('forwards limit and offset and parses the page', () async {
      final env = _buildDio([
        _Reply.json({
          'items': [
            {
              'file_id': 'f-1',
              'mime': 'text/plain',
              'encrypted_name': 'enc',
              'cipher': 'aegis128l',
              'editable': true,
              'share_role': 'co-owner',
              'encrypted_key': 'k',
              'created_at': 5,
              'owner_id': 'o-1',
              'owner_email': 'alice@example.test',
              'owner_pubkey': 'PUB',
              'owner_pubkey_fingerprint': 'FP',
            },
          ],
          'total': 1,
          'limit': 25,
          'offset': 50,
        }),
      ]);

      final page = await SharesClient(
        env.dio,
      ).getSharesMine(limit: 25, offset: 50);

      expect(page.total, 1);
      expect(page.items.single.shareRole, ShareRole.coOwner);
      final req = env.adapter.requests.single;
      expect(req.queryParameters['limit'], 25);
      expect(req.queryParameters['offset'], 50);
    });
  });

  group('SharesClient.getSharesMineBy', () {
    test('GET /api/shares/mine/by/{user}', () async {
      final env = _buildDio([
        _Reply.json({'items': [], 'total': 0, 'limit': 0, 'offset': 0}),
      ]);

      await SharesClient(env.dio).getSharesMineBy('u-7', limit: 10);

      final req = env.adapter.requests.single;
      expect(req.path, '/api/shares/mine/by/u-7');
      expect(req.queryParameters['limit'], 10);
    });
  });

  group('SharesClient.getCapabilities', () {
    test('parses the advertised capabilities', () async {
      final env = _buildDio([
        _Reply.json({
          'sharing': {
            'enabled': true,
            'roles': ['reader', 'editor', 'co-owner'],
          },
          'editable_folders': true,
          'share_groups': true,
          'audit_log': false,
          'fork': true,
        }),
      ]);

      final caps = await SharesClient(env.dio).getCapabilities();

      expect(caps.sharingEnabled, isTrue);
      expect(caps.roles, [
        ShareRole.reader,
        ShareRole.editor,
        ShareRole.coOwner,
      ]);
      expect(caps.fork, isTrue);
    });

    test('404 (pre-1.16 server) fails closed to disabled', () async {
      final env = _buildDio([_Reply.empty(status: 404)]);

      final caps = await SharesClient(env.dio).getCapabilities();

      expect(caps.sharingEnabled, isFalse);
      expect(caps.roles, isEmpty);
    });

    test('unparseable body fails closed to disabled', () async {
      final env = _buildDio([_Reply.jsonList([])]);

      final caps = await SharesClient(env.dio).getCapabilities();

      expect(caps.sharingEnabled, isFalse);
    });
  });

  group('SharesClient.patchMe', () {
    test('PATCH /api/users/me toggles share notifications', () async {
      final env = _buildDio([
        _Reply.json({'id': 'u-1'}),
      ]);

      await SharesClient(env.dio).patchMe(shareNotificationsEnabled: false);

      final req = env.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/users/me');
      expect(req.data, {'share_notifications_enabled': false});
    });
  });

  group('SharesClient.forkFile', () {
    test('POST /api/shares/{file}/fork forwards the body and returns the '
        'new file id', () async {
      final env = _buildDio([
        _Reply.json({'file_id': 'new-1', 'created_at': 100}, status: 201),
      ]);

      final body = <String, dynamic>{
        'new_file_id': 'new-1',
        'encrypted_metadata': 'name',
        'name_hash': 'hash',
        'mime': 'application/pdf',
        'encrypted_key': 'wrap',
        'event_signature': 'sig',
        'timestamp': 7,
      };

      final id = await SharesClient(env.dio).forkFile('src-1', body);

      expect(id, 'new-1');
      final req = env.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/shares/src-1/fork');
      expect(req.data, body);
    });

    test('throws ForkQuotaExceededError on 409 fork_quota_exceeded', () async {
      final env = _buildDio([
        _Reply.json({'message': 'fork_quota_exceeded'}, status: 409),
      ]);

      expect(
        () => SharesClient(env.dio).forkFile('src-1', const {}),
        throwsA(isA<ForkQuotaExceededError>()),
      );
    });

    test('rethrows other errors untouched (no quota masking)', () async {
      final env = _buildDio([
        _Reply.json({'message': 'forbidden_not_forkable'}, status: 403),
      ]);

      expect(
        () => SharesClient(env.dio).forkFile('src-1', const {}),
        throwsA(isA<DioException>()),
      );
    });
  });
}
