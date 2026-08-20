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
late FileItem Function(String id, {bool editable}) _item;

/// Serves pending pages, and drops a file from the pending set the moment it
/// is re-indexed — the way the server does, where "pending" is derived from
/// the absence of tags rather than tracked.
class _FakeStorageClient extends Fake implements StorageClient {
  _FakeStorageClient(this._pending);

  final List<FileItem> _pending;
  final List<String> reindexed = [];
  final Set<String> failFor = {};
  int pendingCalls = 0;

  @override
  Future<List<FileItem>> pendingReindex() async {
    pendingCalls += 1;
    return List<FileItem>.from(_pending);
  }

  @override
  Future<void> reindexFile({
    required String fileId,
    required String nameHash,
    required List<String> searchTokensRoot,
    required List<String> searchTokensFile,
  }) async {
    if (failFor.contains(fileId)) {
      throw StateError('boom');
    }

    reindexed.add(fileId);
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

    _item = (String id, {bool editable = false}) {
      final fileKey = fileCrypto.generateFileKey(cipher: _cipher);

      return FileItem.fromJson({
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

  test('pendingCount reports what the server still owes', () async {
    final storage = _FakeStorageClient([_item('a'), _item('b')]);

    expect(await serviceFor(storage).pendingCount(), 2);
  });

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
    expect(await service.pendingCount(), greaterThan(0));
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

  test('reports a fraction that never exceeds one', () async {
    final storage = _FakeStorageClient(List.generate(5, (i) => _item('f$i')));

    final states = await serviceFor(storage).run().toList();

    for (final state in states) {
      expect(state.fraction, inInclusiveRange(0, 1));
    }
    expect(states.last.fraction, 1);
  });
}
