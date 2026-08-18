import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../src/rust/api.dart' as rust;
import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../storage/database.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';
import 'chunk_download_runner.dart';
import 'chunk_download_transport.dart';
import 'direct_chunk_download.dart';
import 'offline_manager.dart';
import 'tar_fallback.dart';
import 'transfer_manager.dart';

const _log = Logger('ChunkDownloadPipeline');

/// Encrypted-chunk download + decrypt pipeline used by
/// [FileDownloader.downloadFileToDisk].
///
/// Phase 1 pulls the whole archive in a single round-trip: `background_downloader`
/// runs the HTTP leg so the transfer survives app suspension on iOS/Android,
/// and the Rust FFI unpacks the landed tar into individual `.enc` chunks.
/// Servers that don't recognise `?format=tar` surface that through
/// [shouldFallbackToPerChunk]; the capability cache remembers the answer
/// for the rest of the session so the next file skips the probe. Phase 2
/// decrypts the cached `.enc` chunks via [rust.decryptChunksToFile]. Each
/// phase owns its own transfer-overlay entry so the UI shows "downloading"
/// then "decrypting" instead of one opaque bar.
class ChunkDownloadPipeline {
  final ApiClient _client;
  final OfflineManager _offlineManager;
  final TransferManager? _transferManager;
  final ChunkDownloadRunner _runner;
  final AppDatabase? _database;
  final FileCrypto? _fileCrypto;
  final String _accountId;

  ChunkDownloadPipeline({
    required ApiClient client,
    required OfflineManager offlineManager,
    required TarCapabilityCache tarCapabilityCache,
    required String accountId,
    required ChunkDownloadTransport transport,
    AppDatabase? database,
    FileCrypto? fileCrypto,
    TransferManager? transferManager,
  }) : _client = client,
       _database = database,
       _fileCrypto = fileCrypto,
       _offlineManager = offlineManager,
       _accountId = accountId,
       _transferManager = transferManager,
       _runner = ChunkDownloadRunner(
         transport: transport,
         tarCapabilityCache: tarCapabilityCache,
       );

  /// Put every encrypted chunk of [file] in the offline cache and return the
  /// directory holding them.
  ///
  /// This is the one way anything in the app acquires a file's bytes. Export,
  /// offline pinning and preview differ only in what they do with the chunks
  /// afterwards — decrypt to a path, leave them, or decrypt into memory — and
  /// none of them gets to choose a different transport. Anything that fetched
  /// chunks its own way would quietly miss direct transfer, background
  /// survival, resume, and the cache, which is exactly how the pin path ended
  /// up relaying every byte through the server long after export had stopped.
  ///
  /// Chunks already cached are not refetched, so this is cheap to call on a
  /// file that is already offline.
  Future<String> fetchChunks(
    FileItem file, {
    required String displayName,
    required int totalChunks,
    required int totalBytes,
    String? outputPath,
    bool pinned = false,
    bool silent = false,
  }) async {
    final chunksPath = await _offlineManager.chunksDir(_accountId, file.id);

    if (await _offlineManager.hasCachedFile(_accountId, file.id)) {
      _log.debug(
        'all chunks cached — skipping download',
        fields: {'file_id': file.id},
      );
      if (pinned) {
        await _offlineManager.registerChunks(
          accountId: _accountId,
          fileId: file.id,
          chunksDir: chunksPath,
          chunkCount: totalChunks,
          pinned: true,
        );
      }
      return chunksPath;
    }

    final downloadItem = _transferManager?.startTransfer(
      fileName: displayName,
      type: TransferType.downloadHttp,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
      fileId: file.id,
      onWorker: true,
      silent: silent,
    );

    final startedAt = DateTime.now();

    try {
      await _downloadChunks(
        fileId: file.id,
        fileSize: totalBytes,
        chunkCount: totalChunks,
        chunksPath: chunksPath,
        outputPath: outputPath,
        onProgress: downloadItem == null
            ? null
            : (completedChunks, transferredBytes) =>
                  _transferManager?.updateProgress(
                    downloadItem.id,
                    completedChunks: completedChunks,
                    transferredBytes: transferredBytes,
                  ),
      );
    } catch (e) {
      if (downloadItem != null) {
        _transferManager?.failTransfer(
          downloadItem.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }

    _logDownloadTiming(
      fileId: file.id,
      totalBytes: totalBytes,
      started: startedAt,
    );
    if (downloadItem != null) {
      _transferManager?.completeTransfer(downloadItem.id);
    }
    await _offlineManager.registerChunks(
      accountId: _accountId,
      fileId: file.id,
      chunksDir: chunksPath,
      chunkCount: totalChunks,
      pinned: pinned,
    );
    return chunksPath;
  }

  /// Fire-and-forget: acquire the chunks, then decrypt them to [outputPath].
  /// Progress flows through [TransferManager] so the UI can render the overlay
  /// regardless of where the call originated.
  void run(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    required String displayName,
    required int totalChunks,
    required int totalBytes,
    Future<void> Function()? onComplete,
  }) {
    () async {
      try {
        final chunksPath = await fetchChunks(
          file,
          displayName: displayName,
          totalChunks: totalChunks,
          totalBytes: totalBytes,
          outputPath: outputPath,
        );
        await _decryptChunksToOutput(
          file,
          fileKey: fileKey,
          outputPath: outputPath,
          chunksPath: chunksPath,
          displayName: displayName,
          totalChunks: totalChunks,
          totalBytes: totalBytes,
          onComplete: onComplete,
        );
      } catch (e) {
        _log.warn(
          'download setup failed',
          fields: {'file_id': file.id, 'error': describeError(e)},
        );
      }
    }();
  }

  /// Acquire the chunks, then decrypt them into memory.
  ///
  /// The in-memory tail: previews, forks, re-indexing and the MCP tools want
  /// the plaintext itself rather than a file on disk. Everything up to the
  /// decrypt is the same as every other tail, so this gets direct transfer,
  /// background survival, resume and the cache for free — and a second read of
  /// the same file costs nothing but the decrypt.
  Future<Uint8List> fetchAndDecrypt(
    FileItem file, {
    required Uint8List fileKey,
    required String displayName,
    required int totalChunks,
    required int totalBytes,
    bool silent = false,
    void Function(double progress)? onProgress,
  }) async {
    final chunksPath = await fetchChunks(
      file,
      displayName: displayName,
      totalChunks: totalChunks,
      totalBytes: totalBytes,
      silent: silent,
    );
    onProgress?.call(1.0);

    // Straight to a temporary file and back rather than a decrypt-to-memory
    // FFI: the Rust side already streams chunk by chunk into a file, so this
    // holds one plaintext copy instead of one per chunk plus the joined
    // result.
    final scratch = File(
      p.join(Directory.systemTemp.path, 'hoodik-decrypt-${file.id}'),
    );
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
          // A leftover in the system temp dir is the OS's problem, not a
          // reason to fail a read that already succeeded.
        }
      }
    }
  }

  /// Finish the downloads a previous session started that the OS is no longer
  /// carrying, decrypting each one to where the user originally asked for it.
  ///
  /// Each shows in the transfer list while it runs, so it can be cancelled
  /// like anything else. One failure does not stop the rest: a file whose
  /// manifest is gone says nothing about the next file's.
  Future<void> resumeInterrupted(List<PendingDownload> rows) async {
    for (final row in rows) {
      try {
        await _resumeOne(row);
      } catch (e) {
        _log.warn(
          'could not resume an interrupted download',
          fields: {'file_id': row.fileId, 'error': describeError(e)},
        );
      }
    }
  }

  Future<void> _resumeOne(PendingDownload row) async {
    final present = await chunksOnDisk(
      Directory(row.outputDir),
      row.chunkCount,
    );

    final cached = await _database?.getCachedFileById(_accountId, row.fileId);

    // The OS finished it while the app was gone. Nothing left to fetch; it
    // just was never written down as done.
    if (present.length >= row.chunkCount) {
      await _finishResumed(row, cached);
      return;
    }

    final item = _transferManager?.startTransfer(
      fileName: cached?.decryptedName ?? row.fileId.substring(0, 8),
      type: TransferType.downloadHttp,
      totalBytes: cached?.size ?? 0,
      totalChunks: row.chunkCount,
      fileId: row.fileId,
      onWorker: true,
    );

    try {
      await _downloadChunks(
        fileId: row.fileId,
        fileSize: cached?.size ?? 0,
        chunkCount: row.chunkCount,
        chunksPath: row.outputDir,
        onProgress: item == null
            ? null
            : (completedChunks, transferredBytes) =>
                  _transferManager?.updateProgress(
                    item.id,
                    completedChunks: completedChunks,
                    transferredBytes: transferredBytes,
                  ),
      );
    } catch (e) {
      if (item != null) {
        _transferManager?.failTransfer(
          item.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }

    if (item != null) _transferManager?.completeTransfer(item.id);
    await _finishResumed(row, cached);
  }

  Future<void> _finishResumed(PendingDownload row, CachedFile? cached) async {
    await _offlineManager.registerChunks(
      accountId: _accountId,
      fileId: row.fileId,
      chunksDir: row.outputDir,
      chunkCount: row.chunkCount,
    );
    await _writeResumedOutput(row, cached);
    await _offlineManager.clearPendingDownload(
      accountId: _accountId,
      fileId: row.fileId,
    );
    _log.info('resumed download finished', fields: {'file_id': row.fileId});
  }

  /// Decrypt a resumed download to the destination it was originally headed
  /// for.
  ///
  /// Skipped when there is no destination, which is what pinning a file for
  /// offline use is, and when the key cannot be rebuilt — the account may have
  /// lost access to the file between the two sessions. Either way the chunks
  /// are cached, so opening the file is immediate rather than another
  /// download, and the failure is not worth losing that over.
  Future<void> _writeResumedOutput(
    PendingDownload row,
    CachedFile? cached,
  ) async {
    final outputPath = row.outputPath;
    final crypto = _fileCrypto;
    final encryptedKey = cached?.encryptedKey;
    if (outputPath == null || crypto == null || encryptedKey == null) return;

    try {
      await rust.decryptChunksToFile(
        chunksDir: row.outputDir,
        chunkCount: BigInt.from(row.chunkCount),
        decryptionKey: crypto.decryptFileKey(encryptedKey),
        cipher: cached!.cipher,
        outputPath: outputPath,
        fileId: row.fileId,
      );
    } catch (e) {
      _log.warn(
        'resumed download stayed in the cache, could not be written out',
        fields: {'file_id': row.fileId, 'error': describeError(e)},
      );
    }
  }

  Future<void> _downloadChunks({
    required String fileId,
    required int fileSize,
    required int chunkCount,
    required String chunksPath,
    String? outputPath,
    void Function(int completedChunks, int transferredBytes)? onProgress,
  }) async {
    final alreadyDownloaded = await _offlineManager.getDownloadedChunks(
      _accountId,
      fileId,
    );
    await _client.ensureFreshSession();
    final cookie = await _client.getCookieHeader();

    // Asked for per transfer rather than cached: signed URLs outlive the
    // transfer they belong to, and one fetch covers a whole file's chunks.
    // Returns null on every server that cannot serve them, which is the
    // normal case and falls through to downloading via the server.
    final manifest = await _client.files.fetchChunkUrls(fileId);

    // Recorded before the transfer starts, so a launch that follows a kill can
    // tell a download the user still wants from one abandoned with an old
    // session. Only the intent is stored — never the signed URLs, which stay
    // valid for days and have no business sitting on disk.
    await _offlineManager.recordPendingDownload(
      accountId: _accountId,
      fileId: fileId,
      chunkCount: chunkCount,
      outputDir: chunksPath,
      outputPath: outputPath,
    );

    await _runner.run(
      baseUrl: _client.baseUrl,
      cookie: cookie,
      fileId: fileId,
      fileSize: fileSize,
      chunkCount: chunkCount,
      outputDir: chunksPath,
      alreadyDownloaded: alreadyDownloaded,
      accountId: _accountId,
      directUrls: manifest?.urls ?? const [],
      refreshDirectUrls: () async =>
          (await _client.files.fetchChunkUrls(fileId))?.urls,
      onProgress: onProgress,
    );

    // Every chunk is on disk; there is nothing left for a later launch to
    // resume.
    await _offlineManager.clearPendingDownload(
      accountId: _accountId,
      fileId: fileId,
    );
  }

  Future<void> _decryptChunksToOutput(
    FileItem file, {
    required Uint8List fileKey,
    required String outputPath,
    required String chunksPath,
    required String displayName,
    required int totalChunks,
    required int totalBytes,
    Future<void> Function()? onComplete,
  }) async {
    final decryptItem = _transferManager?.startTransfer(
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
      final decryptDuration = DateTime.now().difference(decryptStart);
      _log.debug(
        'chunk decrypt done',
        fields: {
          'file_id': file.id,
          'duration_ms': decryptDuration.inMilliseconds,
        },
      );

      if (decryptItem != null) {
        _transferManager?.completeTransfer(decryptItem.id);
      }
    } catch (e) {
      if (decryptItem != null) {
        _transferManager?.failTransfer(
          decryptItem.id,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      rethrow;
    }

    await onComplete?.call();
  }

  void _logDownloadTiming({
    required String fileId,
    required int totalBytes,
    required DateTime started,
  }) {
    final duration = DateTime.now().difference(started);
    final mbps = totalBytes > 0 && duration.inMicroseconds > 0
        ? (totalBytes * 8 / duration.inMicroseconds).toStringAsFixed(1)
        : '?';
    _log.debug(
      'chunk download done',
      fields: {
        'file_id': fileId,
        'duration_ms': duration.inMilliseconds,
        'size_kb': totalBytes ~/ 1024,
        'mbps': mbps,
      },
    );
  }
}
