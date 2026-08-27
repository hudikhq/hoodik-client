import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/services/transfer_manager.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../preview/widgets/preview_loading.dart';
import '../models/editor_tab.dart';

/// Loading / error / WebView for the active note. Extracted from the
/// workspace so that file stays under its CI line cap.
class NotesEditorPane extends ConsumerWidget {
  const NotesEditorPane({
    super.key,
    required this.tab,
    required this.webViewController,
  });

  final EditorTab tab;
  final WebViewController webViewController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tab.loading || !tab.loaded) {
      final file = tab.file;
      if (file != null) {
        final manager = ref.watch(transferManagerProvider);
        final transfer = manager.transfers
            .where(
              (t) => t.fileId == file.id && t.status == TransferStatus.active,
            )
            .firstOrNull;
        return PreviewLoading(
          progress: transfer?.progress,
          stage: transfer?.type.label,
        );
      }
      return const PreviewLoading();
    }

    if (tab.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            tab.error!,
            style: TextStyle(color: context.colors.text, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return WebViewWidget(controller: webViewController);
  }
}
