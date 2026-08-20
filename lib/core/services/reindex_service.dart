import 'dart:convert';

import 'package:dio/dio.dart';
import 'dart:typed_data';

import '../api/api_client.dart';
import '../utils/logger.dart';
import '../crypto/file_crypto.dart';
import 'file_downloader.dart';

/// Files handled per round. Small enough that cancelling feels immediate and
/// that a note download never blocks the bar for long, large enough that the
/// request overhead is not what dominates the sweep.
const _batchSize = 10;

const _log = Logger('ReindexService');

/// Progress of a re-index sweep.
class ReindexProgress {
  const ReindexProgress({
    this.total = 0,
    this.done = 0,
    this.failed = 0,
    this.running = false,
  });

  final int total;
  final int done;
  final int failed;
  final bool running;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0, 1).toDouble();

  ReindexProgress copyWith({
    int? total,
    int? done,
    int? failed,
    bool? running,
  }) => ReindexProgress(
    total: total ?? this.total,
    done: done ?? this.done,
    failed: failed ?? this.failed,
    running: running ?? this.running,
  );
}

/// Rebuilds the search index for files that predate keyed tags.
///
/// The re-key migration dropped every old index row, and nothing server-side
/// can rebuild them: the tags are keyed on material only this device holds, and
/// a note's body has to be decrypted to be re-indexed at all. So each client
/// walks its own files once.
///
/// Progress needs no bookkeeping of its own. The server reports a file as
/// pending exactly while it has no root-scope tags, so writing them is what
/// marks it done. Closing the app, cancelling, or losing connectivity all
/// resume from the same place, which is simply "whatever is still pending".
class ReindexService {
  ReindexService({
    required ApiClient client,
    required FileCrypto fileCrypto,
    FileDownloader? downloader,
  }) : _client = client,
       _fileCrypto = fileCrypto,
       _downloader = downloader;

  final ApiClient _client;
  final FileCrypto _fileCrypto;
  final FileDownloader? _downloader;

  bool _cancelled = false;

  /// Files that threw, by id. A file that fails stays pending and is tried
  /// again on the next round, so counting attempts would report "2 files
  /// couldn't be re-indexed" when one file failed twice.
  final Set<String> _failedIds = {};

  /// Every file this run has attempted, and every file it has ever seen
  /// pending. Both are counted by id for the same reason as [_failedIds]:
  /// a retried file would otherwise advance the bar twice and show "39 of 39"
  /// on an account with 28 files.
  final Set<String> _attemptedIds = {};
  final Set<String> _seenIds = {};

  /// Stop after the batch in flight. Whatever is left is still pending
  /// server-side, so the next session picks it up from there.
  void cancel() => _cancelled = true;

  /// How many files still need doing. Cheap enough to call on unlock to decide
  /// whether the sweep is worth showing at all.
  Future<int> pendingCount() async =>
      (await _client.storage.pendingReindex()).length;

  /// A note's body is indexed word for word, which is why the old scheme
  /// leaked note contents and not just names. Rebuilding that means fetching
  /// and decrypting the note — there is no shortcut, the server holds only
  /// ciphertext.
  Future<String> _textFor(FileItem file, String name, Uint8List fileKey) async {
    final downloader = _downloader;
    if (!file.editable || downloader == null) {
      return name;
    }

    final bytes = await downloader.downloadFile(
      file,
      fileKey: fileKey,
      showInTransfers: false,
    );

    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> _reindexOne(FileItem file) async {
    final fileKey = _fileCrypto.decryptFileKey(file.encryptedKey!);
    final name = _fileCrypto.decryptFileName(
      encryptedNameHex: file.encryptedName,
      fileKey: fileKey,
      cipher: file.cipher,
    );

    final indexed = await _textFor(file, name, fileKey);

    await _client.storage.reindexFile(
      fileId: file.id,
      nameHash: _fileCrypto.hashFileName(name),
      searchTokensRoot: _fileCrypto.tokenizeForSearch(indexed),
      searchTokensFile: _fileCrypto.tokenizeForSearchWithFileKey(
        fileKey,
        indexed,
      ),
    );
  }

  /// Walk every pending file in batches until the server reports none left.
  ///
  /// A file that throws is counted and skipped rather than aborting the sweep:
  /// one unreadable file should not cost the user their whole index. It stays
  /// pending, so the next run tries it again.
  Stream<ReindexProgress> run() async* {
    _cancelled = false;
    _failedIds.clear();
    _attemptedIds.clear();
    _seenIds.clear();

    var state = const ReindexProgress(running: true);
    var pending = await _client.storage.pendingReindex();
    _seenIds.addAll(pending.map((f) => f.id));
    state = state.copyWith(total: _seenIds.length);
    yield state;

    while (pending.isNotEmpty) {
      for (var i = 0; i < pending.length; i += _batchSize) {
        if (_cancelled) {
          yield state.copyWith(running: false);
          return;
        }

        final batch = pending.skip(i).take(_batchSize);

        for (final file in batch) {
          try {
            await _reindexOne(file);
            _failedIds.remove(file.id);
          } catch (e) {
            // Swallowing this silently is how a systematic failure looks like
            // a handful of unlucky files: the counter goes up and nothing says
            // why. The sweep still continues — one bad file must not cost the
            // user their index — but it says what happened.
            _log.warn(
              'file could not be re-indexed',
              fields: {
                'file_id': file.id,
                'editable': file.editable,
                if (e is DioException) ...{
                  'path': e.requestOptions.path,
                  'status': e.response?.statusCode,
                  'body': e.response?.data?.toString(),
                } else
                  'error': e.toString(),
              },
            );
            _failedIds.add(file.id);
          } finally {
            _attemptedIds.add(file.id);
            state = state.copyWith(
              done: _attemptedIds.length,
              failed: _failedIds.length,
            );
          }
        }

        yield state;
      }

      if (_cancelled) {
        yield state.copyWith(running: false);
        return;
      }

      // The server hands back at most one page at a time, so keep asking until
      // it reports nothing left. Files that failed come back around; if only
      // failures remain, stop rather than spin on them.
      final next = await _client.storage.pendingReindex();
      if (next.length >= pending.length) break;

      _seenIds.addAll(next.map((f) => f.id));
      state = state.copyWith(total: _seenIds.length);
      pending = next;
    }

    yield state.copyWith(running: false);
  }
}
