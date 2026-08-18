import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

/// The search index stores HMAC tags rather than digests of BERT tokens.
///
/// The old scheme hashed each token with unsalted SHA-256. That vocabulary is
/// public, pre-trained and roughly thirty thousand entries, so a table over it
/// reverses the whole index in seconds — recovering file names and, because
/// note bodies are indexed word for word, note contents. These tests assert
/// the properties that stop being true if the tagging regresses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  late String privateKeyPem;
  late FileCrypto fileCrypto;

  setUp(() {
    privateKeyPem = crypto.generateWrappingKeyPair().privatePem;
    fileCrypto = FileCrypto(
      privateKeyPem: privateKeyPem,
      wrappingPrivateKeyPem: privateKeyPem,
    );
  });

  group('search tagging', () {
    test('a tag is never the token\'s bare digest', () {
      final tags = fileCrypto.tokenizeForSearch('invoice');

      expect(tags, isNotEmpty);
      for (final entry in tags) {
        final tag = entry.split(':').first;
        expect(tag, isNot(crypto.sha256(data: utf8.encode('invoice'))));
      }
    });

    test('tags are the expected width and carry weights', () {
      final tags = fileCrypto.tokenizeForSearch('invoice invoice draft');

      expect(tags, isNotEmpty);
      for (final entry in tags) {
        expect(entry, matches(RegExp(r'^[0-9a-f]{32}:\d+$')));
      }

      // A repeated term has to show up as a weight somewhere, however the
      // wordpiece tokenizer chose to split it.
      final weights = tags.map((e) => int.parse(e.split(':').last));
      expect(weights.any((w) => w >= 2), isTrue);
    });

    test('the same word tags differently under a different account key', () {
      final otherPem = crypto.generateWrappingKeyPair().privatePem;
      final other = FileCrypto(
        privateKeyPem: otherPem,
        wrappingPrivateKeyPem: otherPem,
      );

      expect(
        fileCrypto.tokenizeForSearch('invoice'),
        isNot(other.tokenizeForSearch('invoice')),
      );
    });

    test('the account key is stable across calls', () {
      expect(
        fileCrypto.tokenizeForSearch('invoice'),
        fileCrypto.tokenizeForSearch('invoice'),
      );
    });

    test('the file scope differs from the account scope', () {
      final fileKey = Uint8List.fromList(List.filled(32, 7));

      expect(
        fileCrypto.tokenizeForSearchWithFileKey(fileKey, 'invoice'),
        isNot(fileCrypto.tokenizeForSearch('invoice')),
      );
    });

    test('two files tag the same word differently', () {
      final a = Uint8List.fromList(List.filled(32, 7));
      final b = Uint8List.fromList(List.filled(32, 9));

      expect(
        fileCrypto.tokenizeForSearchWithFileKey(a, 'invoice'),
        isNot(fileCrypto.tokenizeForSearchWithFileKey(b, 'invoice')),
      );
    });

    test('a recipient reproduces the owner\'s file tags from the file key', () {
      final fileKey = Uint8List.fromList(List.filled(32, 3));
      final recipientPem = crypto.generateWrappingKeyPair().privatePem;
      final recipient = FileCrypto(
        privateKeyPem: recipientPem,
        wrappingPrivateKeyPem: recipientPem,
      );

      // Different accounts entirely, but the file key is what the share hands
      // over — which is exactly why a grant needs no re-index.
      expect(
        recipient.tokenizeForSearchWithFileKey(fileKey, 'quarterly'),
        fileCrypto.tokenizeForSearchWithFileKey(fileKey, 'quarterly'),
      );
    });

    test('query tags are bare, with no weight suffix', () {
      final tags = fileCrypto.queryTags(fileCrypto.searchRootKey, 'invoice');

      expect(tags, isNotEmpty);
      for (final tag in tags) {
        expect(tag, matches(RegExp(r'^[0-9a-f]{32}$')));
      }
    });

    test('query tags match what indexing wrote for the same word', () {
      final indexed = fileCrypto
          .tokenizeForSearch('invoice')
          .map((e) => e.split(':').first)
          .toList();

      expect(fileCrypto.queryTags(fileCrypto.searchRootKey, 'invoice'), indexed);
    });
  });

  group('name_hash', () {
    test('is keyed, not a bare digest of the name', () {
      // A plain SHA-256 of a file name is reversible with a dictionary of
      // common names, without needing a rainbow table at all.
      expect(
        fileCrypto.hashFileName('Passwords.md'),
        isNot(crypto.sha256(data: utf8.encode('Passwords.md'))),
      );
    });

    test('differs per account for the same name', () {
      final otherPem = crypto.generateWrappingKeyPair().privatePem;
      final other = FileCrypto(
        privateKeyPem: otherPem,
        wrappingPrivateKeyPem: otherPem,
      );

      expect(
        fileCrypto.hashFileName('Passwords.md'),
        isNot(other.hashFileName('Passwords.md')),
      );
    });

    test('is stable for the same account and name', () {
      expect(
        fileCrypto.hashFileName('Passwords.md'),
        fileCrypto.hashFileName('Passwords.md'),
      );
    });
  });
}
