import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hoodik_app/features/notes/widgets/ios_editor_layout.dart';

/// Locks the WebView frame against viewInsets changes. The bug this
/// fixes: WKWebView dismisses its own keyboard the moment the editor
/// frame shrinks mid-rise. If a future change moves the toolbar back
/// into a Column (or adds keyboard-dependent padding around the editor),
/// these checks fail.
void main() {
  // Flutter widget tests run on an 800x600 surface unless overridden.
  // Asserting against the surface height keeps the test resolution-agnostic.
  const double surfaceHeight = 600;

  Future<void> pump(
    WidgetTester tester, {
    required double viewInsetsBottom,
    Widget? tabBar,
    Widget? toolbar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            viewPadding: const EdgeInsets.only(bottom: 34),
            viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: IosEditorLayout(
              tabBar: tabBar,
              toolbar: toolbar,
              editor: Container(key: const Key('editor')),
            ),
          ),
        ),
      ),
    );
  }

  Size editorSize(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('editor')));

  testWidgets('editor frame is identical with keyboard hidden and visible', (
    tester,
  ) async {
    final toolbar = Container(
      key: const Key('toolbar'),
      height: kIosToolbarHeight,
      color: Colors.red,
    );

    await pump(tester, viewInsetsBottom: 0, toolbar: toolbar);
    final hiddenSize = editorSize(tester);

    await pump(tester, viewInsetsBottom: 300, toolbar: toolbar);
    final visibleSize = editorSize(tester);

    expect(
      visibleSize,
      hiddenSize,
      reason:
          'editor frame must be constant — WKWebView dismisses the keyboard '
          'if its frame changes mid keyboard-rise animation',
    );
  });

  testWidgets('toolbar floats above the keyboard via Positioned', (
    tester,
  ) async {
    final toolbar = Container(
      key: const Key('toolbar'),
      height: kIosToolbarHeight,
      color: Colors.red,
    );

    await pump(tester, viewInsetsBottom: 300, toolbar: toolbar);

    final toolbarRect = tester.getRect(find.byKey(const Key('toolbar')));
    expect(
      toolbarRect.bottom,
      surfaceHeight - 300,
      reason: 'toolbar bottom should sit on top of the keyboard',
    );
  });

  testWidgets('editor reserves no bottom slot when there is no toolbar', (
    tester,
  ) async {
    await pump(tester, viewInsetsBottom: 0);
    // With no toolbar, the editor fills the full Scaffold body. The
    // test harness has no AppBar, so body == surface height.
    expect(editorSize(tester).height, surfaceHeight);
  });
}
