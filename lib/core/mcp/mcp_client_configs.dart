import 'dart:convert';

/// Which external MCP client a config snippet targets. Each entry carries
/// the human-readable label, the on-disk config path, and enough metadata
/// for the UI to render a "Copy for X" card without hard-coding details in
/// the widget layer.
enum McpClientKind { claudeDesktop, cursor, genericHttp }

/// Data describing one target AI client we know how to configure.
///
/// The settings screen and the connect wizard both need the same strings
/// (paths, labels, JSON snippets); having them on a single enum-driven
/// descriptor keeps the UI stateless and makes golden-testing the JSON
/// shape feasible without spinning up a widget tree.
class McpClientDescriptor {
  final McpClientKind kind;
  final String label;

  /// Short sentence shown under the client's name in the UI.
  final String description;

  /// Relative config path with environment tokens (`~`, `%AppData%`) left
  /// intact — we don't expand them here because each target platform
  /// resolves them differently.
  final String configPath;

  /// True when the stored config is a merge target — i.e. the user may
  /// already have other MCP servers in the same file, so callers must
  /// merge rather than overwrite.
  final bool merges;

  const McpClientDescriptor({
    required this.kind,
    required this.label,
    required this.description,
    required this.configPath,
    required this.merges,
  });
}

/// The set of clients the wizard knows about, ordered to match the
/// anticipated popularity from user research. Generic stdio/HTTP lives
/// last as a fallback for "any other MCP-capable agent".
const List<McpClientDescriptor> kSupportedMcpClients = [
  McpClientDescriptor(
    kind: McpClientKind.claudeDesktop,
    label: 'Claude Desktop',
    description:
        'Copy this block into Settings > Developer > Edit Config, under mcpServers.',
    configPath:
        '~/Library/Application Support/Claude/claude_desktop_config.json',
    merges: true,
  ),
  McpClientDescriptor(
    kind: McpClientKind.cursor,
    label: 'Cursor',
    description: 'Paste into ~/.cursor/mcp.json under the mcpServers object.',
    configPath: '~/.cursor/mcp.json',
    merges: true,
  ),
  McpClientDescriptor(
    kind: McpClientKind.genericHttp,
    label: 'Generic MCP client',
    description:
        'For any MCP-capable agent that speaks the Streamable HTTP transport.',
    configPath: '',
    merges: false,
  ),
];

/// Resolve [kind] to the platform-specific absolute path where the user
/// should paste the snippet. Returns the tokenised path unchanged if the
/// client doesn't have a well-known on-disk config (e.g. [McpClientKind.genericHttp]).
String resolveConfigPath({
  required McpClientKind kind,
  required String? homeDir,
  required String? appDataDir,
  required bool isWindows,
  required bool isMacOS,
  required bool isLinux,
}) {
  switch (kind) {
    case McpClientKind.claudeDesktop:
      if (isMacOS && homeDir != null) {
        return '$homeDir/Library/Application Support/Claude/claude_desktop_config.json';
      }
      if (isWindows && appDataDir != null) {
        return '$appDataDir\\Claude\\claude_desktop_config.json';
      }
      return '~/Library/Application Support/Claude/claude_desktop_config.json';
    case McpClientKind.cursor:
      if ((isMacOS || isLinux) && homeDir != null) {
        return '$homeDir/.cursor/mcp.json';
      }
      if (isWindows && homeDir != null) {
        return '$homeDir\\.cursor\\mcp.json';
      }
      return '~/.cursor/mcp.json';
    case McpClientKind.genericHttp:
      return '';
  }
}

/// Pretty-printed JSON config snippet for [kind].
///
/// The shape is identical across Claude Desktop and Cursor (both accept
/// `mcpServers` keyed by server name with `url` + `headers.Authorization`).
/// The generic HTTP variant drops the wrapper and shows the raw transport
/// block, which is easier to adapt to agents that expect different wire
/// formats.
String buildClientConfigSnippet({
  required McpClientKind kind,
  required int port,
  required String bearerToken,
}) {
  final transport = {
    'url': 'http://localhost:$port/mcp',
    'headers': {'Authorization': 'Bearer $bearerToken'},
  };

  final Object payload;
  switch (kind) {
    case McpClientKind.claudeDesktop:
    case McpClientKind.cursor:
      payload = {
        'mcpServers': {'hoodik': transport},
      };
    case McpClientKind.genericHttp:
      payload = {'transport': 'streamable-http', ...transport};
  }

  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(payload);
}
