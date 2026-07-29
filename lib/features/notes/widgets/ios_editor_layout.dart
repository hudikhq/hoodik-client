import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Intrinsic height of the formatting toolbar's button row (matches
/// IconButton's 48px default plus 4px of vertical padding in the row).
///
/// Used in two places that must stay in lockstep: the layout below
/// reserves this much space under the editor, and [injectIosCaretInset]
/// pushes the same value into the WebView so WKWebView's auto-scroll
/// keeps the caret above the toolbar overlay.
const double kIosToolbarHeight = 52;

/// Tell WKWebView's auto-scroll to park the caret above the floating
/// toolbar instead of right under it. Without this, focus-induced
/// scrolling lines the caret up against the keyboard top — which is
/// exactly where the toolbar overlay sits.
void injectIosCaretInset(WebViewController controller) {
  final px = kIosToolbarHeight.toInt();
  controller.runJavaScript(
    '(()=>{const s=document.createElement("style");'
    's.id="hoodik-ios-toolbar-inset";'
    's.textContent=":root,html,body{scroll-padding-bottom:${px}px;}";'
    'document.head.appendChild(s);})();',
  );
}

/// iOS-specific notes editor layout. Renders the [tabBar], [editor], and
/// floating [toolbar] in a Stack so the WebView frame stays constant when
/// the keyboard rises.
///
/// Why a Stack rather than a Column: putting the toolbar inline in a
/// Column shrinks the [Expanded] editor whenever the toolbar resizes
/// (e.g., SafeArea bottom inset drops to zero when the keyboard hides
/// the home indicator). WKWebView dismisses its keyboard the instant
/// its frame changes mid-animation, which manifested as a keyboard that
/// "briefly opens then closes." Holding the editor's frame steady — and
/// floating the toolbar above the keyboard via [Positioned] — is the
/// only layout that keeps WKWebView happy.
///
/// The reserved bottom slot below the editor is sized from
/// [MediaQuery.viewPadding.bottom] (the home-indicator inset, which
/// stays stable when the keyboard rises) plus [kIosToolbarHeight]. When
/// the keyboard is hidden the toolbar sits inside this slot; when the
/// keyboard rises the toolbar lifts above it and the slot tucks under
/// the keyboard.
class IosEditorLayout extends StatelessWidget {
  final Widget? tabBar;
  final Widget? toolbar;
  final Widget editor;

  const IosEditorLayout({
    super.key,
    this.tabBar,
    this.toolbar,
    required this.editor,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final showToolbar = toolbar != null;
    final toolbarSlot = mq.viewPadding.bottom + kIosToolbarHeight;

    return Stack(
      children: [
        Column(
          children: [
            ?tabBar,
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: showToolbar ? toolbarSlot : 0),
                child: editor,
              ),
            ),
          ],
        ),
        if (toolbar != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.viewInsets.bottom,
            child: toolbar!,
          ),
      ],
    );
  }
}
