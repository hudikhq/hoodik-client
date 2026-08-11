import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/app_icons.dart';

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
            AppIcons.folderOpen,
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
            icon: Icon(AppIcons.add),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.error, size: 48, color: HoodikColors.iconCrimson),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(AppIcons.refresh),
              label: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
