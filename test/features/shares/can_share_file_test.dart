import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';

FileItem _file({
  String id = 'file-1',
  String mime = 'image/png',
  bool isOwner = true,
  ShareRole? shareRole,
}) {
  return FileItem(
    id: id,
    encryptedName: 'enc',
    mime: mime,
    isOwner: isOwner,
    shareRole: shareRole,
    finishedUploadAt: 1,
  );
}

void main() {
  group('canShareFile', () {
    test('true only for an owned, non-dir file with sharing enabled', () {
      expect(canShareFile(_file(), sharingEnabled: true), isTrue);
    });

    test('false when sharing is disabled on the server', () {
      expect(canShareFile(_file(), sharingEnabled: false), isFalse);
    });

    test('false for a non-owned (incoming-share) file', () {
      expect(
        canShareFile(_file(isOwner: false), sharingEnabled: true),
        isFalse,
      );
    });

    test('false for a directory (folders route through canShareFolder)', () {
      expect(canShareFile(_file(mime: 'dir'), sharingEnabled: true), isFalse);
    });

    test('false for the synthetic "Shared with me" root row', () {
      expect(canShareFile(sharedWithMeFolder(), sharingEnabled: true), isFalse);
    });
  });

  group('canShareFolder', () {
    test('true for an owned folder with sharing enabled', () {
      expect(canShareFolder(_file(mime: 'dir'), sharingEnabled: true), isTrue);
    });

    test('true for a co-owned folder (co-owners may reshare)', () {
      expect(
        canShareFolder(
          _file(mime: 'dir', isOwner: false, shareRole: ShareRole.coOwner),
          sharingEnabled: true,
        ),
        isTrue,
      );
    });

    test('false for a folder shared as reader or editor', () {
      expect(
        canShareFolder(
          _file(mime: 'dir', isOwner: false, shareRole: ShareRole.reader),
          sharingEnabled: true,
        ),
        isFalse,
      );
      expect(
        canShareFolder(
          _file(mime: 'dir', isOwner: false, shareRole: ShareRole.editor),
          sharingEnabled: true,
        ),
        isFalse,
      );
    });

    test('false for a non-directory file', () {
      expect(canShareFolder(_file(), sharingEnabled: true), isFalse);
    });

    test('false when sharing is disabled on the server', () {
      expect(
        canShareFolder(_file(mime: 'dir'), sharingEnabled: false),
        isFalse,
      );
    });

    test('false for the synthetic "Shared with me" root row', () {
      expect(
        canShareFolder(sharedWithMeFolder(), sharingEnabled: true),
        isFalse,
      );
    });
  });

  group('canFork', () {
    test('true for a co-owned non-dir share with sharing enabled', () {
      expect(
        canFork(
          _file(isOwner: false, shareRole: ShareRole.coOwner),
          sharingEnabled: true,
        ),
        isTrue,
      );
    });

    test(
      'false for a reader or editor share (server gates fork to co-owner)',
      () {
        expect(
          canFork(
            _file(isOwner: false, shareRole: ShareRole.reader),
            sharingEnabled: true,
          ),
          isFalse,
        );
        expect(
          canFork(
            _file(isOwner: false, shareRole: ShareRole.editor),
            sharingEnabled: true,
          ),
          isFalse,
        );
      },
    );

    test('false for an owned file (nothing to fork)', () {
      expect(canFork(_file(), sharingEnabled: true), isFalse);
    });

    test('false for a co-owned directory (cannot_fork_directory)', () {
      expect(
        canFork(
          _file(mime: 'dir', isOwner: false, shareRole: ShareRole.coOwner),
          sharingEnabled: true,
        ),
        isFalse,
      );
    });

    test('false when sharing is disabled on the server', () {
      expect(
        canFork(
          _file(isOwner: false, shareRole: ShareRole.coOwner),
          sharingEnabled: false,
        ),
        isFalse,
      );
    });

    test('false for the synthetic "Shared with me" root row', () {
      expect(canFork(sharedWithMeFolder(), sharingEnabled: true), isFalse);
    });
  });

  group('canLeaveFile', () {
    test('true for a non-owned file shared with the caller', () {
      expect(canLeaveFile(_file(isOwner: false), sharingEnabled: true), isTrue);
    });

    test('true for a non-owned folder (recipients can leave folders too)', () {
      expect(
        canLeaveFile(_file(mime: 'dir', isOwner: false), sharingEnabled: true),
        isTrue,
      );
    });

    test('false for an owned file (nothing to leave)', () {
      expect(canLeaveFile(_file(), sharingEnabled: true), isFalse);
    });

    test('false when sharing is disabled on the server', () {
      expect(
        canLeaveFile(_file(isOwner: false), sharingEnabled: false),
        isFalse,
      );
    });

    test('false for the synthetic "Shared with me" root row', () {
      expect(canLeaveFile(sharedWithMeFolder(), sharingEnabled: true), isFalse);
    });
  });
}
