import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/format.dart' as fmt;
import '../../../core/widgets/adaptive.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Paginated user list with search. Tapping a row pushes to user detail.
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<AdminUser> _users = [];
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
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final client = ref.read(apiClientProvider);
    if (client == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await client.admin.listUsers(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        limit: _limit,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _users = result.data;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _offset = 0;
      _loadUsers();
    });
  }

  void _nextPage() {
    if (_offset + _limit < _total) {
      _offset += _limit;
      _loadUsers();
    }
  }

  void _prevPage() {
    if (_offset > 0) {
      _offset = (_offset - _limit).clamp(0, _total);
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: l10n.adminSearchUsersHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _offset = 0;
                        _loadUsers();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              isDense: true,
            ),
          ),
        ),

        // User list
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
              : _users.isEmpty
              ? Center(
                  child: Text(
                    l10n.adminNoUsersFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return _UserTile(
                        user: user,
                        onTap: () async {
                          await context.push('/admin/users/${user.id}');
                          // Refresh after returning from detail
                          // (user may have been modified/deleted).
                          await _loadUsers();
                        },
                      );
                    },
                  ),
                ),
        ),

        // Pagination
        if (!_loading && _total > _limit)
          _PaginationBar(
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

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: user.isAdmin
            ? theme.colorScheme.secondary.withValues(alpha: 0.15)
            : theme.colorScheme.primary.withValues(alpha: 0.1),
        child: Text(
          user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
          style: TextStyle(
            color: user.isAdmin
                ? theme.colorScheme.secondary
                : theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (user.isAdmin) ...[
            const SizedBox(width: 6),
            _Badge(
              label: l10n.adminBadgeAdmin,
              color: theme.colorScheme.secondary,
            ),
          ],
          if (user.hasTfa) ...[
            const SizedBox(width: 4),
            Icon(
              isApplePlatform ? CupertinoIcons.shield_fill : Icons.shield,
              size: 14,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ],
      ),
      subtitle: Text(
        l10n.adminLastActive(
          fmt.formatRelativeTimestamp(
            user.lastSession?.updatedAt ?? user.updatedAt,
          ),
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Icon(
        isApplePlatform ? CupertinoIcons.chevron_right : Icons.chevron_right,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
    );
  }
}

class PaginationBar extends StatelessWidget {
  final int offset;
  final int limit;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const PaginationBar({
    super.key,
    required this.offset,
    required this.limit,
    required this.total,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final start = offset + 1;
    final end = (offset + limit).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.adminPaginationRange(start, end, total),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: onPrev,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: onNext,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Private alias for file-internal use.
class _PaginationBar extends PaginationBar {
  const _PaginationBar({
    required super.offset,
    required super.limit,
    required super.total,
    super.onPrev,
    super.onNext,
  });
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
