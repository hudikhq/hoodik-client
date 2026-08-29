import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/features/files/controllers/files_action_result.dart';
import 'package:hoodik_app/features/shares/controllers/folder_relocation_controller.dart';
import 'package:hoodik_app/features/shares/controllers/folder_share_controller.dart';
import 'package:hoodik_app/features/shares/services/move_executor.dart';
import 'package:hoodik_app/features/shares/services/move_into_shared_cascade.dart';
import 'package:hoodik_app/features/shares/services/move_router.dart';

/// Serves each source-parent's metadata by id so the router's per-item "is this
/// parent shared?" probe can be exercised. The router only calls
/// [getFileMetadata]; an id absent from [parents] throws, exercising the
/// degrade-to-not-shared path.
class _FakeFilesClient extends Fake implements FilesClient {
  _FakeFilesClient(this.parents);

  final Map<String, Map<String, dynamic>> parents;
  final List<String> fetched = [];

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    fetched.add(fileId);
    final meta = parents[fileId];
    if (meta == null) throw StateError('no metadata for $fileId');
    return meta;
  }
}

FileItem _file(String id, {bool isOwner = true, String? parent}) => FileItem(
  id: id,
  fileId: parent,
  encryptedName: 'e',
  mime: 'text/plain',
  isOwner: isOwner,
);

FileItem _dir(String id, {bool isOwner = true, int? membersSignedAt}) =>
    FileItem(
      id: id,
      encryptedName: 'e',
      mime: 'dir',
      isOwner: isOwner,
      membersSignedAt: membersSignedAt,
    );

/// A shared owned folder (has a signed roster) — the canonical multi-key dest.
FileItem _sharedDir(String id) => _dir(id, membersSignedAt: 1736000000);

/// Metadata for a shared (multi-key) parent folder.
Map<String, dynamic> _sharedParentMeta(String id) => {
  'id': id,
  'mime': 'dir',
  'is_owner': true,
  'members_signed_at': 1736000000,
};

/// Metadata for a private (single-key) parent folder.
Map<String, dynamic> _privateParentMeta(String id) => {
  'id': id,
  'mime': 'dir',
  'is_owner': true,
};

void main() {
  MoveRouter router({
    bool sharingEnabled = true,
    Map<String, Map<String, dynamic>> parents = const {},
  }) {
    return MoveRouter(
      files: _FakeFilesClient(parents),
      sharingEnabled: sharingEnabled,
    );
  }

  group('MoveRouter.classify', () {
    test('private destination, root source → PlainMove', () async {
      final decision = await router().classify(
        sources: [_file('f1')],
        destination: _dir('priv'),
      );
      expect(decision, isA<PlainMove>());
    });

    test('owned items into a shared folder → MoveIntoShared', () async {
      final decision = await router().classify(
        sources: [_file('f1'), _dir('d1')],
        destination: _sharedDir('shared'),
      );
      expect(decision, isA<MoveIntoShared>());
      expect((decision as MoveIntoShared).destinationFolderId, 'shared');
      expect(decision.sources.length, 2);
    });

    test('a non-owned item bound for a shared folder → BlockedMove', () async {
      final decision = await router().classify(
        sources: [_file('f1'), _file('notmine', isOwner: false)],
        destination: _sharedDir('shared'),
      );
      expect(decision, isA<BlockedMove>());
    });

    test('owned item out of a shared folder → MoveOutOfShared', () async {
      final decision = await router(
        parents: {'p': _sharedParentMeta('p')},
      ).classify(sources: [_file('f1', parent: 'p')], destination: null);
      expect(decision, isA<MoveOutOfShared>());
      expect((decision as MoveOutOfShared).destinationFolderId, isNull);
    });

    test('a non-owner moving out of a shared folder → BlockedMove', () async {
      final decision = await router(parents: {'p': _sharedParentMeta('p')})
          .classify(
            sources: [_file('notmine', isOwner: false, parent: 'p')],
            destination: null,
          );
      expect(decision, isA<BlockedMove>());
    });

    test('private source parent → PlainMove (not a move-out)', () async {
      final decision = await router(parents: {'p': _privateParentMeta('p')})
          .classify(
            sources: [_file('f1', parent: 'p')],
            destination: _dir('priv'),
          );
      expect(decision, isA<PlainMove>());
    });

    test('sharing disabled never engages the shared paths', () async {
      final files = _FakeFilesClient({'p': _sharedParentMeta('p')});
      final r = MoveRouter(files: files, sharingEnabled: false);
      final decision = await r.classify(
        sources: [_file('f1', parent: 'p')],
        destination: _sharedDir('shared'),
      );
      expect(decision, isA<PlainMove>());
      expect(
        files.fetched,
        isEmpty,
        reason: 'an older server that does not speak sharing is never probed',
      );
    });

    test(
      'a source-parent metadata failure blocks the move (fail closed)',
      () async {
        final decision = await router(parents: const {}).classify(
          sources: [_file('f1', parent: 'p')],
          destination: _dir('priv'),
        );
        expect(
          decision,
          isA<BlockedMove>(),
          reason:
              'an unreadable parent might be shared; routing its item to the plain '
              'path could strand other members, so block rather than guess',
        );
      },
    );

    test(
      'a root (null-parent) source mixed with a shared sibling splits',
      () async {
        final files = _FakeFilesClient({'shared': _sharedParentMeta('shared')});
        final r = MoveRouter(files: files, sharingEnabled: true);
        final decision = await r.classify(
          sources: [
            _file('a', parent: 'shared'),
            _file('b', parent: null),
          ],
          destination: null,
        );
        expect(decision, isA<SplitMove>());
        final split = decision as SplitMove;
        expect(split.outSources.map((f) => f.id), ['a']);
        expect(split.plainSources.map((f) => f.id), ['b']);
        expect(files.fetched, [
          'shared',
        ], reason: 'the null root parent is never probed');
      },
    );

    test('items from distinct shared parents → MoveOutOfShared(all)', () async {
      final r = router(
        parents: {'s1': _sharedParentMeta('s1'), 's2': _sharedParentMeta('s2')},
      );
      final decision = await r.classify(
        sources: [
          _file('a', parent: 's1'),
          _file('b', parent: 's2'),
        ],
        destination: null,
      );
      expect(decision, isA<MoveOutOfShared>());
      expect((decision as MoveOutOfShared).sources.length, 2);
    });

    test(
      'a selection spanning a shared and a private parent → SplitMove',
      () async {
        final r = router(
          parents: {
            'shared': _sharedParentMeta('shared'),
            'priv': _privateParentMeta('priv'),
          },
        );
        final decision = await r.classify(
          sources: [
            _file('a', parent: 'shared'),
            _file('b', parent: 'priv'),
          ],
          destination: _dir('dest'),
        );
        expect(decision, isA<SplitMove>());
        final split = decision as SplitMove;
        expect(split.outSources.map((f) => f.id), ['a']);
        expect(split.plainSources.map((f) => f.id), ['b']);
        expect(split.destinationFolderId, 'dest');
      },
    );

    test(
      'a non-owned item in the shared half of a split → BlockedMove',
      () async {
        final r = router(
          parents: {
            'shared': _sharedParentMeta('shared'),
            'priv': _privateParentMeta('priv'),
          },
        );
        final decision = await r.classify(
          sources: [
            _file('a', isOwner: false, parent: 'shared'),
            _file('b', parent: 'priv'),
          ],
          destination: _dir('dest'),
        );
        expect(decision, isA<BlockedMove>());
      },
    );

    test('each distinct parent is probed once', () async {
      final files = _FakeFilesClient({'p': _sharedParentMeta('p')});
      final r = MoveRouter(files: files, sharingEnabled: true);
      await r.classify(
        sources: [
          _file('a', parent: 'p'),
          _file('b', parent: 'p'),
          _file('c', parent: 'p'),
        ],
        destination: null,
      );
      expect(files.fetched, ['p'], reason: 'one fetch for the shared parent');
    });
  });

  group('MoveExecutor', _executorTests);
}

class _FakeFileOperations extends Fake implements FileOperations {
  final List<({List<String> ids, String? target})> moves = [];

  @override
  Future<void> moveMany(List<String> fileIds, {String? targetDirId}) async {
    moves.add((ids: fileIds, target: targetDirId));
  }
}

class _SpyRelocation extends Fake implements FolderRelocationController {
  int intoSharedCalls = 0;

  @override
  Future<FolderShareOutcome> moveIntoShared({
    required FileItem file,
    required String destinationFolderId,
    String? rosterFolderId,
  }) async {
    intoSharedCalls += 1;
    return const FolderShareOutcome.success();
  }
}

class _SpyCascade extends Fake implements MoveIntoSharedCascade {
  int folderCalls = 0;
  int outCalls = 0;

  /// When set, `moveOutOfShared` reports a failure with this message instead of
  /// succeeding — used to exercise the split's move-out-failure path.
  String? outFailure;

  @override
  Future<FolderShareOutcome> moveFolderIntoShared({
    required FileItem folder,
    required String destinationFolderId,
    String? rosterFolderId,
    void Function(int done, int total)? onProgress,
    Future<bool> Function(MoveCascadePreview preview)? confirm,
  }) async {
    folderCalls += 1;
    return const FolderShareOutcome.success();
  }

  @override
  Future<FolderShareOutcome> moveOutOfShared({
    required FileItem file,
    required String? destinationFolderId,
  }) async {
    outCalls += 1;
    final failure = outFailure;
    if (failure != null) return FolderShareOutcome.failure(failure);
    return const FolderShareOutcome.success();
  }
}

void _executorTests() {
  late _FakeFileOperations ops;
  late _SpyRelocation relocation;
  late _SpyCascade cascade;
  late ProviderContainer container;

  setUp(() {
    ops = _FakeFileOperations();
    relocation = _SpyRelocation();
    cascade = _SpyCascade();
    container = ProviderContainer(
      overrides: [
        folderRelocationControllerProvider.overrideWithValue(relocation),
        moveIntoSharedCascadeProvider.overrideWithValue(cascade),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<FilesActionResult> run(MoveDecision decision, List<FileItem> sources) {
    return container
        .read(moveExecutorProvider)
        .run(
          decision: decision,
          ops: ops,
          sources: sources,
          destinationId: 'dest',
        );
  }

  test('PlainMove calls moveMany with the source ids', () async {
    final sources = [_file('a'), _file('b')];
    final result = await run(const PlainMove(), sources);
    expect(result, isA<FilesActionResult>());
    expect(ops.moves.single.ids, ['a', 'b']);
    expect(ops.moves.single.target, 'dest');
    expect(relocation.intoSharedCalls, 0);
    expect(cascade.folderCalls, 0);
  });

  test('BlockedMove surfaces the message and touches nothing', () async {
    final result = await run(const BlockedMove('nope'), [_file('a')]);
    expect(result.message, 'nope');
    expect(ops.moves, isEmpty);
    expect(relocation.intoSharedCalls, 0);
    expect(cascade.folderCalls, 0);
  });

  test(
    'MoveIntoShared routes a file to relocation, a folder to cascade',
    () async {
      final sources = [_file('a'), _dir('d')];
      await run(MoveIntoShared(sources, 'shared', 'shared'), sources);
      expect(relocation.intoSharedCalls, 1, reason: 'the plain file');
      expect(cascade.folderCalls, 1, reason: 'the folder');
      expect(ops.moves, isEmpty);
    },
  );

  test('MoveOutOfShared routes each source to the move-out path', () async {
    final sources = [_file('a'), _dir('d')];
    await run(MoveOutOfShared(sources, null), sources);
    expect(cascade.outCalls, 2);
    expect(ops.moves, isEmpty);
    expect(relocation.intoSharedCalls, 0);
  });

  test('SplitMove detaches the shared half and plain-moves the rest', () async {
    final plain = [_file('p1'), _file('p2')];
    final out = [_file('o1')];
    final result = await run(SplitMove(plain, out, 'dest'), [...plain, ...out]);
    expect(cascade.outCalls, 1, reason: 'the one shared-parent item');
    expect(ops.moves.single.ids, ['p1', 'p2']);
    expect(ops.moves.single.target, 'dest');
    expect(result.message, 'Moved 3 items');
  });

  test('SplitMove surfaces a move-out failure after the plain leg ran', () async {
    cascade.outFailure = 'rejected';
    final plain = [_file('p1')];
    final out = [_file('o1')];
    final result = await run(SplitMove(plain, out, 'dest'), [...plain, ...out]);
    // Plain relocation runs first (reversible), so the private items moved
    // before the failing detach; the move-out failure is surfaced, not swallowed.
    expect(ops.moves.single.ids, ['p1']);
    expect(cascade.outCalls, 1);
    expect(result.message, 'rejected');
  });
}
