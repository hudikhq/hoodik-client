import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/storage/mcp_audit_dao.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Human-readable list of MCP tool calls recorded by [AuditingMcpToolDispatcher].
///
/// The audit log exists so the user can answer "what has the AI agent actually
/// done with my files?" — but it still respects the project's E2EE guarantee:
/// every row is hashed/redacted so the log itself never leaks file content or
/// bearer-token plaintext.
class McpAuditLogScreen extends ConsumerWidget {
  const McpAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(mcpAuditLogProvider);
    final filter = ref.watch(mcpAuditFilterProvider);
    final toolNames = ref.watch(mcpAuditToolNamesProvider);

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountAuditLogTitle),
        centerTitle: isApplePlatform,
        actions: [
          _ToolFilterMenu(
            filter: filter,
            toolNames: toolNames.valueOrNull ?? const <String>[],
            onChanged: (value) => _setToolName(ref, value),
          ),
          _StatusFilterMenu(
            filter: filter,
            onChanged: (value) => _setStatus(ref, value),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _confirmClear(context, ref);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear',
                child: Text(l10n.accountAuditClearLog),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.refresh(mcpAuditLogProvider),
        child: entriesAsync.when(
          data: (entries) => entries.isEmpty
              ? const _EmptyState()
              : _EntryList(entries: entries),
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (err, _) =>
              Center(child: Text(l10n.accountAuditLoadFailed('$err'))),
        ),
      ),
    );
  }

  void _setToolName(WidgetRef ref, String? value) {
    final notifier = ref.read(mcpAuditFilterProvider.notifier);
    notifier.state = value == null
        ? notifier.state.clearToolName()
        : notifier.state.copyWith(toolName: value);
  }

  void _setStatus(WidgetRef ref, String? value) {
    final notifier = ref.read(mcpAuditFilterProvider.notifier);
    notifier.state = value == null
        ? notifier.state.clearResultStatus()
        : notifier.state.copyWith(resultStatus: value);
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.accountAuditClearConfirmTitle,
      content: l10n.accountAuditClearConfirmBody,
      actions: [
        AdaptiveDialogAction(label: l10n.commonCancel, value: false),
        AdaptiveDialogAction(
          label: l10n.accountClear,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true) return;

    await ref.read(databaseProvider).clearMcpAuditLog();
    if (context.mounted) {
      AppNotification.show(context, message: l10n.accountAuditCleared);
    }
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<McpAuditLogData> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) => _EntryRow(entry: entries[index]),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final McpAuditLogData entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(
        entry.toolName,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      subtitle: Text(
        '${formatRelativeTime(entry.timestamp)} '
        '\u2022 ${l10n.accountAuditMilliseconds(entry.durationMs)}',
      ),
      trailing: _StatusChip(status: entry.resultStatus),
      onTap: () => _showDetail(context, entry),
    );
  }

  void _showDetail(BuildContext context, McpAuditLogData entry) {
    if (isApplePlatform) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => _DetailSheet(entry: entry),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => _DetailSheet(entry: entry),
      );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    switch (status) {
      case 'ok':
        background = CupertinoColors.activeGreen.withValues(alpha: 0.15);
        foreground = CupertinoColors.activeGreen;
      case 'error':
        background = CupertinoColors.systemRed.withValues(alpha: 0.15);
        foreground = CupertinoColors.systemRed;
      case 'denied':
        background = CupertinoColors.systemOrange.withValues(alpha: 0.15);
        foreground = CupertinoColors.systemOrange;
      default:
        background = CupertinoColors.systemGrey.withValues(alpha: 0.15);
        foreground = CupertinoColors.systemGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.entry});

  final McpAuditLogData entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.toolName,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: l10n.accountAuditTimestamp,
                value: formatAbsoluteDate(entry.timestamp, includeTime: true),
              ),
              _DetailRow(
                label: l10n.accountAuditStatus,
                value: entry.resultStatus,
              ),
              _DetailRow(
                label: l10n.accountAuditDuration,
                value: l10n.accountAuditMilliseconds(entry.durationMs),
              ),
              _DetailRow(
                label: l10n.accountAuditSession,
                value: entry.sessionId.isEmpty
                    ? '—'
                    : '${entry.sessionId.substring(0, _prefix(entry.sessionId))}\u2026',
              ),
              _DetailRow(
                label: l10n.accountAuditParamsHash,
                value: entry.paramsHash.isEmpty
                    ? l10n.accountAuditNoParams
                    : '${entry.paramsHash.substring(0, _prefix(entry.paramsHash))}\u2026',
              ),
              _DetailRow(
                label: l10n.accountTitle,
                value: entry.accountId ?? '—',
              ),
              if (entry.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.accountAuditError,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  entry.errorMessage!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _prefix(String value) => value.length < 8 ? value.length : 8;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(
                CupertinoIcons.doc_text_search,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.accountAuditEmptyTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.accountAuditEmptyBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolFilterMenu extends StatelessWidget {
  const _ToolFilterMenu({
    required this.filter,
    required this.toolNames,
    required this.onChanged,
  });

  final McpAuditFilter filter;
  final List<String> toolNames;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String?>(
      tooltip: l10n.accountAuditFilterByTool,
      icon: Icon(
        filter.toolName == null
            ? Icons.filter_list_outlined
            : Icons.filter_list,
      ),
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(l10n.accountAuditAllTools),
        ),
        for (final name in toolNames)
          PopupMenuItem<String?>(value: name, child: Text(name)),
      ],
    );
  }
}

class _StatusFilterMenu extends StatelessWidget {
  const _StatusFilterMenu({required this.filter, required this.onChanged});

  final McpAuditFilter filter;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String?>(
      tooltip: l10n.accountAuditFilterByStatus,
      icon: Icon(
        filter.resultStatus == null
            ? Icons.check_circle_outline
            : Icons.check_circle,
      ),
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text(l10n.accountAuditAllStatuses),
        ),
        PopupMenuItem<String?>(
          value: 'ok',
          child: Text(l10n.accountAuditStatusOk),
        ),
        PopupMenuItem<String?>(
          value: 'error',
          child: Text(l10n.accountAuditError),
        ),
        PopupMenuItem<String?>(
          value: 'denied',
          child: Text(l10n.accountAuditStatusDenied),
        ),
      ],
    );
  }
}
