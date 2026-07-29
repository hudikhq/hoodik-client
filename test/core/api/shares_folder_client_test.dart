import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;

/// In-memory Dio adapter that records every request and replies with scripted
/// responses, so we assert URL and body without real network I/O. Same shape
/// as the adapter in `shares_client_test.dart` / `links_client_test.dart`.
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

/// A representative folder roster, used both as the `getFolderMembers` body
/// and as the `current_members` payload inside the 409 conflict.
Map<String, dynamic> _rosterJson() => {
  'folder_id': 'fold-1',
  'folder_owner_id': 'u-owner',
  'folder_owner_pubkey_fingerprint': 'OWNER-FP',
  'signature_algorithm': 'rsa-pss-sha256',
  'members': [
    {
      'user_id': 'u-owner',
      'pubkey': 'PUB',
      'pubkey_fingerprint': 'OWNER-FP',
      'share_role': 'co-owner',
      'is_owner': true,
    },
    {
      'user_id': 'u-2',
      'email': 'bob@example.test',
      'pubkey': 'PUB2',
      'pubkey_fingerprint': 'BOB-FP',
      'share_role': 'editor',
      'is_owner': false,
      'member_signature': 'sigma',
    },
  ],
  'members_signed_at': 1700,
  'members_list_signature': 'list-sig',
  'members_list_signed_by_user_id': 'u-owner',
};

/// The exact `409 share_membership_changed` body the server emits: the outer
/// `{message, context}` carries the code + roster as a JSON *string* in
/// `message`. Mirrors `Error::Conflict` in `error/src/lib.rs` and
/// `share_membership_changed` in `shares/src/repository/multikey_upload.rs`.
_Reply _membershipChangedReply() {
  final inner = jsonEncode({
    'code': 'share_membership_changed',
    'current_members': _rosterJson(),
  });
  return _Reply.json({'message': inner, 'context': null}, status: 409);
}

void main() {
  group('SharesClient.getFolderMembers', () {
    test('GET /api/shares/folder/{id}/members parses the roster', () async {
      final env = _buildDio([_Reply.json(_rosterJson())]);

      final response = await SharesClient(env.dio).getFolderMembers('fold-1');

      expect(response.folderId, 'fold-1');
      expect(response.folderOwnerId, 'u-owner');
      expect(response.signatureAlgorithm, 'rsa-pss-sha256');
      expect(response.members, hasLength(2));
      expect(response.members.first.isOwner, isTrue);
      expect(response.members.last.shareRole, ShareRole.editor);
      expect(response.membersListSignature, 'list-sig');

      final req = env.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/api/shares/folder/fold-1/members');
    });

    test('404 throws NotAFolderMemberException', () async {
      final env = _buildDio([
        _Reply.json({'message': 'not_found'}, status: 404),
      ]);

      await expectLater(
        SharesClient(env.dio).getFolderMembers('fold-1'),
        throwsA(
          isA<NotAFolderMemberException>().having(
            (e) => e.folderId,
            'folderId',
            'fold-1',
          ),
        ),
      );
    });

    test('unmapped status rethrows the raw DioException', () async {
      final env = _buildDio([_Reply.empty(status: 500)]);

      await expectLater(
        SharesClient(env.dio).getFolderMembers('fold-1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('SharesClient.uploadMultikey', () {
    test('POST /api/storage/upload-multikey returns file_id', () async {
      final env = _buildDio([
        _Reply.json({'file_id': 'new-f-1'}, status: 201),
      ]);

      final body = <String, dynamic>{
        'new_file_id': 'new-f-1',
        'parent_file_id': 'fold-1',
        'name_hash': 'nh',
        'encrypted_name': 'enc',
        'mime': 'text/plain',
        'chunks': 1,
        'member_keys': [
          {
            'user_id': 'u-owner',
            'encrypted_key': 'k1',
            'is_owner_of_file': true,
          },
          {'user_id': 'u-2', 'encrypted_key': 'k2'},
        ],
        'members_list_snapshot': {
          'members_signed_at': 1700,
          'members_list_signature': 'list-sig',
        },
        'event_signature': 'evt',
        'timestamp': 12345,
      };

      final fileId = await SharesClient(env.dio).uploadMultikey(body);

      expect(fileId, 'new-f-1');
      final req = env.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/storage/upload-multikey');
      expect(req.data, body);
    });

    test('409 share_membership_changed throws with parsed roster', () async {
      final env = _buildDio([_membershipChangedReply()]);

      try {
        await SharesClient(env.dio).uploadMultikey(<String, dynamic>{});
        fail('expected ShareMembershipChangedError');
      } on ShareMembershipChangedError catch (e) {
        final members = e.currentMembers;
        expect(members.folderId, 'fold-1');
        expect(members.folderOwnerId, 'u-owner');
        expect(members.members, hasLength(2));
        expect(members.members.last.userId, 'u-2');
        expect(members.members.last.shareRole, ShareRole.editor);
        expect(members.membersListSignature, 'list-sig');
        expect(members.membersSignedAt, 1700);
      }
    });

    test('409 with an unrelated code rethrows the raw DioException', () async {
      final env = _buildDio([
        _Reply.json({
          'message': 'some_other_conflict',
          'context': null,
        }, status: 409),
      ]);

      await expectLater(
        SharesClient(env.dio).uploadMultikey(<String, dynamic>{}),
        throwsA(isA<DioException>()),
      );
    });

    test('non-409 error rethrows the raw DioException', () async {
      final env = _buildDio([_Reply.empty(status: 500)]);

      await expectLater(
        SharesClient(env.dio).uploadMultikey(<String, dynamic>{}),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('SharesClient.moveIntoShared', () {
    test('POST /api/storage/move-into-shared returns file_id', () async {
      final env = _buildDio([
        _Reply.json({'file_id': 'f-moved'}),
      ]);

      final body = <String, dynamic>{
        'file_id': 'f-moved',
        'destination_folder_id': 'fold-1',
        'member_keys': [
          {'user_id': 'u-owner', 'encrypted_key': 'k1'},
        ],
        'members_list_snapshot': {
          'members_signed_at': 1700,
          'members_list_signature': 'list-sig',
        },
        'event_signature': 'evt',
        'timestamp': 222,
      };

      final fileId = await SharesClient(env.dio).moveIntoShared(body);

      expect(fileId, 'f-moved');
      final req = env.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/storage/move-into-shared');
      expect(req.data, body);
    });

    test('409 share_membership_changed throws with parsed roster', () async {
      final env = _buildDio([_membershipChangedReply()]);

      await expectLater(
        SharesClient(env.dio).moveIntoShared(<String, dynamic>{}),
        throwsA(
          isA<ShareMembershipChangedError>().having(
            (e) => e.currentMembers.folderId,
            'currentMembers.folderId',
            'fold-1',
          ),
        ),
      );
    });
  });

  group('SharesClient.evictFromFolder', () {
    test(
      'POST /api/storage/{file}/evict-from-folder returns file_id',
      () async {
        final env = _buildDio([
          _Reply.json({'file_id': 'f-evicted'}),
        ]);

        final body = <String, dynamic>{
          'event_signature': 'evt',
          'timestamp': 9,
        };
        final fileId = await SharesClient(
          env.dio,
        ).evictFromFolder('f-evicted', body);

        expect(fileId, 'f-evicted');
        final req = env.adapter.requests.single;
        expect(req.method, 'POST');
        expect(req.path, '/api/storage/f-evicted/evict-from-folder');
        expect(req.data, body);
      },
    );
  });
}
