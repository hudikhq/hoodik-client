import 'dart:async';
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
/// pending exactly while its `name_hash` is not yet a keyed tag, so the keyed
/// hash every re-index writes is what marks it done. Closing the app,
/// cancelling, or losing connectivity all resume from the same place, which
/// is simply "whatever is still pending".
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

  final _progress = StreamController<ReindexProgress>.broadcast();
  StreamSubscription<ReindexProgress>? _driver;
  Completer<void>? _completion;
  ReindexProgress _current = const ReindexProgress();
  bool _completedFully = false;

  /// Files that threw, by id. A file that fails stays pending for the next
  /// run; this run does not retry it, so the count reads "1 file couldn't be
  /// re-indexed" however often it would have failed.
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
    final rootTags = _fileCrypto.tokenizeForSearch(indexed);
    final fileTags = _fileCrypto.tokenizeForSearchWithFileKey(fileKey, indexed);

    // Migrated rows still carry bare content digests — the third copy of the
    // same leak. Re-key each from the stored value (no re-download needed)
    // and index it in both scopes, which is what makes pasting a digest into
    // search find the file.
    //
    // Only values still in the bare shape are re-keyed. A file can pass
    // through here twice — a note edited before the sweep already got a keyed
    // sha256 from its save, and a failed crypto-migration ceremony can run
    // the whole sweep once on the old key — and keying a keyed value corrupts
    // the column beyond repair. Shape decides for sha1/sha256/blake2b; bare
    // MD5 is 32 hex chars like a tag, so it goes by its siblings: every
    // writer that stored an MD5 stored a SHA-256 next to it, so a row keying
    // any sibling is a bare row and one keying none is already done.
    const bareLengths = {'md5': 32, 'sha1': 40, 'sha256': 64, 'blake2b': 128};
    final hexShape = RegExp(r'^[0-9a-fA-F]+$');
    String? bare(String name, String? digest) {
      if (digest == null || digest.length != bareLengths[name]) return null;
      return hexShape.hasMatch(digest) ? digest : null;
    }

    final bareDigests = <String, String>{};
    for (final entry in {
      'sha1': bare('sha1', file.sha1),
      'sha256': bare('sha256', file.sha256),
      'blake2b': bare('blake2b', file.blake2b),
    }.entries) {
      if (entry.value != null) bareDigests[entry.key] = entry.value!;
    }
    if (bareDigests.isNotEmpty) {
      final md5 = bare('md5', file.md5);
      if (md5 != null) bareDigests['md5'] = md5;
    }

    final fileSearchKey = _fileCrypto.searchFileKeyHex(fileKey);
    final rootKey = _fileCrypto.searchRootKey;
    final digestTokensRoot = <String>[];
    final digestTokensFile = <String>[];
    String? rekey(String name) {
      final digest = bareDigests[name];
      if (digest == null) return null;
      digestTokensRoot.add('${_fileCrypto.exactTag(rootKey, digest)}:1');
      final keyed = _fileCrypto.exactTag(fileSearchKey, digest);
      digestTokensFile.add('$keyed:1');
      return keyed;
    }

    await _client.storage.reindexFile(
      fileId: file.id,
      nameHash: _fileCrypto.hashFileName(name),
      searchTokensRoot: rootTags,
      searchTokensFile: fileTags,
      md5: rekey('md5'),
      sha1: rekey('sha1'),
      sha256: rekey('sha256'),
      blake2b: rekey('blake2b'),
      digestTokensRoot: digestTokensRoot.isEmpty ? null : digestTokensRoot,
      digestTokensFile: digestTokensFile.isEmpty ? null : digestTokensFile,
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

      // The server hands back at most one page at a time (500), so keep asking
      // until nothing fresh comes back. Stopping when the next page is no
      // smaller than this one broke after a single page on any account past
      // that limit: page two is also full, so it read as "no progress" and the
      // sweep quit with most of the account still unindexed. Only what this
      // run has not attempted counts as fresh: retrying an id the server
      // already answered changes nothing the second time — and if a server
      // ever kept reporting a successfully re-indexed file as pending,
      // retrying it would spin this sweep for the life of the app.
      final next = (await _client.storage.pendingReindex())
          .where((f) => !_attemptedIds.contains(f.id))
          .toList();
      if (next.isEmpty) break;

      _seenIds.addAll(next.map((f) => f.id));
      state = state.copyWith(total: _seenIds.length);
      pending = next;
    }

    yield state.copyWith(running: false);
  }

  /// The latest progress, so a dialog that attaches after the sweep has
  /// started opens on the real state rather than an empty bar.
  ReindexProgress get current => _current;

  /// Progress updates for observers. Broadcast on purpose: the dialog can
  /// attach and detach — the user tapping "continue in background" — without
  /// the sweep itself, which is driven below, ever noticing.
  Stream<ReindexProgress> get progress => _progress.stream;

  /// True once the sweep has run to its end without being cancelled. The
  /// give-up bookkeeping keys off this: a cancelled sweep condemns nothing.
  bool get completedFully => _completedFully;

  /// Start the sweep, once. The work is driven here inside the service rather
  /// than by whoever happens to be listening, which is what lets the dialog
  /// close while it keeps running. Returns a future that completes when the
  /// sweep finishes or is cancelled; calling it again while one is in flight
  /// returns that same future.
  Future<void> start() {
    final existing = _completion;
    if (existing != null) return existing.future;

    final completion = Completer<void>();
    _completion = completion;
    _completedFully = false;

    void finish() {
      _driver = null;
      _completion = null;
      if (!completion.isCompleted) completion.complete();
    }

    _driver = run().listen(
      (progress) {
        _current = progress;
        if (!_progress.isClosed) _progress.add(progress);
      },
      onError: (_) => finish(),
      onDone: () {
        _completedFully = !_cancelled;
        finish();
      },
    );

    return completion.future;
  }

  /// Detach observers and stop driving. The broadcast stream stays open for
  /// the service's lifetime; nothing holds it once the sweep is done, so it
  /// goes with the service.
  void dispose() {
    _driver?.cancel();
    _progress.close();
  }
}
