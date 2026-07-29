import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/connectivity_error.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../files/controllers/files_upload_controller.dart';
import '../../files/widgets/files_busy_overlay.dart';
import '../controllers/folder_share_controller.dart';
import '../providers/folder_members_notifier.dart';
import '../widgets/folder_member_add_sheet.dart';
import '../widgets/folder_member_tile.dart';
import '../widgets/share_to_group_sheet.dart';

/// Dedicated roster view for a shared folder, reached at
/// `/shares/folder/:folderId/members`. Lists every member with a per-row
/// signature badge, and — for the owner or a co-owner — lets them add members,
/// change roles, and revoke (with the co-owner cascade made explicit before
/// confirmation). The roster provider is autoDispose, so each visit loads live
/// from the server rather than a roster cached on an earlier visit. Mirrors the
/// web `FolderMembersView`.
class FolderMembersScreen extends ConsumerWidget {
  const FolderMembersScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String folderId;

  /// The decrypted folder name, passed through the route so the title and the
  /// share/revoke flows can name the folder without re-decrypting.
  final String folderName;

  FileItem get _folderItem =>
      FileItem(id: folderId, encryptedName: '', mime: 'dir');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(folderMembersNotifierProvider(folderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          folderName.isEmpty
              ? AppLocalizations.of(context).sharesMembersTitle
              : folderName,
        ),
        centerTitle: isApplePlatform,
      ),
      body: Stack(
        children: [
          state.when(
            loading: () =>
                const Center(child: AdaptiveLoadingIndicator(radius: 12)),
            error: (e, _) => _ErrorBody(
              error: e,
              onRetry: () => ref
                  .read(folderMembersNotifierProvider(folderId).notifier)
                  .refresh(),
            ),
            data: (loaded) => _MembersBody(
              loaded: loaded,
              folder: _folderItem,
              folderName: folderName,
            ),
          ),
          const FilesBusyOverlay(),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A lost-access 404 is a definitive answer, not a transient fault — it gets
    // its own message and no Retry. A verified connectivity failure gets the
    // online-only framing. Anything else is a real fault surfaced as itself,
    // per the warn-only-when-verified rule.
    if (error is NotAFolderMemberException) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.sharesNoLongerHaveAccess,
            textAlign: TextAlign.center,
            style: const TextStyle(color: HoodikColors.brownish100),
          ),
        ),
      );
    }

    final offline = isConnectivityError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.error_outline,
              size: 32,
              color: HoodikColors.brownish100,
            ),
            const SizedBox(height: 12),
            Text(
              offline
                  ? l10n.sharesMembersLoadFailedOffline
                  : l10n.sharesMembersLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HoodikColors.brownish100),
            ),
            if (!offline) ...[
              const SizedBox(height: 6),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: HoodikColors.brownish100,
                ),
              ),
            ],
            const SizedBox(height: 16),
            AdaptiveButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

class _MembersBody extends ConsumerWidget {
  const _MembersBody({
    required this.loaded,
    required this.folder,
    required this.folderName,
  });

  final FolderMembersState loaded;
  final FileItem folder;
  final String folderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final response = loaded.response;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.sharesMembersCount(loaded.members.length),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  color: HoodikColors.brownish100,
                ),
              ),
            ),
            if (loaded.callerCanReshare) ...[
              // Parity with the web's folder sharing surface, where the same
              // people who manage members can also drop new files into the
              // folder. The upload reuses the standard pipeline keyed on this
              // folder id, so the multi-key wrap for every member happens
              // through the existing shared-folder upload path.
              AdaptiveTextButton(
                onPressed: () => _addFiles(context, ref),
                child: Text(l10n.sharesAddFiles),
              ),
              const SizedBox(width: 4),
              AdaptiveTextButton(
                onPressed: () => _addMember(context, ref),
                child: Text(l10n.sharesAddMember),
              ),
              if (_canShareToGroup(ref)) ...[
                const SizedBox(width: 4),
                AdaptiveTextButton(
                  onPressed: () => showShareToGroupSheet(
                    context: context,
                    ref: ref,
                    file: folder,
                    onShared: () => ref.invalidate(
                      folderMembersNotifierProvider(folder.id),
                    ),
                  ),
                  child: Text(l10n.sharesShareToGroup),
                ),
              ],
            ],
          ],
        ),
        const Divider(height: 16, color: HoodikColors.brownish600),
        for (final member in loaded.members)
          FolderMemberTile(
            member: member,
            ownerId: response.folderOwnerId,
            callerId: ref.read(activeServerUserIdProvider),
            signatureStatus:
                loaded.signatureStatus[member.userId] ??
                MemberSignatureStatus.legacy,
            canMutate: loaded.callerCanReshare,
            onChangeRole: () => _changeRole(context, ref, member),
            onRevoke: () => _revoke(context, ref, member, response),
          ),
      ],
    );
  }

  /// The group target is offered only when sharing is enabled and the server
  /// speaks groups; a non-sharing or group-less server hides it.
  static bool _canShareToGroup(WidgetRef ref) {
    final caps = ref.watch(shareCapabilitiesProvider).valueOrNull;
    return (caps?.sharingEnabled ?? false) && (caps?.shareGroups ?? false);
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final changed = await showFolderMemberAddSheet(
      context: context,
      ref: ref,
      folder: folder,
    );
    if (changed) ref.invalidate(folderMembersNotifierProvider(folder.id));
  }

  Future<void> _addFiles(BuildContext context, WidgetRef ref) async {
    // Uploading into a shared folder doesn't change its roster, so there's no
    // members refresh here — the upload controller refreshes the folder's own
    // file listing, and the shared-folder routing wraps each member's key.
    final result = await ref
        .read(filesUploadControllerProvider(folder.id))
        .pickAndUploadFiles();
    if (result == null || !context.mounted) return;
    AppNotification.show(context, message: result.message, type: result.type);
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    FolderMember member,
  ) async {
    if (member.email == null) return;
    final changed = await showFolderMemberAddSheet(
      context: context,
      ref: ref,
      folder: folder,
      prefillEmail: member.email,
      prefillRole: member.shareRole,
    );
    if (changed) ref.invalidate(folderMembersNotifierProvider(folder.id));
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    FolderMember member,
    FolderMembersResponse roster,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cascade = FolderShareController.cascadeImpact(roster, member);
    final extra = cascade > 0
        ? ' ${l10n.sharesRevokeCascadeExtra(cascade)}'
        : '';
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.sharesRevokeAccessTitle,
      content:
          l10n.sharesRevokeFolderBody(
            member.email ?? member.userId,
            folderName,
          ) +
          extra,
      actions: [
        AdaptiveDialogAction(label: l10n.commonCancel, value: false),
        AdaptiveDialogAction(
          label: l10n.sharesRevoke,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    final outcome = await ref
        .read(folderShareControllerProvider)
        .revokeMember(folder: folder, roster: roster, member: member);
    if (!context.mounted) return;
    switch (outcome) {
      case FolderShareSuccess():
        AppNotification.show(
          context,
          message: l10n.sharesAccessRevoked,
          type: NotificationType.success,
        );
        ref.invalidate(folderMembersNotifierProvider(folder.id));
      case FolderShareFailure(:final message):
        AppNotification.show(
          context,
          message: message,
          type: NotificationType.error,
        );
    }
  }
}
