import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../helpers/file_helpers.dart';
import '../providers/files_notifier.dart';
import 'files_action_result.dart';

/// True while the platform picker is materializing the user's selection —
/// after they confirm it, before the paths are available. On iOS the Photos
/// picker exports every asset to a temp file (videos take seconds; iCloud
/// originals download first) and Android copies picks into app cache. The
/// picker future only completes once every file is ready, so without this
/// signal the app sits idle with no feedback until the upload starts.
final uploadPreparingProvider = StateProvider<bool>((ref) => false);

/// Handlers for every code path that produces a new file on the server.
///
/// Each method returns a [FilesActionResult] the host widget surfaces
/// as a snackbar, or `null` when the user dismissed the picker without
/// choosing anything. Successful uploads are dispatched through
/// [SyncService.uploadFileOrQueue] so offline state gets queued the
/// same way regardless of entry point.
class FilesUploadController {
  final Ref _ref;
  final String? _dirId;

  FilesUploadController(this._ref, this._dirId);

  Future<FilesActionResult?> pickAndUploadFiles() async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailableNoKey);
    }

    final result = await _pickFiles();
    if (result == null || result.files.isEmpty) return null;

    final paths = _extractPaths(result);
    if (paths.isEmpty) {
      return FilesActionResult.error(ambientL10n.filesCannotReadPath);
    }

    return uploadPaths(paths);
  }

  Future<FilesActionResult?> pickAndUploadMedia() async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailableNoKey);
    }

    final result = await _pickFiles(type: FileType.media);
    if (result == null || result.files.isEmpty) return null;

    final paths = _extractPaths(result);
    if (paths.isEmpty) {
      return FilesActionResult.error(ambientL10n.filesCannotReadPath);
    }

    return uploadPaths(paths);
  }

  Future<FilesActionResult?> captureAndUploadPhoto() async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailableNoKey);
    }

    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image == null) return null;

    return uploadPaths([image.path]);
  }

  /// Upload a pre-resolved list of absolute file paths. Used by the
  /// picker flows above and by drag-and-drop from the desktop shell.
  Future<FilesActionResult?> uploadPaths(List<String> paths) async {
    final syncService = _ref.read(syncServiceProvider);
    FilesActionResult? failure;

    for (final path in paths) {
      try {
        await syncService.uploadFileOrQueue(
          localPath: path,
          parentDirId: _dirId,
        );
      } catch (e) {
        failure = FilesActionResult.error(
          ambientL10n.filesUploadFailed(formatErrorMessage(e)),
        );
      }
    }

    await _ref.read(filesNotifierProvider(_dirId).notifier).load();
    return failure;
  }

  /// Picks files while mirroring the picker's load phase into
  /// [uploadPreparingProvider] so the UI can show a "Preparing…" overlay.
  /// The `finally` clears the flag even when the picker throws, so the
  /// overlay can never get stuck.
  Future<FilePickerResult?> _pickFiles({FileType type = FileType.any}) async {
    try {
      return await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: type,
        withData: false,
        withReadStream: false,
        onFileLoading: (status) =>
            _setPreparing(status == FilePickerStatus.picking),
      );
    } finally {
      _setPreparing(false);
    }
  }

  void _setPreparing(bool active) {
    _ref.read(uploadPreparingProvider.notifier).state = active;
  }

  List<String> _extractPaths(FilePickerResult result) {
    return result.files
        .map((f) => f.path)
        .where((p) => p != null)
        .cast<String>()
        .toList();
  }
}

/// Per-directory provider so each directory carries its own parent id.
/// Rebuilt only when the account or dirId changes.
final filesUploadControllerProvider =
    Provider.family<FilesUploadController, String?>((ref, dirId) {
      return FilesUploadController(ref, dirId);
    });
