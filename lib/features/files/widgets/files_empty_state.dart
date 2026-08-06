import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Rendered when a directory returns zero items, with a direct route into
/// the create sheet so the first action doesn't depend on spotting the FAB.
class FilesEmptyState extends StatelessWidget {
  const FilesEmptyState({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).filesEmptyTitle,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context).filesEmptyAction),
          ),
        ],
      ),
    );
  }
}

/// Rendered on a load failure with a Retry button that calls back
/// into the screen to re-trigger [FilesNotifier.load].
class FilesErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const FilesErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
