import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/format.dart' as fmt;
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/theme/hoodik_scheme.dart';
import '../../../core/widgets/adaptive_menu.dart';

/// Decrypted public-link row for display. Names, sizes, and thumbnails are
/// decrypted client-side before reaching this model — the server never holds
/// the plaintext.
class LinkItem {
  final String id;
  final String fileId;
  final String name;
  final String mime;
  final int? fileSize;
  final int downloads;
  final int createdAt;
  final int? expiresAt;
  final String linkKeyHex;
  final Uint8List? thumbnailBytes;

  const LinkItem({
    required this.id,
    required this.fileId,
    required this.name,
    required this.mime,
    this.fileSize,
    required this.downloads,
    required this.createdAt,
    this.expiresAt,
    required this.linkKeyHex,
    this.thumbnailBytes,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt! < now;
  }

  /// Copy of this row with its lazily loaded thumbnail attached.
  LinkItem withThumbnail(Uint8List bytes) => LinkItem(
    id: id,
    fileId: fileId,
    name: name,
    mime: mime,
    fileSize: fileSize,
    downloads: downloads,
    createdAt: createdAt,
    expiresAt: expiresAt,
    linkKeyHex: linkKeyHex,
    thumbnailBytes: bytes,
  );
}

/// One public-link list row. Presentational only — every action is delegated
/// to the parent so the list owns the load/refresh state.
class LinkTile extends StatelessWidget {
  const LinkTile({
    super.key,
    required this.link,
    required this.onCopy,
    required this.onShare,
    required this.onEditExpiry,
    required this.onRemoveExpiry,
    required this.onDelete,
  });

  final LinkItem link;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onEditExpiry;
  final VoidCallback onRemoveExpiry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final expired = link.isExpired;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      leading: _leading(context, expired),
      title: Text(
        link.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: expired ? context.colors.textMuted : null),
      ),
      subtitle: Text(
        _subtitle(l10n),
        style: TextStyle(
          color: expired ? context.colors.textMuted : context.colors.textMuted,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(AppIcons.copy, size: 18),
            tooltip: l10n.linksCopyTooltip,
            onPressed: onCopy,
            color: context.colors.iconMuted,
          ),
          AdaptiveMenuButton(
            icon: AppIcons.overflowVertical,
            tooltip: l10n.notesMore,
            builder: (ctx) => [
              AdaptiveMenuAction(
                icon: AppIcons.share,
                iconColor: ctx.colors.sageFill,
                label: l10n.commonShare,
                onTap: onShare,
              ),
              AdaptiveMenuAction(
                icon: AppIcons.schedule,
                iconColor: ctx.colors.iconEmber,
                label: l10n.linksSetExpiry,
                onTap: onEditExpiry,
                sectionBreak: true,
              ),
              if (link.expiresAt != null)
                AdaptiveMenuAction(
                  icon: Icons.timer_off,
                  iconColor: ctx.colors.iconMuted,
                  label: l10n.linksRemoveExpiry,
                  onTap: onRemoveExpiry,
                ),
              AdaptiveMenuAction(
                icon: AppIcons.delete,
                iconColor: ctx.colors.iconCrimson,
                label: l10n.linksDeleteLink,
                onTap: onDelete,
                isDestructive: true,
                sectionBreak: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leading(BuildContext context, bool expired) {
    if (link.thumbnailBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Opacity(
            opacity: expired ? 0.4 : 1.0,
            child: Image.memory(
              link.thumbnailBytes!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _icon(context, expired),
            ),
          ),
        ),
      );
    }
    return _icon(context, expired);
  }

  Widget _icon(BuildContext context, bool expired) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: expired
          ? context.colors.seam
          : context.colors.iconSlate.withValues(alpha: 0.15),
      child: Icon(
        AppIcons.link,
        size: 20,
        color: expired ? context.colors.iconMuted : context.colors.iconSlate,
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final parts = <String>[];

    parts.add(l10n.linksDownloadCount(link.downloads));

    if (link.fileSize != null && link.fileSize! > 0) {
      parts.add(fmt.formatBytes(link.fileSize!));
    }

    if (link.isExpired) {
      parts.add(l10n.linksExpired);
    } else if (link.expiresAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(link.expiresAt! * 1000);
      final diff = dt.difference(DateTime.now());
      if (diff.inDays > 0) {
        parts.add(l10n.linksExpiresInDays(diff.inDays));
      } else if (diff.inHours > 0) {
        parts.add(l10n.linksExpiresInHours(diff.inHours));
      } else {
        parts.add(l10n.linksExpiresSoon);
      }
    }

    return parts.join(' · ');
  }
}
