import 'dart:typed_data';

import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/plaintext_temp.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../helpers/file_helpers.dart';
import '../providers/files_notifier.dart';
import 'files_action_result.dart';

/// Handles the export/download flow. On mobile the file is staged in
/// `hoodik_plaintext/` and handed to the share sheet; on desktop the
/// user picks a destination via [FilePicker.saveFile].
class FilesDownloadController {
  final Ref _ref;
  final String? _dirId;

  FilesDownloadController(this._ref, this._dirId);

  /// Start a download for [file]. Returns `null` if the user cancels a
  /// desktop save-file dialog before the transfer begins.
  ///
  /// On iPad the share sheet must be anchored. Pass [shareOriginRect]
  /// captured from the invoking widget before awaiting any async work,
  /// otherwise the popover throws when the context goes stale.
  /// [key] and [name] let a caller that is not a folder listing — search,
  /// which holds its own decrypted results — export without the file's folder
  /// having been opened. Omitted, both come from the listing as before.
  Future<FilesActionResult?> exportToDisk(
    FileItem file, {
    required Rect shareOriginRect,
    Uint8List? key,
    String? name,
  }) async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }

    final fileKey =
        key ?? _ref.read(filesNotifierProvider(_dirId)).decryptedKeys[file.id];
    if (fileKey == null) {
      return FilesActionResult.error(ambientL10n.filesCannotDecryptKey);
    }

    final fileName =
        name ?? _ref.read(filesNotifierProvider(_dirId)).displayName(file);
    final isMobile = Platform.isIOS || Platform.isAndroid;

    String savePath;
    if (isMobile) {
      savePath = await plaintextTempPath(fileId: file.id, basename: fileName);
    } else {
      final picked = await FilePicker.platform.saveFile(
        dialogTitle: ambientL10n.filesSaveFileDialogTitle,
        fileName: fileName,
      );
      if (picked == null) {
        return null; // user dismissed the save dialog — cancel
      }
      savePath = picked;
    }

    try {
      ops.downloadFileToDisk(
        file,
        fileKey: fileKey,
        outputPath: savePath,
        displayName: fileName,
        onComplete: isMobile
            ? () async {
                final xFile = XFile(savePath, name: fileName);
                await Share.shareXFiles([
                  xFile,
                ], sharePositionOrigin: shareOriginRect);
                try {
                  await File(savePath).delete();
                } catch (_) {}
              }
            : null,
      );
      return FilesActionResult.info(
        isMobile
            ? ambientL10n.filesExportStarted
            : ambientL10n.filesExportingTo(savePath),
      );
    } catch (e) {
      return FilesActionResult.error(
        ambientL10n.filesExportFailed(formatErrorMessage(e)),
      );
    }
  }
}

final filesDownloadControllerProvider =
    Provider.family<FilesDownloadController, String?>((ref, dirId) {
      return FilesDownloadController(ref, dirId);
    });
