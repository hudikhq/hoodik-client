import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/share_group_add_member_models.dart';
import 'package:hoodik_app/core/api/share_group_models.dart';
import 'package:hoodik_app/core/api/share_groups_client.dart';
import 'package:hoodik_app/core/api/share_to_group_models.dart';

/// In-memory Dio adapter mirroring the one in `shares_client_test.dart`:
/// records requests, replies with scripted responses, no network I/O.
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
      if ((options.contentType ?? '').contains('application/json')) {
        captured.data = jsonDecode(utf8.decode(bytes));
      } else {
        captured.data = bytes;
      }
    }
    requests.add(captured);
    if (_index >= replies.length) {
      throw StateError(
        'no reply scripted for ${options.method} ${options.path}',
      );
    }
    final reply = replies[_index++];
    return ResponseBody.fromBytes(
      reply.bytes,
      reply.statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Reply {
  _Reply(this.statusCode, this.bytes);
  final int statusCode;
  final List<int> bytes;

  factory _Reply.json(dynamic body, {int status = 200}) =>
      _Reply(status, utf8.encode(jsonEncode(body)));
  factory _Reply.empty({int status = 200}) => _Reply(status, const []);

  /// A handler-issued error: `{message, context}` at the given status.
  factory _Reply.appError(String message, {int status = 409}) =>
      _Reply(status, utf8.encode(jsonEncode({'message': message})));
}

({Dio dio, _RecordingAdapter adapter}) _dio(List<_Reply> replies) {
  final adapter = _RecordingAdapter(replies);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

void main() {
  group('createGroup', () {
    test('POSTs the name and parses the created group', () async {
      final env = _dio([
        _Reply.json({
          'id': 'g1',
          'owner_id': 'me',
          'name': 'My team',
          'created_at': 1,
        }),
      ]);
      final group = await SharesGroupsClient(env.dio).createGroup('My team');
      final req = env.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/shares/groups');
      expect(req.data['name'], 'My team');
      expect(group.id, 'g1');
      expect(group.name, 'My team');
    });

    test('409 group_name_taken maps to GroupNameTakenError', () async {
      final env = _dio([_Reply.appError('group_name_taken')]);
      expect(
        () => SharesGroupsClient(env.dio).createGroup('Dup'),
        throwsA(isA<GroupNameTakenError>()),
      );
    });
  });

  group('addGroupMember', () {
    test('POSTs only the plain roster body to the members route', () async {
      final env = _dio([_Reply.empty(status: 204)]);
      await SharesGroupsClient(env.dio).addGroupMember(
        'g1',
        AddGroupMemberBody(
          userId: 'u2',
          pubkeyFingerprint: 'FP',
          groupRole: GroupRole.editor,
          timestamp: 100,
          nonce: 'bm9uY2U=',
        ),
      );
      final req = env.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/api/shares/groups/g1/members');
      expect((req.data as Map).keys.toSet(), {
        'user_id',
        'pubkey_fingerprint',
        'group_role',
        'timestamp',
        'nonce',
      });
      expect(req.data['user_id'], 'u2');
      expect(req.data['group_role'], 'editor');
      expect(req.data['nonce'], 'bm9uY2U=');
    });
  });

  group('removeGroupMember', () {
    test('DELETEs the member', () async {
      final env = _dio([_Reply.empty(status: 204)]);
      await SharesGroupsClient(env.dio).removeGroupMember('g1', 'u2');
      final req = env.adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/shares/groups/g1/members/u2');
    });
  });

  group('deleteGroup', () {
    test('DELETEs the group', () async {
      final env = _dio([_Reply.empty(status: 204)]);
      await SharesGroupsClient(env.dio).deleteGroup('g1');
      final req = env.adapter.requests.single;
      expect(req.method, 'DELETE');
      expect(req.path, '/api/shares/groups/g1');
    });
  });

  group('setGroupMemberRole', () {
    test('PUTs the role to the member-role route', () async {
      final env = _dio([_Reply.empty(status: 204)]);
      await SharesGroupsClient(env.dio).setGroupMemberRole(
        'g1',
        'u2',
        SetGroupMemberRoleBody(groupRole: GroupRole.coOwner),
      );
      final req = env.adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.path, '/api/shares/groups/g1/members/u2/role');
      expect(req.data['group_role'], 'co-owner');
    });
  });

  group('renameGroup', () {
    test('PATCHes the new name', () async {
      final env = _dio([_Reply.empty()]);
      await SharesGroupsClient(env.dio).renameGroup('g1', 'New name');
      final req = env.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/api/shares/groups/g1');
      expect(req.data['name'], 'New name');
    });

    test('409 group_name_taken maps to GroupNameTakenError', () async {
      final env = _dio([_Reply.appError('group_name_taken')]);
      expect(
        () => SharesGroupsClient(env.dio).renameGroup('g1', 'Dup'),
        throwsA(isA<GroupNameTakenError>()),
      );
    });
  });

  group('groupMembers', () {
    test('GETs the members route and parses the roster', () async {
      final env = _dio([
        _Reply.json([
          {
            'user_id': 'u2',
            'email': 'alice@example.test',
            'pubkey': 'PUB',
            'fingerprint': 'FP',
            'group_role': 'editor',
            'key_type': 'curve25519',
            'wrapping_pubkey': 'WRAP',
          },
        ]),
      ]);
      final roster = await SharesGroupsClient(env.dio).groupMembers('g1');
      final req = env.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/api/shares/groups/g1/members');
      expect(roster.single.userId, 'u2');
      expect(roster.single.pubkey, 'PUB');
      expect(roster.single.groupRole, GroupRole.editor);
      expect(roster.single.keyType, 'curve25519');
      expect(roster.single.wrappingPubkey, 'WRAP');
    });
  });
}
