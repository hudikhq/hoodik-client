import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';

void main() {
  group('ShareRole / AuditEventAction wire mapping', () {
    test('share role discriminants are stable', () {
      expect(ShareRole.reader.wire, 0);
      expect(ShareRole.editor.wire, 1);
      expect(ShareRole.coOwner.wire, 2);
    });

    test('fromWire fails closed to reader on an unknown string', () {
      expect(ShareRole.fromWire('co-owner'), ShareRole.coOwner);
      expect(ShareRole.fromWire('president'), ShareRole.reader);
    });

    test('audit action discriminants match the canonical enum', () {
      expect(AuditEventAction.grant.wire, 0);
      expect(AuditEventAction.revoke.wire, 1);
      expect(AuditEventAction.roleChange.wire, 2);
      expect(AuditEventAction.sharedFolderUpload.wire, 3);
      expect(AuditEventAction.fork.wire, 4);
      expect(AuditEventAction.sharedByCoOwner.wire, 5);
      expect(AuditEventAction.sharedFolderEdit.wire, 6);
      expect(AuditEventAction.sharedFolderRestore.wire, 7);
      expect(AuditEventAction.sharedFolderEvict.wire, 8);
      expect(AuditEventAction.sharedFolderMoveOut.wire, 9);
    });

    test('move-out is the signed ENUMERATED 9', () {
      final action = AuditEventAction.fromWire('shared_folder_move_out');
      expect(action, AuditEventAction.sharedFolderMoveOut);
      expect(action.wire, 9);
      expect(action.wireString, 'shared_folder_move_out');
    });

    test('cascade-revoke action maps from the server wire string', () {
      final action = AuditEventAction.fromWire('shared_by_co_owner_revoked');
      expect(action, AuditEventAction.sharedByCoOwnerRevoked);
      // The chain hash commits to this exact octet-string, so it must match
      // the bytes the server stored or the page won't verify.
      expect(action.wireString, 'shared_by_co_owner_revoked');
    });

    test('the revoked marker carries a non-ENUMERATED wire sentinel', () {
      // It is never signed into AuditEventSigInputV1; its wire must not
      // collide with move-out's real 9. -1 also can't reach the FFI u8
      // encoder without failing loud.
      expect(AuditEventAction.sharedByCoOwnerRevoked.wire, -1);
      expect(
        AuditEventAction.sharedByCoOwnerRevoked.wire,
        isNot(AuditEventAction.sharedFolderMoveOut.wire),
      );
    });

    test('fromWire fails closed instead of throwing on an unknown action', () {
      expect(
        () => AuditEventAction.fromWire('some_future_action'),
        returnsNormally,
      );
      expect(
        AuditEventAction.fromWire('some_future_action'),
        AuditEventAction.grant,
      );
    });
  });
}
