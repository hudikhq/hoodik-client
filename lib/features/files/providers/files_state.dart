import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../shares/shared_constants.dart';
import '../widgets/file_sort_controls.dart';

/// Immutable snapshot of the files screen state for a given directory.
///
/// A new instance is emitted for every mutation; fields that hold
/// collections are copied shallowly so previous snapshots remain
/// valid references.
class FilesState {
  final List<FileItem>? files;
  final Map<String, String> decryptedNames;
  final Map<String, Uint8List> decryptedKeys;
  final Map<String, Uint8List?> decryptedThumbnails;
  final Set<String> offlineFileIds;
  final bool isFromCache;
  final bool loading;
  final String? error;
  final bool selectionMode;
  final Set<String> selectedIds;
  final SortField sortField;
  final SortOrder sortOrder;
  final String? loadedAccountId;

  const FilesState({
    this.files,
    this.decryptedNames = const {},
    this.decryptedKeys = const {},
    this.decryptedThumbnails = const {},
    this.offlineFileIds = const {},
    this.isFromCache = false,
    this.loading = true,
    this.error,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.sortField = SortField.name,
    this.sortOrder = SortOrder.asc,
    this.loadedAccountId,
  });

  FilesState copyWith({
    List<FileItem>? files,
    bool clearFiles = false,
    Map<String, String>? decryptedNames,
    Map<String, Uint8List>? decryptedKeys,
    Map<String, Uint8List?>? decryptedThumbnails,
    Set<String>? offlineFileIds,
    bool? isFromCache,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? selectionMode,
    Set<String>? selectedIds,
    SortField? sortField,
    SortOrder? sortOrder,
    String? loadedAccountId,
    bool clearLoadedAccountId = false,
  }) {
    return FilesState(
      files: clearFiles ? null : (files ?? this.files),
      decryptedNames: decryptedNames ?? this.decryptedNames,
      decryptedKeys: decryptedKeys ?? this.decryptedKeys,
      decryptedThumbnails: decryptedThumbnails ?? this.decryptedThumbnails,
      offlineFileIds: offlineFileIds ?? this.offlineFileIds,
      isFromCache: isFromCache ?? this.isFromCache,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      selectionMode: selectionMode ?? this.selectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
      loadedAccountId: clearLoadedAccountId
          ? null
          : (loadedAccountId ?? this.loadedAccountId),
    );
  }

  /// Display name for a file, falling back to a placeholder when the
  /// encrypted name has not yet been decrypted.
  String displayName(FileItem file) {
    if (file.id == sharedWithMeDirId) return sharedWithMeDirName;
    return decryptedNames[file.id] ??
        (file.encryptedName.isNotEmpty
            ? ambientL10n.filesEncryptedPlaceholder(file.id.substring(0, 8))
            : ambientL10n.commonUnknown);
  }
}
