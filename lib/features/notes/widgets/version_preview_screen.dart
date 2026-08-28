import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_models.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'markdown_preview_webview.dart';

/// Full-screen renderer for a historical version's content. Pops with
/// `'restore'` when the user taps the restore action so the parent can
/// chain into the existing confirm-then-restore flow without forcing
/// the user to swipe back and tap again.
class VersionPreviewScreen extends StatefulWidget {
  final FileVersion version;
  final String content;
  final String dateLabel;

  const VersionPreviewScreen({
    super.key,
    required this.version,
    required this.content,
    required this.dateLabel,
  });

  @override
  State<VersionPreviewScreen> createState() => _VersionPreviewScreenState();
}

class _VersionPreviewScreenState extends State<VersionPreviewScreen> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    Navigator.of(context).maybePop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.version;
    final dateLabel = widget.dateLabel;
    final content = widget.content;
    return Scaffold(
      appBar: AppBar(
        title: Text('v${version.version} · $dateLabel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: AppLocalizations.of(context).notesRestoreThisVersion,
            onPressed: () => Navigator.of(context).pop('restore'),
          ),
        ],
      ),
      // Reuse the live editor's HTML/Milkdown stack in read-only mode
      // so rendering matches the editor, including TOC anchors.
      body: MarkdownPreviewWebView(content: content),
    );
  }
}
