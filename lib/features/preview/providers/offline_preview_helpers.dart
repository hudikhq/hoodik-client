import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

Future<Uint8List?> loadBytesFromCache(
  WidgetRef ref,
  FileItem file,
  Uint8List? fileKey,
) async {
  if (fileKey == null) return null;

  final offlineManager = ref.read(offlineManagerProvider);
  final account = ref.read(activeAccountProvider);
  if (account == null) return null;

  final crypto = ref.read(fileCryptoProvider);
  if (crypto == null) return null;

  // Check if the cached version is stale. When a file is re-uploaded (edited
  // on another device or via the web), its finishedUploadAt changes. If the
  // file was re-uploaded after the cache entry was created, evict it so we
  // re-download the fresh version.
  if (file.finishedUploadAt != null) {
    final entry = await ref
        .read(databaseProvider)
        .getOfflineFile(account.id, file.id);
    if (entry != null) {
      final uploadedAt = DateTime.fromMillisecondsSinceEpoch(
        file.finishedUploadAt! * 1000,
      );
      if (uploadedAt.isAfter(entry.downloadedAt)) {
        await offlineManager.removeCachedFile(account.id, file.id);
        return null;
      }
    }
  }

  return offlineManager.decryptToMemory(
    accountId: account.id,
    fileId: file.id,
    chunkCount: file.chunks ?? 1,
    decryptChunk: (encrypted, index) => crypto.decryptChunk(
      data: encrypted,
      fileKey: fileKey,
      cipher: file.cipher,
      chunkIndex: index,
    ),
  );
}
