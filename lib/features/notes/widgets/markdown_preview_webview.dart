import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/hoodik_scheme.dart';

/// Read-only markdown viewer that hosts the same `editor.html` (Milkdown)
/// the live editor uses, but locks editing off. Gives version-history
/// previews byte-identical rendering to the editor — same theme, fonts,
/// node styles — without forking a second renderer.
///
/// External links (http/https) open in the system browser; in-page
/// anchor links (`#section`) are handled natively by the webview's
/// scroll behaviour.
class MarkdownPreviewWebView extends StatefulWidget {
  final String content;

  const MarkdownPreviewWebView({super.key, required this.content});

  @override
  State<MarkdownPreviewWebView> createState() => _MarkdownPreviewWebViewState();
}

class _MarkdownPreviewWebViewState extends State<MarkdownPreviewWebView> {
  late final WebViewController _controller;
  bool _ready = false;
  Brightness? _brightness;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'HoodikBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // editor.html is loaded with `about:blank` baseUrl, so any
            // navigation away from that is a click on an external
            // (http/https) link — hand off to the system browser.
            // In-page hash navigation arrives as `about:blank#…` which
            // we let through so the webview's native scroll fires.
            final url = request.url;
            if (url.startsWith('http://') || url.startsWith('https://')) {
              unawaited(
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    _loadEditor();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited widgets aren't resolvable from `initState`, and this re-runs
    // on every appearance change — which is when the preview has to follow.
    final brightness = Theme.of(context).brightness;
    if (!Platform.isMacOS) {
      _controller.setBackgroundColor(context.colors.canvas);
    }
    if (_ready && brightness != _brightness) _pushTheme(brightness);
    _brightness = brightness;
  }

  /// The editor stylesheet is light by default and dark under a `.dark`
  /// root class, so the host owns the switch.
  void _pushTheme(Brightness brightness) => _send('setTheme', {
    'theme': brightness == Brightness.dark ? 'dark' : 'light',
  });

  Future<void> _loadEditor() async {
    final html = await rootBundle.loadString('assets/editor/editor.html');
    await _controller.loadHtmlString(html, baseUrl: 'about:blank');
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (msg['type'] != 'ready' || _ready) return;

    _ready = true;
    _pushTheme(_brightness ?? Theme.of(context).brightness);
    // Push content + lock editing off. Order matters: set editable
    // before setContent so Milkdown configures node selection in
    // read-only mode from the start.
    _send('setEditable', {'editable': false});
    _send('setContent', {'markdown': widget.content});
  }

  void _send(String type, Map<String, dynamic> payload) {
    final msg = jsonEncode({'type': type, ...payload});
    _controller.runJavaScript(
      'window.hoodik.receiveMessage(${jsonEncode(msg)})',
    );
  }

  @override
  void didUpdateWidget(covariant MarkdownPreviewWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.content != widget.content) {
      _send('setContent', {'markdown': widget.content});
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
