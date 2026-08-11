import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Width at which the full toolbar fits without scrolling. Below this we
/// collapse non-essential buttons into a "more" popup so mobile isn't
/// stuck with a horizontally scrolling tool belt.
const double _kCompactThreshold = 520;

/// Allowed zoom steps. Capped at 50–200% so the document stays readable
/// (too small drops below legibility, too large pushes content off-screen).
const List<double> _zoomSteps = [
  0.5,
  0.6,
  0.7,
  0.8,
  0.9,
  1.0,
  1.1,
  1.25,
  1.5,
  1.75,
  2.0,
];

enum _ToolbarAction {
  bold,
  italic,
  strike,
  h1,
  h2,
  h3,
  bulletList,
  numberedList,
  blockquote,
  codeBlock,
  table,
  undo,
  redo,
  zoomOut,
  zoomReset,
  zoomIn,
  exportPdf,
  history,
}

/// Horizontal formatting toolbar shown at the bottom of the editor.
///
/// Emits Milkdown command names (and optional payloads) via [onCommand];
/// the host screen forwards them to the webview over the HoodikBridge.
/// Also hosts the zoom controls, which write directly to
/// [editorZoomProvider] — the host listens and pushes the new scale to
/// the webview's CSS.
///
/// On narrow widths the less-common buttons collapse into a `⋯` menu so
/// mobile users aren't forced to horizontally scroll a tool belt.
class FormattingToolbar extends ConsumerWidget {
  final void Function(String command, [dynamic payload]) onCommand;

  /// Optional — when set, renders a history icon at the trailing end of
  /// the toolbar. Tapping pushes the version-history screen for the
  /// active note. Hidden when null so the toolbar still works for
  /// non-editable contexts that don't have history.
  final VoidCallback? onHistory;

  /// Optional — when set, renders a print icon at the trailing end of
  /// the toolbar. Tapping renders the active note to a PDF and hands
  /// it to the platform share sheet.
  final VoidCallback? onExportPdf;

  /// Optional — when set and the keyboard is open, renders a hide-keyboard
  /// button at the leading edge. The WebView holds native focus, so the
  /// host dismisses by blurring the editor's active element rather than
  /// unfocusing a Flutter node.
  final VoidCallback? onHideKeyboard;

  const FormattingToolbar({
    super.key,
    required this.onCommand,
    this.onHistory,
    this.onExportPdf,
    this.onHideKeyboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final zoom = ref.watch(editorZoomProvider);
    void setZoom(double next) =>
        ref.read(editorZoomProvider.notifier).state = next;
    final hideKeyboard =
        onHideKeyboard != null && MediaQuery.viewInsetsOf(context).bottom > 0
        ? onHideKeyboard
        : null;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.panel,
        border: Border(top: BorderSide(color: context.colors.seam, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _kCompactThreshold;
            return compact
                ? _buildCompact(context, l10n, zoom, setZoom, hideKeyboard)
                : _buildFull(context, l10n, zoom, setZoom, hideKeyboard);
          },
        ),
      ),
    );
  }

  /// Full layout — every action inline, separated by dividers.
  Widget _buildFull(
    BuildContext context,
    AppLocalizations l10n,
    double zoom,
    ValueChanged<double> setZoom,
    VoidCallback? hideKeyboard,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          if (hideKeyboard != null) ...[
            _iconButton(
              context,
              Icons.keyboard_hide_outlined,
              l10n.notesHideKeyboard,
              onTap: hideKeyboard,
            ),
            _divider(context),
          ],
          _iconButton(
            context,
            Icons.format_bold,
            l10n.notesBold,
            onTap: _boldTap,
          ),
          _iconButton(
            context,
            Icons.format_italic,
            l10n.notesItalic,
            onTap: _italicTap,
          ),
          _iconButton(
            context,
            Icons.strikethrough_s,
            l10n.notesStrikethrough,
            onTap: _strikeTap,
          ),
          _divider(context),
          _headingButton(context, l10n, 1),
          _headingButton(context, l10n, 2),
          _headingButton(context, l10n, 3),
          _divider(context),
          _iconButton(
            context,
            Icons.format_list_bulleted,
            l10n.notesBulletList,
            onTap: _bulletTap,
          ),
          _iconButton(
            context,
            Icons.format_list_numbered,
            l10n.notesNumberedList,
            onTap: _numberedTap,
          ),
          _iconButton(
            context,
            Icons.format_quote,
            l10n.notesBlockquote,
            onTap: _quoteTap,
          ),
          _iconButton(context, Icons.code, l10n.notesCode, onTap: _codeTap),
          _iconButton(
            context,
            Icons.table_chart_outlined,
            l10n.notesTable,
            onTap: _tableTap,
          ),
          _divider(context),
          _iconButton(context, Icons.undo, l10n.notesUndo, onTap: _undoTap),
          _iconButton(context, Icons.redo, l10n.notesRedo, onTap: _redoTap),
          _divider(context),
          _ZoomControls(zoom: zoom, onChange: setZoom),
          if (onExportPdf != null) ...[
            _divider(context),
            _iconButton(
              context,
              Icons.picture_as_pdf_outlined,
              l10n.notesExportToPdf,
              onTap: onExportPdf!,
            ),
          ],
          if (onHistory != null) ...[
            _divider(context),
            _iconButton(
              context,
              Icons.history,
              l10n.notesHistory,
              onTap: onHistory!,
            ),
          ],
        ],
      ),
    );
  }

  /// Compact layout for mobile — most-used actions inline plus a more-menu
  /// that carries the less-common actions (strike, h1/h3, numbered list,
  /// code, table, redo) and the optional PDF export + history entries. The
  /// whole row is horizontally scrollable so the zoom controls at the end
  /// remain reachable on 320-dp-class phones where even the trimmed set
  /// can't fit without overflow.
  Widget _buildCompact(
    BuildContext context,
    AppLocalizations l10n,
    double zoom,
    ValueChanged<double> setZoom,
    VoidCallback? hideKeyboard,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          if (hideKeyboard != null) ...[
            _iconButton(
              context,
              Icons.keyboard_hide_outlined,
              l10n.notesHideKeyboard,
              onTap: hideKeyboard,
            ),
            _divider(context),
          ],
          _iconButton(
            context,
            Icons.format_bold,
            l10n.notesBold,
            onTap: _boldTap,
          ),
          _iconButton(
            context,
            Icons.format_italic,
            l10n.notesItalic,
            onTap: _italicTap,
          ),
          _headingButton(context, l10n, 2),
          _iconButton(
            context,
            Icons.format_list_bulleted,
            l10n.notesBulletList,
            onTap: _bulletTap,
          ),
          _iconButton(
            context,
            Icons.format_quote,
            l10n.notesBlockquote,
            onTap: _quoteTap,
          ),
          _iconButton(context, Icons.undo, l10n.notesUndo, onTap: _undoTap),
          _buildMoreMenu(context, l10n),
          _divider(context),
          _ZoomControls(zoom: zoom, onChange: setZoom),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, AppLocalizations l10n) {
    return PopupMenuButton<_ToolbarAction>(
      tooltip: l10n.notesMore,
      icon: Icon(Icons.more_horiz, size: 20, color: context.colors.iconMuted),
      onSelected: (action) {
        switch (action) {
          case _ToolbarAction.strike:
            _strikeTap();
          case _ToolbarAction.h1:
            onCommand('WrapInHeading', 1);
          case _ToolbarAction.h3:
            onCommand('WrapInHeading', 3);
          case _ToolbarAction.numberedList:
            _numberedTap();
          case _ToolbarAction.codeBlock:
            _codeTap();
          case _ToolbarAction.table:
            _tableTap();
          case _ToolbarAction.redo:
            _redoTap();
          case _ToolbarAction.exportPdf:
            onExportPdf?.call();
          case _ToolbarAction.history:
            onHistory?.call();
          // Actions not in this menu fall through silently.
          case _ToolbarAction.bold:
          case _ToolbarAction.italic:
          case _ToolbarAction.h2:
          case _ToolbarAction.bulletList:
          case _ToolbarAction.blockquote:
          case _ToolbarAction.undo:
          case _ToolbarAction.zoomIn:
          case _ToolbarAction.zoomOut:
          case _ToolbarAction.zoomReset:
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ToolbarAction.strike,
          child: _MoreMenuItem(
            icon: Icons.strikethrough_s,
            label: l10n.notesStrikethrough,
          ),
        ),
        PopupMenuItem(
          value: _ToolbarAction.h1,
          child: _MoreMenuItem(icon: Icons.title, label: l10n.notesHeading(1)),
        ),
        PopupMenuItem(
          value: _ToolbarAction.h3,
          child: _MoreMenuItem(icon: Icons.title, label: l10n.notesHeading(3)),
        ),
        PopupMenuItem(
          value: _ToolbarAction.numberedList,
          child: _MoreMenuItem(
            icon: Icons.format_list_numbered,
            label: l10n.notesNumberedList,
          ),
        ),
        PopupMenuItem(
          value: _ToolbarAction.codeBlock,
          child: _MoreMenuItem(icon: Icons.code, label: l10n.notesCode),
        ),
        PopupMenuItem(
          value: _ToolbarAction.table,
          child: _MoreMenuItem(
            icon: Icons.table_chart_outlined,
            label: l10n.notesTable,
          ),
        ),
        PopupMenuItem(
          value: _ToolbarAction.redo,
          child: _MoreMenuItem(icon: Icons.redo, label: l10n.notesRedo),
        ),
        if (onExportPdf != null)
          PopupMenuItem(
            value: _ToolbarAction.exportPdf,
            child: _MoreMenuItem(
              icon: Icons.picture_as_pdf_outlined,
              label: l10n.notesExportToPdf,
            ),
          ),
        if (onHistory != null)
          PopupMenuItem(
            value: _ToolbarAction.history,
            child: _MoreMenuItem(icon: Icons.history, label: l10n.notesHistory),
          ),
      ],
    );
  }

  // Per-action tap handlers — kept as named closures so both layouts
  // (full + compact + menu) can reuse them without duplicating the
  // command string.
  void _boldTap() => onCommand('ToggleStrong');
  void _italicTap() => onCommand('ToggleEmphasis');
  void _strikeTap() => onCommand('ToggleStrikeThrough');
  void _bulletTap() => onCommand('WrapInBulletList');
  void _numberedTap() => onCommand('WrapInOrderedList');
  void _quoteTap() => onCommand('WrapInBlockquote');
  void _codeTap() => onCommand('CreateCodeBlock');
  void _tableTap() => onCommand('InsertTable');
  void _undoTap() => onCommand('Undo');
  void _redoTap() => onCommand('Redo');

  Widget _iconButton(
    BuildContext context,
    IconData icon,
    String tooltip, {
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: context.colors.iconMuted),
        ),
      ),
    );
  }

  Widget _headingButton(
    BuildContext context,
    AppLocalizations l10n,
    int level,
  ) {
    return Tooltip(
      message: l10n.notesHeading(level),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onCommand('WrapInHeading', level),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'H$level',
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: context.colors.seam,
    );
  }
}

/// Zoom-out / percentage / zoom-in cluster. Tapping the percentage label
/// resets to 100%.
class _ZoomControls extends StatelessWidget {
  final double zoom;
  final ValueChanged<double> onChange;

  const _ZoomControls({required this.zoom, required this.onChange});

  double _nextStep(double current, {required bool up}) {
    int idx = _zoomSteps.indexWhere((s) => (s - current).abs() < 0.001);
    if (idx < 0) {
      idx = 0;
      var best = (_zoomSteps[0] - current).abs();
      for (var i = 1; i < _zoomSteps.length; i++) {
        final d = (_zoomSteps[i] - current).abs();
        if (d < best) {
          best = d;
          idx = i;
        }
      }
    }
    final nextIdx = (idx + (up ? 1 : -1)).clamp(0, _zoomSteps.length - 1);
    return _zoomSteps[nextIdx];
  }

  @override
  Widget build(BuildContext context) {
    final canZoomOut = zoom > _zoomSteps.first + 0.001;
    final canZoomIn = zoom < _zoomSteps.last - 0.001;
    final percent = (zoom * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: AppLocalizations.of(context).notesZoomOut,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: canZoomOut
                ? () => onChange(_nextStep(zoom, up: false))
                : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.zoom_out,
                size: 20,
                color: canZoomOut
                    ? context.colors.iconMuted
                    : context.colors.iconMuted,
              ),
            ),
          ),
        ),
        Tooltip(
          message: AppLocalizations.of(context).notesResetZoom,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onChange(1.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: SizedBox(
                width: 38,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: AppLocalizations.of(context).notesZoomIn,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: canZoomIn ? () => onChange(_nextStep(zoom, up: true)) : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.zoom_in,
                size: 20,
                color: canZoomIn
                    ? context.colors.iconMuted
                    : context.colors.iconMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MoreMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.iconMuted),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
