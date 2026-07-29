import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/crypto/file_crypto.dart';
import '../../../core/services/thumbnail_loader.dart';
import '../../../core/utils/log_redact.dart';
import '../../../core/utils/logger.dart';
import '../screens/link_tile.dart';

const _log = Logger('LinksLoader');

/// A decrypted `/api/links` listing: the display rows plus deferred
/// per-link thumbnail resolutions. Rows render immediately; each
/// thumbnail future completes with `(linkId, bytes)` once its blob is
/// decrypted, or null when the link has none / decryption failed.
class LoadedLinks {
  final List<LinkItem> items;
  final List<Future<(String, Uint8List)?>> thumbnails;

  const LoadedLinks({required this.items, required this.thumbnails});
}

/// Decrypt the raw `/api/links` rows client-side. Rows that fail to
/// decrypt (e.g. wrapped under a superseded key) are skipped so one bad
/// link doesn't blank the whole page. Thumbnail loads start immediately
/// but are surfaced as futures so the caller can render the listing
/// first and patch rows in as they complete.
LoadedLinks decryptLinkListing({
  required List<dynamic> rawLinks,
  required FileCrypto fileCrypto,
  required ApiClient client,
}) {
  final items = <LinkItem>[];
  final thumbnails = <Future<(String, Uint8List)?>>[];

  for (final raw in rawLinks) {
    try {
      final map = raw as Map<String, dynamic>;

      final linkKey = fileCrypto.decryptLinkKey(
        map['encrypted_link_key'] as String,
      );
      final name = fileCrypto.decryptWithLinkKey(
        encryptedHex: map['encrypted_name'] as String,
        linkKey: linkKey,
      );

      final id = map['id'] as String;
      final inlineCiphertext = map['encrypted_thumbnail'] as String?;
      final hasThumbnail =
          map['has_thumbnail'] as bool? ??
          (inlineCiphertext?.isNotEmpty ?? false);

      items.add(
        LinkItem(
          id: id,
          fileId: map['file_id'] as String,
          name: name,
          mime: map['file_mime'] as String? ?? '',
          fileSize: map['file_size'] as int?,
          downloads: map['downloads'] as int? ?? 0,
          createdAt: map['created_at'] as int? ?? 0,
          expiresAt: map['expires_at'] as int?,
          linkKeyHex: fileCrypto.hexEncodeKey(linkKey),
        ),
      );
      if (hasThumbnail) {
        thumbnails.add(
          _loadThumbnail(id, linkKey, inlineCiphertext, fileCrypto, client),
        );
      }
    } catch (e) {
      _log.warn(
        'failed to decrypt link',
        fields: {'error': redactException(e)},
      );
    }
  }

  return LoadedLinks(items: items, thumbnails: thumbnails);
}

/// Resolve one link's thumbnail off the listing path: decrypt the
/// inline ciphertext when the server sent it (older servers), fetch the
/// metadata route otherwise.
Future<(String, Uint8List)?> _loadThumbnail(
  String linkId,
  Uint8List linkKey,
  String? inlineCiphertext,
  FileCrypto fileCrypto,
  ApiClient client,
) async {
  try {
    var ciphertext = inlineCiphertext;
    if (ciphertext == null || ciphertext.isEmpty) {
      final metadata = await client.links.metadata(linkId);
      ciphertext = metadata['encrypted_thumbnail'] as String?;
    }
    if (ciphertext == null || ciphertext.isEmpty) return null;

    final dataUrl = fileCrypto.decryptWithLinkKey(
      encryptedHex: ciphertext,
      linkKey: linkKey,
    );
    final bytes = ThumbnailLoader.decodeDataUrl(dataUrl);
    if (bytes == null) return null;

    return (linkId, bytes);
  } catch (e) {
    _log.warn(
      'failed to load link thumbnail',
      fields: {'error': redactException(e)},
    );
    return null;
  }
}
