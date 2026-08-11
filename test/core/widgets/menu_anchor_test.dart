import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/widgets/menu_anchor.dart';

/// The shell's branch navigators sit beside the navigation rail, so their
/// overlay does not start at the window origin. `showMenu` measures against
/// that overlay, and every context menu in the app hands it a point captured
/// in global coordinates — the conversion in between is the whole fix.
///
/// The padding stands in for the rail: it pushes the app (and with it the
/// overlay) 300 right and 100 down of the window origin.
void main() {
  const railWidth = 300.0;
  const chromeHeight = 100.0;
  const tap = Offset(400, 300);

  testWidgets('a menu opens at the global point it was asked for', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Padding(
        padding: EdgeInsets.only(left: railWidth, top: chromeHeight),
        child: MaterialApp(home: _Host(tapPoint: tap)),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final menu = tester.getTopLeft(
      find.ancestor(
        of: find.text('Rename'),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(menu.dx, moreOrLessEquals(tap.dx, epsilon: 1));
    expect(menu.dy, moreOrLessEquals(tap.dy, epsilon: 1));
  });
}

class _Host extends StatelessWidget {
  final Offset tapPoint;

  const _Host({required this.tapPoint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showMenu<void>(
              context: ctx,
              position: menuAnchorAt(ctx, tapPoint),
              items: const [
                PopupMenuItem<void>(child: Text('Rename')),
                PopupMenuItem<void>(child: Text('Delete')),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}
