import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/widgets/adaptive.dart';

/// Renders at [width] and reports what the size-class helpers say about it.
Future<({bool expanded, bool medium})> _at(
  WidgetTester tester,
  double width,
) async {
  late bool expanded;
  late bool medium;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(
        builder: (context) {
          expanded = isExpandedWidth(context);
          medium = isMediumWidth(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (expanded: expanded, medium: medium);
}

void main() {
  testWidgets('a phone is neither medium nor expanded', (tester) async {
    final r = await _at(tester, 393); // iPhone 15/17 portrait
    expect(r.medium, isFalse);
    expect(r.expanded, isFalse);
  });

  testWidgets('a tablet in portrait earns a second pane, not the rail', (
    tester,
  ) async {
    final r = await _at(tester, 834); // iPad portrait
    expect(r.medium, isTrue);
    expect(r.expanded, isFalse);
  });

  testWidgets('a tablet in landscape earns the rail', (tester) async {
    final r = await _at(tester, 1194); // iPad landscape
    expect(r.expanded, isTrue);
  });

  testWidgets('a narrow window on a big screen stays compact', (tester) async {
    // iPad Split View and a half-width macOS window hand the app a phone
    // width on a large device — structure follows the width it is given,
    // never the hardware it runs on.
    final r = await _at(tester, 507);
    expect(r.expanded, isFalse);
    expect(r.medium, isFalse);
  });

  testWidgets('the breakpoints are exact, not approximate', (tester) async {
    expect((await _at(tester, kExpandedWidthBreakpoint - 1)).expanded, isFalse);
    expect((await _at(tester, kExpandedWidthBreakpoint)).expanded, isTrue);
    expect((await _at(tester, kMediumWidthBreakpoint - 1)).medium, isFalse);
    expect((await _at(tester, kMediumWidthBreakpoint)).medium, isTrue);
  });
}
