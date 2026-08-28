import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Host-side find session. Keeps query/count/index and talks to the editor
/// over the existing bridge so [NotesWorkspace] stays under its line cap.
class NoteFindHost {
  NoteFindHost(this._send, this._onChange);

  final void Function(String type, Map<String, dynamic> payload) _send;
  final VoidCallback _onChange;

  bool visible = false;
  bool caseSensitive = false;
  int count = 0;
  int index = 0;
  String? _pending;
  final controller = TextEditingController();
  final focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }

  void _sendFind(String query) {
    _send('find', {'query': query, 'caseSensitive': caseSensitive});
  }

  /// Stash [query] and show the bar. Does not talk to the editor — call
  /// [sync] once the active tab's content is in the webview.
  void prime(String? query, {bool notify = true}) {
    if (query == null || query.isEmpty) return;
    _pending = query;
    controller.text = query;
    visible = true;
    count = 0;
    index = 0;
    if (notify) _onChange();
  }

  void sync({required bool editorReady, required bool tabLoaded}) {
    if (!editorReady || !tabLoaded) return;
    final q = _pending ?? (visible ? controller.text : '');
    _pending = null;
    if (q.isEmpty) return;
    _sendFind(q);
  }

  void show() {
    visible = true;
    _onChange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focus.canRequestFocus) focus.requestFocus();
    });
  }

  void hide() {
    _send('clearFind', const <String, dynamic>{});
    _pending = null;
    controller.clear();
    visible = false;
    count = 0;
    index = 0;
    _onChange();
  }

  void toggleCaseSensitive() {
    caseSensitive = !caseSensitive;
    final q = controller.text;
    if (q.isNotEmpty) {
      _sendFind(q);
    } else {
      _onChange();
    }
  }

  void onQuery(String query) {
    if (query.isEmpty) {
      _send('clearFind', const <String, dynamic>{});
      count = 0;
      index = 0;
      _onChange();
      return;
    }
    _sendFind(query);
  }

  void onResult(Map<String, dynamic> msg) {
    count = (msg['count'] as num?)?.toInt() ?? 0;
    index = (msg['index'] as num?)?.toInt() ?? 0;
    _onChange();
  }

  Widget? buildBar() {
    if (!visible) return null;
    return NoteFindBar(
      controller: controller,
      focusNode: focus,
      count: count,
      index: index,
      caseSensitive: caseSensitive,
      onQueryChanged: onQuery,
      onToggleCaseSensitive: toggleCaseSensitive,
      onNext: () => _send('findNext', const <String, dynamic>{}),
      onPrev: () => _send('findPrev', const <String, dynamic>{}),
      onClose: hide,
    );
  }
}

/// In-note find chrome: query, match count, case, next/prev, close.
class NoteFindBar extends StatelessWidget {
  const NoteFindBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.count,
    required this.index,
    required this.caseSensitive,
    required this.onQueryChanged,
    required this.onToggleCaseSensitive,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int count;
  final int index;
  final bool caseSensitive;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleCaseSensitive;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final displayIndex = count <= 0 ? 0 : index + 1;
    return Material(
      color: colors.panel,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.seam, width: 0.5)),
        ),
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            Icon(AppIcons.search, size: 18, color: colors.iconMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: colors.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.notesFind,
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: onQueryChanged,
                onSubmitted: (_) => onNext(),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.notesFindMatches(displayIndex, count),
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            IconButton(
              icon: Text(
                'Aa',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: caseSensitive ? colors.textCrimson : colors.iconMuted,
                ),
              ),
              tooltip: l10n.notesFindCaseSensitive,
              onPressed: onToggleCaseSensitive,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(
                isApplePlatform
                    ? CupertinoIcons.chevron_up
                    : Icons.keyboard_arrow_up,
              ),
              tooltip: l10n.notesFindPrev,
              onPressed: count == 0 ? null : onPrev,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(
                isApplePlatform
                    ? CupertinoIcons.chevron_down
                    : Icons.keyboard_arrow_down,
              ),
              tooltip: l10n.notesFindNext,
              onPressed: count == 0 ? null : onNext,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(AppIcons.close),
              tooltip: l10n.notesFindClose,
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
