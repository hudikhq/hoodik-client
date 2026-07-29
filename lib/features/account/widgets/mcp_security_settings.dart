import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Requests-per-second picker choices. Tight set so the user never has to
/// think about what a "reasonable" number looks like for an AI agent —
/// picker preserves a sane upper bound of 100 rps.
const List<int> mcpRateLimitRpsChoices = [1, 5, 10, 25, 100];

/// Burst capacity picker choices. Kept roughly proportional to
/// [mcpRateLimitRpsChoices] so each row in the UI has a matching burst
/// that's 2-4x the rps.
const List<int> mcpRateLimitBurstChoices = [5, 20, 50, 200];

/// Security + throttling section of the AI Access screen. Owns three
/// user-visible controls: allow-read-only-while-locked toggle, rate limit
/// rps, and burst capacity. Stateless — the parent screen owns the values
/// and receives change callbacks.
class McpSecuritySettings extends StatelessWidget {
  const McpSecuritySettings({
    super.key,
    required this.allowReadOnlyWhileLocked,
    required this.rateLimitRps,
    required this.rateLimitBurst,
    required this.onAllowReadOnlyChanged,
    required this.onRateLimitRpsChanged,
    required this.onRateLimitBurstChanged,
  });

  final bool allowReadOnlyWhileLocked;
  final int rateLimitRps;
  final int rateLimitBurst;
  final ValueChanged<bool> onAllowReadOnlyChanged;
  final ValueChanged<int> onRateLimitRpsChanged;
  final ValueChanged<int> onRateLimitBurstChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        AdaptiveListSection(
          header: l10n.accountMcpSecurityHeader,
          children: [
            AdaptiveListTile(
              leading: const Icon(CupertinoIcons.lock_shield, size: 22),
              title: Text(l10n.accountMcpAllowReadOnlyTitle),
              subtitle: Text(
                allowReadOnlyWhileLocked
                    ? l10n.accountMcpAllowReadOnlyOn
                    : l10n.accountMcpAllowReadOnlyOff,
              ),
              trailing: CupertinoSwitch(
                value: allowReadOnlyWhileLocked,
                onChanged: onAllowReadOnlyChanged,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            l10n.accountMcpLockedFootnote,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AdaptiveListSection(
          header: l10n.accountMcpRateLimitHeader,
          children: [
            _RateLimitPicker(
              icon: CupertinoIcons.speedometer,
              title: l10n.accountMcpRequestsPerSecond,
              trailingLabel: '$rateLimitRps/s',
              choices: mcpRateLimitRpsChoices,
              current: rateLimitRps,
              onChanged: onRateLimitRpsChanged,
              formatter: (v) => l10n.accountMcpPerSecondOption(v),
            ),
            _RateLimitPicker(
              icon: CupertinoIcons.chart_bar,
              title: l10n.accountMcpBurstCapacity,
              trailingLabel: '$rateLimitBurst',
              choices: mcpRateLimitBurstChoices,
              current: rateLimitBurst,
              onChanged: onRateLimitBurstChanged,
              formatter: (v) => '$v',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            l10n.accountMcpRateLimitFootnote,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _RateLimitPicker extends StatelessWidget {
  const _RateLimitPicker({
    required this.icon,
    required this.title,
    required this.trailingLabel,
    required this.choices,
    required this.current,
    required this.onChanged,
    required this.formatter,
  });

  final IconData icon;
  final String title;
  final String trailingLabel;
  final List<int> choices;
  final int current;
  final ValueChanged<int> onChanged;
  final String Function(int) formatter;

  @override
  Widget build(BuildContext context) {
    return AdaptiveListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailingLabel,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_right, size: 16),
        ],
      ),
      onTap: () => _showPicker(context),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in choices)
                ListTile(
                  title: Text(formatter(value)),
                  trailing: value == current
                      ? const Icon(CupertinoIcons.check_mark)
                      : null,
                  onTap: () => Navigator.of(context).pop(value),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != current) {
      onChanged(selected);
    }
  }
}
