import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/theme/hoodik_colors.dart';
import 'package:hoodik_app/features/files/widgets/file_list_item.dart';

import 'golden_harness.dart';

/// Files-list golden — renders the five canonical fixtures (folder,
/// PDF, image-with-thumbnail, text, markdown-note) via [FileListItem]
/// inside a faithful-chrome Scaffold. Avoids mounting the full
/// `FilesScreen`, which pulls in `FilesNotifier`, `TransferManager`,
/// `WorkerManager`, `SyncService`, and several DB-backed providers
/// that the rendering layer doesn't need to produce the regression
/// surface the goldens guard.
void main() {
  late Uint8List thumbnailBytes;
  late List<FileItem> files;
  late Map<String, String> names;

  setUpAll(() async {
    await configureGoldenEnvironment();
    thumbnailBytes = await checkerboardThumbnail(side: 80);
    files = fakeFileList();
    names = fakeFileDisplayNames();
  });

  Future<List<Override>> overrides() async {
    final prefs = await fakePreferences();
    return [preferencesProvider.overrideWithValue(prefs)];
  }

  runGoldenMatrix(
    screen: 'files_list',
    body: (tester, config) async {
      await pumpGoldenHarness(
        tester,
        config: config,
        child: _FilesListGoldenScaffold(
          files: files,
          names: names,
          thumbnailBytes: thumbnailBytes,
        ),
        overrides: await overrides(),
      );
    },
  );
}

/// Standalone scaffold that composes the same chrome + list tiles as
/// the real files screen, without dragging in the notifier/worker/db
/// providers the goldens don't exercise.
class _FilesListGoldenScaffold extends StatelessWidget {
  const _FilesListGoldenScaffold({
    required this.files,
    required this.names,
    required this.thumbnailBytes,
  });

  final List<FileItem> files;
  final Map<String, String> names;
  final Uint8List thumbnailBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Files'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.search),
          ),
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.view_list),
          ),
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.checklist),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: HoodikColors.redish700,
              child: Text(
                'A',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: files.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final file = files[index];
          final isImage = file.mime.startsWith('image/');
          return FileListItem(
            file: file,
            displayName: names[file.id] ?? file.id,
            thumbnailBytes: isImage ? thumbnailBytes : null,
            isSelected: false,
            isOffline: file.id == 'f_readme_txt',
            selectionMode: false,
            onTap: () {},
            onContextMenu: (_) {},
            onToggleSelection: () {},
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
