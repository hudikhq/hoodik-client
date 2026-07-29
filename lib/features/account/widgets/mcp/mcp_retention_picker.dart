import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/mcp/mcp_audit_retention.dart';
import '../../../../core/widgets/adaptive.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The allowed retention windows. Values are days; `0` means "forever".
/// Kept here so the setting UI, the test suite, and the storage layer all
/// share one source of truth for what's a legal value.
const List<int> kMcpRetentionChoices = [7, 30, 90, 365, kMcpRetentionForever];

/// Row on the MCP settings screen that lets the user pick how long audit
/// entries are kept. Mirrors the shape of the rate-limit pickers so the
/// whole screen has consistent UX.
class McpRetentionPicker extends StatelessWidget {
  const McpRetentionPicker({
    super.key,
    required this.currentDays,
    required this.onChanged,
  });

  final int currentDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdaptiveListSection(
      header: l10n.accountMcpRetentionHeader,
      children: [
        AdaptiveListTile(
          leading: const Icon(CupertinoIcons.clock, size: 22),
          title: Text(l10n.accountMcpRetentionTitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _labelFor(l10n, currentDays),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              ),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.chevron_right, size: 16),
            ],
          ),
          onTap: () => _showPicker(context),
        ),
      ],
    );
  }

  String _labelFor(AppLocalizations l10n, int days) {
    if (days == kMcpRetentionForever) return l10n.accountMcpRetentionForever;
    if (days == 365) return l10n.accountMcpRetentionOneYear;
    return l10n.accountMcpRetentionDays(days);
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final days in kMcpRetentionChoices)
                ListTile(
                  title: Text(_labelFor(l10n, days)),
                  trailing: days == currentDays
                      ? const Icon(CupertinoIcons.check_mark)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(days),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != currentDays) {
      onChanged(picked);
    }
  }
}
