import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Persistent tree state for the notes sidebar.
///
/// Lives in a Riverpod notifier (not in widget [State]) so the user's
/// expansion, selected-folder marker, decrypted names, and per-file
/// keys survive drawer open/close cycles and parent widget rebuilds.
/// Without this, every `Scaffold` drawer reshuffle was wiping the
/// expanded set and forcing a fresh fetch.
///
/// Session-scoped: decrypted names/keys are intentionally never written
/// to disk. The Drift cache on [SyncService.fetchFiles] already holds
/// encrypted server responses for offline restart; we re-decrypt on
/// the fly after unlock. That keeps the plaintext tree strictly in
/// memory, which matches the app's E2E posture.
class NotesSidebarState {
  final Map<String?, List<FileItem>> children;
  final Set<String> expanded;
  final Map<String, String> names;
  final Map<String, Uint8List> keys;
  final String? selectedFolderId;

  const NotesSidebarState({
    required this.children,
    required this.expanded,
    required this.names,
    required this.keys,
    required this.selectedFolderId,
  });

  const NotesSidebarState.empty()
    : this(
        children: const {},
        expanded: const {},
        names: const {},
        keys: const {},
        selectedFolderId: null,
      );

  bool get hasRootCache => children.containsKey(null);

  NotesSidebarState _copyWith({
    Map<String?, List<FileItem>>? children,
    Set<String>? expanded,
    Map<String, String>? names,
    Map<String, Uint8List>? keys,
    String? Function()? selectedFolderId,
  }) {
    return NotesSidebarState(
      children: children ?? this.children,
      expanded: expanded ?? this.expanded,
      names: names ?? this.names,
      keys: keys ?? this.keys,
      selectedFolderId: selectedFolderId != null
          ? selectedFolderId()
          : this.selectedFolderId,
    );
  }
}

class NotesSidebarNotifier extends Notifier<NotesSidebarState> {
  @override
  NotesSidebarState build() => const NotesSidebarState.empty();

  /// Replace the cached children for [dirId] with [files]. Safe to call
  /// repeatedly — used both on first fetch and on silent background
  /// refresh.
  void setChildren(String? dirId, List<FileItem> files) {
    state = state._copyWith(children: {...state.children, dirId: files});
  }

  /// Record the decrypted display name + symmetric key for a single file.
  void setDecrypted(String fileId, String name, Uint8List key) {
    state = state._copyWith(
      names: {...state.names, fileId: name},
      keys: {...state.keys, fileId: key},
    );
  }

  /// Set the display name alone (for failure fallbacks like "(encrypted)").
  void setName(String fileId, String name) {
    state = state._copyWith(names: {...state.names, fileId: name});
  }

  /// Flip a folder's expansion flag.
  void setExpanded(String dirId, bool expanded) {
    final next = Set<String>.from(state.expanded);
    if (expanded) {
      next.add(dirId);
    } else {
      next.remove(dirId);
    }
    state = state._copyWith(expanded: next);
  }

  /// The folder that new notes/folders are created into. `null` = root.
  void selectFolder(String? dirId) {
    state = state._copyWith(selectedFolderId: () => dirId);
  }

  /// Drop a directory's cached children so the next expand triggers a
  /// fresh fetch (used after create/rename/delete mutates it).
  void invalidateDir(String? dirId) {
    final next = Map<String?, List<FileItem>>.from(state.children)
      ..remove(dirId);
    state = state._copyWith(children: next);
  }

  /// Recursively drop a folder and every known descendant — called
  /// after a cascade-delete so stale branches don't linger in the tree.
  void removeSubtree(String folderId) {
    final nextChildren = Map<String?, List<FileItem>>.from(state.children);
    final nextNames = Map<String, String>.from(state.names);
    final nextKeys = Map<String, Uint8List>.from(state.keys);
    final nextExpanded = Set<String>.from(state.expanded);

    void walk(String id) {
      final kids = nextChildren.remove(id);
      nextExpanded.remove(id);
      if (kids == null) return;
      for (final c in kids) {
        nextNames.remove(c.id);
        nextKeys.remove(c.id);
        if (c.isDir) walk(c.id);
      }
    }

    walk(folderId);

    state = state._copyWith(
      children: nextChildren,
      names: nextNames,
      keys: nextKeys,
      expanded: nextExpanded,
      selectedFolderId: state.selectedFolderId == folderId ? () => null : null,
    );
  }

  /// Forget a single file's decrypted metadata (used on delete).
  void forgetFile(String fileId) {
    state = state._copyWith(
      names: {...state.names}..remove(fileId),
      keys: {...state.keys}..remove(fileId),
    );
  }

  /// Bulk-seed names/keys the host already knows (e.g. from the
  /// PreviewContext set by the files screen before opening an editor).
  /// Existing entries are preserved.
  void seed({
    required Map<String, String> names,
    required Map<String, Uint8List> keys,
  }) {
    if (names.isEmpty && keys.isEmpty) return;
    final nextNames = {...state.names, ...names};
    final nextKeys = {...state.keys, ...keys};
    state = state._copyWith(names: nextNames, keys: nextKeys);
  }

  /// Wipe everything — used on logout or account switch so a new
  /// account doesn't inherit the previous user's decrypted tree.
  void clear() {
    state = const NotesSidebarState.empty();
  }
}

final notesSidebarStateProvider =
    NotifierProvider<NotesSidebarNotifier, NotesSidebarState>(
      NotesSidebarNotifier.new,
    );
