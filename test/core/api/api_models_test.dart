import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_models.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;

void main() {
  group('FileItem.fromJson sharing fields', () {
    test('defaults to owned with no share metadata for an owned row', () {
      final item = FileItem.fromJson({
        'id': 'f-1',
        'encrypted_name': 'ENC',
        'mime': 'image/png',
      });

      expect(item.isOwner, isTrue);
      expect(item.shareRole, isNull);
      expect(item.membersSignedAt, isNull);
      expect(item.ownerEmail, isNull);
      expect(item.sharedByEmail, isNull);
      expect(item.sharedWithCount, isNull);
    });

    test('parses every sharing field from the wire', () {
      final item = FileItem.fromJson({
        'id': 'f-2',
        'encrypted_name': 'ENC',
        'mime': 'dir',
        'is_owner': false,
        'share_role': 'co-owner',
        'members_signed_at': 1717000000,
        'owner_email': 'owner@example.test',
        'shared_by_email': 'sharer@example.test',
        'shared_with_count': 3,
      });

      expect(item.isOwner, isFalse);
      expect(item.shareRole, ShareRole.coOwner);
      expect(item.membersSignedAt, 1717000000);
      expect(item.ownerEmail, 'owner@example.test');
      expect(item.sharedByEmail, 'sharer@example.test');
      expect(item.sharedWithCount, 3);
    });

    test('leaves shareRole null when the wire omits it', () {
      final item = FileItem.fromJson({
        'id': 'f-3',
        'encrypted_name': 'ENC',
        'mime': 'dir',
        'is_owner': true,
        'members_signed_at': 42,
      });

      expect(item.shareRole, isNull);
      expect(item.membersSignedAt, 42);
    });

    test('an unknown share_role string fails closed to reader', () {
      final item = FileItem.fromJson({
        'id': 'f-4',
        'encrypted_name': 'ENC',
        'mime': 'text/plain',
        'is_owner': false,
        'share_role': 'superuser',
      });

      expect(item.shareRole, ShareRole.reader);
    });
  });

  group('FileItem.fromIncomingShare', () {
    IncomingShare buildShare({
      String mime = 'image/png',
      int? finishedUploadAt = 1717000500,
    }) {
      return IncomingShare(
        fileId: 'shared-1',
        mime: mime,
        encryptedName: 'ENC_NAME',
        encryptedThumbnail: 'ENC_THUMB',
        cipher: 'chacha20poly1305',
        editable: true,
        size: 2048,
        chunks: 4,
        chunksStored: 4,
        finishedUploadAt: finishedUploadAt,
        sha256: 'DEADBEEF',
        shareRole: ShareRole.editor,
        encryptedKey: 'WRAPPED_KEY',
        createdAt: 1717000000,
        ownerId: 'owner-uuid',
        ownerEmail: 'owner@example.test',
        ownerPubkey: 'OWNER_PUB',
        ownerPubkeyFingerprint: 'OWNER_FP',
        sharedByEmail: 'sharer@example.test',
      );
    }

    test('maps a shared file onto a non-owned FileItem', () {
      final item = FileItem.fromIncomingShare(buildShare());

      expect(item.id, 'shared-1');
      expect(item.isOwner, isFalse);
      expect(item.shareRole, ShareRole.editor);
      expect(item.ownerEmail, 'owner@example.test');
      expect(item.sharedByEmail, 'sharer@example.test');
    });

    test('copies the encrypted name, thumbnail, cipher, size and chunks', () {
      final item = FileItem.fromIncomingShare(buildShare());

      expect(item.encryptedName, 'ENC_NAME');
      expect(item.encryptedThumbnail, 'ENC_THUMB');
      expect(item.encryptedKey, 'WRAPPED_KEY');
      expect(item.cipher, 'chacha20poly1305');
      expect(item.size, 2048);
      expect(item.chunks, 4);
      expect(item.chunksStored, 4);
      expect(item.sha256, 'DEADBEEF');
      expect(item.editable, isTrue);
    });

    test(
      'carries finishedUploadAt so a complete share is not "Uploading…"',
      () {
        final item = FileItem.fromIncomingShare(buildShare());

        expect(item.finishedUploadAt, 1717000500);
        expect(item.isUploading, isFalse);
      },
    );

    test('a shared dir reports isDir and skips the uploading state', () {
      final item = FileItem.fromIncomingShare(
        buildShare(mime: 'dir', finishedUploadAt: null),
      );

      expect(item.isDir, isTrue);
      expect(item.isUploading, isFalse);
    });
  });
}
