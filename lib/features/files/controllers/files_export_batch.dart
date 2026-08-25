import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/file_operations.dart';
import '../../../core/services/plaintext_temp.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../helpers/selection_batch.dart';
import '../providers/files_notifier.dart';
import '../widgets/file_dialogs.dart';
import 'files_action_result.dart';
import 'files_download_controller.dart';

/// Bulk export for the selection bar. Single-file export stays on
/// [FilesDownloadController] so search can keep passing its own key/name.
class FilesExportBatch {
  final Ref _ref;
  final String? _dirId;

  FilesExportBatch(this._ref, this._dirId);

  Future<FilesActionResult?> exportSelected({
    required BuildContext context,
    required Rect shareOriginRect,
  }) async {
    final state = _ref.read(filesNotifierProvider(_dirId));
    final batch = SelectionBatch.resolve(
      state.files ?? const [],
      state.selectedIds,
    );
    final l10n = AppLocalizations.of(context);

    if (batch.isEmpty) {
      if (batch.folderCount > 0) {
        return FilesActionResult.info(
          l10n.filesBulkFoldersSkipped(batch.folderCount),
        );
      }
      return FilesActionResult.info(l10n.filesExportedNone);
    }

    if (batch.needsConfirm) {
      final ok = await confirmBulkExport(
        context: context,
        fileCount: batch.files.length,
        folderCount: batch.folderCount,
        isLarge: batch.isLarge,
      );
      if (ok != true) return null;
    } else if (batch.folderCount > 0) {
      // n = 1: no dialog, but still say why folders did not come along.
    }

    if (batch.files.length == 1) {
      final result = await _ref
          .read(filesDownloadControllerProvider(_dirId))
          .exportToDisk(batch.files.first, shareOriginRect: shareOriginRect);
      if (result == null) return null;
      if (batch.folderCount > 0 && result.message.isNotEmpty) {
        return FilesActionResult.info(
          '${result.message} ${l10n.filesBulkFoldersSkipped(batch.folderCount)}',
        );
      }
      return result;
    }

    if (!context.mounted) return null;
    return _exportMany(
      context: context,
      batch: batch,
      shareOriginRect: shareOriginRect,
      names: {for (final f in batch.files) f.id: state.displayName(f)},
      keys: state.decryptedKeys,
    );
  }

  Future<FilesActionResult?> _exportMany({
    required BuildContext context,
    required SelectionBatch batch,
    required Rect shareOriginRect,
    required Map<String, String> names,
    required Map<String, Uint8List> keys,
  }) async {
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }

    final isMobile = Platform.isIOS || Platform.isAndroid;
    String? destDir;
    if (!isMobile) {
      destDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: ambientL10n.filesSaveFileDialogTitle,
      );
      if (destDir == null) return null;
    }

    final outcomes = await Future.wait([
      for (final file in batch.files)
        _one(
          ops: ops,
          file: file,
          fileKey: keys[file.id],
          displayName: names[file.id] ?? file.id,
          destDir: destDir,
        ),
    ]);

    final successes = [
      for (final o in outcomes)
        if (o.path != null) o,
    ];
    final l10n = ambientL10n;

    if (successes.isEmpty) {
      return FilesActionResult.error(l10n.filesExportedNone);
    }

    if (isMobile) {
      await Share.shareXFiles([
        for (final o in successes) XFile(o.path!, name: o.name),
      ], sharePositionOrigin: shareOriginRect);
      for (final o in successes) {
        try {
          await File(o.path!).delete();
        } catch (_) {}
      }
    }

    await _ref
        .read(filesNotifierProvider(_dirId).notifier)
        .refreshOfflineFileIds();

    if (successes.length == batch.files.length) {
      return FilesActionResult.success(l10n.filesExportStarted);
    }
    return FilesActionResult.info(
      l10n.filesExportedPartial(successes.length, batch.files.length),
    );
  }

  Future<_ExportOutcome> _one({
    required FileOperations ops,
    required FileItem file,
    required Uint8List? fileKey,
    required String displayName,
    String? destDir,
  }) async {
    if (fileKey == null) return _ExportOutcome.failed;
    final savePath = destDir == null
        ? await plaintextTempPath(fileId: file.id, basename: displayName)
        : _uniqueDest(destDir, displayName, file.id);
    final done = Completer<_ExportOutcome>();
    ops.downloadFileToDisk(
      file,
      fileKey: fileKey,
      outputPath: savePath,
      displayName: displayName,
      onComplete: () async {
        if (!done.isCompleted) {
          done.complete(_ExportOutcome(path: savePath, name: displayName));
        }
      },
      onError: (_) {
        if (!done.isCompleted) done.complete(_ExportOutcome.failed);
      },
    );
    return done.future;
  }

  String _uniqueDest(String dir, String name, String fileId) {
    final dest = p.join(dir, name);
    if (!File(dest).existsSync()) return dest;
    final ext = p.extension(name);
    final stem = p.basenameWithoutExtension(name);
    return p.join(dir, '${stem}_$fileId$ext');
  }
}

class _ExportOutcome {
  final String? path;
  final String name;

  const _ExportOutcome({this.path, this.name = ''});
  static const failed = _ExportOutcome();
}

final filesExportBatchProvider = Provider.family<FilesExportBatch, String?>((
  ref,
  dirId,
) {
  return FilesExportBatch(ref, dirId);
});
