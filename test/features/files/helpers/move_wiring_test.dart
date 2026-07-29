import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/controllers/files_mutation_controller.dart';
import 'package:hoodik_app/features/files/helpers/move_wiring.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets(
    'a destination missing from the listing cache but carrying its own wrapped '
    'key and encrypted name shows the decrypted name in the confirm, not the '
    'placeholder',
    (tester) async {
      const cipher = 'aegis128l';
      final keyPair = rust.generateRsaKeypair();
      final fileCrypto = FileCrypto(privateKeyPem: keyPair.privateKeyPem);
      final fileKey = const CryptoService().generateSymmetricKey();

      const plaintextName = 'Quarterly Reports';
      final destination = FileItem(
        id: '00000000-0000-0000-0000-0000000000d1',
        mime: 'dir',
        cipher: cipher,
        encryptedName: fileCrypto.encryptFileName(
          name: plaintextName,
          fileKey: fileKey,
          cipher: cipher,
        ),
        encryptedKey: fileCrypto.encryptFileKey(
          fileKey: fileKey,
          publicKeyPem: keyPair.publicKeyPem,
        ),
      );

      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            decryptedPrivateKeyProvider.overrideWith(
              (ref) => keyPair.privateKeyPem,
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final coordinator = FileMoveCoordinator(
        ref: widgetRef,
        dirId: null,
        mutations: widgetRef.read(filesMutationControllerProvider(null)),
      );

      // The cache misses (decryptedNames is empty), so without on-device
      // decryption the confirm would read "[Encrypted] ...".
      const emptyListing = FilesState(loading: false);
      expect(emptyListing.displayName(destination), startsWith('[Encrypted]'));

      expect(
        coordinator.destinationNameForConfirm(emptyListing, destination),
        plaintextName,
      );
    },
  );
}
