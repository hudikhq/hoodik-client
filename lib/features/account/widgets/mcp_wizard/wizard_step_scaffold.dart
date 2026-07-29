import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/adaptive.dart';

/// Shared chrome for every step in the connect wizard: a title, optional
/// subtitle, the step body, and a right-aligned primary action row with
/// an optional secondary button.
///
/// Each step widget renders one of these so the overall stepper has a
/// consistent look without every author re-inventing the layout.
class WizardStepScaffold extends StatelessWidget {
  const WizardStepScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryDisabled = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 16),
          if (primaryLabel != null || secondaryLabel != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondaryLabel != null)
                  AdaptiveTextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                if (secondaryLabel != null && primaryLabel != null)
                  const SizedBox(width: 12),
                if (primaryLabel != null)
                  SizedBox(
                    width: 180,
                    child: AdaptiveButton(
                      onPressed: primaryDisabled ? null : onPrimary,
                      child: Text(primaryLabel!),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Pill shown in the header of each step that is already satisfied. Keeps
/// the visual language consistent across the four steps — a green tick
/// plus a short success label.
class WizardDoneBadge extends StatelessWidget {
  const WizardDoneBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.activeGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: CupertinoColors.activeGreen,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.activeGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
