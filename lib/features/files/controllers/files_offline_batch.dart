import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../helpers/selection_batch.dart';
import '../providers/files_notifier.dart';
import '../widgets/file_dialogs.dart';
import 'files_action_result.dart';

/// Bulk "make available offline" for the selection bar.
class FilesOfflineBatch {
  final Ref _ref;
  final String? _dirId;

  FilesOfflineBatch(this._ref, this._dirId);

  Future<FilesActionResult?> makeAvailableOfflineSelected({
    required BuildContext context,
    required void Function(FilesActionResult result) onComplete,
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
      return FilesActionResult.info(l10n.filesOfflineNone);
    }

    if (batch.needsConfirm) {
      final ok = await confirmBulkOffline(
        context: context,
        fileCount: batch.files.length,
        folderCount: batch.folderCount,
        isLarge: batch.isLarge,
      );
      if (ok != true) return null;
    }

    final account = _ref.read(activeAccountProvider);
    if (account == null) return null;
    final offlineManager = _ref.read(offlineManagerProvider);
    final ops = _ref.read(fileOperationsProvider);
    if (ops == null) {
      return FilesActionResult.error(ambientL10n.filesOpsUnavailable);
    }

    final toDownload = <FileItem>[];
    var already = 0;
    for (final file in batch.files) {
      final pinned = await offlineManager.pinFile(account.id, file.id);
      if (pinned) {
        already++;
      } else {
        toDownload.add(file);
      }
    }
    await _ref
        .read(filesNotifierProvider(_dirId).notifier)
        .refreshOfflineFileIds();

    if (toDownload.isEmpty) {
      return FilesActionResult.success(
        l10n.filesAvailableOfflineCount(already),
      );
    }

    unawaited(() async {
      var downloaded = 0;
      var failed = 0;
      await Future.wait(
        toDownload.map((file) {
          final done = Completer<void>();
          ops.downloadAndPinOffline(
            file,
            displayName: state.displayName(file),
            onComplete: () {
              downloaded++;
              done.complete();
            },
            onError: (_) {
              failed++;
              done.complete();
            },
          );
          return done.future;
        }),
      );

      await _ref
          .read(filesNotifierProvider(_dirId).notifier)
          .refreshOfflineFileIds();

      final ok = already + downloaded;
      final total = batch.files.length;
      if (failed == 0) {
        onComplete(
          FilesActionResult.success(l10n.filesAvailableOfflineCount(ok)),
        );
      } else {
        onComplete(
          FilesActionResult.info(l10n.filesAvailableOfflinePartial(ok, total)),
        );
      }
    }());

    return FilesActionResult.info(l10n.filesDownloadingForOffline);
  }
}

final filesOfflineBatchProvider = Provider.family<FilesOfflineBatch, String?>((
  ref,
  dirId,
) {
  return FilesOfflineBatch(ref, dirId);
});
