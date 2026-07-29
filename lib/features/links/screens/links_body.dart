import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../services/links_loader.dart';
import '../../../core/theme/hoodik_colors.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../../../core/widgets/app_notification.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'link_tile.dart';

/// The user's public links list with per-link actions (copy URL, share,
/// edit/remove expiry, delete). Owns its own load/refresh state so it can be
/// dropped into the Share hub's "Public links" tab without a wrapping
/// Scaffold. Mirrors the web `ShareHubPublic`.
class LinksBody extends ConsumerStatefulWidget {
  const LinksBody({super.key});

  @override
  ConsumerState<LinksBody> createState() => LinksBodyState();
}

class LinksBodyState extends ConsumerState<LinksBody> {
  List<LinkItem>? _links;
  bool _loading = true;
  String? _error;

  String? _loadedAccountId;

  @override
  void initState() {
    super.initState();
    _loadedAccountId = ref.read(activeAccountProvider)?.id;
    _loadLinks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(activeAccountProvider, (prev, next) {
        if (next != null && next.id != _loadedAccountId) {
          _links = null;
          _loadLinks();
        }
      });
    });
  }

  /// Re-fetch the list. Exposed so the Share hub's refresh action can drive it
  /// through a [GlobalKey] — a link created elsewhere (a file's context menu)
  /// only lands in this list on the next fetch.
  Future<void> reload() => _loadLinks();

  Future<void> _loadLinks() async {
    _loadedAccountId = ref.read(activeAccountProvider)?.id;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final fileCrypto = ref.read(fileCryptoProvider);
      if (client == null || fileCrypto == null) {
        setState(() {
          // ambientL10n: this branch can run synchronously from initState,
          // where an AppLocalizations.of(context) lookup is not allowed.
          _error = ambientL10n.linksNotAuthenticated;
          _loading = false;
        });
        return;
      }

      final rawLinks = await client.links.list(withExpired: true);
      final loaded = decryptLinkListing(
        rawLinks: rawLinks,
        fileCrypto: fileCrypto,
        client: client,
      );

      if (mounted) {
        setState(() {
          _links = loaded.items;
          _loading = false;
        });
        // Rows are on screen already; each thumbnail patches in its own
        // row as it resolves.
        for (final pending in loaded.thumbnails) {
          unawaited(pending.then(_applyThumbnail));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _applyThumbnail((String, Uint8List)? resolved) {
    if (resolved == null || !mounted) return;
    final (linkId, bytes) = resolved;

    setState(() {
      _links = [
        for (final link in _links ?? const <LinkItem>[])
          if (link.id == linkId) link.withThumbnail(bytes) else link,
      ];
    });
  }

  String _linkUrl(LinkItem link) {
    final server = ref.read(activeServerProvider);
    final baseUrl = server?.url ?? '';
    return '$baseUrl/l/${link.id}#${link.linkKeyHex}';
  }

  void _copyLink(LinkItem link) {
    Clipboard.setData(ClipboardData(text: _linkUrl(link)));
    _showSnack(AppLocalizations.of(context).linksCopiedToClipboard);
  }

  Future<void> _shareLink(LinkItem link) async {
    final url = _linkUrl(link);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await Share.share(url, sharePositionOrigin: origin);
  }

  Future<void> _deleteLink(LinkItem link) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.linksDeleteTitle),
        content: Text(l10n.linksDeleteBody(link.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.commonDelete,
              style: const TextStyle(color: HoodikColors.redish400),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = ref.read(apiClientProvider);
      await client?.links.delete(link.id);
      _showSnack(l10n.linksDeleted, NotificationType.success);
      await _loadLinks();
    } catch (e) {
      _showSnack(
        l10n.linksDeleteFailed(e.toString().replaceFirst('Exception: ', '')),
        NotificationType.error,
      );
    }
  }

  Future<void> _editExpiry(LinkItem link) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final initial = link.expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(link.expiresAt! * 1000)
        : now.add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now)
          ? now.add(const Duration(days: 1))
          : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) return;

    try {
      final client = ref.read(apiClientProvider);
      final expiresAt = picked.millisecondsSinceEpoch ~/ 1000;
      await client?.links.updateExpiry(linkId: link.id, expiresAt: expiresAt);
      _showSnack(l10n.linksExpiryUpdated, NotificationType.success);
      await _loadLinks();
    } catch (e) {
      _showSnack(
        l10n.linksUpdateFailed(e.toString().replaceFirst('Exception: ', '')),
        NotificationType.error,
      );
    }
  }

  Future<void> _removeExpiry(LinkItem link) async {
    final l10n = AppLocalizations.of(context);
    try {
      final client = ref.read(apiClientProvider);
      await client?.links.updateExpiry(linkId: link.id);
      _showSnack(l10n.linksExpiryRemoved, NotificationType.success);
      await _loadLinks();
    } catch (e) {
      _showSnack(
        l10n.linksUpdateFailed(e.toString().replaceFirst('Exception: ', '')),
        NotificationType.error,
      );
    }
  }

  void _showSnack(
    String message, [
    NotificationType type = NotificationType.info,
  ]) {
    if (!mounted) return;
    AppNotification.show(context, message: message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: HoodikColors.redish400,
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadLinks,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    final links = _links ?? [];

    if (links.isEmpty) {
      // A scrollable empty state so pull-to-refresh works before the first
      // link exists — otherwise a link created elsewhere can't be pulled in.
      return RefreshIndicator(
        onRefresh: _loadLinks,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.link_off,
                    size: 64,
                    color: HoodikColors.brownish300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).linksEmptyTitle,
                    style: TextStyle(
                      color: HoodikColors.brownish100,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).linksEmptySubtitle,
                    style: TextStyle(
                      color: HoodikColors.brownish300,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLinks,
      child: ListView.separated(
        itemCount: links.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, index) {
          final link = links[index];
          return LinkTile(
            link: link,
            onCopy: () => _copyLink(link),
            onShare: () => _shareLink(link),
            onEditExpiry: () => _editExpiry(link),
            onRemoveExpiry: () => _removeExpiry(link),
            onDelete: () => _deleteLink(link),
          );
        },
      ),
    );
  }
}
