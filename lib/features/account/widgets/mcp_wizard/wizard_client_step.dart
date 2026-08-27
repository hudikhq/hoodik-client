import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/mcp/mcp_client_configs.dart';
import '../../../../core/widgets/adaptive.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'wizard_step_scaffold.dart';

/// Platform hints passed in from the screen so the config-path resolver
/// can mint an absolute path without the widget touching `dart:io`
/// directly. Keeping the inputs explicit makes the step trivially
/// testable against any desktop permutation.
class WizardClientPlatform {
  final String? homeDir;
  final String? appDataDir;
  final bool isMacOS;
  final bool isWindows;
  final bool isLinux;

  const WizardClientPlatform({
    required this.homeDir,
    required this.appDataDir,
    required this.isMacOS,
    required this.isWindows,
    required this.isLinux,
  });
}

/// Step 3 of the connect wizard. Renders a segmented selector for the
/// target AI client and a matching JSON snippet + paste-path panel. The
/// parent owns the selection so advancing to step 4 keeps the user's
/// chosen client available for retry flows.
class WizardClientStep extends StatelessWidget {
  const WizardClientStep({
    super.key,
    required this.port,
    required this.bearerToken,
    this.accountEmail,
    this.serverUrl,
    required this.selected,
    required this.platform,
    required this.onSelected,
    required this.onCopy,
    required this.onOpenFolder,
    required this.onNext,
  });

  final int port;
  final String bearerToken;
  final String? accountEmail;
  final String? serverUrl;
  final McpClientKind selected;
  final WizardClientPlatform platform;
  final ValueChanged<McpClientKind> onSelected;
  final void Function(String snippet) onCopy;
  final Future<void> Function(String path)? onOpenFolder;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final descriptor = kSupportedMcpClients.firstWhere(
      (d) => d.kind == selected,
    );
    final snippet = buildClientConfigSnippet(
      kind: selected,
      port: port,
      bearerToken: bearerToken,
      accountEmail: accountEmail,
      serverUrl: serverUrl,
    );
    final serverKey = mcpServerKey(email: accountEmail, serverUrl: serverUrl);
    final resolvedPath = resolveConfigPath(
      kind: selected,
      homeDir: platform.homeDir,
      appDataDir: platform.appDataDir,
      isMacOS: platform.isMacOS,
      isWindows: platform.isWindows,
      isLinux: platform.isLinux,
    );

    return WizardStepScaffold(
      title: l10n.accountWizardStep3Title,
      subtitle: descriptor.description,
      primaryLabel: l10n.accountWizardNext,
      onPrimary: onNext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClientSelector(selected: selected, onSelected: onSelected),
          const SizedBox(height: 8),
          Text(
            serverKey,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
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
          if (resolvedPath.isNotEmpty)
            _PastePathRow(
              path: resolvedPath,
              onOpenFolder: onOpenFolder == null
                  ? null
                  : () => onOpenFolder!(resolvedPath),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AdaptiveTextButton(
              onPressed: () => onCopy(snippet),
              child: Text(l10n.accountWizardCopyToClipboard),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientSelector extends StatelessWidget {
  const _ClientSelector({required this.selected, required this.onSelected});

  final McpClientKind selected;
  final ValueChanged<McpClientKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final descriptor in kSupportedMcpClients)
          ChoiceChip(
            label: Text(descriptor.label),
            selected: descriptor.kind == selected,
            onSelected: (v) {
              if (v) onSelected(descriptor.kind);
            },
            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
      ],
    );
  }
}

class _PastePathRow extends StatelessWidget {
  const _PastePathRow({required this.path, required this.onOpenFolder});

  final String path;
  final Future<void> Function()? onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          CupertinoIcons.folder,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            path,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
            maxLines: 2,
          ),
        ),
        if (onOpenFolder != null)
          AdaptiveTextButton(
            onPressed: onOpenFolder,
            child: Text(AppLocalizations.of(context).accountWizardOpenFolder),
          ),
      ],
    );
  }
}
