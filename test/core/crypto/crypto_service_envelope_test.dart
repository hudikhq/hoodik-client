import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/crypto_service_migration.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  group('envelope', () {
    test('deriveKek is deterministic 32 bytes', () {
      final a = crypto.envelopeDeriveKek(exportKey: bytes('export-key'));
      final b = crypto.envelopeDeriveKek(exportKey: bytes('export-key'));
      expect(a.length, 32);
      expect(a, equals(b));
    });

    test('seal/open roundtrips a key bundle', () {
      final kek = crypto.envelopeDeriveKek(exportKey: bytes('export-key'));
      final bundle = bytes('identity+wrapping key bundle');

      final sealed = crypto.envelopeSeal(kek: kek, bundle: bundle);
      final opened = crypto.envelopeOpen(kek: kek, envelope: sealed);
      expect(opened, equals(bundle));
    });

    test('open with the wrong kek throws', () {
      final kek = crypto.envelopeDeriveKek(exportKey: bytes('export-key'));
      final wrong = crypto.envelopeDeriveKek(exportKey: bytes('other-key'));
      final sealed = crypto.envelopeSeal(kek: kek, bundle: bytes('secret'));
      expect(
        () => crypto.envelopeOpen(kek: wrong, envelope: sealed),
        throwsA(anything),
      );
    });

    test('rewrap re-seals under a new kek', () {
      final oldKek = crypto.envelopeDeriveKek(exportKey: bytes('old'));
      final newKek = crypto.envelopeDeriveKek(exportKey: bytes('new'));
      final bundle = bytes('secret bundle');

      final sealed = crypto.envelopeSeal(kek: oldKek, bundle: bundle);
      final rewrapped = crypto.envelopeRewrap(
        oldKek: oldKek,
        newKek: newKek,
        envelope: sealed,
      );
      expect(
        crypto.envelopeOpen(kek: newKek, envelope: rewrapped),
        equals(bundle),
      );
    });
  });
}
