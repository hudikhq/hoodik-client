import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// Cross-account coverage for [ShareCrypto.wrapForRecipient]: a sender on one
/// key type wraps a file key for a recipient on either key type, and the
/// recipient opens it with its OWN independent private key through the same
/// [FileCrypto.decryptFileKey] path the real client runs.
///
/// The curve25519-sender -> RSA-recipient row is the regression. Before the
/// fix, wrapForRecipient delegated to the sender-keyed FileCrypto.encryptFileKey,
/// which dispatched on the sender's key type and hybrid-wrapped the recipient's
/// RSA key — throwing `expected HOODIK WRAPPING KEY pem, got RSA PUBLIC KEY`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  late rust.RsaKeyPair senderRsa;
  late rust.RsaKeyPair recipientRsa;
  late rust.Ed25519KeyPair senderEd;
  late rust.WrappingKeyPair senderWrap;
  late rust.Ed25519KeyPair recipientEd;
  late rust.WrappingKeyPair recipientWrap;

  setUpAll(() {
    // 2048-bit RSA keygen is slow; generate the two legacy identities once.
    senderRsa = rust.generateRsaKeypair();
    recipientRsa = rust.generateRsaKeypair();
    senderEd = crypto.generateEd25519KeyPair();
    senderWrap = crypto.generateWrappingKeyPair();
    recipientEd = crypto.generateEd25519KeyPair();
    recipientWrap = crypto.generateWrappingKeyPair();
  });

  ShareCrypto curveSender() => ShareCrypto(
    privateKeyPem: senderEd.privatePem,
    wrappingPrivateKeyPem: senderWrap.privatePem,
  );
  ShareCrypto rsaSender() =>
      ShareCrypto(privateKeyPem: senderRsa.privateKeyPem);

  Uint8List rsaRecipientOpen(String wrapped) => FileCrypto(
    privateKeyPem: recipientRsa.privateKeyPem,
  ).decryptFileKey(wrapped);
  Uint8List curveRecipientOpen(String wrapped) => FileCrypto(
    privateKeyPem: recipientEd.privatePem,
    wrappingPrivateKeyPem: recipientWrap.privatePem,
  ).decryptFileKey(wrapped);

  String wrapForRsaRecipient(ShareCrypto sender, Uint8List fileKey) =>
      sender.wrapForRecipient(
        fileKey: fileKey,
        recipientPubkey: recipientRsa.publicKeyPem,
      );
  String wrapForCurveRecipient(ShareCrypto sender, Uint8List fileKey) =>
      sender.wrapForRecipient(
        fileKey: fileKey,
        recipientPubkey: recipientEd.publicPem,
        recipientKeyType: 'curve25519',
        recipientWrappingPubkey: recipientWrap.publicPem,
      );

  group('wrapForRecipient cross-account matrix', () {
    test('curve25519 sender -> RSA recipient roundtrips (regression)', () {
      final fileKey = crypto.generateSymmetricKey();
      final wrapped = wrapForRsaRecipient(curveSender(), fileKey);
      expect(rsaRecipientOpen(wrapped), equals(fileKey));
    });

    test('curve25519 sender -> curve25519 recipient roundtrips', () {
      final fileKey = crypto.generateSymmetricKey();
      final wrapped = wrapForCurveRecipient(curveSender(), fileKey);
      expect(curveRecipientOpen(wrapped), equals(fileKey));
    });

    test('RSA sender -> RSA recipient roundtrips', () {
      final fileKey = crypto.generateSymmetricKey();
      final wrapped = wrapForRsaRecipient(rsaSender(), fileKey);
      expect(rsaRecipientOpen(wrapped), equals(fileKey));
    });

    test('RSA sender -> curve25519 recipient roundtrips', () {
      final fileKey = crypto.generateSymmetricKey();
      final wrapped = wrapForCurveRecipient(rsaSender(), fileKey);
      expect(curveRecipientOpen(wrapped), equals(fileKey));
    });
  });
}
