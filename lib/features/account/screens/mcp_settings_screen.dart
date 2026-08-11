import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/mcp/mcp_server.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../services/mcp_token_crypto.dart';
import '../widgets/mcp_config_snippet.dart';
import '../widgets/mcp_security_settings.dart';
import '../../../core/theme/hoodik_colors.dart';

/// Settings screen for the MCP (AI Access) server feature.
///
/// macOS only — allows the user to enable/disable the MCP server,
/// configure the port, view and copy the bearer token, and see a
/// ready-to-copy config snippet for Claude Desktop / Claude Code.
class McpSettingsScreen extends ConsumerStatefulWidget {
  const McpSettingsScreen({super.key});

  @override
  ConsumerState<McpSettingsScreen> createState() => _McpSettingsScreenState();
}

class _McpSettingsScreenState extends ConsumerState<McpSettingsScreen> {
  bool _enabled = false;
  int _port = kDefaultMcpPort;
  String _bearerToken = '';
  bool _loading = true;
  String? _error;
  late TextEditingController _portController;

  bool _allowReadOnlyWhileLocked = false;
  int _rateLimitRps = 5;
  int _rateLimitBurst = 20;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: _port.toString());
    _loadSettings();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  String? get _accountId => ref.read(activeAccountProvider)?.id;

  Future<void> _loadSettings() async {
    final accountId = _accountId;
    if (accountId == null) return;

    final db = ref.read(databaseProvider);
    final settings = await db.getMcpSettings(accountId);

    if (!mounted) return;

    var token = '';
    final encrypted = settings?.bearerToken ?? '';
    if (encrypted.isNotEmpty) {
      token = decryptMcpToken(ref, encrypted) ?? '';
    }
    if (token.isEmpty) {
      token = const Uuid().v4();
    }

    setState(() {
      _enabled = settings?.enabled ?? false;
      _port = settings?.port ?? kDefaultMcpPort;
      _portController.text = _port.toString();
      _bearerToken = token;
      _allowReadOnlyWhileLocked = settings?.allowReadOnlyWhileLocked ?? false;
      _rateLimitRps = settings?.rateLimitRps ?? 5;
      _rateLimitBurst = settings?.rateLimitBurst ?? 20;
      _loading = false;
    });

    if (_enabled) {
      unawaited(_startServer());
    }
  }

  Future<void> _saveSettings() async {
    final accountId = _accountId;
    if (accountId == null) return;

    final encryptedToken = encryptMcpToken(ref, _bearerToken);
    if (encryptedToken == null) return;

    final db = ref.read(databaseProvider);
    await db.upsertMcpSettings(
      accountId,
      McpSettingsCompanion(
        enabled: Value(_enabled),
        port: Value(_port),
        bearerToken: Value(encryptedToken),
        allowReadOnlyWhileLocked: Value(_allowReadOnlyWhileLocked),
        rateLimitRps: Value(_rateLimitRps),
        rateLimitBurst: Value(_rateLimitBurst),
      ),
    );
    ref.invalidate(mcpSettingsProvider);
  }

  Future<void> _setAllowReadOnlyWhileLocked(bool value) async {
    setState(() => _allowReadOnlyWhileLocked = value);
    await _saveSettings();
  }

  Future<void> _setRateLimitRps(int value) async {
    setState(() => _rateLimitRps = value);
    await _saveSettings();
  }

  Future<void> _setRateLimitBurst(int value) async {
    setState(() => _rateLimitBurst = value);
    await _saveSettings();
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await _saveSettings();
    if (!mounted) return;

    if (value) {
      await _startServer();
    } else {
      await _stopServer();
    }
  }

  Future<void> _startServer() async {
    final server = ref.read(mcpServerProvider);
    if (server == null || server.isRunning) return;

    try {
      await server.start(port: _port, bearerToken: _bearerToken);
      if (!mounted) return;
      setState(() => _error = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _enabled = false;
      });
      await _saveSettings();
    }
  }

  Future<void> _stopServer() async {
    final server = ref.read(mcpServerProvider);
    await server?.stop();
    setState(() => _error = null);
  }

  Future<void> _regenerateToken() async {
    setState(() {
      _bearerToken = const Uuid().v4();
    });
    await _saveSettings();

    final server = ref.read(mcpServerProvider);
    if (server != null && server.isRunning) {
      await _stopServer();
      if (!mounted) return;
      await _startServer();
    }

    if (!mounted) return;
    AppNotification.show(
      context,
      message: AppLocalizations.of(context).accountMcpTokenRegenerated,
    );
  }

  Future<void> _applyPort() async {
    final parsed = int.tryParse(_portController.text);
    if (parsed == null || parsed < 1024 || parsed > 65535) {
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).accountMcpPortRange,
      );
      _portController.text = _port.toString();
      return;
    }
    if (parsed == _port) return;

    setState(() => _port = parsed);
    await _saveSettings();

    if (_enabled) {
      await _stopServer();
      if (!mounted) return;
      await _startServer();
    }

    if (!mounted) return;
    AppNotification.show(
      context,
      message: AppLocalizations.of(context).accountMcpPortUpdated(_port),
    );
  }

  String get _configSnippet =>
      '''{
  "mcpServers": {
    "hoodik": {
      "url": "http://localhost:$_port/mcp",
      "headers": {
        "Authorization": "Bearer $_bearerToken"
      }
    }
  }
}''';

  void _copyConfig() {
    Clipboard.setData(ClipboardData(text: _configSnippet));
    AppNotification.show(
      context,
      message: AppLocalizations.of(context).accountMcpConfigCopied,
    );
  }

  void _copyToken() {
    Clipboard.setData(ClipboardData(text: _bearerToken));
    AppNotification.show(
      context,
      message: AppLocalizations.of(context).accountMcpTokenCopied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!Platform.isMacOS) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.accountAiAccessTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.accountAiAccessMacosOnly,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final server = ref.watch(mcpServerProvider);
    final isRunning = server?.isRunning ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountAiAccessTitle),
        centerTitle: isApplePlatform,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                AdaptiveListSection(
                  header: l10n.accountMcpServerHeader,
                  children: [
                    AdaptiveListTile(
                      leading: Icon(
                        isRunning
                            ? CupertinoIcons.bolt_fill
                            : CupertinoIcons.bolt_slash,
                        size: 22,
                        color: isRunning ? CupertinoColors.activeGreen : null,
                      ),
                      title: Text(l10n.accountMcpEnable),
                      subtitle: Text(
                        isRunning
                            ? l10n.accountMcpRunningOnPort(_port)
                            : _enabled
                            ? l10n.accountMcpStarting
                            : l10n.accountMcpDisabled,
                      ),
                      trailing: CupertinoSwitch(
                        value: _enabled,
                        onChanged: _toggleEnabled,
                      ),
                    ),
                    AdaptiveListTile(
                      leading: Icon(
                        CupertinoIcons.wand_stars,
                        size: 22,
                        color: HoodikColors.iconCrimson,
                      ),
                      title: Text(l10n.accountMcpConnectClientTitle),
                      subtitle: Text(l10n.accountMcpConnectClientSubtitle),
                      onTap: () =>
                          context.push('/account/ai-access/connect-wizard'),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    l10n.accountMcpEnableFootnote,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: HoodikColors.textCrimson),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                AdaptiveListSection(
                  header: l10n.accountMcpActivityHeader,
                  children: [
                    AdaptiveListTile(
                      leading: const Icon(
                        CupertinoIcons.doc_text_search,
                        size: 22,
                      ),
                      title: Text(l10n.accountMcpViewAuditLog),
                      subtitle: Text(l10n.accountMcpViewAuditLogSubtitle),
                      onTap: () => context.push('/account/ai-access/audit-log'),
                    ),
                  ],
                ),

                if (_enabled) ...[
                  const SizedBox(height: 16),
                  AdaptiveListSection(
                    header: l10n.accountMcpConnectionHeader,
                    children: [
                      AdaptiveListTile(
                        leading: const Icon(CupertinoIcons.number, size: 22),
                        title: Text(l10n.accountMcpPort),
                        trailing: SizedBox(
                          width: 100,
                          child: CupertinoTextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.end,
                            placeholder: kDefaultMcpPort.toString(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                            onSubmitted: (_) => _applyPort(),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ),
                      AdaptiveListTile(
                        leading: const Icon(CupertinoIcons.link, size: 22),
                        title: Text(l10n.accountMcpEndpoint),
                        subtitle: SelectableText(
                          'http://localhost:$_port/mcp',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: HoodikColors.textCrimson,
                          ),
                        ),
                      ),
                      AdaptiveListTile(
                        leading: const Icon(CupertinoIcons.lock, size: 22),
                        title: Text(l10n.accountMcpBearerToken),
                        subtitle: Text(
                          '${_bearerToken.substring(0, 8)}...',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AdaptiveTextButton(
                              onPressed: _copyToken,
                              child: Text(l10n.commonCopy),
                            ),
                            const SizedBox(width: 4),
                            AdaptiveTextButton(
                              onPressed: _regenerateToken,
                              isDestructive: true,
                              child: Text(l10n.accountMcpRegenerate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AdaptiveListSection(
                    header: l10n.accountMcpConfigurationHeader,
                    children: [
                      McpConfigSnippet(
                        snippet: _configSnippet,
                        onCopy: _copyConfig,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Text(
                      l10n.accountMcpConfigFootnote,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  McpSecuritySettings(
                    allowReadOnlyWhileLocked: _allowReadOnlyWhileLocked,
                    rateLimitRps: _rateLimitRps,
                    rateLimitBurst: _rateLimitBurst,
                    onAllowReadOnlyChanged: _setAllowReadOnlyWhileLocked,
                    onRateLimitRpsChanged: _setRateLimitRps,
                    onRateLimitBurstChanged: _setRateLimitBurst,
                  ),
                ],
              ],
            ),
    );
  }
}
