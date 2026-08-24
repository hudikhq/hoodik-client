import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../helpers/file_helpers.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Show a text input dialog and return the entered value, or null if cancelled.
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  required String hint,
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.colors.textMuted),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(AppLocalizations.of(ctx).commonOk),
          ),
        ],
      );
    },
  );
}

/// Show a confirmation dialog with Cancel/Delete buttons.
Future<bool?> showConfirmDeleteDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showAdaptiveAlert<bool>(
    context: context,
    title: title,
    content: message,
    actions: [
      AdaptiveDialogAction(label: l10n.commonCancel, value: false),
      AdaptiveDialogAction(
        label: l10n.commonDelete,
        value: true,
        isDestructive: true,
      ),
    ],
  );
  if (confirmed == true) unawaited(HapticFeedback.mediumImpact());
  return confirmed;
}

/// Confirm a recipient self-removing from a share. Returns true when the user
/// chooses to leave. The body carries the E2E disclaimer (mirrored from the
/// web `RevokeConfirmModal` self-remove copy): leaving only blocks future
/// reads — anything already downloaded stays on the device because end-to-end
/// encryption can't recall plaintext after it's been decrypted.
Future<bool> confirmLeaveShare({
  required BuildContext context,
  required String displayName,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showAdaptiveAlert<bool>(
    context: context,
    title: l10n.filesLeaveShareTitle,
    content: l10n.filesLeaveShareBody(displayName),
    actions: [
      AdaptiveDialogAction(label: l10n.commonCancel, value: false),
      AdaptiveDialogAction(
        label: l10n.filesLeave,
        value: true,
        isDestructive: true,
      ),
    ],
  );
  return result ?? false;
}

Future<bool> confirmBulkExport({
  required BuildContext context,
  required int fileCount,
  required int folderCount,
  required bool isLarge,
}) {
  final l10n = AppLocalizations.of(context);
  return _confirmBulk(
    context: context,
    title: l10n.filesExportBulkTitle(fileCount),
    body: _bulkBody(
      l10n.filesExportBulkBody,
      folderCount: folderCount,
      isLarge: isLarge,
      large: l10n.filesBulkLargeExport,
      foldersSkipped: l10n.filesBulkFoldersSkipped,
    ),
    confirmLabel: l10n.filesExport,
  );
}

Future<bool> confirmBulkOffline({
  required BuildContext context,
  required int fileCount,
  required int folderCount,
  required bool isLarge,
}) {
  final l10n = AppLocalizations.of(context);
  return _confirmBulk(
    context: context,
    title: l10n.filesOfflineBulkTitle(fileCount),
    body: _bulkBody(
      l10n.filesOfflineBulkBody,
      folderCount: folderCount,
      isLarge: isLarge,
      large: l10n.filesBulkLargeDownload,
      foldersSkipped: l10n.filesBulkFoldersSkipped,
    ),
    confirmLabel: l10n.commonDownload,
  );
}

String _bulkBody(
  String lead, {
  required int folderCount,
  required bool isLarge,
  required String large,
  required String Function(int count) foldersSkipped,
}) {
  final parts = <String>[lead];
  if (folderCount > 0) parts.add(foldersSkipped(folderCount));
  if (isLarge) parts.add(large);
  return parts.join('\n\n');
}

Future<bool> _confirmBulk({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showAdaptiveAlert<bool>(
    context: context,
    title: title,
    content: body,
    actions: [
      AdaptiveDialogAction(label: l10n.commonCancel, value: false),
      AdaptiveDialogAction(label: confirmLabel, value: true),
    ],
  );
  return result ?? false;
}

/// Show file detail information in a dialog.
void showFileDetailsDialog({
  required BuildContext context,
  required FileItem file,
  required String displayName,
}) {
  showDialog(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return AlertDialog(
        title: Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(ctx, l10n.filesTypeLabel, file.mime),
            _detailRow(ctx, l10n.filesSizeLabel, formatFileSize(file.size)),
            _detailRow(
              ctx,
              l10n.filesChunksLabel,
              '${file.chunksStored ?? 0}/${file.chunks ?? 0}',
            ),
            _detailRow(ctx, l10n.filesCipherLabel, file.cipher),
            _detailRow(
              ctx,
              l10n.filesCreatedLabel,
              formatFileDate(file.createdAt),
            ),
            _detailRow(ctx, l10n.filesIdLabel, file.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      );
    },
  );
}

/// Show a dialog with the newly created link URL and copy/share actions.
void showLinkCreatedDialog({
  required BuildContext context,
  required String fileName,
  required String linkUrl,
  required void Function(String message) onSnack,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(ctx).filesLinkCreatedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.colors.text,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.seam, width: 0.5),
            ),
            child: Text(
              linkUrl,
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(ctx).commonClose),
        ),
        TextButton(
          onPressed: () {
            Share.share(linkUrl);
          },
          child: Text(AppLocalizations.of(ctx).commonShare),
        ),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: linkUrl));
            Navigator.pop(ctx);
            onSnack(AppLocalizations.of(ctx).filesLinkCopied);
          },
          child: Text(AppLocalizations.of(ctx).filesCopyLink),
        ),
      ],
    ),
  );
}

Widget _detailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
