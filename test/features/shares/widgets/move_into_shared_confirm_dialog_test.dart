import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/widgets/move_into_shared_confirm_dialog.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

FolderMember _member(String userId, {required bool isOwner}) {
  return FolderMember(
    userId: userId,
    email: '$userId@example.test',
    pubkey: 'pub',
    pubkeyFingerprint: 'ab' * 16,
    shareRole: ShareRole.reader,
    isOwner: isOwner,
    addedAt: isOwner ? null : 100,
    signedByUserId: isOwner ? null : 'owner',
    memberSignature: null,
  );
}

/// Pump a host, open the confirm dialog from a live context, and return the
/// pending bool the dialog resolves to. The dialog is on screen once this
/// returns, so the caller asserts copy or taps an action.
Future<Future<bool>> _open(
  WidgetTester tester, {
  required List<FolderMember> members,
  int itemCount = 3,
}) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  final pending = confirmMoveIntoSharedFolder(
    context: ctx,
    folderName: 'Reports',
    destinationName: 'Team',
    itemCount: itemCount,
    members: members,
  );
  await tester.pumpAndSettle();
  return pending;
}

void main() {
  // The cascade hands the dialog the recipients verbatim — the destination
  // owner included, the mover already excluded — so the dialog lists every
  // member it is given, the owner among them.
  final recipients = [
    _member('owner', isOwner: true),
    _member('bob', isOwner: false),
  ];

  testWidgets('renders the folder, destination, and member copy', (
    tester,
  ) async {
    await _open(tester, members: recipients);

    expect(find.text('Move and share folder?'), findsOneWidget);
    expect(find.textContaining('Reports'), findsWidgets);
    expect(find.textContaining('Team'), findsWidgets);
    // Every recipient is listed, the destination owner included.
    expect(find.text('owner@example.test'), findsOneWidget);
    expect(find.text('bob@example.test'), findsOneWidget);
  });

  testWidgets('returns false when cancelled', (tester) async {
    final pending = await _open(tester, members: recipients);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await pending, isFalse);
  });

  testWidgets('returns true when confirmed', (tester) async {
    final pending = await _open(tester, members: recipients);
    await tester.tap(find.text('Move and share'));
    await tester.pumpAndSettle();
    expect(await pending, isTrue);
  });

  testWidgets('an empty recipient set omits the member list', (tester) async {
    await _open(tester, members: const [], itemCount: 1);
    // No recipients → the "will share with" phrasing and the member rows are
    // both absent; the copy reads as a plain re-parent of 1 item.
    expect(find.textContaining('will move it'), findsOneWidget);
    expect(find.textContaining('will share it'), findsNothing);
  });
}
