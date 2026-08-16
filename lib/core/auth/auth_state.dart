import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/providers/notes_sidebar_notifier.dart';
import '../../features/shares/providers/audit_log_notifier.dart';
import '../../features/shares/providers/folder_members_notifier.dart';
import '../../features/shares/providers/groups_notifier.dart';
import '../providers.dart';
import '../storage/database.dart';
import '../utils/account_context.dart';
import '../utils/log_redact.dart';
import '../utils/logger.dart';

const _log = Logger('AuthState');

/// Convenience extensions on [WidgetRef] to update login/logout state
/// in a single call instead of repeating 4-5 provider writes everywhere.
extension AuthStateExtension on WidgetRef {
  /// Set all session providers after a successful login or session restore.
  void setLoggedIn({
    required Account account,
    required Server? server,
    String? privateKey,
    String? wrappingPrivateKey,
  }) {
    // [activeAccountProvider] is written LAST, once everything derived from
    // the session is already current. Riverpod delivers `ref.listen`
    // callbacks synchronously and only marks dependent providers dirty
    // afterwards, so a listener that fires on the account change reads
    // whatever the rest of this method has not updated yet. Publishing the
    // account first made FilesNotifier reload the previous account's listing
    // over the previous account's client, then decrypt it with the new key —
    // a drive full of "Encrypted …" rows after every switch.
    read(isLoggedInProvider.notifier).state = true;
    read(activeServerProvider.notifier).state = server;
    read(decryptedPrivateKeyProvider.notifier).state = privateKey;
    read(decryptedWrappingPrivateKeyProvider.notifier).state =
        wrappingPrivateKey;

    // Tell the logger which account is active, so every emitted record
    // carries `[<email> / <server-host>]` — the redactor UI shows this
    // prefix so the user can trace lines per account in the bug report.
    AccountContext.set(
      email: account.email,
      serverHost: server == null ? null : Uri.tryParse(server.url)?.host,
    );

    // Force apiClientProvider to re-evaluate so it picks up the new
    // AuthService.activeClient. Without this, account switches (where
    // isLoggedInProvider stays true→true) would leave workerManagerProvider,
    // fileOperationsProvider, and syncServiceProvider using the old client.
    invalidate(apiClientProvider);

    // Wipe any leftover tree from the previous account. On first login
    // this is a no-op; on account switch it guarantees we don't show
    // the previous user's decrypted file names.
    read(notesSidebarStateProvider.notifier).clear();
    // Drop any cached folder roster so a switched-in account never sees the
    // previous account's members. Family provider → all folders invalidated.
    invalidate(folderMembersNotifierProvider);
    // Same for the share-group list — the switched-in account must not see the
    // previous account's groups.
    invalidate(groupsNotifierProvider);
    // And the audit log — events are scoped to the previous account's identity.
    invalidate(auditLogNotifierProvider);

    read(activeAccountProvider.notifier).state = account;

    // Eagerly evaluate mcpServerProvider so its auto-start listener is
    // registered. Without this, the provider is never created (it's lazy)
    // and the MCP server won't start until the settings screen is opened.
    // It reads the active account on first evaluation, so it has to come
    // after the write above. This is a best-effort warm-up: on the unlock
    // path the navigation that follows can dispose dependencies
    // mid-evaluation, and the macOS-only server falls back to lazily
    // initializing on first settings/tray read, so a failure here must never
    // escape and crash the sign-in.
    try {
      read(mcpServerProvider);
    } catch (e) {
      _log.warn(
        'MCP server warm-up skipped on sign-in',
        fields: {'error': redactException(e)},
      );
    }
  }

  /// Clear all session providers on logout or session expiration.
  void setLoggedOut() {
    read(isLoggedInProvider.notifier).state = false;
    read(activeAccountProvider.notifier).state = null;
    read(activeServerProvider.notifier).state = null;
    read(decryptedPrivateKeyProvider.notifier).state = null;
    read(decryptedWrappingPrivateKeyProvider.notifier).state = null;

    // Drop the logger's account prefix so post-logout lifecycle logs are
    // not mis-attributed to the account that just left.
    AccountContext.clear();
    // Wipe the notes sidebar cache — the next account must not see the
    // previous one's decrypted tree.
    read(notesSidebarStateProvider.notifier).clear();
    // Drop any cached folder roster for the same reason.
    invalidate(folderMembersNotifierProvider);
    // Drop the cached share-group list so the next account re-fetches its own.
    invalidate(groupsNotifierProvider);
    // Drop the cached audit log so the next account never sees these events.
    invalidate(auditLogNotifierProvider);
    // Drop the cached tar-capability answers so a follow-up login against
    // a different server (or even a rebuilt one at the same URL) re-probes.
    read(tarCapabilityCacheProvider).clear();
    // Wipe the dismissed-outdated-server set so the next session sees the
    // warning again if the operator still hasn't upgraded.
    read(dismissedOutdatedServerBannersProvider.notifier).state = <String>{};
  }
}
