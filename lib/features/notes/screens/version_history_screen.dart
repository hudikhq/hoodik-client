import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/utils/l10n_lookup.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/helpers/file_helpers.dart' show formatErrorMessage;
import '../widgets/markdown_preview_webview.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../widgets/version_row.dart';

/// Push as `/notes/:fileId/history`. The screen owns its own data load
/// and surfaces back to the editor via the `restored` value passed to
/// [Navigator.pop] — `true` means the editor must reload, `false` /
/// `null` means it doesn't.
class VersionHistoryScreen extends ConsumerStatefulWidget {
  final String fileId;
  const VersionHistoryScreen({super.key, required this.fileId});

  @override
  ConsumerState<VersionHistoryScreen> createState() =>
      _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends ConsumerState<VersionHistoryScreen> {
  List<FileVersion>? _versions;
  FileItem? _file;
  Uint8List? _fileKey;
  String? _decryptedName;
  String? _error;
  bool _busy = false;

  /// True if anything in here changed the active version — tells the
  /// editor to reload its content on pop.
  bool _activeVersionChanged = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = ref.read(apiClientProvider);
    final fileCrypto = ref.read(fileCryptoProvider);
    if (client == null || fileCrypto == null) {
      setState(() => _error = ambientL10n.notesNotAuthenticated);
      return;
    }

    setState(() {
      _error = null;
    });

    try {
      final metaJson = await client.files.getFileMetadata(widget.fileId);
      final file = FileItem.fromJson(metaJson);
      Uint8List? key;
      String? name;
      if (file.encryptedKey != null) {
        key = fileCrypto.decryptFileKey(file.encryptedKey!);
        name = fileCrypto.decryptFileName(
          encryptedNameHex: file.encryptedName,
          fileKey: key,
          cipher: file.cipher,
        );
      }
      final versions = await client.versions.list(widget.fileId);
      if (!mounted) return;
      setState(() {
        _file = file;
        _fileKey = key;
        _decryptedName = name;
        _versions = versions;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = formatErrorMessage(e));
      }
    }
  }

  Future<Uint8List> _decryptVersion(FileVersion v) async {
    final client = ref.read(apiClientProvider);
    final fileCrypto = ref.read(fileCryptoProvider);
    final key = _fileKey;
    final cipher = _file?.cipher;
    if (client == null || fileCrypto == null || key == null || cipher == null) {
      throw Exception(_l10n.notesKeyUnavailable);
    }

    // Concat all chunks. History downloads are owner-only on the server,
    // so the regular session cookie is enough — no transfer token needed.
    final out = BytesBuilder(copy: false);
    for (var i = 0; i < v.chunks; i++) {
      final encrypted = await client.versions.downloadChunk(
        fileId: widget.fileId,
        version: v.version,
        chunk: i,
      );
      final plaintext = fileCrypto.decryptChunk(
        data: encrypted,
        fileKey: key,
        cipher: cipher,
        chunkIndex: i,
      );
      out.add(plaintext);
    }
    return out.toBytes();
  }

  Future<void> _previewVersion(FileVersion v) async {
    setState(() => _busy = true);
    try {
      final bytes = await _decryptVersion(v);
      if (!mounted) return;
      final text = utf8.decode(bytes, allowMalformed: true);
      // Preview pops with `'restore'` if the user picked that action
      // there — saves them the second tap on the history list.
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => _VersionPreviewScreen(
            version: v,
            content: text,
            dateLabel: _formatDate(v.createdAt),
          ),
        ),
      );
      if (!mounted) return;
      if (result == 'restore') {
        await _restore(v);
      }
    } catch (e) {
      _showError(_l10n.notesPreviewFailed(formatErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(FileVersion v) async {
    final when = _formatDate(v.createdAt);
    final confirmed = await _confirm(
      title: _l10n.notesRestoreVersionTitle(v.version),
      message: _l10n.notesRestoreVersionMsg(v.version, when),
      confirmLabel: _l10n.notesRestore,
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider)!;
      await client.versions.restore(fileId: widget.fileId, version: v.version);
      _activeVersionChanged = true;
      _showInfo(_l10n.notesRestoredVersion(v.version));
      await _load();
    } catch (e) {
      _showError(_l10n.notesRestoreFailed(formatErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forkAsNewNote(FileVersion v) async {
    final fileCrypto = ref.read(fileCryptoProvider);
    final client = ref.read(apiClientProvider);
    final file = _file;
    final key = _fileKey;
    final name = _decryptedName;
    if (client == null ||
        fileCrypto == null ||
        file == null ||
        key == null ||
        name == null ||
        file.encryptedKey == null) {
      _showError(_l10n.notesMetadataUnavailable);
      return;
    }

    final stamp = _formatDate(v.createdAt);
    final base = name.toLowerCase().endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
    final newName = '$base (restored $stamp).md';

    setState(() => _busy = true);
    try {
      final encryptedName = fileCrypto.encryptFileName(
        name: newName,
        fileKey: key,
        cipher: file.cipher,
      );

      // Name and body together, the way every other note write indexes one.
      // The copy holds the words this version does, so indexing its title
      // alone leaves it out of every search that finds the note it came from,
      // and nothing revisits a fork afterwards.
      final indexed =
          '$newName\n${utf8.decode(await _decryptVersion(v), allowMalformed: true)}';
      // The new file shares the source's symmetric key (chunks are
      // server-copied verbatim), so the existing RSA-wrapped
      // encrypted_key is reusable as-is for the new owner row.
      final body = <String, dynamic>{
        'name_hash': fileCrypto.hashFileName(newName),
        'encrypted_name': encryptedName,
        'encrypted_key': file.encryptedKey!,
        'mime': 'text/markdown',
        'cipher': file.cipher,
        'editable': true,
        if (file.fileId != null) 'file_id': file.fileId,
        // Both scopes, under the names the server actually reads.
        // `search_tokens_hashed` is the pre-keyed field the re-key migration
        // retired: the server ignores it, so everything sent under it was
        // dropped and the copy was born unfindable. The fork reuses the
        // source's symmetric key — its chunks are copied verbatim — so the
        // file scope is keyed on that same key.
        'search_tokens_root': fileCrypto.tokenizeForSearch(indexed),
        'search_tokens_file': fileCrypto.tokenizeForSearchWithFileKey(
          key,
          indexed,
        ),
      };

      final result = await client.versions.fork(
        fileId: widget.fileId,
        version: v.version,
        newFile: body,
      );
      final newFileId = result['id'] as String?;
      if (newFileId == null) throw Exception(_l10n.notesNoServerId);

      if (!mounted) return;
      _showInfo(_l10n.notesCreatedNote(newName));
      // Replace the workspace root URL with the new note so back
      // doesn't dump the user back into history.
      context.go('/editor/$newFileId');
    } catch (e) {
      _showError(_l10n.notesForkFailed(formatErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(FileVersion v) async {
    final when = _formatDate(v.createdAt);
    final confirmed = await _confirm(
      title: _l10n.notesDeleteVersionTitle(v.version),
      message: _l10n.notesDeleteVersionMsg(v.version, when),
      confirmLabel: _l10n.commonDelete,
      destructive: true,
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider)!;
      await client.versions.delete(fileId: widget.fileId, version: v.version);
      await _load();
    } catch (e) {
      _showError(_l10n.notesDeleteVersionFailed(formatErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purgeAll() async {
    final confirmed = await _confirm(
      title: _l10n.notesClearHistoryTitle,
      message: _l10n.notesClearHistoryBody,
      confirmLabel: _l10n.notesDeleteAll,
      destructive: true,
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider)!;
      await client.versions.purgeAll(widget.fileId);
      await _load();
    } catch (e) {
      _showError(_l10n.notesPurgeFailed(formatErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDate(int unixSeconds) {
    return fmt.formatAbsoluteTimestamp(unixSeconds, includeTime: true);
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.commonCancel),
          ),
          TextButton(
            style: destructive
                ? TextButton.styleFrom(
                    foregroundColor: context.colors.textCrimson,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    AppNotification.show(context, message: msg, type: NotificationType.error);
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    AppNotification.show(context, message: msg, type: NotificationType.success);
  }

  @override
  Widget build(BuildContext context) {
    // Block system-back while a destructive op is in flight; the back
    // arrow returns a "did anything change" bool the workspace uses to
    // decide whether to reload the editor.
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(AppIcons.back),
            onPressed: () =>
                Navigator.of(context).pop<bool>(_activeVersionChanged),
          ),
          title: Text(
            _decryptedName == null
                ? _l10n.notesHistory
                : _l10n.notesHistoryNamed(_decryptedName!),
          ),
          actions: [
            if (_versions != null && _versions!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: _l10n.notesClearHistoryTooltip,
                onPressed: _busy ? null : _purgeAll,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_versions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_versions!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _l10n.notesNoHistory,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMuted),
          ),
        ),
      );
    }
    return Stack(
      children: [
        ListView.separated(
          itemCount: _versions!.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final v = _versions![index];
            return VersionRow(
              version: v,
              dateLabel: _formatDate(v.createdAt),
              busy: _busy,
              onPreview: () => _previewVersion(v),
              onRestore: () => _restore(v),
              onFork: () => _forkAsNewNote(v),
              onDelete: () => _delete(v),
            );
          },
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.error, size: 48, color: context.colors.iconCrimson),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(AppIcons.refresh),
              label: Text(AppLocalizations.of(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen renderer for a historical version's content. Pops with
/// `'restore'` when the user taps the restore action so the parent can
/// chain into the existing confirm-then-restore flow without forcing
/// the user to swipe back and tap again.
class _VersionPreviewScreen extends StatelessWidget {
  final FileVersion version;
  final String content;
  final String dateLabel;

  const _VersionPreviewScreen({
    required this.version,
    required this.content,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
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
      // — gives byte-identical rendering to what the user sees while
      // editing, including TOC anchors that scroll on tap.
      body: MarkdownPreviewWebView(content: content),
    );
  }
}
