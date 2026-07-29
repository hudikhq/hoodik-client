import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/share_event_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';

void main() {
  group('ShareEventPage.fromJson', () {
    test('parses events, users, and pagination', () {
      final page = ShareEventPage.fromJson(const {
        'events': [
          {
            'id': 'evt-1',
            'sender_id': 'u-alice',
            'recipient_id': 'u-bob',
            'file_id': 'f-1',
            'action': 'grant',
            'share_role_before': null,
            'share_role_after': 'editor',
            'created_at': 1700000000,
            'prev_event_hash': null,
            'this_event_hash': 'aGFzaA==',
            'sender_signature': 'c2ln',
            'encrypted_name': 'deadbeef',
            'cipher': 'aegis128l',
            'encrypted_key': 'd3JhcA==',
          },
        ],
        'users': {
          'u-alice': {
            'id': 'u-alice',
            'email': 'alice@example.test',
            'pubkey': 'PUBKEY-A',
            'fingerprint': 'aabbccdd',
            'key_type': 'curve25519',
            'wrapping_pubkey': 'WRAP-A',
          },
          'u-bob': {
            'id': 'u-bob',
            'email': 'bob@example.test',
            'pubkey': 'PUBKEY-B',
            'fingerprint': 'eeff0011',
          },
        },
        'total': 42,
        'limit': 100,
        'offset': 0,
      });

      expect(page.events, hasLength(1));
      expect(page.total, 42);
      expect(page.limit, 100);
      expect(page.users.keys, containsAll(['u-alice', 'u-bob']));
      expect(page.users['u-alice']!.email, 'alice@example.test');
      expect(page.users['u-alice']!.pubkey, 'PUBKEY-A');
      expect(page.users['u-alice']!.keyType, 'curve25519');
      expect(page.users['u-alice']!.wrappingPubkey, 'WRAP-A');
      expect(page.users['u-bob']!.keyType, 'rsa');
      expect(page.users['u-bob']!.wrappingPubkey, isNull);

      final event = page.events.single;
      expect(event.id, 'evt-1');
      expect(event.senderId, 'u-alice');
      expect(event.recipientId, 'u-bob');
      expect(event.action, AuditEventAction.grant);
      expect(event.shareRoleBefore, isNull);
      expect(event.shareRoleAfter, ShareRole.editor);
      expect(event.prevEventHash, isNull);
      expect(event.thisEventHash, 'aGFzaA==');
      expect(event.canDecryptName, isTrue);
    });

    test('treats a null sender / signature row as a system row', () {
      final page = ShareEventPage.fromJson(const {
        'events': [
          {
            'id': 'evt-sys',
            'sender_id': null,
            'recipient_id': 'u-bob',
            'file_id': 'f-1',
            'action': 'shared_folder_evict',
            'share_role_before': 'reader',
            'share_role_after': null,
            'created_at': 1700000500,
            'prev_event_hash': 'cHJldg==',
            'this_event_hash': 'dGhpcw==',
            'sender_signature': null,
            'encrypted_name': null,
            'cipher': null,
            'encrypted_key': null,
          },
        ],
        'users': <String, dynamic>{},
        'total': 1,
        'limit': 100,
        'offset': 0,
      });

      final event = page.events.single;
      expect(event.senderId, isNull);
      expect(event.senderSignature, isNull);
      expect(event.action, AuditEventAction.sharedFolderEvict);
      expect(event.shareRoleBefore, ShareRole.reader);
      expect(event.canDecryptName, isFalse, reason: 'deleted file: no name');
    });

    test('tolerates missing keys and an empty page', () {
      final page = ShareEventPage.fromJson(const {});
      expect(page.events, isEmpty);
      expect(page.users, isEmpty);
      expect(page.total, 0);
    });
  });

  group('AppShareEvent.toEventRow', () {
    test('carries the chain fields and drops the decrypt material', () {
      final event = AppShareEvent.fromJson(const {
        'id': 'evt-1',
        'sender_id': 'u-alice',
        'recipient_id': 'u-bob',
        'file_id': 'f-1',
        'action': 'role_change',
        'share_role_before': 'reader',
        'share_role_after': 'co-owner',
        'created_at': 1700000000,
        'prev_event_hash': 'cHJldg==',
        'this_event_hash': 'dGhpcw==',
        'sender_signature': 'c2ln',
        'encrypted_name': 'deadbeef',
        'cipher': 'aegis128l',
        'encrypted_key': 'd3JhcA==',
      });

      final row = event.toEventRow();
      expect(row.id, 'evt-1');
      expect(row.senderId, 'u-alice');
      expect(row.recipientId, 'u-bob');
      expect(row.action, AuditEventAction.roleChange);
      expect(row.shareRoleBefore, ShareRole.reader);
      expect(row.shareRoleAfter, ShareRole.coOwner);
      expect(row.prevEventHash, 'cHJldg==');
      expect(row.thisEventHash, 'dGhpcw==');
      expect(row.senderSignature, 'c2ln');
    });
  });

  group('ShareEventQuery.toQueryParameters', () {
    test('omits null fields and maps the action to its wire string', () {
      const query = ShareEventQuery(
        fileId: 'f-1',
        action: AuditEventAction.grant,
        limit: 50,
      );
      final params = query.toQueryParameters();
      expect(params['file_id'], 'f-1');
      expect(params['action'], 'grant');
      expect(params['limit'], 50);
      expect(params.containsKey('offset'), isFalse);
    });

    test('an empty query sends nothing', () {
      expect(const ShareEventQuery().toQueryParameters(), isEmpty);
    });
  });
}
