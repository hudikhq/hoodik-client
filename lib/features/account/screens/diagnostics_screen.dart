import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Entry point of the bug-report flow. Explains the no-telemetry stance,
/// walks the user through reproducing the bug, then hands off to the
/// log-redactor screen where the user reviews every line before sending.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountDiagnosticsTitle),
        centerTitle: isApplePlatform,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              l10n.accountDiagnosticsNoTracking,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.accountDiagnosticsNoTelemetryBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.accountDiagnosticsTellUsBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            _Step(number: 1, text: l10n.accountDiagnosticsStep1),
            _Step(number: 2, text: l10n.accountDiagnosticsStep2),
            _Step(number: 3, text: l10n.accountDiagnosticsStep3),
            _Step(number: 4, text: l10n.accountDiagnosticsStep4),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isApplePlatform
                        ? CupertinoIcons.info_circle
                        : AppIcons.info,
                    size: 20,
                    color: context.colors.iconEmber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.accountDiagnosticsLogsInfo,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AdaptiveButton(
              onPressed: () => context.push('/account/diagnostics/redact'),
              child: Text(l10n.accountDiagnosticsExportLogs),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$number.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.iconEmber,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
