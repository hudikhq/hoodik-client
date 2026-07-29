import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/share_group_models.dart';
import 'package:hoodik_app/features/shares/widgets/member_of_group_tile.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

ShareGroupAsMember _group(GroupRole role) {
  return ShareGroupAsMember(
    id: 'g1',
    ownerId: 'owner',
    ownerEmail: 'owner@example.test',
    name: 'Team',
    createdAt: 100,
    addedAt: 100,
    groupRole: role,
  );
}

Future<void> _pump(WidgetTester tester, GroupRole role) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MemberOfGroupTile(group: _group(role), onAddMember: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('co-owner sees Add member but never Rename group', (
    tester,
  ) async {
    await _pump(tester, GroupRole.coOwner);
    expect(find.byTooltip('Add member'), findsOneWidget);
    expect(find.byTooltip('Rename group'), findsNothing);
    expect(find.text('Rename group'), findsNothing);
  });

  testWidgets('reader sees neither Add member nor Rename group', (
    tester,
  ) async {
    await _pump(tester, GroupRole.reader);
    expect(find.byTooltip('Add member'), findsNothing);
    expect(find.byTooltip('Rename group'), findsNothing);
  });
}
