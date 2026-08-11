import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../core/utils/log_redact.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/helpers/file_helpers.dart';
import '../../../core/widgets/app_icons.dart';

const _log = Logger('RecentNotesPanel');

/// "Recent notes" list, rendered as the empty state in the notes
/// workspace when no tab is open (and as the body of the mobile Notes
/// tab landing).
///
/// Mirrors the web's NotesLanding: a flat list of every editable
/// markdown file across the whole account, ordered by modification
/// time (desc). Clicking a note invokes [onOpenNote] with the decrypted
/// name and symmetric key — the host decides whether to open it in a
/// tab (desktop) or navigate to the editor (mobile).
class RecentNotesPanel extends ConsumerStatefulWidget {
  final void Function(FileItem file, String name, Uint8List fileKey) onOpenNote;

  const RecentNotesPanel({super.key, required this.onOpenNote});

  @override
  ConsumerState<RecentNotesPanel> createState() => RecentNotesPanelState();
}

class RecentNotesPanelState extends ConsumerState<RecentNotesPanel> {
  List<FileItem>? _notes;
  bool _loading = true;
  String? _error;

  final Map<String, String> _decryptedNames = {};
  final Map<String, Uint8List> _decryptedKeys = {};

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  /// Expose the refresh path so the host can re-sync after creating a
  /// new note from outside (e.g. the sidebar's `+` menu).
  Future<void> refresh() => _loadNotes();

  Future<void> _loadNotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = ref.read(apiClientProvider);
    if (client == null) {
      setState(() {
        _loading = false;
        _error = ambientL10n.notesNotSignedIn;
      });
      return;
    }

    try {
      final response = await client.files.listFiles(
        editable: true,
        orderBy: 'modified_at',
        order: 'desc',
      );

      // Server returns directories and non-markdown editable files too
      // (future-proofing) — filter to markdown notes only on the client.
      final notes = response.children.where(_isMarkdownNote).toList();
      _decryptNames(notes);

      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ambientL10n.notesLoadNotesFailed(formatErrorMessage(e));
      });
    }
  }

  bool _isMarkdownNote(FileItem file) {
    if (file.isDir) return false;
    if (file.mime.toLowerCase() == 'text/markdown') return true;
    final name = _decryptedNames[file.id];
    return name != null && name.toLowerCase().endsWith('.md');
  }

  void _decryptNames(List<FileItem> files) {
    final pending = files
        .where(
          (f) =>
              !_decryptedNames.containsKey(f.id) &&
              f.encryptedName.isNotEmpty &&
              f.encryptedKey != null &&
              f.encryptedKey!.isNotEmpty,
        )
        .toList();
    if (pending.isEmpty) return;

    final fileCrypto = ref.read(fileCryptoProvider);
    if (fileCrypto == null) {
      _log.warn('file crypto not available — cannot decrypt note names');
      return;
    }

    for (final file in pending) {
      try {
        final key = fileCrypto.decryptFileKey(file.encryptedKey!);
        _decryptedKeys[file.id] = key;
        _decryptedNames[file.id] = fileCrypto.decryptFileName(
          encryptedNameHex: file.encryptedName,
          fileKey: key,
          cipher: file.cipher,
        );
      } catch (e) {
        _log.warn(
          'failed to decrypt note name',
          fields: {'file_id': file.id, 'error': redactException(e)},
        );
      }
    }
  }

  String _displayName(FileItem file) {
    final l10n = AppLocalizations.of(context);
    return _decryptedNames[file.id] ??
        (file.encryptedName.isNotEmpty
            ? l10n.notesEncryptedFallback(file.id.substring(0, 8))
            : l10n.notesUntitled);
  }

  void _openNote(FileItem file) {
    final key = _decryptedKeys[file.id];
    if (key == null) {
      AppNotification.show(
        context,
        message: AppLocalizations.of(context).notesCannotOpenNoKey,
        type: NotificationType.error,
      );
      return;
    }
    widget.onOpenNote(file, _displayName(file), key);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _loadNotes, child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading && _notes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error, size: 32, color: HoodikColors.iconCrimson),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: HoodikColors.dirtyWhite),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadNotes,
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    final notes = _notes ?? const <FileItem>[];
    if (notes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 120), _NotesEmptyIllustration()],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: notes.length + 1,
      separatorBuilder: (_, i) {
        if (i == 0) return const SizedBox.shrink();
        return const Divider(
          height: 1,
          color: HoodikColors.brownish700,
          indent: 16,
          endIndent: 16,
        );
      },
      itemBuilder: (context, i) {
        if (i == 0) return const _RecentHeader();
        final file = notes[i - 1];
        return _NoteTile(
          name: _displayName(file),
          modifiedAt: file.fileModifiedAt,
          onTap: () => _openNote(file),
        );
      },
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Icon(AppIcons.history, size: 16, color: HoodikColors.iconMuted),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).notesRecentHeader,
            style: const TextStyle(
              color: HoodikColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final String name;
  final int? modifiedAt;
  final VoidCallback onTap;

  const _NoteTile({
    required this.name,
    required this.modifiedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = formatRelativeTimestamp(modifiedAt, fallback: '—');

    return ListTile(
      onTap: onTap,
      leading: Icon(AppIcons.note, color: HoodikColors.orangy500),
      title: Tooltip(
        message: name,
        waitDuration: const Duration(milliseconds: 400),
        child: Text(
          name,
          style: const TextStyle(color: HoodikColors.dirtyWhite, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Text(
        AppLocalizations.of(context).notesModified(subtitle),
        style: const TextStyle(color: HoodikColors.textMuted, fontSize: 12),
      ),
    );
  }
}

class _NotesEmptyIllustration extends StatelessWidget {
  const _NotesEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.note, size: 48, color: HoodikColors.iconMuted),
            const SizedBox(height: 12),
            Text(
              l10n.notesEmptyTitle,
              style: const TextStyle(
                color: HoodikColors.dirtyWhite,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.notesEmptyHint,
              style: const TextStyle(
                color: HoodikColors.textMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
