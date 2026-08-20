import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/reindex_service.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Shown once per account after the search re-key, while the device rebuilds
/// its own index.
///
/// The work has to happen here rather than on the server: the new index stores
/// tags keyed on material the server never sees, and note bodies have to be
/// downloaded and decrypted to be re-indexed at all. Until a file is done it
/// does not turn up in search, so the user gets told what is happening rather
/// than left wondering why their files vanished from the search box.
class ReindexDialog extends ConsumerStatefulWidget {
  const ReindexDialog({super.key, required this.service});

  final ReindexService service;

  @override
  ConsumerState<ReindexDialog> createState() => _ReindexDialogState();
}

class _ReindexDialogState extends ConsumerState<ReindexDialog> {
  ReindexProgress _progress = const ReindexProgress(running: true);
  StreamSubscription<ReindexProgress>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.service.run().listen(
      (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
        // Nothing left to watch: close rather than leave a full bar sitting
        // there waiting to be dismissed.
        if (!progress.running) Navigator.of(context).maybePop();
      },
      onError: (_) {
        if (mounted) Navigator.of(context).maybePop();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // No PopScope here. `canPop: false` blocks every pop, including the ones
    // these buttons issue, which left the dialog with two exits and no way
    // out. Dismissal is already gated by `barrierDismissible: false` at the
    // call site, so a stray tap outside cannot pick an exit by accident.
    return AlertDialog(
      title: Text(l10n.reindexTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reindexExplanation),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress.total == 0 ? null : _progress.fraction,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.reindexProgress(_progress.done, _progress.total),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_progress.failed > 0) ...[
            const SizedBox(height: 8),
            Text(
              l10n.reindexFailed(_progress.failed),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          // Stops after the batch in flight. Whatever is left stays pending
          // server-side, so the next session picks it up.
          onPressed: () {
            widget.service.cancel();
            Navigator.of(context).maybePop();
          },
          child: Text(l10n.reindexCancel),
        ),
        TextButton(
          // Closes the dialog and lets the sweep finish: the subscription
          // lives on the service, not on this widget.
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.reindexBackground),
        ),
      ],
    );
  }
}

/// Start the sweep if the server reports anything pending.
///
/// Nothing is persisted about having run. The server derives "pending" from
/// the absence of tags, so a cancelled or interrupted sweep simply resumes
/// here next time.
Future<void> maybeShowReindexDialog(BuildContext context, WidgetRef ref) async {
  final client = ref.read(apiClientProvider);
  final fileCrypto = ref.read(fileCryptoProvider);
  if (client == null || fileCrypto == null) return;

  final service = ReindexService(
    client: client,
    fileCrypto: fileCrypto,
    downloader: ref.read(fileDownloaderProvider),
  );

  final prefs = ref.read(preferencesProvider);
  final gaveUp = prefs.reindexGaveUpFileIds;

  final List<String> pending;
  try {
    pending = (await client.storage.pendingReindex()).map((f) => f.id).toList();
  } catch (_) {
    // An older server has no such route; nothing to rebuild against it.
    return;
  }

  // Only interrupt the user for work that might actually finish. Files the
  // sweep has already failed on stay pending forever, and without this the
  // dialog returns on every launch with no way to stop it.
  if (pending.every(gaveUp.contains)) {
    if (pending.isNotEmpty) {
      // Still worth retrying quietly: a file that becomes readable again
      // recovers without the user ever seeing this.
      unawaited(service.run().drain<void>());
    }
    return;
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReindexDialog(service: service),
  );

  // Whatever is still pending after a full sweep could not be indexed, so
  // remember it rather than asking again next launch.
  try {
    final left = (await client.storage.pendingReindex()).map((f) => f.id);
    await prefs.setReindexGaveUpFileIds({...gaveUp, ...left});
  } catch (_) {
    // Not worth failing the flow over; the next run reaches the same state.
  }
}
