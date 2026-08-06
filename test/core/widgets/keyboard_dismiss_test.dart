import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/widgets/keyboard_dismiss.dart';

void main() {
  testWidgets('tap on empty space releases focus', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            KeyboardDismissOnTap(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: focusNode),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('tapping the field itself keeps focus', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            KeyboardDismissOnTap(child: child ?? const SizedBox.shrink()),
        home: Scaffold(body: TextField(focusNode: focusNode)),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  });
}
