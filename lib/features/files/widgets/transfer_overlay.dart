import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'failed_uploads_panel.dart';
import 'transfer_row.dart';

/// An inline transfer-progress widget placed between content and bottom nav.
///
/// - Collapsed: compact bar with current transfer info
/// - Expanded: scrollable list of all transfers
/// - Dismissed: a small right-aligned pill shows active count — tap to restore
/// - Transfers continue in the background regardless of widget state
class TransferOverlay extends ConsumerStatefulWidget {
  const TransferOverlay({super.key});

  @override
  ConsumerState<TransferOverlay> createState() => _TransferOverlayState();
}

class _TransferOverlayState extends ConsumerState<TransferOverlay> {
  bool _expanded = false;
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(transferManagerProvider);
    final transfers = manager.transfers;
    final failedCount = ref.watch(permanentlyFailedCountProvider).value ?? 0;

    // External open-request (e.g. the failed-uploads badge). Consume and
    // reset so repeat taps still fire — the provider is a one-shot channel.
    ref.listen<TransferOverlayRequest?>(transferOverlayRequestProvider, (
      _,
      next,
    ) {
      if (next == null) return;
      setState(() {
        _dismissed = false;
        _expanded = true;
      });
      Future.microtask(() {
        if (!mounted) return;
        ref.read(transferOverlayRequestProvider.notifier).state = null;
      });
    });

    if (transfers.isEmpty) {
      // Reset dismissed state when all transfers are cleared.
      _dismissed = false;
      if (failedCount == 0) return const SizedBox.shrink();
      return _buildShell(child: _buildFailedOnly());
    }

    final activeCount = transfers
        .where((t) => t.status == TransferStatus.active)
        .length;

    // When dismissed, show a small pill that can restore the overlay.
    if (_dismissed) {
      if (activeCount == 0) {
        // No active transfers and dismissed — hide completely.
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Align(
          alignment: Alignment.centerRight,
          child: _buildMiniBadge(activeCount),
        ),
      );
    }

    return _buildShell(
      dismissible: true,
      child: _expanded
          ? _buildExpanded(manager, transfers)
          : _buildCollapsed(transfers),
    );
  }

  Widget _buildShell({required Widget child, bool dismissible = false}) {
    final card = AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: HoodikColors.brownish800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HoodikColors.brownish600, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Material(
        color: Colors.transparent,
        child: dismissible ? _buildDismissible(child: card) : card,
      ),
    );
  }

  /// No active/completed transfers are tracked, but failed uploads remain.
  /// Render just the `FailedUploadsPanel` so the user can retry or discard
  /// without waiting for another transfer to happen first.
  Widget _buildFailedOnly() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: FailedUploadsPanel(),
    );
  }

  Widget _buildDismissible({required Widget child}) {
    return Dismissible(
      key: const ValueKey('transfer_overlay'),
      direction: DismissDirection.down,
      onDismissed: (_) => setState(() => _dismissed = true),
      background: const SizedBox.shrink(),
      child: child,
    );
  }

  Widget _buildMiniBadge(int activeCount) {
    return GestureDetector(
      onTap: () => setState(() {
        _dismissed = false;
        _expanded = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: HoodikColors.brownish800,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HoodikColors.brownish600, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation(
                  HoodikColors.orangy500,
                ),
                backgroundColor: HoodikColors.brownish600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).filesTransfersCount(activeCount),
              style: const TextStyle(
                color: HoodikColors.dirtyWhite,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsed(List<TransferItem> transfers) {
    final active = transfers
        .where((t) => t.status == TransferStatus.active)
        .toList();
    final display = active.isNotEmpty ? active.first : transfers.first;

    final isUpload = display.type.isUpload;
    final accentColor = isUpload
        ? HoodikColors.orangy500
        : HoodikColors.blueish400;
    final icon = transferTypeIcon(display.type);
    final statusText = _collapsedStatusText(display, transfers);
    final percentage = (display.progress * 100).toStringAsFixed(0);
    final showSpeed = display.type.isNetworkTransfer;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: HoodikColors.dirtyWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (display.status == TransferStatus.active) ...[
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showSpeed && display.speedString.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      display.speedString,
                      style: const TextStyle(
                        color: HoodikColors.brownish100,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
                if (display.status == TransferStatus.completed)
                  const Icon(
                    Icons.check_circle,
                    color: HoodikColors.greeny300,
                    size: 18,
                  ),
                if (display.status == TransferStatus.failed)
                  const Icon(
                    Icons.error,
                    color: HoodikColors.redish400,
                    size: 18,
                  ),
                if (display.status == TransferStatus.cancelled)
                  const Icon(
                    Icons.cancel_outlined,
                    color: HoodikColors.brownish100,
                    size: 18,
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_up,
                  color: HoodikColors.brownish300,
                  size: 18,
                ),
              ],
            ),
            if (display.status == TransferStatus.active) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: display.progress,
                  minHeight: 4,
                  backgroundColor: HoodikColors.brownish600,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _collapsedStatusText(
    TransferItem display,
    List<TransferItem> allTransfers,
  ) {
    final l10n = AppLocalizations.of(context);
    final activeCount = allTransfers
        .where((t) => t.status == TransferStatus.active)
        .length;

    switch (display.status) {
      case TransferStatus.active:
        final verb = display.type.label;
        if (activeCount > 1) {
          return l10n.filesTransferActiveMore(
            verb,
            display.fileName,
            activeCount - 1,
          );
        }
        return l10n.filesTransferActive(verb, display.fileName);
      case TransferStatus.completed:
        return l10n.filesTransferDone(display.fileName);
      case TransferStatus.failed:
        return l10n.filesTransferFailed(display.fileName);
      case TransferStatus.cancelled:
        return l10n.filesTransferCancelled(display.fileName);
      case TransferStatus.queued:
        return l10n.filesTransferQueued(display.fileName);
    }
  }

  Widget _buildExpanded(TransferManager manager, List<TransferItem> transfers) {
    final hasCompletedOrFailed = transfers.any(
      (t) =>
          t.status == TransferStatus.completed ||
          t.status == TransferStatus.failed ||
          t.status == TransferStatus.cancelled,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).filesTransfersTitle,
                    style: const TextStyle(
                      color: HoodikColors.dirtyWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasCompletedOrFailed)
                  TextButton(
                    onPressed: () => manager.clearCompleted(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      AppLocalizations.of(context).filesClear,
                      style: const TextStyle(
                        color: HoodikColors.brownish100,
                        fontSize: 13,
                      ),
                    ),
                  ),
                // Minimize button
                IconButton(
                  tooltip: AppLocalizations.of(
                    context,
                  ).filesTransfersMinimizeTooltip,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: HoodikColors.brownish300,
                  ),
                  onPressed: () => setState(() => _expanded = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                // Dismiss button
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: HoodikColors.brownish300,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _dismissed = true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: AppLocalizations.of(
                    context,
                  ).filesTransfersDismissTooltip,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: HoodikColors.brownish600),
          const FailedUploadsPanel(),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: transfers.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: HoodikColors.brownish600,
              ),
              itemBuilder: (context, index) =>
                  TransferRow(item: transfers[index], manager: manager),
            ),
          ),
        ],
      ),
    );
  }
}
