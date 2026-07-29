import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/files_upload_controller.dart';

/// Dimmed backdrop that blocks input while a blocking operation runs.
///
/// Shown while a mutation is in flight ([busy]) or while the platform
/// picker is still materializing picked files ([uploadPreparingProvider]) —
/// the gap between confirming a selection and the upload actually starting,
/// which for videos from the iOS Photos library can take many seconds.
class FilesBusyOverlay extends ConsumerWidget {
  final bool busy;

  const FilesBusyOverlay({super.key, this.busy = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preparing = ref.watch(uploadPreparingProvider);
    if (!busy && !preparing) return const SizedBox.shrink();

    return Container(
      color: Colors.black38,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (preparing) ...[
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).filesPreparing,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
