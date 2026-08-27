import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_registry.dart';
import 'package:hoodik_app/features/account/screens/mcp_tools_docs_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows resolve_path and list_files from the MCP registry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: McpToolsDocsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent tools'), findsOneWidget);

    final names = {for (final tool in mcpTools) tool['name'] as String};
    expect(names, containsAll(['list_files', 'resolve_path']));

    expect(find.text('list_files'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('resolve_path'), 200);
    expect(find.text('resolve_path'), findsOneWidget);
  });
}
