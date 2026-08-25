import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../shares/shared_constants.dart';
import 'files_state.dart';

/// Selection-bar mutations for a [FilesNotifier].
///
/// Lives here so [FilesNotifier] can stay focused on listing/decrypt, and
/// so select-all / clear can be added without growing that file.
mixin FilesSelection on FamilyNotifier<FilesState, String?> {
  /// Rows the selection bar's actions can't touch never enter the set. The
  /// guard lives here rather than only in the checkbox so a second entry
  /// point (select-all, a keyboard shortcut) can't put one back in.
  bool _selectable(String fileId) {
    final file = state.files?.where((f) => f.id == fileId).firstOrNull;
    return file == null || canSelectFile(file);
  }

  void enterSelectionMode(String fileId) {
    state = state.copyWith(
      selectionMode: true,
      selectedIds: _selectable(fileId)
          ? {...state.selectedIds, fileId}
          : state.selectedIds,
    );
  }

  void exitSelectionMode() {
    state = state.copyWith(selectionMode: false, selectedIds: {});
  }

  void toggleSelection(String fileId) {
    if (!_selectable(fileId)) return;
    final next = {...state.selectedIds};
    if (next.contains(fileId)) {
      next.remove(fileId);
    } else {
      next.add(fileId);
    }
    state = state.copyWith(
      selectedIds: next,
      selectionMode: next.isEmpty ? false : state.selectionMode,
    );
  }

  void enterEmptySelectionMode() {
    state = state.copyWith(selectionMode: true);
  }

  void selectAll() {
    final ids = {
      for (final file in state.files ?? const <FileItem>[])
        if (_selectable(file.id)) file.id,
    };
    state = state.copyWith(selectionMode: true, selectedIds: ids);
  }

  /// Empty the set without leaving selection mode. Close (X) is what exits.
  void clearSelection() {
    state = state.copyWith(selectionMode: true, selectedIds: {});
  }

  void toggleSelectAllOrClear() {
    final selectable = [
      for (final file in state.files ?? const <FileItem>[])
        if (_selectable(file.id)) file.id,
    ];
    if (selectable.isEmpty) return;
    if (state.selectedIds.length >= selectable.length) {
      clearSelection();
    } else {
      selectAll();
    }
  }
}
