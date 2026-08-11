import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/providers.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/storage/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Panel listing uploads that exhausted their retry budget so the user
/// can either retry or discard them.
///
/// Renders as an empty widget when there's nothing to surface, so the
/// caller can unconditionally embed it and let the panel handle visibility.
class FailedUploadsPanel extends ConsumerStatefulWidget {
  const FailedUploadsPanel({super.key});

  @override
  ConsumerState<FailedUploadsPanel> createState() => _FailedUploadsPanelState();
}

class _FailedUploadsPanelState extends ConsumerState<FailedUploadsPanel> {
  List<PendingUpload> _failed = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    final sync = ref.read(syncServiceProvider);
    final failed = await sync.permanentlyFailedUploads();
    if (!mounted) return;
    setState(() => _failed = failed);
  }

  Future<void> _retry(SyncService sync, PendingUpload upload) async {
    await sync.retryPermanentlyFailed(upload.id);
    await _refresh();
  }

  Future<void> _discard(SyncService sync, PendingUpload upload) async {
    await sync.discardPermanentlyFailed(upload.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to SyncService change notifications so reconnect-driven
    // updates reach the panel.
    ref.watch(syncServiceProvider);
    final sync = ref.read(syncServiceProvider);

    if (_failed.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.seam, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(AppIcons.error, color: context.colors.iconCrimson, size: 16),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(
                  context,
                ).filesFailedUploadsHeader(_failed.length),
                style: TextStyle(
                  color: context.colors.textCrimson,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final upload in _failed)
            _FailedUploadRow(
              upload: upload,
              onRetry: () => _retry(sync, upload),
              onDiscard: () => _discard(sync, upload),
            ),
        ],
      ),
    );
  }
}

class _FailedUploadRow extends StatelessWidget {
  const _FailedUploadRow({
    required this.upload,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingUpload upload;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.basename(upload.localPath),
              style: TextStyle(color: context.colors.text, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.commonRetry,
              style: TextStyle(color: context.colors.iconEmber, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(
              AppIcons.close,
              size: 16,
              color: context.colors.iconMuted,
            ),
            onPressed: onDiscard,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: kMinTapTarget,
              minHeight: kMinTapTarget,
            ),
            tooltip: l10n.filesDiscard,
          ),
        ],
      ),
    );
  }
}
