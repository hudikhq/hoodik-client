import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/files/helpers/files_preview_navigation.dart';
import 'package:hoodik_app/features/notes/providers/open_note_request.dart';

void main() {
  test('OpenNoteRequest carries highlightQuery', () {
    const req = OpenNoteRequest(
      fileId: 'note-1',
      epoch: 3,
      highlightQuery: 'invoice',
    );
    expect(req.highlightQuery, 'invoice');
    expect(req.fileId, 'note-1');
  });

  testWidgets('requestOpenNoteFromWidget and openEditor pass highlightQuery', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final target = FileItem(
      id: 'note-1',
      encryptedName: 'enc',
      mime: 'text/markdown',
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => requestOpenNoteFromWidget(
                      ref,
                      'note-1',
                      highlightQuery: 'from-widget',
                    ),
                    child: const Text('request'),
                  ),
                  ElevatedButton(
                    onPressed: () => openEditor(
                      context: context,
                      ref: ref,
                      file: target,
                      siblings: const [],
                      names: {'note-1': 'note.md'},
                      keys: {'note-1': Uint8List(0)},
                      highlightQuery: 'from-search',
                    ),
                    child: const Text('open'),
                  ),
                ],
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

    await tester.tap(find.text('request'));
    await tester.pump();
    expect(
      container.read(openNoteRequestProvider)?.highlightQuery,
      'from-widget',
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      container.read(openNoteRequestProvider)?.highlightQuery,
      'from-search',
    );
    expect(container.read(openNoteRequestProvider)?.fileId, 'note-1');
  });
}
