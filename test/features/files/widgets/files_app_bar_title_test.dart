import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/widgets/file_sort_controls.dart';
import 'package:hoodik_app/features/files/widgets/files_app_bar.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

import '../../../helpers/fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  String? dirId,
  String? dirName,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityProvider.overrideWith((ref) => FakeConnectivityService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: FilesAppBar(
            dirId: dirId,
            dirName: dirName,
            selectionMode: false,
            selectionCount: 0,
            busy: false,
            hasFiles: false,
            isFromCache: false,
            sortField: SortField.name,
            sortOrder: SortOrder.asc,
            onExitSelection: () {},
            onMoveSelected: () {},
            onDeleteSelected: () {},
            onEnterSelection: () {},
            onCreate: () {},
            onSortFieldSelected: (_) {},
          ),
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('root listing shows My Files', (tester) async {
    await _pump(tester);
    expect(find.text('My Files'), findsOneWidget);
  });

  testWidgets('subfolder shows the decrypted folder name', (tester) async {
    await _pump(tester, dirId: 'dir-1', dirName: 'Tax 2026');
    expect(find.text('Tax 2026'), findsOneWidget);
    expect(find.text('Files'), findsNothing);
  });

  testWidgets('cold deep-link without a name falls back to Files', (
    tester,
  ) async {
    await _pump(tester, dirId: 'dir-1');
    expect(find.text('Files'), findsOneWidget);
  });

  testWidgets('shared-with-me keeps its virtual-folder title', (tester) async {
    await _pump(tester, dirId: sharedWithMeDirId, dirName: 'ignored');
    expect(find.text('Shared with me'), findsOneWidget);
  });
}
