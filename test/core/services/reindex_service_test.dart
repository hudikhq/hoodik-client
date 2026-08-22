import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/services/reindex_service.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

const _cipher = 'aegis128l';

/// Real ciphertext, not placeholders: the sweep decrypts each file's key and
/// name before it can tag anything, so a fixture with empty fields would only
/// ever exercise the error path.
late FileItem Function(String id, {bool editable, Map<String, dynamic> extra})
_item;

/// Serves pending pages, and drops a file from the pending set the moment it
/// is re-indexed — the way the server does, where "pending" is derived from
/// the absence of tags rather than tracked.
class _FakeStorageClient extends Fake implements StorageClient {
  _FakeStorageClient(this._pending, {this.pageSize});

  final List<FileItem> _pending;

  /// Mirrors the server's paging: a poll returns at most this many rows, so a
  /// sweep that trusts one page is caught out. Null returns everything.
  final int? pageSize;

  final List<String> reindexed = [];
  final Set<String> failFor = {};
  final Map<String, Map<String, dynamic>> written = {};
  int pendingCalls = 0;

  @override
  Future<List<FileItem>> pendingReindex() async {
    pendingCalls += 1;
    final take = pageSize ?? _pending.length;
    return List<FileItem>.from(_pending.take(take));
  }

  @override
  Future<void> reindexFile({
    required String fileId,
    required String nameHash,
    required List<String> searchTokensRoot,
    required List<String> searchTokensFile,
    List<String>? digestTokensRoot,
    List<String>? digestTokensFile,
    String? md5,
    String? sha1,
    String? sha256,
    String? blake2b,
  }) async {
    if (failFor.contains(fileId)) {
      throw StateError('boom');
    }

    reindexed.add(fileId);
    written[fileId] = {
      'search_tokens_root': searchTokensRoot,
      'search_tokens_file': searchTokensFile,
      'digest_tokens_root': digestTokensRoot,
      'digest_tokens_file': digestTokensFile,
      'md5': md5,
      'sha1': sha1,
      'sha256': sha256,
      'blake2b': blake2b,
    };
    _pending.removeWhere((f) => f.id == fileId);
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this.storage);

  @override
  final StorageClient storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late FileCrypto fileCrypto;

  setUp(() {
    const crypto = CryptoService();
    final pair = crypto.generateWrappingKeyPair();
    fileCrypto = FileCrypto(
      privateKeyPem: pair.privatePem,
      wrappingPrivateKeyPem: pair.privatePem,
      crypto: crypto,
    );

    _item =
        (
          String id, {
          bool editable = false,
          Map<String, dynamic> extra = const {},
        }) {
          final fileKey = fileCrypto.generateFileKey(cipher: _cipher);

          return FileItem.fromJson({
            ...extra,
            'id': id,
            'encrypted_name': fileCrypto.encryptFileName(
              name: '$id-notes.md',
              fileKey: fileKey,
              cipher: _cipher,
            ),
            'encrypted_key': fileCrypto.encryptFileKey(
              fileKey: fileKey,
              publicKeyPem: pair.publicPem,
            ),
            'mime': editable ? 'text/markdown' : 'application/octet-stream',
            'cipher': _cipher,
            // Editable files would be downloaded and decrypted to index their
            // bodies; no downloader is wired here, so keep them plain.
            'editable': false,
            'is_owner': true,
          });
        };
  });

  ReindexService serviceFor(_FakeStorageClient storage) =>
      ReindexService(client: _FakeApiClient(storage), fileCrypto: fileCrypto);

  test('walks every pending file and finishes empty', () async {
    final storage = _FakeStorageClient(List.generate(23, (i) => _item('f$i')));

    final states = await serviceFor(storage).run().toList();

    expect(storage.reindexed.length, 23);
    expect(states.last.running, isFalse);
    expect(states.last.done, 23);
    expect(states.last.failed, 0);
  });

  test('re-polls between rounds rather than trusting one page', () async {
    final storage = _FakeStorageClient([_item('a')]);

    await serviceFor(storage).run().toList();

    // One poll to seed the run, one to confirm nothing is left.
    expect(storage.pendingCalls, greaterThan(1));
  });

  test('a file that throws is counted and skipped, not fatal', () async {
    final storage = _FakeStorageClient([_item('a'), _item('b'), _item('c')])
      ..failFor.add('b');

    final states = await serviceFor(storage).run().toList();

    // The other two still got done: one unreadable file must not cost the
    // user their whole index.
    expect(storage.reindexed, containsAll(<String>['a', 'c']));
    expect(states.last.failed, 1);
    expect(states.last.running, isFalse);
  });

  test('stops rather than spinning when only failures remain', () async {
    final storage = _FakeStorageClient([_item('a')])..failFor.add('a');

    final states = await serviceFor(storage).run().toList();

    expect(storage.reindexed, isEmpty);
    expect(states.last.failed, 1);
    expect(states.last.running, isFalse);
  });

  test('cancelling stops the sweep and leaves the rest pending', () async {
    final storage = _FakeStorageClient(List.generate(40, (i) => _item('f$i')));
    final service = serviceFor(storage);

    // Cancel after the first batch lands. The check runs between batches, so
    // the batch in flight completes and the remainder is left for next time.
    await for (final state in service.run()) {
      if (state.done > 0) service.cancel();
    }

    expect(storage.reindexed.length, lessThan(40));
  });

  test('a cancelled sweep resumes from what is still pending', () async {
    final storage = _FakeStorageClient(List.generate(30, (i) => _item('f$i')));

    final first = serviceFor(storage);
    await for (final state in first.run()) {
      if (state.done > 0) first.cancel();
    }
    final afterCancel = storage.reindexed.length;
    expect(afterCancel, lessThan(30));

    // Nothing was persisted about the first run; the second simply asks what
    // is still pending and carries on.
    await serviceFor(storage).run().toList();

    expect(storage.reindexed.length, 30);
    expect(await storage.pendingReindex(), isEmpty);
  });

  test(
    'sweeps past the first page on an account larger than one page',
    () async {
      // The server pages at 500; a small page here forces several rounds. A
      // sweep that stops when a page is no smaller than the last quits after
      // page one — every later page is also full.
      final storage = _FakeStorageClient(
        List.generate(12, (i) => _item('f$i')),
        pageSize: 5,
      );

      final states = await serviceFor(storage).run().toList();

      expect(storage.reindexed.length, 12);
      expect(states.last.done, 12);
      expect(states.last.total, 12);
      expect(states.last.running, isFalse);
    },
  );

  test('the sweep keeps running after its only observer detaches', () async {
    final storage = _FakeStorageClient(List.generate(30, (i) => _item('f$i')));
    final service = serviceFor(storage);

    final sweep = service.start();
    // Attach an observer and drop it almost at once — closing the dialog with
    // "continue in background" does exactly this.
    final sub = service.progress.listen((_) {});
    await sub.cancel();

    await sweep;

    expect(storage.reindexed.length, 30);
    expect(service.completedFully, isTrue);
  });

  test('a cancelled background sweep is not marked complete', () async {
    final storage = _FakeStorageClient(List.generate(40, (i) => _item('f$i')));
    final service = serviceFor(storage);

    final sweep = service.start();
    service.progress.listen((p) {
      if (p.done > 0) service.cancel();
    });
    await sweep;

    // The give-up bookkeeping keys off completedFully; a cancelled sweep must
    // not condemn the files it never reached.
    expect(service.completedFully, isFalse);
    expect(storage.reindexed.length, lessThan(40));
  });

  test('reports a fraction that never exceeds one', () async {
    final storage = _FakeStorageClient(List.generate(5, (i) => _item('f$i')));

    final states = await serviceFor(storage).run().toList();

    for (final state in states) {
      expect(state.fraction, inInclusiveRange(0, 1));
    }
    expect(states.last.fraction, 1);
  });

  test(
    're-keys bare digests, into the digest fields and never in plaintext',
    () async {
      final bareSha256 = 'a' * 64;
      final bareMd5 = 'b' * 32;
      final storage = _FakeStorageClient([
        _item('bare', extra: {'sha256': bareSha256, 'md5': bareMd5}),
      ]);

      await serviceFor(storage).run().drain<void>();

      final written = storage.written['bare']!;
      // Keyed: a 32-hex tag, never the stored value back.
      expect(written['sha256'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(written['sha256'], isNot(bareSha256));
      // MD5 shares the tag's shape; the bare sha256 sibling is what proves
      // this row has not been keyed yet.
      expect(written['md5'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(written['md5'], isNot(bareMd5));
      expect(written['digest_tokens_root'], hasLength(2));
      expect(written['digest_tokens_file'], hasLength(2));
      // Digest tags stay out of the word lists — those are the scopes a
      // rename replaces — and the bare digest crosses the wire nowhere.
      expect(written.toString(), isNot(contains(bareSha256)));
    },
  );

  test('a second pass leaves already-keyed digests alone', () async {
    // What the first sweep wrote: 32-hex tags in every digest column. A
    // failed crypto-migration ceremony makes this row pending again, and
    // keying a keyed value would corrupt it beyond repair.
    final storage = _FakeStorageClient([
      _item('keyed', extra: {'sha256': 'c' * 32, 'md5': 'd' * 32}),
    ]);

    await serviceFor(storage).run().drain<void>();

    final written = storage.written['keyed']!;
    expect(written['sha256'], isNull);
    expect(written['md5'], isNull);
    expect(written['digest_tokens_root'], isNull);
    expect(written['digest_tokens_file'], isNull);
  });
}
