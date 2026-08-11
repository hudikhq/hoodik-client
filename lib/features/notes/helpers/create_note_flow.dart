import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/providers/files_notifier.dart';
import '../../preview/providers/preview_providers.dart';
import '../providers/notes_sidebar_notifier.dart';
import '../providers/open_note_request.dart';
import '../widgets/new_note_dialog.dart';

/// Prompt for a name, create the note, then route to `/editor/<id>` so
/// the workspace opens it as a tab.
///
/// Used by the notes app-bar create action. The sidebar has
/// its own in-place version at [NotesSidebar._handleCreateNote] that also
/// updates local tree state directly — this one is for callers that don't
/// live inside the sidebar and need a self-contained flow.
///
/// Seeds both [previewContextProvider] (so the workspace's `initialFileId`
/// path can resolve the file + key without a cold re-fetch on the editor
/// side) and the sidebar's decrypted-name cache (so when the drawer opens
/// the new note is already named without a refetch).
Future<void> createNoteAndOpen({
  required BuildContext context,
  required WidgetRef ref,
  String? parentDirId,
  String? parentFolderName,
  bool returnToFiles = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showNewNoteDialog(
    context: context,
    parentDirId: parentDirId,
    parentFolderName: parentFolderName,
  );
  if (chosen == null || chosen.name.isEmpty) return;
  final name = chosen.name;
  // The dialog owns the destination from here — the caller's folder was only
  // the starting point.
  parentDirId = chosen.parentDirId;

  final ops = ref.read(fileOperationsProvider);
  final client = ref.read(apiClientProvider);
  final fileCrypto = ref.read(fileCryptoProvider);
  if (ops == null || client == null || fileCrypto == null) {
    if (context.mounted) {
      AppNotification.show(
        context,
        message: l10n.notesNotSignedIn,
        type: NotificationType.error,
      );
    }
    return;
  }

  final noteName = name.endsWith('.md') ? name : '$name.md';
  final displayTitle = noteName.replaceAll(
    RegExp(r'\.md$', caseSensitive: false),
    '',
  );
  // Seed with a heading matching the file name. The web app does the same,
  // and the server rejects zero-byte uploads at the size validator.
  final initialContent = '# $displayTitle\n';

  try {
    final newId = await ops.createNote(
      noteName,
      initialContent,
      parentDirId: parentDirId,
    );

    // Re-fetch so we have the server-generated encryptedKey — the uploader
    // holds the plaintext file key in memory during creation but doesn't
    // return it. One extra round-trip is fine at create-note frequency.
    final metaJson = await client.files.getFileMetadata(newId);
    final newFile = FileItem.fromJson(metaJson);
    if (newFile.encryptedKey == null) {
      throw Exception(l10n.notesCreatedNoteMissingKey);
    }
    final fileKey = fileCrypto.decryptFileKey(newFile.encryptedKey!);
    final decryptedName = fileCrypto.decryptFileName(
      encryptedNameHex: newFile.encryptedName,
      fileKey: fileKey,
      cipher: newFile.cipher,
    );

    ref.read(previewContextProvider.notifier).state = PreviewContext(
      files: [newFile],
      names: {newId: decryptedName},
      keys: {newId: fileKey},
      parentDirId: parentDirId,
    );

    final sidebar = ref.read(notesSidebarStateProvider.notifier);
    sidebar.invalidateDir(parentDirId);
    sidebar.setDecrypted(newId, decryptedName, fileKey);

    // Surface the new note in the Files list/grid for this folder without a
    // manual refresh (the notes sidebar was just invalidated above).
    await ref.read(filesNotifierProvider(parentDirId).notifier).load();

    // Tell the workspace to open this note. See the comment on
    // [OpenNoteRequest] for why the URL alone isn't enough.
    requestOpenNoteFromWidget(ref, newId, returnToFiles: returnToFiles);

    if (!context.mounted) return;
    context.go('/editor/$newId');
  } catch (e) {
    if (!context.mounted) return;
    AppNotification.show(
      context,
      message: l10n.notesCreateNoteFailed('$e'),
      type: NotificationType.error,
    );
  }
}
