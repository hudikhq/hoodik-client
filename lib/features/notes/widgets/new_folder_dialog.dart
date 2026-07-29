import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/hoodik_colors.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Ask the user for a name for a new folder.
///
/// Returns the entered name or `null` if cancelled. [parentFolderName]
/// is shown in the dialog to tell the user where the folder will be
/// created.
Future<String?> showNewFolderDialog({
  required BuildContext context,
  String? parentFolderName,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NewFolderDialog(parentFolderName: parentFolderName),
  );
}

class _NewFolderDialog extends StatefulWidget {
  final String? parentFolderName;

  const _NewFolderDialog({this.parentFolderName});

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _controller = TextEditingController();
  String? _error;

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
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = widget.parentFolderName == null
        ? l10n.notesCreateFolderInRoot
        : l10n.notesCreateFolderIn(widget.parentFolderName!);

    if (isApplePlatform) {
      return CupertinoAlertDialog(
        title: Text(l10n.notesNewFolder),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _controller,
                placeholder: l10n.notesFolderNameHint,
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: HoodikColors.redish400,
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
            child: Text(l10n.commonCreate),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.notesNewFolder),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.notesFolderNameHint,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.commonCreate)),
      ],
    );
  }
}
