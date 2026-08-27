import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../src/rust/frb_generated.dart';
import 'file_crypto.dart';

/// Encrypted folder metadata produced off the UI isolate so MCP (and the
/// files UI) never run Rust FFI on the main isolate.
class PreparedFolderCreate {
  final Uint8List fileKey;
  final String nameHash;
  final String encryptedName;
  final String encryptedKey;
  final List<String> searchTokensRoot;
  final List<String> searchTokensFile;

  const PreparedFolderCreate({
    required this.fileKey,
    required this.nameHash,
    required this.encryptedName,
    required this.encryptedKey,
    required this.searchTokensRoot,
    required this.searchTokensFile,
  });
}

class _FolderJob {
  final String name;
  final String cipher;
  final String privateKeyPem;
  final String? wrappingPrivateKeyPem;
  final String publicKeyPem;

  const _FolderJob({
    required this.name,
    required this.cipher,
    required this.privateKeyPem,
    required this.wrappingPrivateKeyPem,
    required this.publicKeyPem,
  });
}

class _ChunkJob {
  final String cipher;
  final Uint8List fileKey;
  final Uint8List plaintext;
  final int chunkSize;

  const _ChunkJob({
    required this.cipher,
    required this.fileKey,
    required this.plaintext,
    required this.chunkSize,
  });
}

class _NameJob {
  final String privateKeyPem;
  final String? wrappingPrivateKeyPem;
  final List<_NameRow> rows;

  const _NameJob({
    required this.privateKeyPem,
    required this.wrappingPrivateKeyPem,
    required this.rows,
  });
}

class _NameRow {
  final String encryptedName;
  final String? encryptedKey;
  final String cipher;

  const _NameRow({
    required this.encryptedName,
    required this.encryptedKey,
    required this.cipher,
  });
}

/// Generate + encrypt folder metadata on a worker isolate (RustLib is
/// per-isolate). A SIGSEGV in FFI kills the worker, not the UI / MCP listener.
Future<PreparedFolderCreate> prepareFolderCreateOffUi({
  required String name,
  required String cipher,
  required String privateKeyPem,
  required String? wrappingPrivateKeyPem,
  required String publicKeyPem,
}) {
  return Isolate.run(
    () => _prepareFolderCreate(
      _FolderJob(
        name: name,
        cipher: cipher,
        privateKeyPem: privateKeyPem,
        wrappingPrivateKeyPem: wrappingPrivateKeyPem,
        publicKeyPem: publicKeyPem,
      ),
    ),
  );
}

Future<PreparedFolderCreate> _prepareFolderCreate(_FolderJob job) async {
  await RustLib.init();
  final crypto = FileCrypto(
    privateKeyPem: job.privateKeyPem,
    wrappingPrivateKeyPem: job.wrappingPrivateKeyPem,
  );
  final fileKey = crypto.generateFileKey(cipher: job.cipher);
  return PreparedFolderCreate(
    fileKey: Uint8List.fromList(fileKey),
    nameHash: crypto.hashFileName(job.name),
    encryptedName: crypto.encryptFileName(
      name: job.name,
      fileKey: fileKey,
      cipher: job.cipher,
    ),
    encryptedKey: crypto.encryptFileKey(
      fileKey: fileKey,
      publicKeyPem: job.publicKeyPem,
    ),
    searchTokensRoot: crypto.tokenizeForSearch(job.name),
    searchTokensFile: crypto.tokenizeForSearchWithFileKey(fileKey, job.name),
  );
}

/// Encrypt note/file chunks off the UI isolate. Copies every sublist so the
/// FRB CST encoder never sees a view into a larger buffer (that SIGSEGV'd
/// at 0xf on iOS/macOS AOT).
Future<Map<int, Uint8List>> encryptChunksOffUi({
  required String cipher,
  required Uint8List fileKey,
  required Uint8List plaintext,
  required int chunkSize,
}) {
  return Isolate.run(
    () => _encryptChunks(
      _ChunkJob(
        cipher: cipher,
        fileKey: Uint8List.fromList(fileKey),
        plaintext: Uint8List.fromList(plaintext),
        chunkSize: chunkSize,
      ),
    ),
  );
}

Future<Map<int, Uint8List>> _encryptChunks(_ChunkJob job) async {
  await RustLib.init();
  final crypto = FileCrypto();
  final length = job.plaintext.length;
  final totalChunks = math.max(1, (length / job.chunkSize).ceil());
  final out = <int, Uint8List>{};
  for (var i = 0; i < totalChunks; i++) {
    final start = i * job.chunkSize;
    final end = math.min(start + job.chunkSize, length);
    final slice = start >= length
        ? Uint8List(0)
        : Uint8List.fromList(job.plaintext.sublist(start, end));
    out[i] = Uint8List.fromList(
      crypto.encryptChunk(
        data: slice,
        fileKey: job.fileKey,
        cipher: job.cipher,
        chunkIndex: i,
      ),
    );
  }
  return out;
}

/// Best-effort name decrypt for a listing, one isolate hop for the batch.
Future<List<String>> decryptNamesOffUi({
  required String privateKeyPem,
  required String? wrappingPrivateKeyPem,
  required List<({String encryptedName, String? encryptedKey, String cipher})>
  files,
}) {
  return Isolate.run(
    () => _decryptNames(
      _NameJob(
        privateKeyPem: privateKeyPem,
        wrappingPrivateKeyPem: wrappingPrivateKeyPem,
        rows: [
          for (final f in files)
            _NameRow(
              encryptedName: f.encryptedName,
              encryptedKey: f.encryptedKey,
              cipher: f.cipher,
            ),
        ],
      ),
    ),
  );
}

Future<List<String>> _decryptNames(_NameJob job) async {
  await RustLib.init();
  final crypto = FileCrypto(
    privateKeyPem: job.privateKeyPem,
    wrappingPrivateKeyPem: job.wrappingPrivateKeyPem,
  );
  return [for (final row in job.rows) _decryptOne(crypto, row)];
}

String _decryptOne(FileCrypto crypto, _NameRow row) {
  try {
    final keyB64 = row.encryptedKey;
    if (keyB64 == null || keyB64.isEmpty) return '(encrypted)';
    final key = crypto.decryptFileKey(keyB64);
    return crypto.decryptFileName(
      encryptedNameHex: row.encryptedName,
      fileKey: key,
      cipher: row.cipher,
    );
  } catch (_) {
    return '(decryption failed)';
  }
}
