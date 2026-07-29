import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/auth_client.dart';

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
      captured.data = jsonDecode(utf8.decode(Uint8List.fromList(chunks)));
    }
    requests.add(captured);

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

  _Reply(this.statusCode, this.bytes, this.headers);

  factory _Reply.json(Map<String, dynamic> body, {int status = 200}) {
    return _Reply(status, utf8.encode(jsonEncode(body)), {
      'content-type': ['application/json'],
    });
  }

  factory _Reply.empty({int status = 204}) {
    return _Reply(status, const [], {
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
  group('AuthClient.signupRegisterStart', () {
    test(
      'POSTs email + registration_request and returns the response',
      () async {
        final env = _buildDio([
          _Reply.json({'registration_response': 'srv-resp'}),
        ]);
        final client = AuthClient(env.dio);

        final resp = await client.signupRegisterStart(
          email: 'new@test.io',
          registrationRequest: 'client-req',
        );

        expect(resp, 'srv-resp');
        final req = env.adapter.requests.single;
        expect(req.method, 'POST');
        expect(req.path, '/api/auth/register/pake/start');
        expect(req.data, {
          'email': 'new@test.io',
          'registration_request': 'client-req',
        });
      },
    );
  });

  group('AuthClient.register', () {
    test(
      'sends the exact v2 field names with key_type curve25519 and no password',
      () async {
        final env = _buildDio([
          _Reply.json({
            'user': {
              'id': 'u1',
              'email': 'new@test.io',
              'pubkey': 'ED-PUB',
              'wrapping_pubkey': 'X-PUB',
              'fingerprint': 'FP',
              'encrypted_private_key': 'ENV',
              'key_type': 'curve25519',
              'security_version': 1,
            },
            'session': {'expires_at': 1700000000},
          }, status: 201),
        ]);
        final client = AuthClient(env.dio);

        final resp = await client.register(
          email: 'new@test.io',
          pubkey: 'ED-PUB',
          wrappingPubkey: 'X-PUB',
          fingerprint: 'FP',
          encryptedPrivateKey: 'ENV',
          opaqueRegistrationUpload: 'OPAQUE-UPLOAD',
        );

        expect(resp, isNotNull);
        expect(resp!.securityVersion, 1);
        expect(resp.keyType, 'curve25519');
        expect(resp.wrappingPubkey, 'X-PUB');

        final body = env.adapter.requests.single.data as Map;
        expect(env.adapter.requests.single.path, '/api/auth/register');
        expect(body['email'], 'new@test.io');
        expect(body['pubkey'], 'ED-PUB');
        expect(body['wrapping_pubkey'], 'X-PUB');
        expect(body['fingerprint'], 'FP');
        expect(body['key_type'], 'curve25519');
        expect(body['encrypted_private_key'], 'ENV');
        expect(body['opaque_registration_upload'], 'OPAQUE-UPLOAD');
        // The server refuses a plaintext password on the v2 register surface.
        expect(body.containsKey('password'), isFalse);
        // Optional fields are omitted when null, not sent as null.
        expect(body.containsKey('secret'), isFalse);
        expect(body.containsKey('token'), isFalse);
        expect(body.containsKey('invitation_id'), isFalse);
      },
    );

    test('includes secret, token and invitation_id when provided', () async {
      final env = _buildDio([
        _Reply.json({
          'user': {'id': 'u1', 'email': 'new@test.io'},
          'session': {'expires_at': 1700000000},
        }, status: 201),
      ]);
      final client = AuthClient(env.dio);

      await client.register(
        email: 'new@test.io',
        pubkey: 'ED-PUB',
        wrappingPubkey: 'X-PUB',
        fingerprint: 'FP',
        encryptedPrivateKey: 'ENV',
        opaqueRegistrationUpload: 'OPAQUE-UPLOAD',
        secret: 'S',
        token: '123456',
        invitationId: 'inv-1',
      );

      final body = env.adapter.requests.single.data as Map;
      expect(body['secret'], 'S');
      expect(body['token'], '123456');
      expect(body['invitation_id'], 'inv-1');
    });

    test(
      'returns null when the server enforces email activation (204)',
      () async {
        final env = _buildDio([_Reply.empty(status: 204)]);
        final client = AuthClient(env.dio);

        final resp = await client.register(
          email: 'new@test.io',
          pubkey: 'ED-PUB',
          wrappingPubkey: 'X-PUB',
          fingerprint: 'FP',
          encryptedPrivateKey: 'ENV',
          opaqueRegistrationUpload: 'OPAQUE-UPLOAD',
        );

        expect(resp, isNull);
      },
    );
  });
}
