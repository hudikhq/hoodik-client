import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/files/controllers/files_action_result.dart';
import 'package:hoodik_app/features/files/controllers/files_mutation_controller.dart';
import 'package:hoodik_app/features/files/helpers/move_wiring.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/features/shares/services/move_into_shared_cascade.dart';

final _refProvider = Provider<Ref>((ref) => ref);

class _RecordingFilesClient extends Fake implements FilesClient {
  _RecordingFilesClient(this.metadata);

  /// Metadata keyed by file id. A drop target and a nested source can both be
  /// fetched in one move, so the client serves whichever id is asked for.
  final Map<String, Map<String, dynamic>> metadata;
  final List<String> metadataIds = [];

  String? get lastMetadataId => metadataIds.isEmpty ? null : metadataIds.last;

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    metadataIds.add(fileId);
    final found = metadata[fileId];
    if (found == null) throw StateError('no metadata for $fileId');
    return found;
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files);

  final FilesClient _files;

  @override
  FilesClient get files => _files;
}

class _SeededFilesNotifier extends FilesNotifier {
  _SeededFilesNotifier(this._files);

  final List<FileItem> _files;

  @override
  FilesState build(String? arg) => FilesState(loading: false, files: _files);
}

class _RecordingMutationController extends FilesMutationController {
  _RecordingMutationController(super.ref, super.dirId);

  bool called = false;
  bool sawDestination = false;
  List<FileItem> sawSources = const [];

  @override
  Future<FilesActionResult> move(
    List<FileItem> sources, {
    required FileItem? destination,
    Future<bool> Function(MoveCascadePreview preview)? confirm,
    void Function(int done, int total)? onProgress,
  }) async {
    called = true;
    sawDestination = destination != null;
    sawSources = sources;
    return const FilesActionResult.success('moved');
  }
}

void main() {
  testWidgets('dropping onto the root target moves with a null destination and '
      'no metadata fetch', (tester) async {
    final dragged = FileItem(
      id: '00000000-0000-0000-0000-0000000000a1',
      mime: 'dir',
      encryptedName: 'deadbeef',
    );

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesNotifierProvider.overrideWith(
            () => _SeededFilesNotifier([dragged]),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final mutations = _RecordingMutationController(
      widgetRef.read(_refProvider),
      null,
    );
    final coordinator = FileMoveCoordinator(
      ref: widgetRef,
      dirId: null,
      mutations: mutations,
    );

    final result = await coordinator.dropMove(
      tester.element(find.byType(SizedBox)),
      [dragged.id],
      null,
    )();

    expect(mutations.called, isTrue);
    expect(mutations.sawDestination, isFalse);
    expect(result.message, 'moved');
  });

  testWidgets('dropping into a folder fetches its metadata and moves with a '
      'non-null destination', (tester) async {
    const folderId = '00000000-0000-0000-0000-0000000000b2';
    final dragged = FileItem(
      id: '00000000-0000-0000-0000-0000000000a1',
      mime: 'image/png',
      encryptedName: 'deadbeef',
    );

    final filesClient = _RecordingFilesClient({
      folderId: {'id': folderId, 'mime': 'dir', 'encrypted_name': 'enc'},
    });

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesNotifierProvider.overrideWith(
            () => _SeededFilesNotifier([dragged]),
          ),
          apiClientProvider.overrideWithValue(_FakeApiClient(filesClient)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final mutations = _RecordingMutationController(
      widgetRef.read(_refProvider),
      null,
    );
    final coordinator = FileMoveCoordinator(
      ref: widgetRef,
      dirId: null,
      mutations: mutations,
    );

    final result = await coordinator.dropMove(
      tester.element(find.byType(SizedBox)),
      [dragged.id],
      folderId,
    )();

    expect(filesClient.lastMetadataId, folderId);
    expect(mutations.called, isTrue);
    expect(mutations.sawDestination, isTrue);
    expect(result.message, 'moved');
  });

  testWidgets('a nested item moved out of a shared folder from the root tree '
      'resolves via metadata and classifies on its own parent', (tester) async {
    const sharedFolderId = '00000000-0000-0000-0000-0000000000c3';
    const nestedId = '00000000-0000-0000-0000-0000000000a9';

    // The screen sits at the account root; the dragged item is shown nested
    // under an expanded shared folder, so it is absent from the root listing
    // and must be fetched by metadata.
    final filesClient = _RecordingFilesClient({
      nestedId: {
        'id': nestedId,
        'file_id': sharedFolderId,
        'mime': 'text/plain',
        'encrypted_name': 'enc',
        'is_owner': true,
      },
    });

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesNotifierProvider.overrideWith(
            () => _SeededFilesNotifier(const []),
          ),
          apiClientProvider.overrideWithValue(_FakeApiClient(filesClient)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final mutations = _RecordingMutationController(
      widgetRef.read(_refProvider),
      null,
    );
    final coordinator = FileMoveCoordinator(
      ref: widgetRef,
      dirId: null,
      mutations: mutations,
    );

    final result = await coordinator.dropMove(
      tester.element(find.byType(SizedBox)),
      const [nestedId],
      null,
    )();

    expect(filesClient.metadataIds, contains(nestedId));
    expect(mutations.called, isTrue);
    expect(mutations.sawSources.single.id, nestedId);
    expect(
      mutations.sawSources.single.fileId,
      sharedFolderId,
      reason:
          'the resolved source carries its own parent, so move-out '
          'classification keys on it, not the root the screen is showing',
    );
    expect(result.message, 'moved');
  });
}
