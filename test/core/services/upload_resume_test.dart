import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/file_item.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/upload_resume.dart';

class _FakeFileCrypto extends Fake implements FileCrypto {
  String? decryptedKeyInput;

  @override
  Uint8List decryptFileKey(String encryptedKeyBase64) {
    decryptedKeyInput = encryptedKeyBase64;
    return Uint8List.fromList(List.filled(32, 7));
  }

  @override
  String searchFileKeyHex(Uint8List fileKey) => 'file-search-key';

  @override
  String exactTag(String key, String value) => 'keyed($key|$value)';
}

FileItem _partialRow({
  String? encryptedKey = 'wrapped-key',
  int chunks = 169,
  int chunksStored = 0,
  List<int>? uploadedChunks,
  String? sha256 = 'keyed(file-search-key|abc123)',
  int? finishedUploadAt,
  String mime = 'video/mp4',
}) {
  return FileItem(
    id: 'file-1',
    encryptedName: 'enc-name',
    encryptedKey: encryptedKey,
    mime: mime,
    chunks: chunks,
    chunksStored: chunksStored,
    uploadedChunks: uploadedChunks,
    sha256: sha256,
    cipher: 'aegis128l',
    finishedUploadAt: finishedUploadAt,
  );
}

void main() {
  final crypto = _FakeFileCrypto();

  group('UploadResume.of', () {
    test('no existing row means a fresh upload', () {
      expect(
        UploadResume.of(null, totalChunks: 169, fileCrypto: crypto),
        isNull,
      );
    });

    // The kill-and-relaunch case this exists for: the server holds the row
    // and some chunks, the create route refuses duplicates, so the only way
    // this file ever completes is adopting what the first attempt made.
    test('a partial row is adopted with its id, key and stored chunks', () {
      final resume = UploadResume.of(
        _partialRow(uploadedChunks: [0, 1, 5]),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      expect(resume, isNotNull);
      expect(resume!.fileId, 'file-1');
      expect(resume.cipher, 'aegis128l');
      expect(resume.uploadedChunks, {0, 1, 5});
      expect(crypto.decryptedKeyInput, 'wrapped-key');
    });

    test('a row with no stored-chunk listing resumes from zero', () {
      final resume = UploadResume.of(
        _partialRow(uploadedChunks: null),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      expect(resume!.uploadedChunks, isEmpty);
    });

    test('a complete row still refuses the upload', () {
      expect(
        () => UploadResume.of(
          _partialRow(chunksStored: 169, uploadedChunks: null),
          totalChunks: 169,
          fileCrypto: crypto,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a finished row refuses even when chunk counts disagree', () {
      expect(
        () => UploadResume.of(
          _partialRow(finishedUploadAt: 1755770000),
          totalChunks: 42,
          fileCrypto: crypto,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a directory with the same name refuses the upload', () {
      expect(
        () => UploadResume.of(
          _partialRow(mime: 'dir', chunks: 0),
          totalChunks: 169,
          fileCrypto: crypto,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // A row the caller cannot decrypt cannot be finished by them either.
    test('a partial row without a key refuses rather than adopting', () {
      expect(
        () => UploadResume.of(
          _partialRow(encryptedKey: null),
          totalChunks: 169,
          fileCrypto: crypto,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // Same name, different local file: the chunk counts no longer line up
    // and silently mixing two generations of ciphertext must be impossible.
    test('a chunk-count mismatch refuses the upload', () {
      expect(
        () => UploadResume.of(
          _partialRow(chunks: 169),
          totalChunks: 12,
          fileCrypto: crypto,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ensureSameContent', () {
    test('passes when the keyed local hash matches the row', () {
      final resume = UploadResume.of(
        _partialRow(),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      resume!.ensureSameContent('abc123');
    });

    test('throws when the local file no longer matches the row', () {
      final resume = UploadResume.of(
        _partialRow(),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      expect(
        () => resume!.ensureSameContent('other'),
        throwsA(isA<Exception>()),
      );
    });

    test('a bare pre-keying digest proves equality bare-to-bare', () {
      // A row from before the app keyed its digests stores the plaintext
      // digest — recognisable by its length, twice a tag's. The local bare
      // digest proves equality for it just as well, and refusing would
      // strand every upload interrupted before the update in a conflict no
      // retry ever clears.
      final bare = 'a' * 64;
      final resume = UploadResume.of(
        _partialRow(sha256: bare, uploadedChunks: [0]),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      resume!.ensureSameContent(bare);
    });

    test('a bare pre-keying digest that differs still refuses the row', () {
      final resume = UploadResume.of(
        _partialRow(sha256: 'a' * 64, uploadedChunks: [0]),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      expect(
        () => resume!.ensureSameContent('b' * 64),
        throwsA(isA<Exception>()),
      );
    });

    test('passes when a hashless row stores no chunks yet', () {
      final resume = UploadResume.of(
        _partialRow(sha256: null),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      resume!.ensureSameContent('abc123');
    });

    test('throws when a hashless row already stores chunks', () {
      final resume = UploadResume.of(
        _partialRow(sha256: null, uploadedChunks: [0, 1]),
        totalChunks: 169,
        fileCrypto: crypto,
      );

      expect(
        () => resume!.ensureSameContent('abc123'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
