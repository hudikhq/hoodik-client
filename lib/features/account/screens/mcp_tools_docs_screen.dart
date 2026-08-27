import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/mcp/mcp_tool_registry.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// In-app documentation of every MCP tool, sourced from [mcpTools].
///
/// Agents discover tools via `tools/list`. This screen renders that same
/// registry so the UI cannot drift from what a connected client is allowed
/// to call: name, description, and `inputSchema` (params, required, enums).
class McpToolsDocsScreen extends StatelessWidget {
  const McpToolsDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountMcpToolsTitle),
        centerTitle: isApplePlatform,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: mcpTools.length,
        itemBuilder: (context, index) => _ToolCard(tool: mcpTools[index]),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final Map<String, dynamic> tool;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = tool['name']?.toString() ?? '';
    final description = tool['description']?.toString() ?? '';
    final properties = _properties(tool);
    final required = _requiredNames(tool);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (properties.isEmpty)
                  Text(
                    l10n.accountMcpToolsNoParams,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  for (final entry in properties.entries)
                    _ParamBlock(
                      name: entry.key,
                      spec: _asStringKeyedMap(entry.value),
                      isRequired: required.contains(entry.key),
                    ),
              ],
            ),
          ),
          ExpansionTile(
            title: Text(l10n.accountMcpToolsRawSchema),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    jsonEncode(tool),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamBlock extends StatelessWidget {
  const _ParamBlock({
    required this.name,
    required this.spec,
    required this.isRequired,
  });

  final String name;
  final Map<String, dynamic> spec;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = spec['type']?.toString();
    final description = spec['description']?.toString();
    final enumValues = spec['enum'];
    final enumLabel = enumValues is List && enumValues.isNotEmpty
        ? enumValues.map((value) => value.toString()).join(', ')
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (type != null)
                Text(
                  type,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              if (isRequired)
                Text(
                  l10n.accountMcpToolsRequired,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colors.textSage,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
          if (enumLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              enumLabel,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

Map<String, dynamic> _properties(Map<String, dynamic> tool) {
  final schema = tool['inputSchema'];
  if (schema is! Map) return const {};
  final properties = schema['properties'];
  if (properties is! Map || properties.isEmpty) return const {};
  return {
    for (final entry in properties.entries) entry.key.toString(): entry.value,
  };
}

Set<String> _requiredNames(Map<String, dynamic> tool) {
  final schema = tool['inputSchema'];
  if (schema is! Map) return const {};
  final required = schema['required'];
  if (required is! List) return const {};
  return {
    for (final item in required)
      if (item is String) item,
  };
}

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return const {};
}
