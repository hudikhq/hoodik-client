import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Detail screen for a single user. Shows info, storage breakdown, sessions,
/// and admin actions (edit role/quota, disable 2FA, delete).
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  AdminUserDetail? _detail;
  List<AdminSession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await client.admin.getUser(widget.userId);

      // Also load recent sessions for this user.
      List<AdminSession> sessions = [];
      try {
        final s = await client.admin.listSessions(
          userId: widget.userId,
          limit: 10,
        );
        sessions = s.data;
      } catch (_) {
        // Non-critical — sessions may fail if user was just deleted.
      }

      if (mounted) {
        setState(() {
          _detail = detail;
          _sessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _editRoleAndQuota() async {
    final l10n = AppLocalizations.of(context);
    final user = _detail!.user;
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (ctx) => _EditRoleQuotaDialog(
        currentRole: user.role,
        currentQuotaBytes: user.quota,
      ),
    );
    if (result == null) return;

    final client = ref.read(apiClientProvider);
    if (client == null) return;

    try {
      final updated = await client.admin.updateUser(
        widget.userId,
        role: result.role,
        quota: result.quotaBytes,
      );
      if (mounted) {
        setState(() => _detail = updated);
        AppNotification.show(
          context,
          message: l10n.adminUserUpdated,
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.adminActionFailed(e.toString()),
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _disableTfa() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.adminDisableTfaTitle,
      content: l10n.adminDisableTfaBody(_detail!.user.email),
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.adminDisable,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true) return;

    final client = ref.read(apiClientProvider);
    if (client == null) return;

    try {
      await client.admin.disableTfa(widget.userId);
      await _load();
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.adminActionFailed(e.toString()),
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _killAllSessions() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.adminKillAllSessions,
      content: l10n.adminKillAllSessionsBody(_detail!.user.email),
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.adminKillAll,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true) return;

    final client = ref.read(apiClientProvider);
    if (client == null) return;

    try {
      await client.admin.killUserSessions(widget.userId);
      await _load();
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.adminActionFailed(e.toString()),
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _deleteUser() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.adminDeleteUser,
      content: l10n.adminDeleteUserBody(_detail!.user.email),
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.commonDelete,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true) return;

    final client = ref.read(apiClientProvider);
    if (client == null) return;

    try {
      await client.admin.deleteUser(widget.userId);
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.adminUserDeleted,
          type: NotificationType.success,
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.adminActionFailed(e.toString()),
          type: NotificationType.error,
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.user.email ?? l10n.adminRoleUser),
        centerTitle: isApplePlatform,
        actions: [
          if (_detail != null)
            IconButton(
              icon: Icon(
                isApplePlatform ? CupertinoIcons.pencil : Icons.edit_outlined,
                size: 20,
              ),
              tooltip: l10n.adminEditRoleQuotaTooltip,
              onPressed: _editRoleAndQuota,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: AdaptiveLoadingIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(message: _error!),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildUserInfo(theme),
                  const SizedBox(height: 16),
                  _buildStorageStats(theme),
                  const SizedBox(height: 16),
                  _buildSessions(theme),
                  const SizedBox(height: 16),
                  _buildDangerZone(theme),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfo(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final user = _detail!.user;

    return AdaptiveListSection(
      header: l10n.adminUserInfoHeader,
      children: [
        AdaptiveListTile(
          title: Text(l10n.adminEmailLabel),
          subtitle: Text(user.email),
          trailing: IconButton(
            tooltip: l10n.commonCopy,
            icon: Icon(
              isApplePlatform ? CupertinoIcons.doc_on_doc : Icons.copy,
              size: 16,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: user.email));
              AppNotification.show(context, message: l10n.adminCopied);
            },
            visualDensity: VisualDensity.compact,
          ),
        ),
        AdaptiveListTile(
          title: Text(l10n.adminRoleLabel),
          subtitle: Text(user.role ?? 'user'),
        ),
        AdaptiveListTile(
          title: Text(l10n.adminTwoFactorLabel),
          subtitle: Text(user.hasTfa ? l10n.adminEnabled : l10n.adminDisabled),
          trailing: user.hasTfa
              ? Icon(
                  isApplePlatform ? CupertinoIcons.shield_fill : Icons.shield,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                )
              : null,
        ),
        AdaptiveListTile(
          title: Text(l10n.adminEmailVerifiedLabel),
          subtitle: Text(
            user.emailVerifiedAt != null
                ? fmt.formatAbsoluteTimestamp(
                    user.emailVerifiedAt!,
                    includeTime: true,
                  )
                : l10n.adminNotVerified,
          ),
        ),
        AdaptiveListTile(
          title: Text(l10n.adminQuotaLabel),
          subtitle: Text(
            user.quota != null
                ? fmt.formatBytes(user.quota!)
                : l10n.adminUnlimited,
          ),
        ),
        AdaptiveListTile(
          title: Text(l10n.adminRegisteredLabel),
          subtitle: Text(
            fmt.formatAbsoluteTimestamp(user.createdAt, includeTime: true),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageStats(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final stats = _detail!.stats;

    return AdaptiveListSection(
      header: l10n.adminStorageHeader(
        fmt.formatBytes(_detail!.totalSize),
        _detail!.totalFiles,
      ),
      children: stats.isEmpty
          ? [
              AdaptiveListTile(
                title: Text(l10n.adminNoFiles),
                subtitle: Text(l10n.adminNoFilesSubtitle),
              ),
            ]
          : stats.map((s) {
              return AdaptiveListTile(
                title: Text(s.mime),
                subtitle: Text(l10n.adminFileCount(s.count)),
                trailing: Text(
                  fmt.formatBytes(s.size),
                  style: theme.textTheme.bodySmall,
                ),
              );
            }).toList(),
    );
  }

  Widget _buildSessions(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return AdaptiveListSection(
      header: l10n.adminSessionsHeader(_sessions.length),
      children: _sessions.isEmpty
          ? [AdaptiveListTile(title: Text(l10n.adminNoActiveSessions))]
          : _sessions.map((s) {
              final isActive = DateTime.fromMillisecondsSinceEpoch(
                s.expiresAt * 1000,
              ).isAfter(DateTime.now());
              return AdaptiveListTile(
                title: Text(
                  s.ip,
                  style: TextStyle(
                    color: isActive
                        ? null
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                subtitle: Text(
                  _truncateUserAgent(s.userAgent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isActive
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              );
            }).toList(),
    );
  }

  Widget _buildDangerZone(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final user = _detail!.user;
    final isSelf = ref.read(activeAccountProvider)?.id == user.id;

    return AdaptiveListSection(
      header: l10n.adminActionsHeader,
      children: [
        if (user.hasTfa)
          AdaptiveListTile(
            leading: Icon(
              Icons.lock_open,
              size: 20,
              color: theme.colorScheme.error,
            ),
            title: Text(
              l10n.adminDisableTfa,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: _disableTfa,
          ),
        if (_sessions.isNotEmpty)
          AdaptiveListTile(
            leading: Icon(
              Icons.logout,
              size: 20,
              color: theme.colorScheme.error,
            ),
            title: Text(
              l10n.adminKillAllSessions,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: _killAllSessions,
          ),
        if (!isSelf)
          AdaptiveListTile(
            leading: Icon(
              Icons.delete_forever,
              size: 20,
              color: theme.colorScheme.error,
            ),
            title: Text(
              l10n.adminDeleteUser,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: Text(l10n.adminDeleteUserSubtitle),
            onTap: _deleteUser,
          ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _truncateUserAgent(String ua) {
    if (ua.length <= 60) return ua;
    return '${ua.substring(0, 57)}...';
  }
}

class _EditResult {
  final String? role;
  final int? quotaBytes;

  _EditResult({this.role, this.quotaBytes});
}

class _EditRoleQuotaDialog extends StatefulWidget {
  final String? currentRole;
  final int? currentQuotaBytes;

  const _EditRoleQuotaDialog({this.currentRole, this.currentQuotaBytes});

  @override
  State<_EditRoleQuotaDialog> createState() => _EditRoleQuotaDialogState();
}

class _EditRoleQuotaDialogState extends State<_EditRoleQuotaDialog> {
  late String _selectedRole;
  final _quotaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole ?? 'user';
    if (widget.currentQuotaBytes != null) {
      _quotaController.text = fmt.quotaBytesToGb(widget.currentQuotaBytes!);
    }
  }

  @override
  void dispose() {
    _quotaController.dispose();
    super.dispose();
  }

  void _submit() {
    final quota = fmt.quotaGbToBytes(_quotaController.text);

    Navigator.pop(
      context,
      _EditResult(
        role: _selectedRole == 'user' ? null : _selectedRole,
        quotaBytes: quota,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(l10n.adminEditUserTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: InputDecoration(
              labelText: l10n.adminRoleLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: 'user', child: Text(l10n.adminRoleUser)),
              DropdownMenuItem(
                value: 'admin',
                child: Text(l10n.adminRoleAdmin),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedRole = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quotaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.adminQuotaGbLabel,
              hintText: l10n.adminQuotaUnlimitedHint,
              border: const OutlineInputBorder(),
              suffixText: 'GB',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}
