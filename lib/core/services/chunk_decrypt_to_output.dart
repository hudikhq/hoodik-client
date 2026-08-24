import 'dart:typed_data';

import '../../src/rust/api.dart' as rust;
import '../api/api_client.dart';
import '../utils/logger.dart';
import 'transfer_manager.dart';

const _log = Logger('ChunkDecryptToOutput');

/// Decrypt cached chunks to [outputPath] and drive a decrypt overlay entry.
Future<void> decryptChunksToOutput({
  required FileItem file,
  required Uint8List fileKey,
  required String outputPath,
  required String chunksPath,
  required String displayName,
  required int totalChunks,
  required int totalBytes,
  TransferManager? transferManager,
  Future<void> Function()? onComplete,
}) async {
  final decryptItem = transferManager?.startTransfer(
    fileName: displayName,
    type: TransferType.downloadDecrypt,
    totalBytes: totalBytes,
    totalChunks: totalChunks,
    fileId: file.id,
  );

  try {
    final decryptStart = DateTime.now();
    await rust.decryptChunksToFile(
      chunksDir: chunksPath,
      chunkCount: BigInt.from(totalChunks),
      decryptionKey: fileKey,
      cipher: file.cipher,
      outputPath: outputPath,
      fileId: file.id,
    );
    _log.debug(
      'chunk decrypt done',
      fields: {
        'file_id': file.id,
        'duration_ms': DateTime.now().difference(decryptStart).inMilliseconds,
      },
    );

    if (decryptItem != null) {
      transferManager?.completeTransfer(decryptItem.id);
    }
  } catch (e) {
    if (decryptItem != null) {
      transferManager?.failTransfer(
        decryptItem.id,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
    rethrow;
  }

  await onComplete?.call();
}
