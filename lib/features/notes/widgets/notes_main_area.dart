import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../models/editor_tab.dart';
import 'formatting_toolbar.dart';
import 'ios_editor_layout.dart';
import 'notes_tab_bar.dart';

/// Composes the editor chrome below the app bar: the tab strip on top,
/// the WebView in the middle, the formatting toolbar at the bottom.
///
/// On iOS the layout delegates to [IosEditorLayout] (Stack with a
/// floating, keyboard-aware toolbar); on every other platform it falls
/// back to a plain [Column]. The platform branch lives here so
/// `notes_workspace.dart` only needs to wire callbacks.
class NotesMainArea extends StatelessWidget {
  final List<EditorTab> tabs;
  final int activeTabIndex;
  final bool showTabs;
  final bool editorReady;
  final Widget editor;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onCloseTab;
  final VoidCallback? onExpandSidebar;
  final void Function(String command, [dynamic payload]) onCommand;
  final VoidCallback onHistory;
  final VoidCallback onExportPdf;

  const NotesMainArea({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.showTabs,
    required this.editorReady,
    required this.editor,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onExpandSidebar,
    required this.onCommand,
    required this.onHistory,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final tabBar = showTabs
        ? NotesTabBar(
            tabs: tabs,
            activeIndex: activeTabIndex,
            onSelect: onSelectTab,
            onClose: onCloseTab,
            onExpandSidebar: onExpandSidebar,
          )
        : null;
    final toolbar = tabs[activeTabIndex].editable && editorReady
        ? FormattingToolbar(
            onCommand: onCommand,
            onHistory: onHistory,
            onExportPdf: onExportPdf,
          )
        : null;
    if (Platform.isIOS) {
      return IosEditorLayout(tabBar: tabBar, toolbar: toolbar, editor: editor);
    }
    return Column(
      children: [
        ?tabBar,
        Expanded(child: editor),
        ?toolbar,
      ],
    );
  }
}
