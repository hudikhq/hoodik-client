import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/features/files/providers/files_selection.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/features/shares/shared_constants.dart';

FileItem _file(String id, {bool dir = false}) => FileItem(
  id: id,
  encryptedName: 'enc-$id',
  mime: dir ? 'dir' : 'text/plain',
  finishedUploadAt: 1,
);

class _Sel extends FamilyNotifier<FilesState, String?> with FilesSelection {
  @override
  FilesState build(String? arg) => FilesState(
    loading: false,
    files: [
      _file('a'),
      _file('folder', dir: true),
      _file(sharedWithMeDirId, dir: true),
    ],
  );
}

final _selProvider = NotifierProvider.family<_Sel, FilesState, String?>(
  _Sel.new,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  _Sel notifier() => container.read(_selProvider(null).notifier);
  FilesState state() => container.read(_selProvider(null));

  test('selectAll includes files and folders, excludes Shared-with-me', () {
    notifier().selectAll();
    expect(state().selectionMode, isTrue);
    expect(state().selectedIds, {'a', 'folder'});
    expect(state().selectedIds.contains(sharedWithMeDirId), isFalse);
  });

  test('clearSelection empties the set and stays in selection mode', () {
    notifier().selectAll();
    notifier().clearSelection();
    expect(state().selectionMode, isTrue);
    expect(state().selectedIds, isEmpty);
  });

  test('unchecking the last row exits selection mode', () {
    notifier().enterSelectionMode('a');
    expect(state().selectionMode, isTrue);
    notifier().toggleSelection('a');
    expect(state().selectionMode, isFalse);
    expect(state().selectedIds, isEmpty);
  });
}
