import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_models.dart';
import 'package:hoodik_app/core/api/shares_models.dart';

void main() {
  group('FileItem thumbnail flags', () {
    test('has_thumbnail comes from the wire flag when present', () {
      final file = FileItem.fromJson(const {'id': 'f1', 'has_thumbnail': true});
      expect(file.hasThumbnail, isTrue);
      expect(file.encryptedThumbnail, isNull);
      expect(file.thumbnailAvailable, isTrue);
    });

    test('falls back to inline blob presence on older servers', () {
      final withBlob = FileItem.fromJson(const {
        'id': 'f1',
        'encrypted_thumbnail': 'aabbcc',
      });
      expect(withBlob.hasThumbnail, isTrue);
      expect(withBlob.thumbnailAvailable, isTrue);

      final without = FileItem.fromJson(const {'id': 'f1'});
      expect(without.hasThumbnail, isFalse);
      expect(without.thumbnailAvailable, isFalse);
    });

    test('copyWith and fromIncomingShare carry the flag', () {
      final file = FileItem.fromJson(const {'id': 'f1', 'has_thumbnail': true});
      expect(file.copyWith(sharedWithCount: 2).hasThumbnail, isTrue);

      final share = IncomingShare.fromJson(const {
        'file_id': 'f2',
        'share_role': 'reader',
        'has_thumbnail': true,
      });
      expect(FileItem.fromIncomingShare(share).hasThumbnail, isTrue);
    });
  });

  group('IncomingShare thumbnail flags', () {
    test('has_thumbnail comes from the wire flag when present', () {
      final share = IncomingShare.fromJson(const {
        'file_id': 'f1',
        'share_role': 'reader',
        'has_thumbnail': true,
      });
      expect(share.hasThumbnail, isTrue);
      expect(share.encryptedThumbnail, isNull);
    });

    test('falls back to inline blob presence on older servers', () {
      final withBlob = IncomingShare.fromJson(const {
        'file_id': 'f1',
        'share_role': 'reader',
        'encrypted_thumbnail': 'aabbcc',
      });
      expect(withBlob.hasThumbnail, isTrue);

      final without = IncomingShare.fromJson(const {
        'file_id': 'f1',
        'share_role': 'reader',
      });
      expect(without.hasThumbnail, isFalse);
    });
  });
}
