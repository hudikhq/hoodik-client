import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/features/shares/widgets/recipient_email_field.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';

Future<TextEditingController> _pump(
  WidgetTester tester, {
  required List<String> peers,
  required VoidCallback onSelected,
  bool enabled = true,
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [trustedPeerEmailsProvider.overrideWith((ref) async => peers)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: RecipientEmailField(
              controller: controller,
              label: 'Recipient email',
              placeholder: 'someone@example.com',
              enabled: enabled,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('typing filters trusted peers and shows matches', (tester) async {
    await _pump(
      tester,
      peers: ['alice@example.test', 'bob@example.test'],
      onSelected: () {},
    );

    await tester.enterText(find.byType(EditableText), 'ali');
    await tester.pumpAndSettle();

    expect(find.text('alice@example.test'), findsOneWidget);
    expect(find.text('bob@example.test'), findsNothing);
  });

  testWidgets('picking a suggestion fills the field and runs discovery', (
    tester,
  ) async {
    var discovered = false;
    final controller = await _pump(
      tester,
      peers: ['alice@example.test'],
      onSelected: () => discovered = true,
    );

    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pumpAndSettle();
    await tester.tap(find.text('alice@example.test'));
    await tester.pumpAndSettle();

    expect(controller.text, 'alice@example.test');
    expect(discovered, isTrue);
  });

  testWidgets('shows nothing while disabled', (tester) async {
    await _pump(
      tester,
      peers: ['alice@example.test'],
      onSelected: () {},
      enabled: false,
    );

    await tester.tap(find.byType(EditableText), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('alice@example.test'), findsNothing);
  });
}
