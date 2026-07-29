import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/helpers/share_surface.dart';

/// Decrypts to a fixed name without real RSA/cipher work. The fixed name
/// stands in for the plaintext folder name the members header must show.
class _FakeFileCrypto extends Fake implements FileCrypto {
  @override
  Uint8List decryptFileKey(String encryptedKeyBase64) => Uint8List(16);

  @override
  String decryptFileName({
    required String encryptedNameHex,
    required Uint8List fileKey,
    required String cipher,
  }) => 'Tax Returns';
}

void main() {
  testWidgets('openShareSurface routes a folder with its decrypted name, '
      'not the encrypted placeholder', (tester) async {
    final folder = FileItem(
      id: 'dir-1',
      encryptedName: 'deadbeef',
      encryptedKey: 'enc-key',
      mime: 'dir',
    );

    final container = ProviderContainer(
      overrides: [fileCryptoProvider.overrideWithValue(_FakeFileCrypto())],
    );
    addTearDown(container.dispose);

    String? routedName;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () =>
                    openShareSurface(context, ref, dirId: null, file: folder),
                child: const Text('share'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/shares/folder/:id/members',
          builder: (_, state) {
            routedName = state.uri.queryParameters['name'];
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();

    expect(routedName, 'Tax Returns');
  });
}
