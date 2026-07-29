import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/mcp/mcp_connection_tester.dart';

/// Environment hooks the connect wizard needs to reach the real world.
///
/// Injecting a bundle keeps the wizard deterministic under test: the widget
/// harness swaps these with fakes so no shell commands fire during unit
/// runs, and the screen itself never reaches for `dart:io` directly.
class McpWizardEnv {
  final McpConnectionTester tester;

  /// Opens a path in the user's file manager. Defaults to the system
  /// default; tests pass a mock that records the calls.
  final Future<bool> Function(Uri uri) openUri;

  /// Override home directory resolution. Falls back to Platform environment
  /// variables when the constructor is called with defaults.
  final String? Function() homeDir;

  /// Override APPDATA resolution on Windows.
  final String? Function() appDataDir;

  McpWizardEnv({
    McpConnectionTester? tester,
    Future<bool> Function(Uri uri)? openUri,
    String? Function()? homeDir,
    String? Function()? appDataDir,
  }) : tester = tester ?? McpConnectionTester(),
       openUri = openUri ?? launchUrl,
       homeDir = homeDir ?? _defaultHomeDir,
       appDataDir = appDataDir ?? _defaultAppDataDir;

  static String? _defaultHomeDir() =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  static String? _defaultAppDataDir() => Platform.environment['APPDATA'];
}

/// Body of the wizard. Renders a step-indicator pill row above the
/// currently-active step widget. Kept separate from the screen so the
/// screen file stays close to its state-management responsibilities.
class WizardBody extends StatelessWidget {
  const WizardBody({
    super.key,
    required this.currentStep,
    required this.children,
  });

  final int currentStep;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _StepIndicator(count: children.length, current: currentStep),
        const SizedBox(height: 8),
        children[currentStep],
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (int i = 0; i < count; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != count - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
