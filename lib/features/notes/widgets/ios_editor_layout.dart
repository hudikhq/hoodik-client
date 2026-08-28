import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Intrinsic height of the formatting toolbar's button row (matches
/// IconButton's 48px default plus 4px of vertical padding in the row).
///
/// The layout reserves this much room under the editor and adds it back
/// when working out how much of the editor the floating toolbar covers, so
/// it has to track the toolbar's real height.
const double kIosToolbarHeight = 52;

/// Shrink the editor's scroll container by [inset] logical pixels so the
/// part of the WebView hidden behind the keyboard (and the floating
/// toolbar above it) stops counting as visible, then pull the caret back
/// into what's left.
///
/// The WebView's native frame deliberately does not move when the keyboard
/// rises — see [IosEditorLayout] — so WKWebView believes its whole height
/// is on screen and never scrolls the caret clear of the keyboard. Without
/// this the last lines of a note are unreachable while typing; the only
/// workaround was padding the document with blank lines.
void applyIosEditorInset(WebViewController controller, double inset) {
  final px = inset.round();
  controller.runJavaScript(
    '(()=>{'
    'let s=document.getElementById("hoodik-ios-inset");'
    'if(!s){s=document.createElement("style");s.id="hoodik-ios-inset";'
    'document.head.appendChild(s);}'
    's.textContent="#editor{height:calc(100% - ${px}px);}";'
    'const sel=document.getSelection();'
    'const n=sel&&sel.rangeCount?sel.getRangeAt(0).startContainer:null;'
    'const el=n?(n.nodeType===1?n:n.parentElement):null;'
    'if(el)el.scrollIntoView({block:"nearest"});'
    '})();',
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
///
/// Whatever the keyboard and toolbar then cover of the steady WebView
/// frame is reported through [onBottomInsetChanged], which the host feeds
/// back into the page via [applyIosEditorInset].
class IosEditorLayout extends StatefulWidget {
  final Widget? tabBar;
  final Widget? findBar;
  final Widget? toolbar;
  final Widget editor;
  final ValueChanged<double> onBottomInsetChanged;

  const IosEditorLayout({
    super.key,
    this.tabBar,
    this.findBar,
    this.toolbar,
    required this.editor,
    required this.onBottomInsetChanged,
  });

  @override
  State<IosEditorLayout> createState() => _IosEditorLayoutState();
}

class _IosEditorLayoutState extends State<IosEditorLayout> {
  double? _reportedInset;

  double _reservedSlot(MediaQueryData mq) =>
      widget.toolbar == null ? 0 : mq.viewPadding.bottom + kIosToolbarHeight;

  /// How much of the editor's frame the keyboard and the floating toolbar
  /// cover, after subtracting the slot already reserved below the frame.
  double _obscuredEditorHeight(MediaQueryData mq) {
    final covered =
        mq.viewInsets.bottom + (widget.toolbar == null ? 0 : kIosToolbarHeight);
    return math.max(0, covered - _reservedSlot(mq));
  }

  /// The keyboard's arrival lands here rather than in `build` — MediaQuery
  /// changes are a dependency change, and the report is a side effect that
  /// has no business running on every rebuild.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportInset();
  }

  /// The toolbar appearing (or going away with a read-only tab) changes the
  /// reserved slot without any MediaQuery involvement.
  @override
  void didUpdateWidget(IosEditorLayout old) {
    super.didUpdateWidget(old);
    if ((old.toolbar == null) != (widget.toolbar == null)) _reportInset();
  }

  void _reportInset() {
    final inset = _obscuredEditorHeight(MediaQuery.of(context));
    if (inset == _reportedInset) return;
    _reportedInset = inset;
    widget.onBottomInsetChanged(inset);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Stack(
      children: [
        Column(
          children: [
            ?widget.tabBar,
            ?widget.findBar,
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: _reservedSlot(mq)),
                child: widget.editor,
              ),
            ),
          ],
        ),
        if (widget.toolbar != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.viewInsets.bottom,
            child: widget.toolbar!,
          ),
      ],
    );
  }
}
