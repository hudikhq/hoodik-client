import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../controllers/files_share_controller.dart';
import '../helpers/files_preview_navigation.dart';
import '../providers/files_notifier.dart';
import '../widgets/file_actions_sheet.dart';
import '../widgets/file_dialogs.dart';
import '../widgets/file_menu_actions_builder.dart';

export '../../preview/providers/preview_providers.dart' show isPreviewable;

/// Preview a listing row, refusing files whose upload has not finished.
///
/// An in-progress upload has a DB entry but no chunks yet. Opening it
/// fires a tar download the server cannot fulfil. Non-markdown files are
/// already filtered by [isPreviewable]; the markdown path bypasses that
/// and needs the same guard.
void openFilesPreview({
  required BuildContext context,
  required WidgetRef ref,
  required String? dirId,
  required FileItem file,
  required void Function(String message, NotificationType type) onSnack,
}) {
  if (file.isUploading) {
    onSnack(
      AppLocalizations.of(context).filesStillUploading,
      NotificationType.info,
    );
    return;
  }

  final state = ref.read(filesNotifierProvider(dirId));
  final siblings = state.files ?? const <FileItem>[];
  if (isMarkdownFile(file, displayName: state.displayName(file))) {
    openEditor(
      context: context,
      ref: ref,
      file: file,
      siblings: siblings,
      names: state.decryptedNames,
      keys: state.decryptedKeys,
      parentDirId: dirId,
    );
    return;
  }
  openPreview(
    context: context,
    ref: ref,
    file: file,
    siblings: siblings,
    names: state.decryptedNames,
    keys: state.decryptedKeys,
    parentDirId: dirId,
  );
}

Future<void> leaveSharedFile({
  required BuildContext context,
  required WidgetRef ref,
  required String? dirId,
  required FileItem file,
  required Future<void> Function() onLeft,
}) async {
  final confirmed = await confirmLeaveShare(
    context: context,
    displayName: ref.read(filesNotifierProvider(dirId)).displayName(file),
  );
  if (!confirmed || !context.mounted) return;
  final outcome = await ref
      .read(filesShareControllerProvider(dirId))
      .leaveShare(file);
  if (!context.mounted) return;
  if (outcome is ShareFailure) {
    AppNotification.show(
      context,
      message: outcome.message,
      type: NotificationType.error,
    );
  } else {
    await onLeft();
  }
}

void showFilesRowMenu({
  required BuildContext context,
  required WidgetRef ref,
  required String? dirId,
  required FileItem file,
  required FileMenuCallbacks callbacks,
  required bool sharingEnabled,
  Offset? anchor,
}) {
  final state = ref.read(filesNotifierProvider(dirId));
  showFileActionsSheet(
    context: context,
    file: file,
    displayName: state.displayName(file),
    isOffline: state.offlineFileIds.contains(file.id),
    callbacks: callbacks,
    sharingEnabled: sharingEnabled,
    anchor: anchor,
  );
}
