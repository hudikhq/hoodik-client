import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';

/// A reader who turned motion off at the OS level still got every transition.
/// The surface is small — five implicit animations — which is exactly why it
/// was worth routing through one helper before more motion exists.
void main() {
  Future<Duration> resolve(
    WidgetTester tester, {
    required bool disabled,
  }) async {
    late Duration result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Builder(
          builder: (context) {
            result = motionDuration(context, const Duration(milliseconds: 250));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('motion plays at full length by default', (tester) async {
    expect(
      await resolve(tester, disabled: false),
      const Duration(milliseconds: 250),
    );
  });

  testWidgets('Reduce Motion collapses it to an instant cut', (tester) async {
    // Zero rather than "fast": an implicit animation with no duration jumps to
    // its end state, which is the behaviour the setting asks for.
    expect(await resolve(tester, disabled: true), Duration.zero);
  });
}
