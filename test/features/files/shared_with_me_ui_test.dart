import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart' show ShareRole;
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:hoodik_app/features/files/helpers/file_helpers.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/features/files/widgets/file_list_item.dart';
import 'package:hoodik_app/features/files/widgets/file_sort_controls.dart';
import 'package:hoodik_app/features/files/widgets/files_app_bar.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

import '../../helpers/fakes.dart';
import 'package:hoodik_app/core/widgets/app_icons.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';

FileItem _recipientRow() {
  return FileItem(
    id: 'shared-file',
    encryptedName: 'enc',
    mime: 'image/png',
    finishedUploadAt: 1,
    isOwner: false,
    shareRole: ShareRole.reader,
    ownerEmail: 'alice@example.com',
  );
}

FileItem _ownedSharedRow() {
  return FileItem(
    id: 'owned-file',
    encryptedName: 'enc',
    mime: 'image/png',
    finishedUploadAt: 1,
    sharedWithCount: 3,
  );
}

Widget _wrapTile(FileItem file, {required bool sharingEnabled}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: FileListItem(
        file: file,
        displayName: 'name',
        isSelected: false,
        isOffline: false,
        selectionMode: false,
        sharingEnabled: sharingEnabled,
        onTap: () {},
        onContextMenu: (_) {},
        onToggleSelection: () {},
      ),
    ),
  );
}

class _SpyFilesNotifier extends FilesNotifier {
  int loadCalls = 0;

  @override
  FilesState build(String? arg) => const FilesState();

  @override
  Future<void> load() async => loadCalls++;
}

Future<_SpyFilesNotifier> _pumpRefreshAppBar(
  WidgetTester tester, {
  required TargetPlatform platform,
  String? dirId,
  bool busy = false,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final spy = _SpyFilesNotifier();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        connectivityProvider.overrideWith((ref) => FakeConnectivityService()),
        filesNotifierProvider.overrideWith(() => spy),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: FilesAppBar(
            dirId: dirId,
            selectionMode: false,
            selectionCount: 0,
            busy: busy,
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
        ),
      ),
    ),
  );
  await tester.pump();
  return spy;
}

/// The refresh glyph is adaptive — resolve the same variant the app bar
/// renders on this host.
final IconData _refreshIcon = adaptiveIcon(
  material: Icons.refresh,
  cupertino: CupertinoIcons.arrow_clockwise,
);

void main() {
  group('FileListItem share badges', () {
    testWidgets('recipient row shows an "Owned by" pill', (tester) async {
      await tester.pumpWidget(_wrapTile(_recipientRow(), sharingEnabled: true));
      expect(find.text('Owned by alice@example.com'), findsOneWidget);
    });

    testWidgets('owned shared row shows a "Shared with N" pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapTile(_ownedSharedRow(), sharingEnabled: true),
      );
      expect(find.text('Shared with 3'), findsOneWidget);
    });

    testWidgets('badges are suppressed when sharing is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapTile(_recipientRow(), sharingEnabled: false),
      );
      expect(find.textContaining('Owned by'), findsNothing);

      await tester.pumpWidget(
        _wrapTile(_ownedSharedRow(), sharingEnabled: false),
      );
      expect(find.textContaining('Shared with'), findsNothing);
    });

    testWidgets('owned non-shared row shows no share pill', (tester) async {
      final plain = FileItem(
        id: 'plain',
        encryptedName: 'enc',
        mime: 'image/png',
        finishedUploadAt: 1,
      );
      await tester.pumpWidget(_wrapTile(plain, sharingEnabled: true));
      expect(find.textContaining('Owned by'), findsNothing);
      expect(find.textContaining('Shared with'), findsNothing);
    });
  });

  group('FileListItem overflow trigger', () {
    testWidgets('a normal folder renders the kebab', (tester) async {
      final folder = FileItem(id: 'dir-1', encryptedName: 'enc', mime: 'dir');
      await tester.pumpWidget(_wrapTile(folder, sharingEnabled: true));
      expect(find.byIcon(AppIcons.overflowVertical), findsOneWidget);
    });

    testWidgets('the "Shared with me" virtual folder renders no kebab', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapTile(sharedWithMeFolder(), sharingEnabled: true),
      );
      expect(find.byIcon(AppIcons.overflowVertical), findsNothing);
    });
  });

  group('synthetic folder helpers', () {
    final synthetic = sharedWithMeFolder();

    testWidgets('icon is folder_shared and color differs from a plain folder', (
      tester,
    ) async {
      final plainFolder = FileItem(
        id: 'dir-1',
        encryptedName: 'enc',
        mime: 'dir',
      );
      expect(fileIcon(synthetic), Icons.folder_shared);
      expect(fileIcon(plainFolder), AppIcons.folder);

      // The colour now resolves from the theme, so it needs a real context.
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: HoodikTheme.dark(),
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        fileIconColor(ctx, synthetic),
        isNot(fileIconColor(ctx, plainFolder)),
      );
    });

    test('displayName renders the friendly label', () {
      const state = FilesState();
      expect(state.displayName(synthetic), 'Shared with me');
    });
  });

  group('FilesAppBar title', () {
    testWidgets('renders "Shared with me" for the synthetic id', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            connectivityProvider.overrideWith(
              (ref) => FakeConnectivityService(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: FilesAppBar(
                dirId: sharedWithMeDirId,
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
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Shared with me'), findsOneWidget);
    });
  });

  group('FilesAppBar refresh action', () {
    testWidgets('is shown on desktop and tapping it reloads', (tester) async {
      final spy = await _pumpRefreshAppBar(
        tester,
        platform: TargetPlatform.macOS,
      );

      expect(find.byTooltip('Refresh'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();

      expect(spy.loadCalls, 1);
    });

    testWidgets('is hidden on mobile, where pull-to-refresh covers it', (
      tester,
    ) async {
      await _pumpRefreshAppBar(tester, platform: TargetPlatform.android);

      expect(find.byIcon(_refreshIcon), findsNothing);
    });

    testWidgets('is disabled on desktop while busy', (tester) async {
      final spy = await _pumpRefreshAppBar(
        tester,
        platform: TargetPlatform.macOS,
        busy: true,
      );

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(_refreshIcon),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.byTooltip('Refresh'), warnIfMissed: false);
      await tester.pump();
      expect(spy.loadCalls, 0);
    });
  });
}
