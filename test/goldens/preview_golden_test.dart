import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/preview/providers/preview_cache.dart';
import 'package:hoodik_app/features/preview/providers/preview_providers.dart';
import 'package:hoodik_app/features/preview/screens/preview_screen.dart';

import 'golden_harness.dart';

/// Preview golden — renders the loaded-image variant (checkerboard
/// PNG) across the 8-viewport matrix. The loading-skeleton variant is
/// intentionally omitted so the whole suite stays at 40 PNGs total.
void main() {
  late Uint8List imageBytes;
  late FileItem file;

  setUpAll(() async {
    await configureGoldenEnvironment();
    imageBytes = await checkerboardThumbnail(side: 256);
    file = FileItem(
      id: 'preview_image',
      encryptedName: 'enc_preview',
      mime: 'image/jpeg',
      size: imageBytes.lengthInBytes,
      createdAt: timestampForDaysAgo(0),
      finishedUploadAt: timestampForDaysAgo(0),
      chunks: 1,
      chunksStored: 1,
    );
  });

  runGoldenMatrix(
    screen: 'preview',
    body: (tester, config) async {
      // A fresh PreviewCache preloaded with the checkerboard PNG makes
      // the PreviewImage widget hit the in-memory short-circuit so no
      // download/decrypt pipeline is invoked inside the test.
      final cache = PreviewCache()..put(file, imageBytes);
      addTearDown(cache.dispose);

      await pumpGoldenHarness(
        tester,
        config: config,
        child: PreviewScreen(fileId: file.id),
        overrides: [
          previewCacheProvider.overrideWithValue(cache),
          previewContextProvider.overrideWith(
            (ref) => PreviewContext(
              files: [file],
              names: const {'preview_image': 'sunset.jpg'},
              keys: {file.id: Uint8List(32)},
            ),
          ),
        ],
      );
    },
  );
}
