import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../controllers/files_fork_controller.dart';
import '../providers/files_notifier.dart';

/// Fork [file] into the caller's own drive and surface the result. Download +
/// re-upload progress is tracked by the controller through `TransferManager`,
/// so this only kicks the flow off, snackbars the outcome, and reloads the
/// listing so a fork landing in the current view (the caller's root) appears.
///
/// Kept out of `FilesScreen` for the same reason as [openShareSurface]: the
/// files screen is at its size ceiling, so each new action entry point lives
/// in a sibling helper rather than growing the god class.
Future<void> openForkSurface(
  BuildContext context,
  WidgetRef ref, {
  required String? dirId,
  required FileItem file,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = ref.read(filesNotifierProvider(dirId)).displayName(file);
  AppNotification.show(
    context,
    message: l10n.filesForkSaving(name),
    type: NotificationType.info,
  );

  final outcome = await ref.read(filesForkControllerProvider(dirId)).fork(file);

  if (!context.mounted) return;

  switch (outcome) {
    case ForkFailure(:final message):
      AppNotification.show(
        context,
        message: message,
        type: NotificationType.error,
      );
    case ForkSuccess():
      AppNotification.show(
        context,
        message: l10n.filesForkSaved(name),
        type: NotificationType.success,
      );
      await ref.read(filesNotifierProvider(dirId).notifier).load();
  }
}
