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
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/adaptive_menu.dart';
import '../../../core/theme/hoodik_scheme.dart';

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
          AdaptiveMenuButton(
            icon: AppIcons.overflowVertical,
            tooltip: l10n.notesMore,
            builder: (ctx) => [
              AdaptiveMenuAction(
                icon: AppIcons.delete,
                iconColor: ctx.colors.iconCrimson,
                label: l10n.accountAuditClearLog,
                onTap: () => _confirmClear(context, ref),
                isDestructive: true,
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
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        if (index == 0) return const _EntryHeader();
        return _EntryRow(entry: entries[index - 1]);
      },
    );
  }
}

/// First 8 characters of a hex digest (or the whole string if shorter).
int _prefix(String value) => value.length < 8 ? value.length : 8;

String _prefixed(String value) => '${value.substring(0, _prefix(value))}\u2026';

class _AuditLine extends StatelessWidget {
  const _AuditLine({
    required this.tool,
    required this.timestamp,
    required this.status,
    required this.duration,
    required this.session,
    required this.params,
  });

  final Widget tool;
  final Widget timestamp;
  final Widget status;
  final Widget duration;
  final Widget session;
  final Widget params;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    Widget cell(double width, Widget child) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );
    }

    return SizedBox(
      height: _height,
      child: ClipRect(
        child: Row(
          children: [
            cell(140, tool),
            cell(148, timestamp),
            cell(72, status),
            cell(88, duration),
            cell(108, session),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Align(alignment: Alignment.centerLeft, child: params),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: context.colors.textMuted,
    );
    return _AuditLine(
      tool: _Cell('', style: style),
      timestamp: _Cell(l10n.accountAuditTimestamp, style: style),
      status: _Cell(l10n.accountAuditStatus, style: style),
      duration: _Cell(l10n.accountAuditDuration, style: style),
      session: _Cell(l10n.accountAuditSession, style: style),
      params: _Cell(l10n.accountAuditParamsHash, style: style),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final McpAuditLogData entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return InkWell(
      onTap: () => _showDetail(context, entry),
      child: _AuditLine(
        tool: _Cell(entry.toolName, style: mono),
        timestamp: _Cell(
          formatAbsoluteDate(entry.timestamp, includeTime: true),
        ),
        status: _StatusChip(status: entry.resultStatus),
        duration: _Cell(l10n.accountAuditMilliseconds(entry.durationMs)),
        session: _Cell(
          entry.sessionId.isEmpty ? '—' : _prefixed(entry.sessionId),
          style: mono,
        ),
        params: _Cell(
          entry.paramsHash.isEmpty
              ? l10n.accountAuditNoParams
              : _prefixed(entry.paramsHash),
          style: mono,
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, McpAuditLogData entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
          child: _DetailSheet(entry: entry),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Each pair is a tested ground and foreground rather than a system hue at
    // low alpha: the chip has to clear 4.5:1 wherever it lands, and alpha
    // makes that depend on the surface underneath it.
    final (Color background, Color foreground) = switch (status) {
      'ok' => (c.sageWash, c.textSage),
      'error' => (c.crimsonWash, c.onCrimsonWash),
      'denied' => (c.emberWash, c.textEmber),
      _ => (c.recess, c.textMuted),
    };

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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                value: entry.sessionId.isEmpty ? '—' : entry.sessionId,
              ),
              _DetailRow(
                label: l10n.accountAuditParamsHash,
                value: entry.paramsHash.isEmpty
                    ? l10n.accountAuditNoParams
                    : entry.paramsHash,
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
        ],
      ),
    );
  }
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
    return AdaptiveMenuButton(
      tooltip: l10n.accountAuditFilterByTool,
      icon: filter.toolName == null
          ? Icons.filter_list_outlined
          : Icons.filter_list,
      builder: (ctx) => [
        AdaptiveMenuAction(
          icon: Icons.filter_list_outlined,
          iconColor: ctx.colors.iconMuted,
          label: l10n.accountAuditAllTools,
          isSelected: filter.toolName == null,
          onTap: () => onChanged(null),
        ),
        for (final name in toolNames)
          AdaptiveMenuAction(
            icon: Icons.filter_list,
            iconColor: ctx.colors.iconMuted,
            label: name,
            isSelected: filter.toolName == name,
            onTap: () => onChanged(name),
          ),
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
    return AdaptiveMenuButton(
      tooltip: l10n.accountAuditFilterByStatus,
      icon: filter.resultStatus == null
          ? Icons.check_circle_outline
          : AppIcons.success,
      builder: (ctx) => [
        for (final (value, label) in <(String?, String)>[
          (null, l10n.accountAuditAllStatuses),
          ('ok', l10n.accountAuditStatusOk),
          ('error', l10n.accountAuditError),
          ('denied', l10n.accountAuditStatusDenied),
        ])
          AdaptiveMenuAction(
            icon: AppIcons.success,
            iconColor: ctx.colors.iconMuted,
            label: label,
            isSelected: filter.resultStatus == value,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}
