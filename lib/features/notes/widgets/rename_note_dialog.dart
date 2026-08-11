import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Ask the user for a new name for an existing note.
///
/// Returns the entered name (without enforcing `.md` — the caller decides)
/// or `null` if cancelled. The input is pre-filled with [currentName] and
/// its extension portion is excluded from the initial text selection so
/// the user can just retype the stem.
Future<String?> showRenameNoteDialog({
  required BuildContext context,
  required String currentName,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _RenameNoteDialog(currentName: currentName),
  );
}

class _RenameNoteDialog extends StatefulWidget {
  final String currentName;

  const _RenameNoteDialog({required this.currentName});

  @override
  State<_RenameNoteDialog> createState() => _RenameNoteDialogState();
}

class _RenameNoteDialogState extends State<_RenameNoteDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    // Pre-select the stem so users can type over it without deleting the
    // extension by accident.
    final dotIndex = widget.currentName.lastIndexOf('.');
    final end = dotIndex > 0 ? dotIndex : widget.currentName.length;
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: end);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).notesNameRequired);
      return;
    }
    if (raw == widget.currentName) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isApplePlatform) {
      return CupertinoAlertDialog(
        title: Text(l10n.notesRenameNote),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoTextField(
                controller: _controller,
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: HoodikColors.textCrimson,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _submit,
            child: Text(l10n.commonRename),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.notesRenameNote),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.commonRename)),
      ],
    );
  }
}
