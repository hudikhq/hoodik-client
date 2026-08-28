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
  late ReindexProgress _progress = widget.service.current;

  /// A finished sweep keeps the dialog up until the user dismisses it — the
  /// result (and any failures) should be seen, not vanish mid-read. Seeded
  /// true when the sweep already completed before the dialog opened; the
  /// fresh-service seed is `running: false` with nothing counted yet, which
  /// is "not started", not "done".
  late bool _finished = !_progress.running && _progress.total > 0;

  StreamSubscription<ReindexProgress>? _sub;

  @override
  void initState() {
    super.initState();
    // The service owns the sweep; this only watches it. Ensuring it is running
    // here is idempotent — the caller already started it — and the dialog
    // seeds from `current` so it opens on real progress, not an empty bar.
    widget.service.start();
    _sub = widget.service.progress.listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          if (!progress.running) _finished = true;
        });
      },
      onError: (_) {
        // A broken stream can never reach the done state; closing beats a
        // dialog stuck mid-bar with no working exit.
        if (mounted) Navigator.of(context).maybePop();
      },
    );
  }

  @override
  void dispose() {
    // Cancels only this observer. The sweep keeps running in the service,
    // which is exactly what "continue in background" means.
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
      actions: _finished
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.reindexDone),
              ),
            ]
          : [
              TextButton(
                // Stops after the batch in flight. Whatever is left stays
                // pending server-side, so the next session picks it up.
                onPressed: () {
                  widget.service.cancel();
                  Navigator.of(context).maybePop();
                },
                child: Text(l10n.reindexCancel),
              ),
              TextButton(
                // Closes the dialog and lets the sweep finish: the service
                // drives it, not this widget, so closing here detaches only
                // the observer.
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
  final fingerprint = ref.read(activeAccountProvider)?.fingerprint;
  if (client == null ||
      fileCrypto == null ||
      fingerprint == null ||
      fingerprint.isEmpty) {
    return;
  }

  final service = ReindexService(
    client: client,
    fileCrypto: fileCrypto,
    fingerprint: fingerprint,
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

  // Records the files a completed sweep still could not index, so the dialog
  // stops returning for them. Attached to the sweep's completion rather than
  // the dialog's — "continue in background" closes the dialog while the sweep
  // runs on, and reading pending then would condemn files still being worked.
  // A cancelled sweep condemns nothing.
  Future<void> rememberGiveUps() async {
    try {
      if (!service.completedFully) return;
      final left = (await client.storage.pendingReindex()).map((f) => f.id);
      await prefs.setReindexGaveUpFileIds({...gaveUp, ...left});
    } catch (_) {
      // Not worth failing over; the next run reaches the same state.
    } finally {
      // The service is built fresh per launch and nothing else holds it, so
      // its broadcast stream controller is this flow's to close.
      service.dispose();
    }
  }

  // Only interrupt the user for work that might actually finish. Files the
  // sweep has already failed on stay pending forever, and without this the
  // dialog returns on every launch with no way to stop it.
  if (pending.every(gaveUp.contains)) {
    if (pending.isNotEmpty) {
      // Still worth retrying quietly: a file that becomes readable again
      // recovers without the user ever seeing this.
      unawaited(service.start().whenComplete(rememberGiveUps));
    }
    return;
  }

  unawaited(service.start().whenComplete(rememberGiveUps));

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReindexDialog(service: service),
  );
}
