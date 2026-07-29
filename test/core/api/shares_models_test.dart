import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;

void main() {
  group('ShareRole.fromWire', () {
    test('maps each kebab wire string', () {
      expect(ShareRole.fromWire('reader'), ShareRole.reader);
      expect(ShareRole.fromWire('editor'), ShareRole.editor);
      expect(ShareRole.fromWire('co-owner'), ShareRole.coOwner);
    });

    test('fails closed to reader for unknown or empty values', () {
      expect(ShareRole.fromWire('admin'), ShareRole.reader);
      expect(ShareRole.fromWire(''), ShareRole.reader);
    });

    test('carries both the int discriminant and the wire string', () {
      expect(ShareRole.reader.wire, 0);
      expect(ShareRole.editor.wire, 1);
      expect(ShareRole.coOwner.wire, 2);
      expect(ShareRole.coOwner.wireString, 'co-owner');
    });
  });

  group('DiscoveredUser.fromJson', () {
    test('reads all fields', () {
      final user = DiscoveredUser.fromJson({
        'user_id': 'u-1',
        'email': 'bob@example.test',
        'pubkey': 'PUB',
        'fingerprint': 'FP',
        'key_type': 'curve25519',
        'wrapping_pubkey': 'WRAP',
      });

      expect(user.userId, 'u-1');
      expect(user.email, 'bob@example.test');
      expect(user.pubkey, 'PUB');
      expect(user.fingerprint, 'FP');
      expect(user.keyType, 'curve25519');
      expect(user.wrappingPubkey, 'WRAP');
    });

    test('tolerates missing fields with empty defaults', () {
      final user = DiscoveredUser.fromJson(const {});

      expect(user.userId, '');
      expect(user.email, '');
      expect(user.pubkey, '');
      expect(user.fingerprint, '');
      expect(user.keyType, 'rsa');
      expect(user.wrappingPubkey, isNull);
    });
  });

  group('AppShare.fromJson', () {
    test('reads required and optional fields', () {
      final share = AppShare.fromJson({
        'file_id': 'f-1',
        'recipient_id': 'u-2',
        'recipient_email': 'bob@example.test',
        'recipient_pubkey_fingerprint': 'FP',
        'share_role': 'editor',
        'created_at': 100,
        'shared_at': 120,
        'shared_by_user_id': 'u-9',
        'shared_by_email': 'alice@example.test',
      });

      expect(share.fileId, 'f-1');
      expect(share.recipientId, 'u-2');
      expect(share.shareRole, ShareRole.editor);
      expect(share.createdAt, 100);
      expect(share.sharedAt, 120);
      expect(share.sharedByUserId, 'u-9');
      expect(share.sharedByEmail, 'alice@example.test');
    });

    test('leaves nullable sender fields null when absent', () {
      final share = AppShare.fromJson({
        'file_id': 'f-1',
        'recipient_id': 'u-2',
        'recipient_email': 'bob@example.test',
        'recipient_pubkey_fingerprint': 'FP',
        'share_role': 'reader',
        'created_at': 1,
      });

      expect(share.sharedAt, isNull);
      expect(share.sharedByUserId, isNull);
      expect(share.sharedByEmail, isNull);
      expect(share.shareRole, ShareRole.reader);
    });
  });

  group('CreateShareResponse.fromJson', () {
    test('unwraps the shares envelope', () {
      final response = CreateShareResponse.fromJson({
        'shares': [
          {
            'file_id': 'f-1',
            'recipient_id': 'u-2',
            'recipient_email': 'bob@example.test',
            'recipient_pubkey_fingerprint': 'FP',
            'share_role': 'co-owner',
            'created_at': 1,
          },
        ],
      });

      expect(response.shares, hasLength(1));
      expect(response.shares.single.shareRole, ShareRole.coOwner);
    });

    test('defaults to an empty list when shares is absent', () {
      expect(CreateShareResponse.fromJson(const {}).shares, isEmpty);
    });
  });

  group('IncomingShare.fromJson', () {
    test('reads file metadata, role, and owner identity', () {
      final share = IncomingShare.fromJson({
        'file_id': 'f-1',
        'mime': 'image/png',
        'encrypted_name': 'enc-name',
        'encrypted_thumbnail': 'enc-thumb',
        'cipher': 'chacha20poly1305',
        'editable': true,
        'size': 2048,
        'chunks': 2,
        'chunks_stored': 2,
        'finished_upload_at': 999,
        'sha256': 'abc',
        'share_role': 'editor',
        'encrypted_key': 'wrapped',
        'created_at': 10,
        'shared_at': 20,
        'owner_id': 'o-1',
        'owner_email': 'alice@example.test',
        'owner_pubkey': 'PUB',
        'owner_pubkey_fingerprint': 'FP',
        'shared_by_user_id': 'u-9',
        'shared_by_email': 'carol@example.test',
      });

      expect(share.fileId, 'f-1');
      expect(share.mime, 'image/png');
      expect(share.encryptedThumbnail, 'enc-thumb');
      expect(share.cipher, 'chacha20poly1305');
      expect(share.editable, isTrue);
      expect(share.size, 2048);
      expect(share.finishedUploadAt, 999);
      expect(share.sha256, 'abc');
      expect(share.shareRole, ShareRole.editor);
      expect(share.encryptedKey, 'wrapped');
      expect(share.ownerEmail, 'alice@example.test');
      expect(share.isDir, isFalse);
    });

    test('applies defaults for missing fields', () {
      final share = IncomingShare.fromJson(const {});

      expect(share.fileId, '');
      expect(share.mime, 'unknown');
      expect(share.cipher, 'aegis128l');
      expect(share.editable, isFalse);
      expect(share.size, isNull);
      expect(share.encryptedThumbnail, isNull);
      expect(share.shareRole, ShareRole.reader);
      expect(share.sharedByEmail, isNull);
    });

    test('isDir is true for a dir mime', () {
      final share = IncomingShare.fromJson({'mime': 'dir'});
      expect(share.isDir, isTrue);
    });
  });

  group('IncomingSharePage.fromJson', () {
    test('reads items and paging metadata', () {
      final page = IncomingSharePage.fromJson({
        'items': [
          {'file_id': 'f-1', 'share_role': 'reader'},
          {'file_id': 'f-2', 'share_role': 'editor'},
        ],
        'total': 7,
        'limit': 25,
        'offset': 50,
      });

      expect(page.items, hasLength(2));
      expect(page.items.first.fileId, 'f-1');
      expect(page.total, 7);
      expect(page.limit, 25);
      expect(page.offset, 50);
    });

    test('defaults to an empty page when fields are absent', () {
      final page = IncomingSharePage.fromJson(const {});

      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.limit, 0);
      expect(page.offset, 0);
    });
  });

  group('Capabilities', () {
    test('fromJson reads the sharing block and feature flags', () {
      final caps = Capabilities.fromJson({
        'sharing': {
          'enabled': true,
          'roles': ['reader', 'co-owner'],
        },
        'editable_folders': true,
        'share_groups': true,
        'audit_log': true,
        'fork': true,
        'default_cipher': 'aegis256',
      });

      expect(caps.sharingEnabled, isTrue);
      expect(caps.roles, [ShareRole.reader, ShareRole.coOwner]);
      expect(caps.editableFolders, isTrue);
      expect(caps.shareGroups, isTrue);
      expect(caps.auditLog, isTrue);
      expect(caps.fork, isTrue);
      expect(caps.defaultCipher, 'aegis256');
    });

    test('fromJson fails closed when the sharing block is missing', () {
      final caps = Capabilities.fromJson(const {});

      expect(caps.sharingEnabled, isFalse);
      expect(caps.roles, isEmpty);
      expect(caps.editableFolders, isFalse);
      expect(caps.shareGroups, isFalse);
      expect(caps.fork, isFalse);
      expect(caps.defaultCipher, 'aegis128l');
    });

    test('share_groups defaults false on a server that omits it', () {
      final caps = Capabilities.fromJson({
        'sharing': {'enabled': true, 'roles': <String>[]},
      });

      expect(caps.sharingEnabled, isTrue);
      expect(caps.shareGroups, isFalse);
    });

    test('disabled() turns everything off', () {
      const caps = Capabilities.disabled();

      expect(caps.sharingEnabled, isFalse);
      expect(caps.roles, isEmpty);
      expect(caps.editableFolders, isFalse);
      expect(caps.shareGroups, isFalse);
      expect(caps.auditLog, isFalse);
      expect(caps.fork, isFalse);
      expect(caps.defaultCipher, 'aegis128l');
    });
  });

  group('FolderMember.fromJson', () {
    test('reads a fully-populated row', () {
      final member = FolderMember.fromJson({
        'user_id': 'u-1',
        'email': 'bob@example.test',
        'pubkey': 'PUB',
        'pubkey_fingerprint': 'FP',
        'share_role': 'co-owner',
        'is_owner': false,
        'key_type': 'curve25519',
        'wrapping_pubkey': 'WRAP',
        'added_at': 42,
        'signed_by_user_id': 'u-owner',
        'member_signature': 'sigma',
      });

      expect(member.userId, 'u-1');
      expect(member.email, 'bob@example.test');
      expect(member.shareRole, ShareRole.coOwner);
      expect(member.isOwner, isFalse);
      expect(member.keyType, 'curve25519');
      expect(member.wrappingPubkey, 'WRAP');
      expect(member.addedAt, 42);
      expect(member.signedByUserId, 'u-owner');
      expect(member.memberSignature, 'sigma');
    });

    test('tolerates the owner row missing email and signature', () {
      final member = FolderMember.fromJson({
        'user_id': 'u-owner',
        'pubkey': 'PUB',
        'pubkey_fingerprint': 'FP',
        'share_role': 'co-owner',
        'is_owner': true,
      });

      expect(member.userId, 'u-owner');
      expect(member.email, isNull);
      expect(member.isOwner, isTrue);
      expect(member.keyType, 'rsa');
      expect(member.wrappingPubkey, isNull);
      expect(member.addedAt, isNull);
      expect(member.signedByUserId, isNull);
      expect(member.memberSignature, isNull);
    });

    test('fails closed to reader for an unknown role', () {
      final member = FolderMember.fromJson(const {'share_role': 'admin'});
      expect(member.shareRole, ShareRole.reader);
      expect(member.isOwner, isFalse);
    });
  });

  group('FolderMembersResponse.fromJson', () {
    test('reads the signed roster with its members', () {
      final response = FolderMembersResponse.fromJson({
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
      });

      expect(response.folderId, 'fold-1');
      expect(response.folderOwnerId, 'u-owner');
      expect(response.folderOwnerPubkeyFingerprint, 'OWNER-FP');
      expect(response.signatureAlgorithm, 'rsa-pss-sha256');
      expect(response.members, hasLength(2));
      expect(response.members.first.isOwner, isTrue);
      expect(response.members.last.shareRole, ShareRole.editor);
      expect(response.membersSignedAt, 1700);
      expect(response.membersListSignature, 'list-sig');
      expect(response.membersListSignedByUserId, 'u-owner');
    });

    test('defaults to an empty roster with no signature when absent', () {
      final response = FolderMembersResponse.fromJson(const {});

      expect(response.folderId, '');
      expect(response.folderOwnerId, '');
      expect(response.signatureAlgorithm, '');
      expect(response.members, isEmpty);
      expect(response.membersSignedAt, isNull);
      expect(response.membersListSignature, isNull);
      expect(response.membersListSignedByUserId, isNull);
    });
  });

  group('MemberKey.toJson', () {
    test('emits is_owner_of_file when set', () {
      final json = MemberKey(
        userId: 'u-1',
        encryptedKey: 'wrapped',
        isOwnerOfFile: true,
      ).toJson();

      expect(json, {
        'user_id': 'u-1',
        'encrypted_key': 'wrapped',
        'is_owner_of_file': true,
      });
    });

    test('omits is_owner_of_file when null', () {
      final json = MemberKey(userId: 'u-2', encryptedKey: 'wrapped').toJson();

      expect(json.containsKey('is_owner_of_file'), isFalse);
      expect(json, {'user_id': 'u-2', 'encrypted_key': 'wrapped'});
    });
  });

  group('MembersListSnapshot.toJson', () {
    test('carries the signed-at timestamp and signature', () {
      final json = MembersListSnapshot(
        membersSignedAt: 1700,
        membersListSignature: 'list-sig',
      ).toJson();

      expect(json, {
        'members_signed_at': 1700,
        'members_list_signature': 'list-sig',
      });
    });

    test('keeps null fields for a folder with no signed roster', () {
      final json = MembersListSnapshot().toJson();

      expect(json, {'members_signed_at': null, 'members_list_signature': null});
    });
  });
}
