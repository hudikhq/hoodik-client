import 'dart:convert';

import 'package:dio/dio.dart';

import 'shares_models.dart';

/// Why discovery fails, mapped from the server's error `message` code so the
/// UI can show a precise message instead of a generic network error. A 404
/// (`user_not_found`) is deliberately absent — that path returns `null`, not
/// an exception, because "no such user" is a normal lookup outcome.
enum DiscoverErrorKind { cannotDiscoverSelf, rateLimited, sharingDisabled }

/// Thrown by [SharesClient.discoverUser] for the server's typed rejections.
/// [retryAfter] is populated only when the server emits a `Retry-After`
/// header (it does not today — see [SharesClient.discoverUser]).
class DiscoverException implements Exception {
  DiscoverException(this.kind, {this.retryAfter});

  final DiscoverErrorKind kind;
  final Duration? retryAfter;

  @override
  String toString() => 'DiscoverException($kind)';
}

/// Thrown when the caller is not a member of a folder. The server returns
/// 404 for non-members so a folder's existence isn't leaked; the client turns
/// that into this typed signal rather than swallowing it, so the membership
/// view can distinguish "you lost access" from a real fetch failure.
class NotAFolderMemberException implements Exception {
  NotAFolderMemberException(this.folderId);

  final String folderId;

  @override
  String toString() => 'NotAFolderMemberException($folderId)';
}

/// Thrown when a multi-key upload or move races a change to the destination
/// folder's roster. The server's `409 share_membership_changed` carries the
/// fresh [currentMembers] so the caller re-verifies fingerprints, re-wraps
/// the file key for the new member set, and retries without an extra
/// round-trip.
class ShareMembershipChangedError implements Exception {
  ShareMembershipChangedError(this.currentMembers);

  final FolderMembersResponse currentMembers;

  @override
  String toString() =>
      'ShareMembershipChangedError(${currentMembers.folderId})';
}

/// Why a `move-out-of-shared` was refused, mapped from the server's error
/// code so the UI shows a precise message. [notOwner] is the 403 a non-owner
/// hits (only the file owner may detach it); [destinationShared] is the 400
/// when the chosen destination is itself a shared folder (that flow is
/// move-into-shared's re-wrap path, not move-out).
enum MoveOutRejection { notOwner, destinationShared }

/// Thrown by [SharesClient.moveOutOfShared] for the server's typed rejections.
class MoveOutRejected implements Exception {
  const MoveOutRejected(this.reason);

  final MoveOutRejection reason;

  @override
  String toString() => 'MoveOutRejected($reason)';
}

/// Thrown when a fork would push the caller past their storage quota. The
/// server returns `409 fork_quota_exceeded` before creating any file row, so a
/// caller catching this knows nothing was written and can surface a "not
/// enough space" message instead of a generic failure.
class ForkQuotaExceededError implements Exception {
  const ForkQuotaExceededError();

  @override
  String toString() => 'ForkQuotaExceededError()';
}

/// HTTP client scoped to the account-to-account sharing routes.
///
/// Instantiated with the [Dio] instance owned by [ApiClient], so it shares
/// the same auth interceptors, cookie jar, and refresh handling. Grouping the
/// share calls here mirrors [LinksClient] and keeps [ApiClient] close to its
/// line ceiling.
class SharesClient {
  final Dio _dio;

  SharesClient(this._dio);

  /// `GET /api/users/discover?email=` — resolve a recipient's pubkey and
  /// fingerprint by email.
  ///
  /// Returns `null` for 404 (`user_not_found`); the caller treats "no such
  /// user" as an empty result, not an error. The server's other rejections
  /// surface as a typed [DiscoverException] so the dialog can explain why:
  /// 400 `cannot_discover_self`, 429 `rate_limited`, 503 `sharing_disabled`.
  /// Any other status rethrows the raw [DioException].
  Future<DiscoveredUser?> discoverUser(String email) async {
    try {
      final resp = await _dio.get(
        '/api/users/discover',
        queryParameters: {'email': email},
      );
      return DiscoveredUser.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) return null;

      final code = _messageCode(e.response?.data);
      if (status == 400 && code == 'cannot_discover_self') {
        throw DiscoverException(DiscoverErrorKind.cannotDiscoverSelf);
      }
      if (status == 429) {
        throw DiscoverException(
          DiscoverErrorKind.rateLimited,
          retryAfter: _retryAfter(e.response?.headers),
        );
      }
      if (status == 503) {
        throw DiscoverException(DiscoverErrorKind.sharingDisabled);
      }
      rethrow;
    }
  }

  /// `POST /api/shares` — idempotent grant or role change. [envelope] is the
  /// signed request body (`payload_der`, `signature`, `entries`,
  /// `event_signature`) assembled client-side. Unwraps the `{shares: [...]}`
  /// response into the affected recipient rows.
  Future<List<AppShare>> createShare(Map<String, dynamic> envelope) async {
    final resp = await _dio.post('/api/shares', data: envelope);
    return CreateShareResponse.fromJson(
      resp.data as Map<String, dynamic>,
    ).shares;
  }

  /// `DELETE /api/shares/{fileId}/{userId}` — revoke a recipient (owner /
  /// co-owner) or leave a share (recipient revokes themselves). [body] carries
  /// the signed audit-event proof.
  Future<void> revokeShare(
    String fileId,
    String userId,
    Map<String, dynamic> body,
  ) async {
    await _dio.delete('/api/shares/$fileId/$userId', data: body);
  }

  /// `GET /api/shares/{fileId}` — the recipient roster for a file the caller
  /// owns or co-owns.
  Future<List<AppShare>> getShareRecipients(String fileId) async {
    final resp = await _dio.get('/api/shares/$fileId');
    return (resp.data as List)
        .map((e) => AppShare.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /api/shares/keys` — every file shared with the caller, as
  /// `(file_id, encrypted_key)` pairs.
  ///
  /// Distinct from [getSharesMine], which reports share *roots* for browsing:
  /// it trims any row whose parent is also shared. Search needs the untrimmed
  /// set, because files inside a shared folder are tagged under their own keys
  /// and a query has to carry a tag per key.
  Future<List<Map<String, String>>> getIncomingKeys() async {
    final resp = await _dio.get('/api/shares/keys');
    final rows = resp.data is List ? resp.data as List : const [];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => {
            'file_id': row['file_id'] as String? ?? '',
            'encrypted_key': row['encrypted_key'] as String? ?? '',
          },
        )
        .where((row) => row['encrypted_key']!.isNotEmpty)
        .toList();
  }

  /// `GET /api/shares/mine` — one page of the caller's incoming shares.
  Future<IncomingSharePage> getSharesMine({int? limit, int? offset}) async {
    final resp = await _dio.get(
      '/api/shares/mine',
      queryParameters: _pageParams(limit, offset),
    );
    return IncomingSharePage.fromJson(resp.data as Map<String, dynamic>);
  }

  /// `GET /api/shares/mine/by/{userId}` — incoming shares narrowed to those
  /// granted by [userId].
  Future<IncomingSharePage> getSharesMineBy(
    String userId, {
    int? limit,
    int? offset,
  }) async {
    final resp = await _dio.get(
      '/api/shares/mine/by/$userId',
      queryParameters: _pageParams(limit, offset),
    );
    return IncomingSharePage.fromJson(resp.data as Map<String, dynamic>);
  }

  /// `GET /api/capabilities` — the server's sharing capability advertisement.
  ///
  /// Throws rather than answering for the server. The caller fails closed on
  /// every outcome, but only it can tell a server that *said* something — a
  /// 404 from a pre-1.16 build, an unparseable body — from a request that
  /// never landed, and only the second is worth asking again.
  Future<Capabilities> getCapabilities() async {
    final resp = await _dio.get('/api/capabilities');
    return Capabilities.fromJson(resp.data as Map<String, dynamic>);
  }

  /// `PATCH /api/users/me` — partial update of the caller's own user row:
  /// the share-notification opt-out and the outbound-email locale.
  Future<void> patchMe({
    bool? shareNotificationsEnabled,
    String? locale,
  }) async {
    await _dio.patch(
      '/api/users/me',
      data: {
        'share_notifications_enabled': ?shareNotificationsEnabled,
        'locale': ?locale,
      },
    );
  }

  /// `GET /api/shares/folder/{folderId}/members` — the signed roster of an
  /// editable folder.
  ///
  /// Throws [NotAFolderMemberException] on 404: the server hides a folder's
  /// existence from non-members, so a 404 means "you aren't a member", not
  /// "no such folder". Any other status rethrows the raw [DioException].
  Future<FolderMembersResponse> getFolderMembers(String folderId) async {
    try {
      final resp = await _dio.get('/api/shares/folder/$folderId/members');
      return FolderMembersResponse.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw NotAFolderMemberException(folderId);
      }
      rethrow;
    }
  }

  /// `POST /api/storage/upload-multikey` — create a file in a shared folder
  /// with one wrapped key per current member. [body] is the signed request
  /// (`new_file_id`, `member_keys`, `members_list_snapshot`,
  /// `event_signature`, …) assembled client-side. Returns the server's
  /// `file_id` (always the caller's supplied `new_file_id` so the audit
  /// signature lines up), reused as the chunk-upload id.
  ///
  /// On `409 share_membership_changed` throws [ShareMembershipChangedError]
  /// carrying the fresh roster so the caller can re-wrap and retry.
  Future<String> uploadMultikey(Map<String, dynamic> body) async {
    try {
      final resp = await _dio.post('/api/storage/upload-multikey', data: body);
      return (resp.data as Map<String, dynamic>)['file_id'] as String;
    } on DioException catch (e) {
      throw _parseMembershipChanged(e) ?? e;
    }
  }

  /// `POST /api/storage/move-into-shared` — re-parent a file the caller owns
  /// into a shared folder, pre-wrapping its key for every current member.
  /// [body] carries `file_id`, `destination_folder_id`, `member_keys`,
  /// `members_list_snapshot`, and the signed audit event. Returns the
  /// server's `file_id`.
  ///
  /// On `409 share_membership_changed` throws [ShareMembershipChangedError]
  /// with the fresh roster, exactly like [uploadMultikey].
  Future<String> moveIntoShared(Map<String, dynamic> body) async {
    try {
      final resp = await _dio.post('/api/storage/move-into-shared', data: body);
      return (resp.data as Map<String, dynamic>)['file_id'] as String;
    } on DioException catch (e) {
      throw _parseMembershipChanged(e) ?? e;
    }
  }

  /// `POST /api/storage/move-out-of-shared` — the file's owner detaches their
  /// own file (or folder subtree) from the shared folder it lives in; the
  /// nodes revert to private files the owner already holds keys for, so no
  /// wraps travel. [body] carries `file_id`, optional `destination_folder_id`
  /// (absent/null = drive root), and the signed audit event. Returns the
  /// server's `file_id`.
  ///
  /// The server's typed rejections surface as a [MoveOutRejected] so the UI
  /// can explain why: 403 `cannot_move_not_owner`, 400 `destination_is_shared`.
  /// Any other status rethrows the raw [DioException]. This endpoint never
  /// races the roster, so there is no 409 to handle.
  Future<String> moveOutOfShared(Map<String, dynamic> body) async {
    try {
      final resp = await _dio.post(
        '/api/storage/move-out-of-shared',
        data: body,
      );
      return (resp.data as Map<String, dynamic>)['file_id'] as String;
    } on DioException catch (e) {
      final code = _messageCode(e.response?.data);
      if (code == 'cannot_move_not_owner') {
        throw const MoveOutRejected(MoveOutRejection.notOwner);
      }
      if (code == 'destination_is_shared') {
        throw const MoveOutRejected(MoveOutRejection.destinationShared);
      }
      rethrow;
    }
  }

  /// `POST /api/storage/{fileId}/evict-from-folder` — the folder owner
  /// detaches a contributor's file from the folder; the file persists in the
  /// contributor's drive at root. [body] carries the signed audit event.
  /// Returns the server's `file_id`. This endpoint never races the roster, so
  /// there is no 409 to handle here.
  Future<String> evictFromFolder(
    String fileId,
    Map<String, dynamic> body,
  ) async {
    final resp = await _dio.post(
      '/api/storage/$fileId/evict-from-folder',
      data: body,
    );
    return (resp.data as Map<String, dynamic>)['file_id'] as String;
  }

  /// `POST /api/shares/{sourceFileId}/fork` — save an independent copy of a
  /// shared file into the caller's own drive at root (owner / co-owner only).
  /// [body] carries the re-keyed metadata: a fresh wrapped key, the
  /// re-encrypted name + thumbnail, recomputed hashes, and the signed `fork`
  /// audit event. Returns the server's `file_id` — always the client-minted
  /// `new_file_id` — which the caller reuses as the chunk-upload id.
  ///
  /// On `409 fork_quota_exceeded` throws [ForkQuotaExceededError] so the UI can
  /// say "not enough space"; no file row is created in that case.
  Future<String> forkFile(
    String sourceFileId,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await _dio.post(
        '/api/shares/$sourceFileId/fork',
        data: body,
      );
      return (resp.data as Map<String, dynamic>)['file_id'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 &&
          _messageCode(e.response?.data) == 'fork_quota_exceeded') {
        throw const ForkQuotaExceededError();
      }
      rethrow;
    }
  }

  /// Both `mine` listings ask for `compact` rows — recipient thumbnails
  /// load lazily from the storage thumbnail route. Older servers ignore
  /// the flag and ship full rows.
  Map<String, dynamic> _pageParams(int? limit, int? offset) => {
    'limit': ?limit,
    'offset': ?offset,
    'compact': true,
  };

  /// The Hoodik error body is `{message, context}` with the code string in
  /// `message`. Tolerant of a non-map body so a malformed response degrades
  /// to "no code" instead of throwing.
  static String? _messageCode(dynamic data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  /// Parse a `409 share_membership_changed` into a typed error, or null if
  /// [e] isn't that conflict. The body is double-wrapped: the outer
  /// `{message, context}` carries the code+roster as a JSON *string* in
  /// `message`, which this decodes to `{code, current_members}`. Tolerant of
  /// a missing or malformed inner payload — anything that doesn't decode to
  /// the expected shape yields null so the raw [DioException] propagates.
  static ShareMembershipChangedError? _parseMembershipChanged(DioException e) {
    if (e.response?.statusCode != 409) return null;
    final inner = _messageCode(e.response?.data);
    if (inner == null || inner.isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(inner);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['code'] != 'share_membership_changed') return null;
    final members = decoded['current_members'];
    if (members is! Map<String, dynamic>) return null;
    return ShareMembershipChangedError(FolderMembersResponse.fromJson(members));
  }

  static Duration? _retryAfter(Headers? headers) {
    final value = headers?.value('retry-after');
    final seconds = value == null ? null : int.tryParse(value);
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
