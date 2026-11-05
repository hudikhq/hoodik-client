import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_client.dart';
import '../../../core/crypto/file_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/utils/logger.dart';
import '../providers/preview_providers.dart';
import 'chunked_preview_source.dart';
import 'preview_stream_server.dart';

const _log = Logger('PreviewStreamResolver');

class PreviewStreamHandle {
  PreviewStreamHandle({required this.uri, required this.server});

  final Uri uri;
  final PreviewStreamServer server;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await server.unregister(uri);
  }
}

Future<PreviewStreamHandle?> openPreviewStream(
  WidgetRef ref, {
  required FileItem file,
  required Uint8List? fileKey,
  String? fileName,
}) async {
  final client = ref.read(apiClientProvider);
  final crypto = ref.read(fileCryptoProvider);
  final size = file.size;
  final chunks = file.chunks;

  if (fileKey == null ||
      client == null ||
      crypto == null ||
      size == null ||
      size <= 0 ||
      chunks == null ||
      chunks <= 0 ||
      file.cipher.isEmpty) {
    return null;
  }

  if ((chunks - 1) * kPreviewChunkSize >= size) return null;

  final account = ref.read(activeAccountProvider);
  final chunksDir = account == null
      ? null
      : await ref.read(offlineManagerProvider).chunksDir(account.id, file.id);

  final source = ChunkedPreviewSource(
    length: size,
    chunkSize: kPreviewChunkSize,
    fetchChunk: (index) => _fetchChunk(
      client: client,
      crypto: crypto,
      file: file,
      fileKey: fileKey,
      chunksDir: chunksDir,
      index: index,
    ),
  );

  try {
    final server = ref.read(previewStreamServerProvider);
    final uri = await server.register(
      source: source,
      contentType: file.mime,
      fileName: fileName,
    );
    return PreviewStreamHandle(uri: uri, server: server);
  } catch (e) {
    await source.close();
    _log.warn(
      'could not start preview stream',
      fields: {'file_id': file.id, 'error': e.toString()},
    );
    return null;
  }
}

Future<Uint8List> _fetchChunk({
  required ApiClient client,
  required FileCrypto crypto,
  required FileItem file,
  required Uint8List fileKey,
  required String? chunksDir,
  required int index,
}) async {
  final cached = await _readCachedChunk(chunksDir, index);
  if (cached != null) {
    try {
      return crypto.decryptChunk(
        data: cached,
        fileKey: fileKey,
        cipher: file.cipher,
        chunkIndex: index,
      );
    } catch (_) {}
  }

  final encrypted = await _downloadChunkWithRetry(client, file.id, index);
  return crypto.decryptChunk(
    data: encrypted,
    fileKey: fileKey,
    cipher: file.cipher,
    chunkIndex: index,
  );
}

Future<Uint8List?> _readCachedChunk(String? chunksDir, int index) async {
  if (chunksDir == null) return null;
  final cached = File(
    p.join(chunksDir, '${index.toString().padLeft(6, '0')}.enc'),
  );
  try {
    if (await cached.exists()) return await cached.readAsBytes();
  } catch (_) {}
  return null;
}

Future<Uint8List> _downloadChunkWithRetry(
  ApiClient client,
  String fileId,
  int index,
) async {
  Object? lastError;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await client.files.downloadChunk(fileId: fileId, chunk: index);
    } catch (e) {
      lastError = e;
      await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
    }
  }
  throw lastError ?? Exception('chunk download failed');
}
