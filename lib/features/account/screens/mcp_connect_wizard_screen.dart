import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/mcp/mcp_client_configs.dart';
import '../../../core/mcp/mcp_connection_tester.dart';
import '../../../core/mcp/mcp_server.dart';
import '../../../core/providers.dart';
import '../../../core/storage/database.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../services/mcp_token_crypto.dart';
import '../widgets/mcp_wizard/wizard_client_step.dart';
import '../widgets/mcp_wizard/wizard_credentials_step.dart';
import '../widgets/mcp_wizard/wizard_enable_step.dart';
import '../widgets/mcp_wizard/wizard_layout.dart';
import '../widgets/mcp_wizard/wizard_test_step.dart';

export '../widgets/mcp_wizard/wizard_layout.dart' show McpWizardEnv;

/// Step-by-step wizard that walks a user through connecting an AI client
/// to the local MCP server. The four visible steps mirror the decision
/// points — start the server, confirm credentials, pick a client, verify
/// the handshake. Every step defers the actual work (start/stop, clipboard,
/// `initialize` call) to the injected [McpWizardEnv] or to shared core
/// services so the screen itself stays thin.
class McpConnectWizardScreen extends ConsumerStatefulWidget {
  const McpConnectWizardScreen({super.key, this.env});

  final McpWizardEnv? env;

  @override
  ConsumerState<McpConnectWizardScreen> createState() =>
      _McpConnectWizardScreenState();
}

class _McpConnectWizardScreenState
    extends ConsumerState<McpConnectWizardScreen> {
  late final McpWizardEnv _env = widget.env ?? McpWizardEnv();

  int _currentStep = 0;
  bool _loading = true;
  bool _busy = false;
  String? _startError;

  int _port = kDefaultMcpPort;
  String _bearerToken = '';
  TokenVisibility _tokenVisibility = TokenVisibility.masked;

  McpClientKind _selectedClient = McpClientKind.claudeDesktop;

  WizardTestState _testState = WizardTestState.idle;
  McpTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String? get _accountId => ref.read(activeAccountProvider)?.id;

  Future<void> _loadSettings() async {
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _loading = false);
      return;
    }

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
      _port = settings?.port ?? kDefaultMcpPort;
      _bearerToken = token;
      _loading = false;
    });
  }

  Future<void> _persistSettings({bool enabled = true}) async {
    final accountId = _accountId;
    if (accountId == null) return;

    final encrypted = encryptMcpToken(ref, _bearerToken);
    if (encrypted == null) return;

    final db = ref.read(databaseProvider);
    await db.upsertMcpSettings(
      accountId,
      McpSettingsCompanion(
        enabled: Value(enabled),
        port: Value(_port),
        bearerToken: Value(encrypted),
      ),
    );
    ref.invalidate(mcpSettingsProvider);
  }

  Future<void> _enableServer() async {
    final server = ref.read(mcpServerProvider);
    if (server == null) {
      setState(
        () => _startError = AppLocalizations.of(context).accountMcpUnavailable,
      );
      return;
    }
    setState(() {
      _busy = true;
      _startError = null;
    });

    await _persistSettings(enabled: true);
    try {
      if (!server.isRunning) {
        await server.start(port: _port, bearerToken: _bearerToken);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _startError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() {
      _bearerToken = const Uuid().v4();
      _tokenVisibility = TokenVisibility.masked;
      _testState = WizardTestState.idle;
      _testResult = null;
    });
    await _persistSettings();

    final server = ref.read(mcpServerProvider);
    if (server != null && server.isRunning) {
      await server.stop();
      try {
        await server.start(port: _port, bearerToken: _bearerToken);
      } catch (e) {
        if (!mounted) return;
        setState(() => _startError = e.toString());
      }
    }

    if (mounted) {
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).accountMcpTokenRegenerated,
      );
    }
  }

  void _copyToken() {
    Clipboard.setData(ClipboardData(text: _bearerToken));
    AppNotification.show(
      context,
      message: AppLocalizations.of(context).accountMcpTokenCopied,
    );
  }

  void _copySnippet(String snippet) {
    Clipboard.setData(ClipboardData(text: snippet));
    AppNotification.show(
      context,
      message: AppLocalizations.of(context).accountMcpConfigCopied,
    );
  }

  Future<void> _openConfigFolder(String fullPath) async {
    final folder = _parentDirectory(fullPath);
    if (folder.isEmpty) return;
    try {
      await Directory(folder).create(recursive: true);
    } catch (_) {
      // Falling through to the open attempt below — worst case the file
      // manager errors out and the user sees nothing, which is still the
      // right outcome for a wizard-style "open folder" affordance.
    }
    final uri = Uri.file(folder);
    await _env.openUri(uri);
  }

  static String _parentDirectory(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx <= 0) return '';
    return path.substring(0, idx);
  }

  Future<void> _runTest() async {
    setState(() {
      _testState = WizardTestState.running;
      _testResult = null;
    });

    final result = await _env.tester.probe(
      port: _port,
      bearerToken: _bearerToken,
    );

    if (!mounted) return;
    setState(() {
      _testResult = result;
      _testState = result.success
          ? WizardTestState.success
          : WizardTestState.failure;
    });
  }

  void _finish() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/account');
    }
  }

  bool get _serverRunning => ref.watch(mcpServerProvider)?.isRunning ?? false;

  WizardClientPlatform _clientPlatform() {
    return WizardClientPlatform(
      homeDir: _env.homeDir(),
      appDataDir: _env.appDataDir(),
      isMacOS: Platform.isMacOS,
      isWindows: Platform.isWindows,
      isLinux: Platform.isLinux,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!Platform.isMacOS) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.accountMcpConnectClientTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.accountMcpWizardMacosOnly,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountMcpConnectClientTitle),
        centerTitle: isApplePlatform,
      ),
      body: SafeArea(
        child: WizardBody(
          currentStep: _currentStep,
          children: [
            WizardEnableStep(
              isRunning: _serverRunning,
              port: _port,
              busy: _busy,
              errorMessage: _startError,
              onEnable: _enableServer,
              onNext: () => setState(() => _currentStep = 1),
            ),
            WizardCredentialsStep(
              bearerToken: _bearerToken,
              visibility: _tokenVisibility,
              busy: _busy,
              onCopy: _copyToken,
              onToggleVisibility: () => setState(() {
                _tokenVisibility = _tokenVisibility == TokenVisibility.masked
                    ? TokenVisibility.plain
                    : TokenVisibility.masked;
              }),
              onRegenerate: _regenerate,
              onNext: () => setState(() => _currentStep = 2),
            ),
            WizardClientStep(
              port: _port,
              bearerToken: _bearerToken,
              selected: _selectedClient,
              platform: _clientPlatform(),
              onSelected: (k) => setState(() => _selectedClient = k),
              onCopy: _copySnippet,
              onOpenFolder: _openConfigFolder,
              onNext: () => setState(() => _currentStep = 3),
            ),
            WizardTestStep(
              state: _testState,
              result: _testResult,
              onRun: _runTest,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}
