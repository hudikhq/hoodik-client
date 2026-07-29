import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/core/mcp/mcp_client_configs.dart';
import 'package:hoodik_app/core/mcp/mcp_connection_tester.dart';
import 'package:hoodik_app/features/account/widgets/mcp_wizard/wizard_client_step.dart';
import 'package:hoodik_app/features/account/widgets/mcp_wizard/wizard_credentials_step.dart';
import 'package:hoodik_app/features/account/widgets/mcp_wizard/wizard_enable_step.dart';
import 'package:hoodik_app/features/account/widgets/mcp_wizard/wizard_test_step.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _clientPlatform = WizardClientPlatform(
  homeDir: '/home/tibor',
  appDataDir: null,
  isMacOS: true,
  isWindows: false,
  isLinux: false,
);

void main() {
  group('WizardEnableStep', () {
    testWidgets('off state triggers enable callback', (tester) async {
      var enableCalled = false;
      await tester.pumpWidget(
        _wrap(
          WizardEnableStep(
            isRunning: false,
            port: 19548,
            busy: false,
            errorMessage: null,
            onEnable: () async {
              enableCalled = true;
            },
            onNext: () {},
          ),
        ),
      );
      await tester.tap(find.text('Enable AI Access'));
      await tester.pump();
      expect(enableCalled, isTrue);
    });

    testWidgets('running state shows endpoint and advances', (tester) async {
      var nextCalled = false;
      await tester.pumpWidget(
        _wrap(
          WizardEnableStep(
            isRunning: true,
            port: 19548,
            busy: false,
            errorMessage: null,
            onEnable: () async {},
            onNext: () => nextCalled = true,
          ),
        ),
      );
      expect(find.textContaining('19548'), findsWidgets);
      expect(find.text('Enabled'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(nextCalled, isTrue);
    });
  });

  group('WizardCredentialsStep', () {
    testWidgets('masked by default, toggle reveals plaintext', (tester) async {
      var visibility = TokenVisibility.masked;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setState) => WizardCredentialsStep(
              bearerToken: 'abcd1234-secret-token-tail',
              visibility: visibility,
              busy: false,
              onCopy: () {},
              onToggleVisibility: () => setState(() {
                visibility = visibility == TokenVisibility.masked
                    ? TokenVisibility.plain
                    : TokenVisibility.masked;
              }),
              onRegenerate: () async {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('\u2022\u2022\u2022'), findsOneWidget);
      expect(find.text('abcd1234-secret-token-tail'), findsNothing);

      await tester.tap(find.byTooltip('Show token'));
      await tester.pump();

      expect(find.text('abcd1234-secret-token-tail'), findsOneWidget);
    });

    testWidgets('copy token places full token on clipboard', (tester) async {
      const token = 'my-bearer-token-value';
      String? captured;
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            captured = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        _wrap(
          WizardCredentialsStep(
            bearerToken: token,
            visibility: TokenVisibility.masked,
            busy: false,
            onCopy: () {
              Clipboard.setData(const ClipboardData(text: token));
            },
            onToggleVisibility: () {},
            onRegenerate: () async {},
            onNext: () {},
          ),
        ),
      );

      await tester.tap(find.text('Copy token'));
      await tester.pump();

      expect(captured, token);
    });
  });

  group('WizardClientStep', () {
    testWidgets('Claude Desktop snippet contains url + bearer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WizardClientStep(
            port: 19548,
            bearerToken: 'TEST-BEARER',
            selected: McpClientKind.claudeDesktop,
            platform: _clientPlatform,
            onSelected: (_) {},
            onCopy: (_) {},
            onOpenFolder: null,
            onNext: () {},
          ),
        ),
      );

      expect(find.textContaining('"mcpServers"'), findsOneWidget);
      expect(find.textContaining('http://localhost:19548/mcp'), findsOneWidget);
      expect(find.textContaining('Bearer TEST-BEARER'), findsOneWidget);
    });

    testWidgets('Cursor snippet points at ~/.cursor/mcp.json', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WizardClientStep(
            port: 19548,
            bearerToken: 'TOK',
            selected: McpClientKind.cursor,
            platform: _clientPlatform,
            onSelected: (_) {},
            onCopy: (_) {},
            onOpenFolder: null,
            onNext: () {},
          ),
        ),
      );

      expect(
        find.textContaining('/home/tibor/.cursor/mcp.json'),
        findsOneWidget,
      );
    });

    testWidgets('Generic client drops the mcpServers wrapper', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WizardClientStep(
            port: 19548,
            bearerToken: 'TOK',
            selected: McpClientKind.genericHttp,
            platform: _clientPlatform,
            onSelected: (_) {},
            onCopy: (_) {},
            onOpenFolder: null,
            onNext: () {},
          ),
        ),
      );

      expect(find.textContaining('"transport"'), findsOneWidget);
      expect(find.textContaining('streamable-http'), findsOneWidget);
    });
  });

  group('WizardTestStep', () {
    testWidgets('success renders capabilities verbatim', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WizardTestStep(
            state: WizardTestState.success,
            result: const McpTestResult(
              success: true,
              serverName: 'hoodik',
              serverVersion: '1.0.0',
              protocolVersion: '2025-03-26',
              capabilities: ['tools', 'logging'],
            ),
            onRun: () async {},
            onFinish: () {},
          ),
        ),
      );

      expect(find.text('Connected'), findsOneWidget);
      expect(
        find.textContaining('Capabilities: tools, logging'),
        findsOneWidget,
      );
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('failure shows error text and offers retry', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WizardTestStep(
            state: WizardTestState.failure,
            result: McpTestResult.failure('Connection refused'),
            onRun: () async {},
            onFinish: () {},
          ),
        ),
      );

      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Connection refused'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
