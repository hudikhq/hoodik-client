import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Read-only panel that displays a JSON snippet and a "Copy" button beneath
/// it. Used by the AI Access settings screen to show the Claude Desktop /
/// Claude Code configuration block.
class McpConfigSnippet extends StatelessWidget {
  const McpConfigSnippet({
    super.key,
    required this.snippet,
    required this.onCopy,
  });

  final String snippet;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              snippet,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: AdaptiveButton(
              onPressed: onCopy,
              child: Text(AppLocalizations.of(context).accountMcpCopyConfig),
            ),
          ),
        ],
      ),
    );
  }
}
