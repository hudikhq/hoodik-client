import 'dart:io';

import '../api/api_client.dart';
import 'offline_manager.dart';
import 'transfer_manager.dart';

/// Sequential per-chunk pin used when [ChunkDownloadPipeline] is unavailable.
Future<void> pinOfflineOnMainThread({
  required ApiClient client,
  required OfflineManager offlineManager,
  required String accountId,
  required TransferManager? transferManager,
  required FileItem file,
  required String chunksPath,
  required int totalChunks,
  required int totalBytes,
  bool pinned = true,
  TransferItem? transferItem,
  void Function()? onComplete,
  void Function(String error)? onError,
}) async {
  try {
    await client.ensureFreshSession();
    for (var i = 0; i < totalChunks; i++) {
      final encryptedChunk = await client.files.downloadChunk(
        fileId: file.id,
        chunk: i,
      );
      final dir = Directory(chunksPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final chunkPath = '$chunksPath/${i.toString().padLeft(6, '0')}.enc';
      await File(chunkPath).writeAsBytes(encryptedChunk);

      if (transferItem != null) {
        final transferred = (totalBytes * (i + 1) / totalChunks).round();
        transferManager?.updateProgress(
          transferItem.id,
          completedChunks: i + 1,
          transferredBytes: transferred,
        );
      }
    }

    await offlineManager.registerChunks(
      accountId: accountId,
      fileId: file.id,
      chunksDir: chunksPath,
      chunkCount: totalChunks,
      pinned: pinned,
    );

    if (transferItem != null) {
      transferManager?.completeTransfer(transferItem.id);
    }

    onComplete?.call();
  } catch (e) {
    if (transferItem != null) {
      transferManager?.failTransfer(transferItem.id, e.toString());
    }
    onError?.call(e.toString());
  }
}
