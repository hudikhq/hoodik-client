import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/files/widgets/file_menu_actions_builder.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';
import 'package:flutter/material.dart';
import 'package:hoodik_app/core/theme/hoodik_theme.dart';

FileMenuCallbacks _noopCallbacks({
  void Function(FileItem)? onPreview,
  void Function(FileItem)? onRemoveOffline,
  void Function(FileItem)? onMakeOffline,
  void Function(FileItem)? onConvertToNote,
  void Function(FileItem)? onShare,
  void Function(FileItem)? onLeave,
  void Function(FileItem)? onFork,
  void Function(FileItem)? onSelect,
}) {
  return FileMenuCallbacks(
    onPreview: onPreview ?? (_) {},
    onConvertToNote: onConvertToNote ?? (_) {},
    onDownload: (_) {},
    onMakeOffline: onMakeOffline ?? (_) {},
    onRemoveOffline: onRemoveOffline ?? (_) {},
    onRename: (_) {},
    onDelete: (_) {},
    onCreateLink: (_) {},
    onShare: onShare,
    onLeave: onLeave,
    onFork: onFork,
    onDetails: (_) {},
    onSelect: onSelect ?? (_) {},
  );
}

FileItem _file({
  String mime = 'application/octet-stream',
  bool editable = false,
  int? finishedUploadAt = 1,
  bool isOwner = true,
  ShareRole? shareRole,
}) {
  return FileItem(
    id: 'id-1',
    encryptedName: 'enc',
    mime: mime,
    editable: editable,
    finishedUploadAt: finishedUploadAt,
    isOwner: isOwner,
    shareRole: shareRole,
  );
}

FileItem _dir({bool isOwner = true}) {
  return FileItem(
    id: 'dir-1',
    encryptedName: 'enc',
    mime: 'dir',
    isOwner: isOwner,
  );
}

/// Pumps a themed shell and hands back a context the builder can resolve
/// colours from.
Future<BuildContext> _ctx(WidgetTester tester) async {
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
  return ctx;
}

void main() {
  group('buildFileMenuActions', () {
    testWidgets('folder menu omits file-only actions', (tester) async {
      final ctx = await _ctx(tester);
      final actions = buildFileMenuActions(
        context: ctx,
        file: _dir(),
        isOffline: false,
        sharingEnabled: false,
        callbacks: _noopCallbacks(),
      );
      final labels = actions.map((a) => a.label).toList();
      expect(labels, isNot(contains('Preview')));
      expect(labels, isNot(contains('Export')));
      expect(labels, isNot(contains('Create Link')));
      expect(labels, isNot(contains('Make Available Offline')));
      expect(labels, isNot(contains('Remove Offline Copy')));
      expect(labels, isNot(contains('Details')));
      expect(labels, containsAll(['Rename', 'Delete', 'Select']));
    });

    testWidgets('synthetic "Shared with me" folder has no actions', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      final actions = buildFileMenuActions(
        context: ctx,
        file: sharedWithMeFolder(),
        isOffline: false,
        sharingEnabled: true,
        callbacks: _noopCallbacks(onShare: (_) {}, onLeave: (_) {}),
      );
      expect(actions, isEmpty);
    });

    testWidgets('previewable image file includes Preview and Export', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      final actions = buildFileMenuActions(
        context: ctx,
        file: _file(mime: 'image/jpeg'),
        isOffline: false,
        sharingEnabled: false,
        callbacks: _noopCallbacks(),
      );
      final labels = actions.map((a) => a.label).toList();
      expect(labels, contains('Preview'));
      expect(labels, contains('Export'));
      expect(labels, contains('Create Link'));
      expect(labels, contains('Make Available Offline'));
      expect(labels, isNot(contains('Remove Offline Copy')));
    });

    testWidgets('offline toggle flips based on isOffline flag', (tester) async {
      final ctx = await _ctx(tester);
      final offline = buildFileMenuActions(
        context: ctx,
        file: _file(mime: 'image/jpeg'),
        isOffline: true,
        sharingEnabled: false,
        callbacks: _noopCallbacks(),
      );
      expect(offline.map((a) => a.label), contains('Remove Offline Copy'));
      expect(
        offline.map((a) => a.label),
        isNot(contains('Make Available Offline')),
      );
    });

    testWidgets('non-editable markdown file shows "Convert to note"', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      final actions = buildFileMenuActions(
        context: ctx,
        file: _file(mime: 'text/markdown'),
        isOffline: false,
        sharingEnabled: false,
        callbacks: _noopCallbacks(),
      );
      expect(actions.map((a) => a.label), contains('Convert to note'));
    });

    testWidgets('editable markdown file does not show "Convert to note"', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      final actions = buildFileMenuActions(
        context: ctx,
        file: _file(mime: 'text/markdown', editable: true),
        isOffline: false,
        sharingEnabled: false,
        callbacks: _noopCallbacks(),
      );
      expect(actions.map((a) => a.label), isNot(contains('Convert to note')));
    });

    testWidgets(
      'tapping an action invokes the matching callback with the file',
      (tester) async {
        final ctx = await _ctx(tester);
        FileItem? selected;
        final file = _file(mime: 'image/png');
        final actions = buildFileMenuActions(
          context: ctx,
          file: file,
          isOffline: false,
          sharingEnabled: false,
          callbacks: _noopCallbacks(onSelect: (f) => selected = f),
        );
        actions.firstWhere((a) => a.label == 'Select').onTap();
        expect(selected, same(file));
      },
    );
  });

  group('Share action visibility', () {
    List<String> labelsFor(
      BuildContext ctx,
      FileItem file, {
      required bool sharingEnabled,
      bool wired = true,
    }) {
      return buildFileMenuActions(
        context: ctx,
        file: file,
        isOffline: false,
        sharingEnabled: sharingEnabled,
        callbacks: _noopCallbacks(onShare: wired ? (_) {} : null),
      ).map((a) => a.label).toList();
    }

    testWidgets('owned non-dir file shows Share when sharing is enabled', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, _file(mime: 'image/png'), sharingEnabled: true),
        contains('Share'),
      );
    });

    testWidgets('hidden when sharing is disabled on the server', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, _file(mime: 'image/png'), sharingEnabled: false),
        isNot(contains('Share')),
      );
    });

    testWidgets('hidden when the caller did not wire an onShare handler', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(mime: 'image/png'),
          sharingEnabled: true,
          wired: false,
        ),
        isNot(contains('Share')),
      );
    });

    testWidgets('hidden for a file the caller does not own', (tester) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(mime: 'image/png', isOwner: false),
          sharingEnabled: true,
        ),
        isNot(contains('Share')),
      );
    });

    testWidgets('hidden for folders even when owned and sharing is enabled', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, _dir(), sharingEnabled: true),
        isNot(contains('Share')),
      );
    });

    testWidgets('tapping Share invokes onShare with the file', (tester) async {
      final ctx = await _ctx(tester);
      FileItem? shared;
      final file = _file(mime: 'image/png');
      final actions = buildFileMenuActions(
        context: ctx,
        file: file,
        isOffline: false,
        sharingEnabled: true,
        callbacks: _noopCallbacks(onShare: (f) => shared = f),
      );
      actions.firstWhere((a) => a.label == 'Share').onTap();
      expect(shared, same(file));
    });
  });

  group('Leave action visibility', () {
    List<String> labelsFor(
      BuildContext ctx,
      FileItem file, {
      required bool sharingEnabled,
      bool wired = true,
    }) {
      return buildFileMenuActions(
        context: ctx,
        file: file,
        isOffline: false,
        sharingEnabled: sharingEnabled,
        callbacks: _noopCallbacks(onLeave: wired ? (_) {} : null),
      ).map((a) => a.label).toList();
    }

    testWidgets('shown for a non-owned file when sharing is enabled', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(mime: 'image/png', isOwner: false),
          sharingEnabled: true,
        ),
        contains('Leave'),
      );
    });

    testWidgets('shown for a non-owned folder (recipients can leave folders)', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, _dir(isOwner: false), sharingEnabled: true),
        contains('Leave'),
      );
    });

    testWidgets('hidden for an owned file (nothing to leave)', (tester) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, _file(mime: 'image/png'), sharingEnabled: true),
        isNot(contains('Leave')),
      );
    });

    testWidgets('hidden when sharing is disabled on the server', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(mime: 'image/png', isOwner: false),
          sharingEnabled: false,
        ),
        isNot(contains('Leave')),
      );
    });

    testWidgets('hidden when the caller did not wire an onLeave handler', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(mime: 'image/png', isOwner: false),
          sharingEnabled: true,
          wired: false,
        ),
        isNot(contains('Leave')),
      );
    });

    testWidgets('hidden for the synthetic "Shared with me" root row', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, sharedWithMeFolder(), sharingEnabled: true),
        isNot(contains('Leave')),
      );
    });

    testWidgets('tapping Leave invokes onLeave with the file', (tester) async {
      final ctx = await _ctx(tester);
      FileItem? left;
      final file = _file(mime: 'image/png', isOwner: false);
      final actions = buildFileMenuActions(
        context: ctx,
        file: file,
        isOffline: false,
        sharingEnabled: true,
        callbacks: _noopCallbacks(onLeave: (f) => left = f),
      );
      actions.firstWhere((a) => a.label == 'Leave').onTap();
      expect(left, same(file));
    });
  });

  group('Save to my drive (Fork) action visibility', () {
    List<String> labelsFor(
      BuildContext ctx,
      FileItem file, {
      required bool sharingEnabled,
      bool wired = true,
    }) {
      return buildFileMenuActions(
        context: ctx,
        file: file,
        isOffline: false,
        sharingEnabled: sharingEnabled,
        callbacks: _noopCallbacks(onFork: wired ? (_) {} : null),
      ).map((a) => a.label).toList();
    }

    testWidgets('shown for a co-owned non-dir share when sharing is enabled', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(
            mime: 'image/png',
            isOwner: false,
            shareRole: ShareRole.coOwner,
          ),
          sharingEnabled: true,
        ),
        contains('Save to my drive'),
      );
    });

    testWidgets('hidden for a reader or editor share', (tester) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(mime: 'image/png', isOwner: false, shareRole: ShareRole.reader),
          sharingEnabled: true,
        ),
        isNot(contains('Save to my drive')),
      );
      expect(
        labelsFor(
          ctx,
          _file(mime: 'image/png', isOwner: false, shareRole: ShareRole.editor),
          sharingEnabled: true,
        ),
        isNot(contains('Save to my drive')),
      );
    });

    testWidgets('hidden for an owned file', (tester) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, _file(mime: 'image/png'), sharingEnabled: true),
        isNot(contains('Save to my drive')),
      );
    });

    testWidgets('hidden for a co-owned folder (cannot fork a directory)', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(ctx, _dir(isOwner: false), sharingEnabled: true),
        isNot(contains('Save to my drive')),
      );
    });

    testWidgets('hidden when sharing is disabled on the server', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(
            mime: 'image/png',
            isOwner: false,
            shareRole: ShareRole.coOwner,
          ),
          sharingEnabled: false,
        ),
        isNot(contains('Save to my drive')),
      );
    });

    testWidgets('hidden when the caller did not wire an onFork handler', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      expect(
        labelsFor(
          ctx,
          _file(
            mime: 'image/png',
            isOwner: false,
            shareRole: ShareRole.coOwner,
          ),
          sharingEnabled: true,
          wired: false,
        ),
        isNot(contains('Save to my drive')),
      );
    });

    testWidgets('tapping Save to my drive invokes onFork with the file', (
      tester,
    ) async {
      final ctx = await _ctx(tester);
      FileItem? forked;
      final file = _file(
        mime: 'image/png',
        isOwner: false,
        shareRole: ShareRole.coOwner,
      );
      final actions = buildFileMenuActions(
        context: ctx,
        file: file,
        isOffline: false,
        sharingEnabled: true,
        callbacks: _noopCallbacks(onFork: (f) => forked = f),
      );
      actions.firstWhere((a) => a.label == 'Save to my drive').onTap();
      expect(forked, same(file));
    });
  });
}
