import 'package:dio/dio.dart';

import 'share_group_add_member_models.dart';
import 'share_group_models.dart';
import 'share_to_group_models.dart';

/// Thrown when a group name collides with one the caller already owns
/// (`409 group_name_taken`), so the create/rename dialog can show a precise
/// message instead of a generic conflict.
class GroupNameTakenError implements Exception {
  @override
  String toString() => 'GroupNameTakenError';
}

/// HTTP client scoped to the share-group routes.
///
/// Constructed with the [Dio] instance [ApiClient] owns, so it shares the
/// same auth interceptors, cookie jar, and refresh handling. Kept separate
/// from [SharesClient] because the group surface is its own resource with its
/// own conflict idioms, and folding it in would push `shares_client.dart`
/// past its line target.
///
/// A group is a saved recipient selection — there is no server-side group→file
/// tracking. Sharing a file to a group is a client-side fan-out over the roster
/// ([groupMembers]) using the single-share routes, so this client only covers
/// group CRUD, the roster, and role management.
class SharesGroupsClient {
  final Dio _dio;

  SharesGroupsClient(this._dio);

  /// `POST /api/shares/groups` — create a new group owned by the caller.
  ///
  /// Throws [GroupNameTakenError] on `409 group_name_taken` (the only unique
  /// index the insert can trip) so the dialog can re-prompt for a fresh name.
  Future<ShareGroup> createGroup(String name) async {
    try {
      final resp = await _dio.post('/api/shares/groups', data: {'name': name});
      return ShareGroup.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 &&
          _messageCode(e.response?.data) == 'group_name_taken') {
        throw GroupNameTakenError();
      }
      rethrow;
    }
  }

  /// `GET /api/shares/groups` — the caller's owned groups (with rosters) plus
  /// the groups they're a member of (identity only).
  Future<GroupsResponse> listGroups() async {
    final resp = await _dio.get('/api/shares/groups');
    return GroupsResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  /// `DELETE /api/shares/groups/{id}` — owner-only deletion.
  Future<void> deleteGroup(String groupId) async {
    await _dio.delete('/api/shares/groups/$groupId');
  }

  /// `POST /api/shares/groups/{id}/members` — add a member. A group is a saved
  /// recipient selection, so this is a plain roster insert: [body] carries the
  /// new member's identity, their group role, and a timestamp + nonce for replay
  /// protection. No file keys move.
  Future<void> addGroupMember(String groupId, AddGroupMemberBody body) async {
    await _dio.post('/api/shares/groups/$groupId/members', data: body.toJson());
  }

  /// `DELETE /api/shares/groups/{id}/members/{userId}` — remove a member (a
  /// co-owner or the owner; or the caller removing themselves).
  Future<void> removeGroupMember(String groupId, String userId) async {
    await _dio.delete('/api/shares/groups/$groupId/members/$userId');
  }

  /// `PATCH /api/shares/groups/{id}` — rename a group (co-owner+). Throws
  /// [GroupNameTakenError] on `409 group_name_taken`.
  Future<void> renameGroup(String groupId, String name) async {
    try {
      await _dio.patch('/api/shares/groups/$groupId', data: {'name': name});
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 &&
          _messageCode(e.response?.data) == 'group_name_taken') {
        throw GroupNameTakenError();
      }
      rethrow;
    }
  }

  /// `PUT /api/shares/groups/{id}/members/{userId}/role` — change a member's
  /// *group* role (co-owner+). No crypto: a group role moves no file key.
  Future<void> setGroupMemberRole(
    String groupId,
    String userId,
    SetGroupMemberRoleBody body,
  ) async {
    await _dio.put(
      '/api/shares/groups/$groupId/members/$userId/role',
      data: body.toJson(),
    );
  }

  /// `GET /api/shares/groups/{id}/members` — the roster a share-to-group
  /// fan-out targets: the group owner plus every member, each with the pubkey
  /// material needed to wrap a file key. The owner is a valid recipient when a
  /// non-owner member initiates the share, so they are part of the set.
  Future<List<GroupMemberWithKey>> groupMembers(String groupId) async {
    final resp = await _dio.get('/api/shares/groups/$groupId/members');
    final list = (resp.data as List?) ?? const [];
    return list
        .map((e) => GroupMemberWithKey.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The Hoodik error body is `{message, context}` with the code string in
  /// `message`. Tolerant of a non-map body so a malformed response degrades to
  /// "no code" instead of throwing.
  static String? _messageCode(dynamic data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
