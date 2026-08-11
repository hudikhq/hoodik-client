import 'package:flutter/material.dart';

import '../../../core/services/transfer_manager.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// A single row in the expanded transfer list.
///
/// Extracted from `transfer_overlay.dart` so the overlay can host the
/// pending-upload retry panel alongside active/completed transfers
/// without pushing the main file further over the size ceiling.
class TransferRow extends StatelessWidget {
  const TransferRow({super.key, required this.item, required this.manager});

  final TransferItem item;
  final TransferManager manager;

  @override
  Widget build(BuildContext context) {
    final accentColor = item.type.isUpload
        ? context.colors.iconEmber
        : context.colors.iconSlate;

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, accentColor, l10n),
          if (item.status == TransferStatus.active)
            ..._buildActiveBody(context, accentColor),
          if (item.status == TransferStatus.completed)
            _buildCompletedFooter(context, l10n),
          if (item.status == TransferStatus.failed)
            _buildFailedFooter(context, l10n),
          if (item.status == TransferStatus.cancelled)
            _buildCancelledFooter(context, l10n),
        ],
      ),
    );
  }

  Row _buildHeader(
    BuildContext context,
    Color accentColor,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        _StatusIcon(item: item),
        const SizedBox(width: 4),
        _WorkerBadge(onWorker: item.onWorker),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.fileName,
            style: TextStyle(
              color: context.colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _TrailingInfo(item: item),
        if (item.status == TransferStatus.active ||
            item.status == TransferStatus.queued)
          IconButton(
            icon: Icon(
              AppIcons.close,
              size: 16,
              color: context.colors.iconMuted,
            ),
            onPressed: () => manager.cancelTransfer(item.id),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: kMinTapTarget,
              minHeight: kMinTapTarget,
            ),
            tooltip: l10n.commonCancel,
          ),
      ],
    );
  }

  List<Widget> _buildActiveBody(BuildContext context, Color accentColor) {
    return [
      const SizedBox(height: 6),
      Row(
        children: [
          Text(
            '${item.type.label} ${(item.progress * 100).toInt()}%',
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item.type.isNetworkTransfer && item.speedString.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              item.speedString,
              style: TextStyle(color: context.colors.textMuted, fontSize: 11),
            ),
          ],
          if (item.type.isNetworkTransfer && item.etaString.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              item.etaString,
              style: TextStyle(color: context.colors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 4,
                backgroundColor: context.colors.seam,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(item.progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Text(
            item.sizeProgressString,
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ];
  }

  Widget _buildCompletedFooter(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Text(
            l10n.filesTransferDoneSize(
              TransferItem.formatBytes(item.totalBytes),
            ),
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedFooter(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Expanded(
            child: Text(
              item.errorMessage ?? l10n.filesUnknownError,
              style: TextStyle(color: context.colors.textCrimson, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledFooter(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Text(
            l10n.filesCancelled,
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

IconData transferTypeIcon(TransferType type) {
  return switch (type) {
    TransferType.uploadEncrypt => AppIcons.locked,
    TransferType.uploadHttp => AppIcons.sortAscending,
    TransferType.downloadHttp => AppIcons.sortDescending,
    TransferType.downloadDecrypt => AppIcons.unlocked,
  };
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.item});
  final TransferItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case TransferStatus.active:
      case TransferStatus.queued:
        final color = item.type.isUpload
            ? context.colors.iconEmber
            : context.colors.iconSlate;
        return Icon(transferTypeIcon(item.type), color: color, size: 18);
      case TransferStatus.completed:
        return Icon(AppIcons.success, color: context.colors.textSage, size: 18);
      case TransferStatus.failed:
        return Icon(Icons.error, color: context.colors.iconCrimson, size: 18);
      case TransferStatus.cancelled:
        return Icon(
          Icons.cancel_outlined,
          color: context.colors.iconMuted,
          size: 18,
        );
    }
  }
}

class _WorkerBadge extends StatelessWidget {
  const _WorkerBadge({required this.onWorker});
  final bool onWorker;

  @override
  Widget build(BuildContext context) {
    final label = onWorker ? 'W' : 'M';
    final color = onWorker ? context.colors.textSage : context.colors.iconEmber;

    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _TrailingInfo extends StatelessWidget {
  const _TrailingInfo({required this.item});
  final TransferItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case TransferStatus.active:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.speedString.isNotEmpty)
              Text(
                item.speedString,
                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
              ),
            if (item.etaString.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                item.etaString,
                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
              ),
            ],
          ],
        );
      case TransferStatus.completed:
      case TransferStatus.failed:
      case TransferStatus.cancelled:
        return const SizedBox.shrink();
      case TransferStatus.queued:
        return Text(
          AppLocalizations.of(context).filesQueued,
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        );
    }
  }
}
