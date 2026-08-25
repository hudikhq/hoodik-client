import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../src/rust/api.dart' as rust;
import '../api/api_client.dart';
import 'plaintext_temp.dart';

/// Decrypt cached `.enc` chunks into memory via a scratch file under
/// [plaintextTempDirectory], then delete the scratch.
///
/// The Rust FFI streams chunk by chunk into a file, so this holds one
/// plaintext copy instead of one per chunk plus the joined result.
Future<Uint8List> decryptChunksToMemory({
  required String chunksPath,
  required FileItem file,
  required Uint8List fileKey,
  required int totalChunks,
}) async {
  final dir = await plaintextTempDirectory();
  final scratch = File(p.join(dir.path, 'hoodik-decrypt-${file.id}'));
  try {
    await rust.decryptChunksToFile(
      chunksDir: chunksPath,
      chunkCount: BigInt.from(totalChunks),
      decryptionKey: fileKey,
      cipher: file.cipher,
      outputPath: scratch.path,
      fileId: file.id,
    );
    return await scratch.readAsBytes();
  } finally {
    if (await scratch.exists()) {
      try {
        await scratch.delete();
      } catch (_) {
        // A leftover in the plaintext temp dir is swept on the next launch.
      }
    }
  }
}
