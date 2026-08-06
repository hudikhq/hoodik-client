import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/router.dart';

/// Reproduces the MainShell Apple layout: CupertinoPageScaffold with the
/// tab bar as a Column sibling of the branch content, and the branch
/// wrapped in [ShellBranchInsets].
Widget _shell({required bool resizeToAvoidBottomInset, required Widget probe}) {
  return CupertinoApp(
    home: CupertinoPageScaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: Column(
        children: [Expanded(child: ShellBranchInsets(child: probe))],
      ),
    ),
  );
}

void main() {
  testWidgets('keyboard inset consumed by the scaffold is not re-injected', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    late MediaQueryData seen;
    await tester.pumpWidget(
      _shell(
        resizeToAvoidBottomInset: true,
        probe: Builder(
          builder: (context) {
            seen = MediaQuery.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    // The scaffold consumed the inset by shrinking the branch; if the
    // branch saw it again, every sheet inside would pad by another
    // keyboard height (the double-inset bug).
    expect(seen.viewInsets.bottom, 0);
  });

  testWidgets('raw keyboard inset passes through when resize is off', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    late MediaQueryData seen;
    await tester.pumpWidget(
      _shell(
        resizeToAvoidBottomInset: false,
        probe: Builder(
          builder: (context) {
            seen = MediaQuery.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    // The Notes branch turns resize off and positions its toolbar by the
    // raw inset — that path must keep seeing the full keyboard height.
    expect(seen.viewInsets.bottom, 300 / tester.view.devicePixelRatio);
  });

  testWidgets('bottom safe-area padding is stripped for the branch', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);

    late MediaQueryData seen;
    await tester.pumpWidget(
      _shell(
        resizeToAvoidBottomInset: true,
        probe: Builder(
          builder: (context) {
            seen = MediaQuery.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    expect(seen.padding.bottom, 0);
  });
}
