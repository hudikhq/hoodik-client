import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/share_group_models.dart';

void main() {
  group('GroupRole.fromWire', () {
    test('maps the three known wire strings', () {
      expect(GroupRole.fromWire('reader'), GroupRole.reader);
      expect(GroupRole.fromWire('editor'), GroupRole.editor);
      expect(GroupRole.fromWire('co-owner'), GroupRole.coOwner);
      expect(GroupRole.fromWire('owner'), GroupRole.owner);
    });

    test('fails closed to reader for an unknown role', () {
      expect(GroupRole.fromWire('superadmin'), GroupRole.reader);
      expect(GroupRole.fromWire(''), GroupRole.reader);
    });
  });

  group('capability gates', () {
    test('canShareToGroup is editor and above', () {
      expect(GroupRole.reader.canShareToGroup, isFalse);
      expect(GroupRole.editor.canShareToGroup, isTrue);
      expect(GroupRole.coOwner.canShareToGroup, isTrue);
      expect(GroupRole.owner.canShareToGroup, isTrue);
    });

    test('canManageGroup is co-owner and above', () {
      expect(GroupRole.reader.canManageGroup, isFalse);
      expect(GroupRole.editor.canManageGroup, isFalse);
      expect(GroupRole.coOwner.canManageGroup, isTrue);
      expect(GroupRole.owner.canManageGroup, isTrue);
    });

    test('canDeleteGroup is owner only', () {
      expect(GroupRole.reader.canDeleteGroup, isFalse);
      expect(GroupRole.editor.canDeleteGroup, isFalse);
      expect(GroupRole.coOwner.canDeleteGroup, isFalse);
      expect(GroupRole.owner.canDeleteGroup, isTrue);
    });
  });

  group('canSetRoleTo — privilege-escalation guard', () {
    test('owner may set any current member to any tier but the owner tier', () {
      for (final current in GroupRole.values) {
        expect(GroupRole.owner.canSetRoleTo(current, GroupRole.reader), isTrue);
        expect(GroupRole.owner.canSetRoleTo(current, GroupRole.editor), isTrue);
        expect(
          GroupRole.owner.canSetRoleTo(current, GroupRole.coOwner),
          isTrue,
        );
        expect(GroupRole.owner.canSetRoleTo(current, GroupRole.owner), isFalse);
      }
    });

    test('co-owner may set a reader/editor to reader/editor', () {
      for (final current in [GroupRole.reader, GroupRole.editor]) {
        expect(
          GroupRole.coOwner.canSetRoleTo(current, GroupRole.reader),
          isTrue,
        );
        expect(
          GroupRole.coOwner.canSetRoleTo(current, GroupRole.editor),
          isTrue,
        );
      }
    });

    test('co-owner may never grant co-owner (no privilege-equal escalation) '
        'nor the owner tier', () {
      for (final current in GroupRole.values) {
        expect(
          GroupRole.coOwner.canSetRoleTo(current, GroupRole.coOwner),
          isFalse,
        );
        expect(
          GroupRole.coOwner.canSetRoleTo(current, GroupRole.owner),
          isFalse,
        );
      }
    });

    test('co-owner may not act on an owner or another co-owner', () {
      for (final current in [GroupRole.owner, GroupRole.coOwner]) {
        for (final next in [GroupRole.reader, GroupRole.editor]) {
          expect(GroupRole.coOwner.canSetRoleTo(current, next), isFalse);
        }
      }
    });

    test('editor and reader may set nothing', () {
      for (final current in GroupRole.values) {
        for (final next in GroupRole.values) {
          expect(GroupRole.editor.canSetRoleTo(current, next), isFalse);
          expect(GroupRole.reader.canSetRoleTo(current, next), isFalse);
        }
      }
    });
  });
}
