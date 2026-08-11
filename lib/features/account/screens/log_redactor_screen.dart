import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/log_export_service.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Second step of the bug-report flow: load log lines, let the user remove
/// any they don't want to share, then hand the remainder to the native
/// share sheet or the clipboard.
class LogRedactorScreen extends StatefulWidget {
  const LogRedactorScreen({super.key, LogExportService? serviceOverride})
    : _serviceOverride = serviceOverride;

  final LogExportService? _serviceOverride;

  @override
  State<LogRedactorScreen> createState() => _LogRedactorScreenState();
}

class _LogRedactorScreenState extends State<LogRedactorScreen> {
  late final LogExportService _service =
      widget._serviceOverride ?? LogExportService();

  /// When true, only lines from the current app session are loaded; when
  /// false, every retained line (up to 3 days) is loaded.
  bool _currentSessionOnly = true;

  /// Loaded + formatted log lines the user can pick from.
  List<String> _lines = const [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final lines = await _service.loadLines(
        currentSessionOnly: _currentSessionOnly,
      );
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lines = const [];
        _loading = false;
      });
    }
  }

  void _removeAt(int index) {
    setState(() {
      _lines = [..._lines.sublist(0, index), ..._lines.sublist(index + 1)];
    });
  }

  void _clearAll() {
    setState(() => _lines = const []);
  }

  Future<void> _copyToClipboard() async {
    if (_lines.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: _service.clipboardContent(_lines)),
    );
    if (!mounted) return;
    AppNotification.show(
      context,
      message: AppLocalizations.of(context).accountLogsCopied,
    );
  }

  Future<void> _sendViaEmail() async {
    if (_lines.isEmpty) return;
    try {
      final file = await _service.writeExportFile(_lines);
      await _service.shareViaEmail(file);
    } catch (_) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).accountLogsShareFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountLogsReviewTitle),
        centerTitle: isApplePlatform,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ScopeToggle(
              currentSessionOnly: _currentSessionOnly,
              onChanged: (value) {
                setState(() => _currentSessionOnly = value);
                _reload();
              },
            ),
            if (!_loading && _lines.isNotEmpty)
              _Toolbar(count: _lines.length, onClear: _clearAll),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : _lines.isEmpty
                  ? _Empty(theme: theme)
                  : ListView.separated(
                      itemCount: _lines.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) => _LineTile(
                        text: _lines[index],
                        onDismissed: () => _removeAt(index),
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    AdaptiveButton(
                      onPressed: _lines.isEmpty ? null : _sendViaEmail,
                      child: Text(
                        l10n.accountLogsSendViaEmail(
                          LogExportService.supportEmail,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AdaptiveTextButton(
                      onPressed: _lines.isEmpty ? null : _copyToClipboard,
                      child: Text(l10n.accountLogsCopyToClipboard),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({
    required this.currentSessionOnly,
    required this.onChanged,
  });

  final bool currentSessionOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(
            value: true,
            label: Text(l10n.accountLogsCurrentSession),
          ),
          ButtonSegment(value: false, label: Text(l10n.accountLogsPastDays)),
        ],
        selected: {currentSessionOnly},
        onSelectionChanged: (sel) => onChanged(sel.first),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Text(
            l10n.accountLogsLineCount(count),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          TextButton(onPressed: onClear, child: Text(l10n.accountLogsClearAll)),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.text, required this.onDismissed});

  final String text;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(identityHashCode(this)),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: context.colors.dangerFill.withValues(alpha: 0.1),
        child: Icon(
          isApplePlatform ? CupertinoIcons.delete : AppIcons.delete,
          color: context.colors.dangerFill,
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isApplePlatform
                  ? CupertinoIcons.doc_text_search
                  : Icons.text_snippet_outlined,
              size: 48,
              color: muted,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).accountLogsEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).accountLogsEmptyBody,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
