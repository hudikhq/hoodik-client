import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/services/thumbnail_loader.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../helpers/file_helpers.dart';
import '../providers/files_notifier.dart';
import 'files_action_result.dart';

/// Successful result of [FilesLinkController.createLink] — the URL
/// plus the encrypted-name-decrypted filename so the calling widget
/// can show both in the "link created" dialog.
class CreatedLink {
  final String fileName;
  final String url;

  const CreatedLink({required this.fileName, required this.url});
}

/// Outcome of link creation. Exactly one of [link]/[error] is set.
class LinkCreationOutcome {
  final CreatedLink? link;
  final FilesActionResult? error;

  const LinkCreationOutcome.success(this.link) : error = null;

  const LinkCreationOutcome.failure(this.error) : link = null;
}

/// Builds the E2E-encrypted payload for a shared link, posts it to the
/// server, and returns a fragment-carrying URL. The crypto flow mirrors
/// the web frontend exactly — the link key never leaves the client
/// except via the URL fragment (`#<linkKeyHex>`), which the browser
/// itself never forwards on the request line.
class FilesLinkController {
  final Ref _ref;
  final String? _dirId;

  FilesLinkController(this._ref, this._dirId);

  Future<LinkCreationOutcome> createLink(FileItem file) async {
    final fileCrypto = _ref.read(fileCryptoProvider);
    final client = _ref.read(apiClientProvider);
    final account = _ref.read(activeAccountProvider);
    final server = _ref.read(activeServerProvider);

    if (fileCrypto == null || client == null || account == null) {
      return LinkCreationOutcome.failure(
        FilesActionResult.error(ambientL10n.filesNotAuthenticated),
      );
    }
    // Curve accounts wrap the link key to their hybrid wrapping key; the Ed25519
    // identity in `publicKey` can't do key wrapping. Legacy RSA accounts have no
    // wrapping key and fall back to their RSA public key.
    final wrapPublicKey = account.wrappingPublicKey ?? account.publicKey;
    if (wrapPublicKey == null) {
      return LinkCreationOutcome.failure(
        FilesActionResult.error(ambientL10n.filesPublicKeyUnavailable),
      );
    }

    final notifierState = _ref.read(filesNotifierProvider(_dirId));
    final fileKey = notifierState.decryptedKeys[file.id];
    if (fileKey == null) {
      return LinkCreationOutcome.failure(
        FilesActionResult.error(ambientL10n.filesCannotDecryptKey),
      );
    }

    final fileName = notifierState.displayName(file);

    try {
      final linkKey = fileCrypto.generateLinkKey();
      final linkKeyHex = fileCrypto.hexEncodeKey(linkKey);
      final signature = fileCrypto.signFileId(file.id);
      final encryptedName = fileCrypto.encryptWithLinkKey(
        text: fileName,
        linkKey: linkKey,
      );
      final encryptedFileKey = fileCrypto.encryptFileKeyWithLinkKey(
        fileKey: fileKey,
        linkKey: linkKey,
      );
      final encryptedLinkKey = fileCrypto.encryptLinkKey(
        linkKey: linkKey,
        publicKeyPem: wrapPublicKey,
      );

      final thumbPlaintext = await _ref
          .read(thumbnailLoaderProvider)
          .loadDataUrl(file, fileKey);
      String? encryptedThumbnail;
      if (thumbPlaintext != null) {
        encryptedThumbnail = fileCrypto.encryptWithLinkKey(
          text: thumbPlaintext,
          linkKey: linkKey,
        );
      }

      final response = await client.links.create({
        'file_id': file.id,
        'signature': signature,
        'encrypted_name': encryptedName,
        'encrypted_link_key': encryptedLinkKey,
        'encrypted_file_key': encryptedFileKey,
        'encrypted_thumbnail': ?encryptedThumbnail,
      });

      final linkId = response['id'] as String;
      final baseUrl = server?.url ?? '';
      return LinkCreationOutcome.success(
        CreatedLink(fileName: fileName, url: '$baseUrl/l/$linkId#$linkKeyHex'),
      );
    } catch (e) {
      return LinkCreationOutcome.failure(
        FilesActionResult.error(
          ambientL10n.filesCreateLinkFailed(formatErrorMessage(e)),
        ),
      );
    }
  }
}

final filesLinkControllerProvider =
    Provider.family<FilesLinkController, String?>((ref, dirId) {
      return FilesLinkController(ref, dirId);
    });
