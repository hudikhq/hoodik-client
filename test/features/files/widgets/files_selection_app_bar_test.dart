import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/features/files/widgets/files_selection_app_bar.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

FileItem _file(String id) => FileItem(
  id: id,
  encryptedName: 'enc-$id',
  mime: 'text/plain',
  finishedUploadAt: 1,
);

class _StubNotifier extends FilesNotifier {
  _StubNotifier(this._initial);
  final FilesState _initial;

  @override
  FilesState build(String? arg) => _initial;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required FilesState state,
    required int selectionCount,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        key: ValueKey('${selectionCount}_${state.selectedIds.length}'),
        overrides: [
          filesNotifierProvider.overrideWith(() => _StubNotifier(state)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: FilesSelectionAppBar(
              dirId: null,
              selectionCount: selectionCount,
              busy: false,
              onExitSelection: () {},
              onExportSelected: () {},
              onMakeOfflineSelected: () {},
              onMoveSelected: () {},
              onDeleteSelected: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Select all / Clear label flips; Export disabled at count 0', (
    tester,
  ) async {
    final files = [_file('a'), _file('b')];
    await pump(
      tester,
      selectionCount: 0,
      state: FilesState(loading: false, files: files, selectionMode: true),
    );

    expect(find.text('Select all'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Export',
            ),
          )
          .onPressed,
      isNull,
    );

    await pump(
      tester,
      selectionCount: 2,
      state: FilesState(
        loading: false,
        files: files,
        selectionMode: true,
        selectedIds: {'a', 'b'},
      ),
    );

    expect(find.text('Clear'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Export',
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}
