import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/auth_client.dart';

/// Captures the request that [AuthClient] puts on the wire and scripts the
/// response, so the migration/keys and migration/complete contracts can be
/// pinned without a live server.
class _FakeDio extends Fake implements Dio {
  Object? getResponse;
  Object? postResponse;
  String? lastPostPath;
  Object? lastPostData;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: getResponse as T?,
    );
  }

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
  late _FakeDio dio;
  late AuthClient client;

  setUp(() {
    dio = _FakeDio();
    client = AuthClient(dio);
  });

  group('migrationKeys', () {
    test('parses the {keys, link_keys} envelope', () async {
      dio.getResponse = {
        'keys': [
          {'file_id': 'f1', 'encrypted_key': 'k1'},
        ],
        'link_keys': [
          {'link_id': 'l1', 'encrypted_link_key': 'e1', 'file_id': 'f9'},
          {'link_id': 'l2', 'encrypted_link_key': 'e2', 'file_id': 'f8'},
        ],
        'next_offset': 500,
      };

      final resp = await client.migrationKeys();

      expect(resp.keys, hasLength(1));
      expect(resp.keys.single, {'file_id': 'f1', 'encrypted_key': 'k1'});
      expect(resp.linkKeys, hasLength(2));
      expect(resp.linkKeys.first, {
        'link_id': 'l1',
        'encrypted_link_key': 'e1',
        'file_id': 'f9',
      });
      expect(resp.nextOffset, 500);
    });

    test('reports a null cursor on the final page', () async {
      dio.getResponse = {
        'keys': <Map<String, dynamic>>[],
        'link_keys': <Map<String, dynamic>>[],
        'next_offset': null,
      };

      final resp = await client.migrationKeys(offset: 500);

      expect(resp.nextOffset, isNull);
    });

    test('tolerates a bare file-key array (no link keys, no cursor)', () async {
      dio.getResponse = [
        {'file_id': 'f1', 'encrypted_key': 'k1'},
      ];

      final resp = await client.migrationKeys();

      expect(resp.keys, hasLength(1));
      expect(resp.linkKeys, isEmpty);
      expect(resp.nextOffset, isNull);
    });
  });

  group('migrationRewrap', () {
    test('posts the batch under the {keys, link_keys} field names', () async {
      dio.postResponse = null;
      final keys = [
        {'file_id': 'f1', 'encrypted_key': 'k1'},
      ];
      final links = [
        {'link_id': 'l1', 'encrypted_link_key': 'e1', 'signature': 's1'},
      ];

      await client.migrationRewrap(keys: keys, linkKeys: links);

      expect(dio.lastPostPath, '/api/auth/migration/rewrap');
      final body = dio.lastPostData as Map<String, dynamic>;
      expect(body['keys'], keys);
      expect(body['link_keys'], links);
      expect(body.keys, unorderedEquals(['keys', 'link_keys']));
    });
  });

  group('migrationComplete', () {
    test('no longer carries the re-wraps, only the identity fields', () async {
      dio.postResponse = {'ok': true};

      await client.migrationComplete(
        newIdentityPubkey: 'p',
        newWrappingPubkey: 'w',
        newFingerprint: 'fp',
        transitionOldSignature: 'os',
        transitionNewSignature: 'ns',
        transitionIssuedAt: 1,
        opaqueRegistrationUpload: 'u',
        encryptedPrivateKey: 'env',
        auditEventSignature: 'audit-sig',
      );

      expect(dio.lastPostPath, '/api/auth/migration/complete');
      final body = dio.lastPostData as Map<String, dynamic>;
      // The re-wraps moved to migration/rewrap — the bug was carrying them here.
      expect(body.containsKey('rewrapped_keys'), isFalse);
      expect(body.containsKey('rewrapped_link_keys'), isFalse);
      expect(body['audit_event_signature'], 'audit-sig');
      expect(body['new_identity_pubkey'], 'p');
    });
  });
}
