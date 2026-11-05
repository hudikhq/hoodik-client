import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/helpers/files_preview_navigation.dart';
import 'package:hoodik_app/features/files/helpers/files_screen_row_actions.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/features/files/widgets/file_sort_controls.dart';

class _StubFilesNotifier extends FilesNotifier {
  _StubFilesNotifier(this._initial);
  final FilesState _initial;

  @override
  FilesState build(String? arg) => _initial;
}

void main() {
  testWidgets('openEditor seeds the tapped note even when siblings omit it', (
    tester,
  ) async {
    final target = FileItem(
      id: 'note-1',
      encryptedName: 'enc',
      mime: 'text/markdown',
    );
    // A note shared directly resolves its parent to the account root, whose
    // listing holds other markdown notes but not the target itself.
    final siblings = [
      FileItem(id: 'other-note', encryptedName: 'enc', mime: 'text/markdown'),
      FileItem(id: 'image-1', encryptedName: 'enc', mime: 'image/png'),
    ];

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => openEditor(
                  context: context,
                  ref: ref,
                  file: target,
                  siblings: siblings,
                  names: {'note-1': 'shared-note.md'},
                  keys: {'note-1': Uint8List(0)},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/editor/:fileId',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final seeded = container.read(previewContextProvider);
    expect(seeded, isNotNull);
    expect(seeded!.files.map((f) => f.id), contains('note-1'));
  });

  testWidgets('openPreview seeds the tapped file even when siblings omit it', (
    tester,
  ) async {
    final target = FileItem(
      id: 'image-1',
      encryptedName: 'enc',
      mime: 'image/png',
      finishedUploadAt: 1,
    );
    // Same direct-share case as openEditor: the resolved siblings carry other
    // previewable rows but not the file the recipient actually opened.
    final siblings = [
      FileItem(
        id: 'image-2',
        encryptedName: 'enc',
        mime: 'image/jpeg',
        finishedUploadAt: 1,
      ),
      FileItem(
        id: 'doc-1',
        encryptedName: 'enc',
        mime: 'application/pdf',
        finishedUploadAt: 1,
      ),
    ];

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => openPreview(
                  context: context,
                  ref: ref,
                  file: target,
                  siblings: siblings,
                  names: {'image-1': 'shared.png'},
                  keys: {'image-1': Uint8List(0)},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/preview/:fileId',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final seeded = container.read(previewContextProvider);
    expect(seeded, isNotNull);
    expect(seeded!.files.map((f) => f.id), contains('image-1'));
  });

  testWidgets('openFilesPreview seeds siblings in the displayed sort order', (
    tester,
  ) async {
    final target = FileItem(
      id: 'img-b',
      encryptedName: 'enc-b',
      mime: 'image/png',
      finishedUploadAt: 1,
    );
    final files = [
      FileItem(
        id: 'img-c',
        encryptedName: 'enc-c',
        mime: 'image/png',
        finishedUploadAt: 1,
      ),
      FileItem(
        id: 'img-a',
        encryptedName: 'enc-a',
        mime: 'image/png',
        finishedUploadAt: 1,
      ),
      target,
    ];

    final container = ProviderContainer(
      overrides: [
        filesNotifierProvider.overrideWith(
          () => _StubFilesNotifier(
            FilesState(
              loading: false,
              files: files,
              decryptedNames: {
                'img-a': 'alpha.png',
                'img-b': 'bravo.png',
                'img-c': 'charlie.png',
              },
              sortField: SortField.name,
              sortOrder: SortOrder.asc,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => openFilesPreview(
                  context: context,
                  ref: ref,
                  dirId: null,
                  file: target,
                  onSnack: (_, _) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/preview/:fileId',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final seeded = container.read(previewContextProvider);
    expect(seeded, isNotNull);
    expect(seeded!.files.map((f) => f.id).toList(), [
      'img-a',
      'img-b',
      'img-c',
    ]);
  });
}
