import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/providers/folder_members_notifier.dart';
import 'package:hoodik_app/features/shares/widgets/folder_member_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

FolderMember _member({
  required String userId,
  required ShareRole role,
  required bool isOwner,
}) {
  return FolderMember(
    userId: userId,
    email: '$userId@example.test',
    pubkey: 'pub',
    pubkeyFingerprint: 'ab' * 16,
    shareRole: role,
    isOwner: isOwner,
    addedAt: isOwner ? null : 100,
    signedByUserId: isOwner ? null : 'owner',
    memberSignature: null,
  );
}

Future<void> _pump(WidgetTester tester, FolderMember member) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FolderMemberTile(
          member: member,
          ownerId: 'owner',
          callerId: 'owner',
          signatureStatus: MemberSignatureStatus.verified,
          canMutate: false,
          onChangeRole: () {},
          onRevoke: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('owner row shows only the Owner badge, not a role', (
    tester,
  ) async {
    // The server reports the owner as a co-owner; pairing "Co-owner" with
    // "Owner" reads as a contradiction, so the owner gets only the Owner badge.
    await _pump(
      tester,
      _member(userId: 'owner', role: ShareRole.coOwner, isOwner: true),
    );
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Co-owner'), findsNothing);
  });

  testWidgets('a non-owner shows its role badge and no Owner badge', (
    tester,
  ) async {
    await _pump(
      tester,
      _member(userId: 'bob', role: ShareRole.coOwner, isOwner: false),
    );
    expect(find.text('Co-owner'), findsOneWidget);
    expect(find.text('Owner'), findsNothing);
  });
}
