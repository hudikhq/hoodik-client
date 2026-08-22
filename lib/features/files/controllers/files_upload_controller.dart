import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/services/media_picker_channel.dart';
import '../../../core/services/transfer_manager.dart';
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

  /// Live placeholder row for the picker's load phase, when one is up.
  String? _preparingTransferId;

  static const _preparingRowKey = 'picker-selection';

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

    if (MediaPickerChannel.isSupported) {
      return _pickAndUploadMediaNative();
    }

    final result = await _pickFiles(type: FileType.media);
    if (result == null || result.files.isEmpty) return null;

    final paths = _extractPaths(result);
    if (paths.isEmpty) {
      return FilesActionResult.error(ambientL10n.filesCannotReadPath);
    }

    return uploadPaths(paths);
  }

  /// Media picking through the native channel: the sheet closes as soon as
  /// the user confirms, every selected asset gets its own transfer row with
  /// the export's real progress, and each file starts uploading the moment
  /// its bytes land — while later items are still exporting.
  Future<FilesActionResult?> _pickAndUploadMediaNative() async {
    final tm = _ref.read(transferManagerProvider);
    final syncService = _ref.read(syncServiceProvider);
    final rowIds = <int, String>{};
    FilesActionResult? failure;
    var anyPicked = false;

    await for (final event
        in _ref.read(mediaPickerChannelProvider).pickMedia()) {
      switch (event) {
        case MediaPickSelection(:final items):
          anyPicked = items.isNotEmpty;
          for (final item in items) {
            rowIds[item.index] = tm
                .startTransfer(
                  fileName: item.name,
                  type: TransferType.uploadPrepare,
                  totalBytes: 100,
                  totalChunks: 1,
                  fileId: 'pick-${item.index}',
                )
                .id;
          }
        case MediaPickProgress(:final index, :final fraction):
          final id = rowIds[index];
          if (id != null) {
            tm.updateProgress(
              id,
              completedChunks: 0,
              transferredBytes: (fraction * 100).round(),
            );
          }
        case MediaPickReady(:final index, :final path):
          final id = rowIds.remove(index);
          if (id != null) {
            tm.completeTransfer(id);
            tm.dismissTransfer(id);
          }
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
        case MediaPickFailed(:final index, :final message):
          final id = rowIds.remove(index);
          if (id != null) {
            tm.failTransfer(id, message);
          }
          failure = FilesActionResult.error(
            ambientL10n.filesUploadFailed(message),
          );
      }
    }

    if (!anyPicked) return null;
    await _ref.read(filesNotifierProvider(_dirId).notifier).load();
    return failure;
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
  /// [uploadPreparingProvider] and a transfer row, so the wait between
  /// confirming a selection and the paths arriving is visible without
  /// blocking the screen. The `finally` clears both even when the picker
  /// throws, so neither can get stuck.
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

    // The platform picker gives no per-file signal while it materializes
    // the selection, so one placeholder row stands in for all of it. It
    // completes and dismisses in the same breath: a "prepared" entry in
    // the done list would just echo every upload that follows it.
    final tm = _ref.read(transferManagerProvider);
    if (active) {
      _preparingTransferId ??= tm
          .startTransfer(
            fileName: ambientL10n.serviceTransferSelectionName,
            type: TransferType.uploadPrepare,
            totalBytes: 1,
            totalChunks: 1,
            fileId: _preparingRowKey,
          )
          .id;
    } else {
      final id = _preparingTransferId;
      if (id != null) {
        _preparingTransferId = null;
        tm.completeTransfer(id);
        tm.dismissTransfer(id);
      }
    }
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
