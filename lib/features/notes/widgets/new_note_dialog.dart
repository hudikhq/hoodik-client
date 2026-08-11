import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/widgets/folder_picker_dialog.dart';

/// What the new-note dialog came back with: a name, and where to put it.
class NewNote {
  const NewNote({required this.name, this.parentDirId, this.parentName});

  final String name;

  /// `null` means the root folder.
  final String? parentDirId;
  final String? parentName;
}

/// Ask for a name and a destination for a new note.
///
/// Returns `null` if cancelled. The name is returned as typed — the caller
/// appends `.md`. [parentDirId] and [parentFolderName] seed the destination,
/// which the user can then change without leaving the dialog.
Future<NewNote?> showNewNoteDialog({
  required BuildContext context,
  String? parentDirId,
  String? parentFolderName,
}) {
  return showDialog<NewNote>(
    context: context,
    builder: (ctx) => _NewNoteDialog(
      parentDirId: parentDirId,
      parentFolderName: parentFolderName,
    ),
  );
}

class _NewNoteDialog extends ConsumerStatefulWidget {
  final String? parentDirId;
  final String? parentFolderName;

  const _NewNoteDialog({this.parentDirId, this.parentFolderName});

  @override
  ConsumerState<_NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends ConsumerState<_NewNoteDialog> {
  final _controller = TextEditingController();
  String? _error;
  late String? _parentDirId = widget.parentDirId;
  late String? _parentName = widget.parentFolderName;

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
    Navigator.of(context).pop(
      NewNote(name: raw, parentDirId: _parentDirId, parentName: _parentName),
    );
  }

  Future<void> _pickFolder() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    final picked = await showFolderPicker(
      context: context,
      client: client,
      fileCrypto: ref.read(fileCryptoProvider),
      confirmLabel: AppLocalizations.of(context).notesCreateHere,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _parentDirId = picked.folderId;
      _parentName = picked.folderName;
    });
  }

  String _destination(AppLocalizations l10n) => _parentName == null
      ? l10n.notesCreateNoteInRoot
      : l10n.notesCreateNoteIn(_parentName!);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isApplePlatform) {
      return CupertinoAlertDialog(
        title: Text(l10n.notesNewNote),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoTextField(
                controller: _controller,
                placeholder: l10n.notesNoteNameHint,
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _pickFolder,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.folder,
                      size: 16,
                      color: context.colors.iconEmber,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _destination(l10n),
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: context.colors.textCrimson,
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
      title: Text(l10n.notesNewNote),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.notesNoteNameHint,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickFolder,
            icon: Icon(
              AppIcons.folder,
              size: 18,
              color: context.colors.iconEmber,
            ),
            label: Text(_destination(l10n), overflow: TextOverflow.ellipsis),
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
