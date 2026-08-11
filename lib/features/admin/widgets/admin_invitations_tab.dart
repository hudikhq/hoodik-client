import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'admin_users_tab.dart' show PaginationBar;
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_type.dart';
import '../../../core/theme/hoodik_scheme.dart';

/// Lists invitations with create / expire actions.
class AdminInvitationsTab extends ConsumerStatefulWidget {
  const AdminInvitationsTab({super.key});

  @override
  ConsumerState<AdminInvitationsTab> createState() =>
      _AdminInvitationsTabState();
}

class _AdminInvitationsTabState extends ConsumerState<AdminInvitationsTab>
    with AutomaticKeepAliveClientMixin {
  List<Invitation> _invitations = [];
  int _total = 0;
  int _offset = 0;
  final int _limit = 15;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final result = await client.admin.listInvitations(
        withExpired: true,
        limit: _limit,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _invitations = result.data;
          _total = result.total;
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

  Future<void> _createInvitation() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_InviteFormResult>(
      context: context,
      builder: (ctx) => const _CreateInviteDialog(),
    );
    if (result == null) return;

    final client = ref.read(apiClientProvider);
    if (client == null) return;

    try {
      await client.admin.createInvitation(
        email: result.email,
        role: result.isAdmin ? 'admin' : null,
        quota: result.quota,
      );
      if (mounted) {
        AppNotification.show(
          context,
          message: l10n.adminInvitationSent(result.email),
          type: NotificationType.success,
        );
      }
      _offset = 0;
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

  Future<void> _expireInvitation(Invitation inv) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAdaptiveAlert<bool>(
      context: context,
      title: l10n.adminExpireInvitationTitle,
      content: l10n.adminExpireInvitationBody(inv.email),
      actions: [
        AdaptiveDialogAction(
          label: l10n.commonCancel,
          value: false,
          isDefault: true,
        ),
        AdaptiveDialogAction(
          label: l10n.adminExpire,
          value: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true) return;

    final client = ref.read(apiClientProvider);
    if (client == null) return;

    try {
      await client.admin.expireInvitation(inv.id);
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

  void _nextPage() {
    if (_offset + _limit < _total) {
      _offset += _limit;
      _load();
    }
  }

  void _prevPage() {
    if (_offset > 0) {
      _offset = (_offset - _limit).clamp(0, _total);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Header with create button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.adminInvitationCount(_total),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              FilledButton.icon(
                onPressed: _createInvitation,
                icon: Icon(AppIcons.add, size: 18),
                label: Text(l10n.adminInvite),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: AdaptiveLoadingIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorBanner(message: _error!),
                  ),
                )
              : _invitations.isEmpty
              ? Center(
                  child: Text(
                    l10n.adminNoInvitations,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _invitations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final inv = _invitations[index];
                      return _InvitationTile(
                        invitation: inv,
                        onExpire: (!inv.isExpired && !inv.isRedeemed)
                            ? () => _expireInvitation(inv)
                            : null,
                      );
                    },
                  ),
                ),
        ),

        // Pagination
        if (!_loading && _total > _limit)
          PaginationBar(
            offset: _offset,
            limit: _limit,
            total: _total,
            onPrev: _offset > 0 ? _prevPage : null,
            onNext: _offset + _limit < _total ? _nextPage : null,
          ),
      ],
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final Invitation invitation;
  final VoidCallback? onExpire;

  const _InvitationTile({required this.invitation, this.onExpire});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    Color statusColor;
    String statusLabel;
    if (invitation.isRedeemed) {
      statusColor = theme.colorScheme.tertiary;
      statusLabel = l10n.adminStatusRedeemed;
    } else if (invitation.isExpired) {
      statusColor = theme.colorScheme.error;
      statusLabel = l10n.adminStatusExpired;
    } else {
      statusColor = theme.colorScheme.primary;
      statusLabel = l10n.adminStatusPending;
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: statusColor.withValues(alpha: 0.12),
        child: Icon(
          invitation.isRedeemed
              ? (isApplePlatform
                    ? CupertinoIcons.checkmark_alt
                    : AppIcons.check)
              : (isApplePlatform ? CupertinoIcons.mail : Icons.mail_outline),
          size: 18,
          color: statusColor,
        ),
      ),
      title: Text(
        invitation.email,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: HoodikType.minimumSize,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
          if (invitation.role != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                invitation.role!,
                style: TextStyle(
                  fontSize: HoodikType.minimumSize,
                  fontWeight: FontWeight.w500,
                  color: context.colors.iconEmber,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: onExpire != null
          ? IconButton(
              icon: Icon(
                isApplePlatform
                    ? CupertinoIcons.xmark_circle
                    : Icons.cancel_outlined,
                size: 20,
                color: theme.colorScheme.error.withValues(alpha: 0.7),
              ),
              tooltip: l10n.adminExpire,
              onPressed: onExpire,
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}

class _InviteFormResult {
  final String email;
  final bool isAdmin;
  final int? quota;

  _InviteFormResult({required this.email, this.isAdmin = false, this.quota});
}

class _CreateInviteDialog extends StatefulWidget {
  const _CreateInviteDialog();

  @override
  State<_CreateInviteDialog> createState() => _CreateInviteDialogState();
}

class _CreateInviteDialogState extends State<_CreateInviteDialog> {
  final _emailController = TextEditingController();
  final _quotaController = TextEditingController();
  bool _isAdmin = false;

  @override
  void dispose() {
    _emailController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    final quota = fmt.quotaGbToBytes(_quotaController.text);

    Navigator.pop(
      context,
      _InviteFormResult(email: email, isAdmin: _isAdmin, quota: quota),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(l10n.adminSendInvitationTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.adminEmailLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quotaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.adminQuotaGbLabel,
              hintText: l10n.adminQuotaDefaultHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adminAdminRole),
            value: _isAdmin,
            onChanged: (v) => setState(() => _isAdmin = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSend)),
      ],
    );
  }
}
