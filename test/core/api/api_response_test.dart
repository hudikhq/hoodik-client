import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';

void main() {
  group('AuthResponse', () {
    test('hasTfa false when secret is missing', () {
      final auth = AuthResponse(user: {'id': 'u1'});
      expect(auth.hasTfa, false);
    });

    test('hasTfa false when secret is false', () {
      final auth = AuthResponse(user: {'id': 'u1', 'secret': false});
      expect(auth.hasTfa, false);
    });

    test('expiresAt delegates to session', () {
      final auth = AuthResponse(
        user: {},
        session: SessionInfo.fromJson({'expires_at': 1700000000}),
      );

      expect(auth.expiresAt, 1700000000);
    });

    test('expiresAt null when no session', () {
      final auth = AuthResponse(user: {});
      expect(auth.expiresAt, isNull);
    });
  });

  group('StorageResponse', () {
    test('fromJson parses children and metadata', () {
      final resp = StorageResponse.fromJson({
        'children': [
          {
            'id': 'f1',
            'encrypted_name': 'enc1',
            'mime': 'image/png',
            'size': 1024,
            'finished_upload_at': 1700000000,
          },
          {'id': 'f2', 'encrypted_name': 'enc2', 'mime': 'dir'},
        ],
        'used_space': 50000,
        'quota': 1073741824,
      });

      expect(resp.children.length, 2);
      expect(resp.children[0].id, 'f1');
      expect(resp.children[0].mime, 'image/png');
      expect(resp.children[1].isDir, true);
    });

    test('fromJson handles empty children', () {
      final resp = StorageResponse.fromJson({'children': []});

      expect(resp.children, isEmpty);
    });

    test('fromJson handles missing children key', () {
      final resp = StorageResponse.fromJson({});

      expect(resp.children, isEmpty);
    });
  });

  group('FileItem', () {
    test('fromJson parses all fields', () {
      final file = FileItem.fromJson({
        'id': 'f1',
        'file_id': 'dir-parent',
        'encrypted_name': 'enc_name',
        'encrypted_key': 'enc_key',
        'encrypted_thumbnail': 'enc_thumb',
        'mime': 'application/pdf',
        'size': 2048,
        'chunks': 4,
        'chunks_stored': 4,
        'cipher': 'chacha20poly1305',
        'file_modified_at': 1690000000,
        'created_at': 1690000000,
        'finished_upload_at': 1690000001,
      });

      expect(file.id, 'f1');
      expect(file.fileId, 'dir-parent');
      expect(file.encryptedName, 'enc_name');
      expect(file.encryptedKey, 'enc_key');
      expect(file.encryptedThumbnail, 'enc_thumb');
      expect(file.mime, 'application/pdf');
      expect(file.size, 2048);
      expect(file.chunks, 4);
      expect(file.chunksStored, 4);
      expect(file.cipher, 'chacha20poly1305');
      expect(file.fileModifiedAt, 1690000000);
      expect(file.createdAt, 1690000000);
      expect(file.finishedUploadAt, 1690000001);
      expect(file.isUploading, false);
      expect(file.isDir, false);
    });

    test('fromJson defaults for missing fields', () {
      final file = FileItem.fromJson({'id': 'f1', 'encrypted_name': 'enc'});

      expect(file.mime, 'unknown');
      expect(file.cipher, 'aegis128l');
      expect(file.fileId, isNull);
      expect(file.encryptedKey, isNull);
      expect(file.encryptedThumbnail, isNull);
      expect(file.size, isNull);
      expect(file.finishedUploadAt, isNull);
      expect(file.isUploading, true);
    });

    test('isDir true for mime "dir"', () {
      final d = FileItem(id: 'd1', encryptedName: 'enc', mime: 'dir');
      expect(d.isDir, true);
    });

    test('isUploading true when finishedUploadAt is null', () {
      final f = FileItem(id: 'f1', encryptedName: 'enc', mime: 'text/plain');
      expect(f.isUploading, true);
    });

    test('isUploading false when finishedUploadAt is set', () {
      final f = FileItem(
        id: 'f1',
        encryptedName: 'enc',
        mime: 'text/plain',
        finishedUploadAt: 1700000000,
      );
      expect(f.isUploading, false);
    });

    test('isDir false for regular mime types', () {
      for (final mime in ['image/png', 'text/plain', 'application/pdf']) {
        final f = FileItem(id: 'f', encryptedName: 'e', mime: mime);
        expect(f.isDir, false, reason: 'mime=$mime should not be dir');
      }
    });
  });

  group('AdminUser', () {
    test('fromJson parses all fields including lastSession', () {
      final user = AdminUser.fromJson({
        'id': 'u1',
        'role': 'admin',
        'email': 'admin@test.com',
        'secret': true,
        'quota': 5368709120,
        'fingerprint': 'fp123',
        'email_verified_at': 1700000000,
        'created_at': 1690000000,
        'updated_at': 1695000000,
        'last_session': {
          'id': 's1',
          'user_id': 'u1',
          'email': 'admin@test.com',
          'ip': '192.168.1.1',
          'user_agent': 'Chrome',
          'created_at': 1694000000,
          'updated_at': 1695000000,
          'expires_at': 1700000000,
          'active': true,
        },
      });

      expect(user.id, 'u1');
      expect(user.isAdmin, true);
      expect(user.hasTfa, true);
      expect(user.quota, 5368709120);
      expect(user.lastSession, isNotNull);
      expect(user.lastSession!.ip, '192.168.1.1');
    });

    test('isAdmin false for non-admin role', () {
      final user = AdminUser.fromJson({
        'id': 'u1',
        'role': 'user',
        'email': 'user@test.com',
        'created_at': 0,
        'updated_at': 0,
      });

      expect(user.isAdmin, false);
    });

    test('isAdmin false when role is null', () {
      final user = AdminUser.fromJson({
        'id': 'u1',
        'email': 'test@test.com',
        'created_at': 0,
        'updated_at': 0,
      });

      expect(user.isAdmin, false);
    });
  });

  group('AdminUserDetail', () {
    test('totalSize and totalFiles aggregate stats', () {
      final detail = AdminUserDetail.fromJson({
        'user': {
          'id': 'u1',
          'email': 'test@test.com',
          'created_at': 0,
          'updated_at': 0,
        },
        'stats': [
          {'mime': 'image/jpeg', 'size': 1000, 'count': 5},
          {'mime': 'video/mp4', 'size': 2000, 'count': 3},
          {'mime': 'text/plain', 'size': 500, 'count': 10},
        ],
      });

      expect(detail.totalSize, 3500);
      expect(detail.totalFiles, 18);
      expect(detail.stats.length, 3);
    });
  });

  group('Invitation', () {
    test('isExpired true for past timestamp', () {
      final inv = Invitation.fromJson({
        'id': 'inv-1',
        'email': 'test@test.com',
        'created_at': 1000000000,
        'expires_at': 1000000001,
      });

      expect(inv.isExpired, true);
    });

    test('isExpired false for future timestamp', () {
      final futureTs =
          (DateTime.now()
                      .add(const Duration(days: 365))
                      .millisecondsSinceEpoch /
                  1000)
              .round();
      final inv = Invitation.fromJson({
        'id': 'inv-1',
        'email': 'test@test.com',
        'created_at': 1000000000,
        'expires_at': futureTs,
      });

      expect(inv.isExpired, false);
    });

    test('isRedeemed true when userId present', () {
      final inv = Invitation.fromJson({
        'id': 'inv-1',
        'user_id': 'u1',
        'email': 'test@test.com',
        'created_at': 0,
        'expires_at': 0,
      });

      expect(inv.isRedeemed, true);
    });

    test('isRedeemed false when userId absent', () {
      final inv = Invitation.fromJson({
        'id': 'inv-1',
        'email': 'test@test.com',
        'created_at': 0,
        'expires_at': 0,
      });

      expect(inv.isRedeemed, false);
    });
  });

  group('ServerSettings', () {
    test('fromJson parses nested users object', () {
      final s = ServerSettings.fromJson({
        'users': {
          'quota_bytes': 5368709120,
          'allow_register': true,
          'enforce_email_activation': true,
        },
      });

      expect(s.quotaBytes, 5368709120);
      expect(s.allowRegister, true);
      expect(s.enforceEmailActivation, true);
    });

    test('fromJson defaults when users key missing', () {
      final s = ServerSettings.fromJson({});

      expect(s.quotaBytes, isNull);
      expect(s.allowRegister, false);
      expect(s.enforceEmailActivation, false);
    });

    test('toJson produces correct structure', () {
      final s = ServerSettings(
        quotaBytes: 1073741824,
        allowRegister: true,
        enforceEmailActivation: false,
      );

      final json = s.toJson();
      final users = json['users'] as Map<String, dynamic>;

      expect(users['quota_bytes'], 1073741824);
      expect(users['allow_register'], true);
      expect(users['enforce_email_activation'], false);
    });

    test('toJson roundtrip preserves values', () {
      final original = ServerSettings(
        quotaBytes: null,
        allowRegister: false,
        enforceEmailActivation: true,
      );

      final restored = ServerSettings.fromJson(original.toJson());

      expect(restored.quotaBytes, original.quotaBytes);
      expect(restored.allowRegister, original.allowRegister);
      expect(restored.enforceEmailActivation, original.enforceEmailActivation);
    });

    test('fromJson reads the sharing block when present', () {
      final s = ServerSettings.fromJson({
        'users': <String, dynamic>{},
        'sharing': {'enabled': false},
      });

      expect(s.sharingSupported, true);
      expect(s.sharingEnabled, false);
    });

    test('fromJson treats a missing sharing block as an older server', () {
      final s = ServerSettings.fromJson({'users': <String, dynamic>{}});

      expect(s.sharingSupported, false);
      // Server default is enabled; the UI hides the toggle regardless.
      expect(s.sharingEnabled, true);
    });

    test('toJson omits the sharing block for an unsupported server', () {
      final s = ServerSettings(
        allowRegister: true,
        enforceEmailActivation: false,
        sharingSupported: false,
      );

      expect(s.toJson().containsKey('sharing'), false);
    });

    test('toJson emits the sharing block once the server supports it', () {
      final s = ServerSettings(
        allowRegister: true,
        enforceEmailActivation: false,
        sharingEnabled: false,
        sharingSupported: true,
      );

      expect(s.toJson()['sharing'], {'enabled': false});
    });

    test('copyWith preserves sharing support across an unrelated edit', () {
      final s = ServerSettings(
        allowRegister: false,
        enforceEmailActivation: false,
        sharingEnabled: true,
        sharingSupported: true,
      ).copyWith(allowRegister: true);

      expect(s.allowRegister, true);
      expect(s.sharingSupported, true);
      expect(s.sharingEnabled, true);
    });
  });

  group('StorageStats', () {
    test('fromJson parses fields', () {
      final s = StorageStats.fromJson({
        'mime': 'video/mp4',
        'size': 999999,
        'count': 3,
      });

      expect(s.mime, 'video/mp4');
      expect(s.size, 999999);
      expect(s.count, 3);
    });

    test('fromJson defaults for missing', () {
      final s = StorageStats.fromJson({});
      expect(s.mime, 'unknown');
      expect(s.size, 0);
      expect(s.count, 0);
    });
  });

  group('Paginated', () {
    test('stores data and total', () {
      final page = Paginated<String>(data: ['a', 'b', 'c'], total: 10);

      expect(page.data.length, 3);
      expect(page.total, 10);
    });

    test('empty page', () {
      final page = Paginated<int>(data: [], total: 0);
      expect(page.data, isEmpty);
      expect(page.total, 0);
    });
  });
}
