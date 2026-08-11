import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/theme/hoodik_type.dart';

/// App-bar entry point for uploads that exhausted their retry budget.
///
/// Before this badge existed the `FailedUploadsPanel` was only reachable
/// through the transfer overlay, which collapses itself when no active
/// transfer is running — meaning a permanently-failed upload could stay
/// invisible until the user happened to start another transfer. The badge
/// surfaces the count persistently so the user can always get back to the
/// failed list from the files screen.
///
/// Tapping asks [transferOverlayRequestProvider] to open the overlay with
/// the failed section scrolled into view. Hidden when the count is 0, so
/// it does not compete for chrome space in the common case.
class FailedUploadsBadge extends ConsumerWidget {
  const FailedUploadsBadge({super.key, this.onTap});

  /// Optional override for the tap handler. Callers generally leave this
  /// null and let the badge drive the overlay; tests inject a spy to
  /// verify the tap wiring without mounting the overlay.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(permanentlyFailedCountProvider);
    final count = countAsync.value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final handler =
        onTap ??
        () {
          ref.read(transferOverlayRequestProvider.notifier).state =
              const TransferOverlayRequest(scrollToFailed: true);
        };

    final tooltip = AppLocalizations.of(
      context,
    ).filesFailedUploadsTooltip(count);

    return IconButton(
      icon: _BadgedIcon(count: count),
      tooltip: tooltip,
      onPressed: handler,
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      isApplePlatform ? CupertinoIcons.exclamationmark_triangle : Icons.report,
      color: context.colors.iconCrimson,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(right: -6, top: -4, child: _CountBubble(count: count)),
      ],
    );
  }
}

class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: context.colors.crimsonFill,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.onFill,
          fontSize: HoodikType.minimumSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
