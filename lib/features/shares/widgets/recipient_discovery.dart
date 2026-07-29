import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';
import '../services/trusted_fingerprint_dao.dart';
import 'share_fingerprint_tile.dart';

/// Result of resolving a recipient by email: either a verified user plus its
/// trust state, or a UI-ready error message. Shared by the file share dialog
/// and the folder add-member sheet so both surfaces resolve recipients
/// identically — discover, hard-stop on a server key/fingerprint mismatch, then
/// classify the trust state against the local TOFU store.
sealed class RecipientLookup {
  const RecipientLookup();
}

class RecipientResolved extends RecipientLookup {
  const RecipientResolved({
    required this.user,
    required this.formattedFingerprint,
    required this.status,
    this.cachedFingerprint,
  });

  final DiscoveredUser user;
  final String formattedFingerprint;
  final ShareTrustStatus status;

  /// Formatted previously-trusted fingerprint; set only on
  /// [ShareTrustStatus.mismatch].
  final String? cachedFingerprint;
}

/// No such user (404) or a typed/transport failure. [message] is null only for
/// the 404 case so the caller can choose its own "not found" copy if it wants;
/// every other path carries a message.
class RecipientLookupFailed extends RecipientLookup {
  const RecipientLookupFailed(this.message);

  final String? message;
}

/// Resolve [email] to a recipient and its trust state, scoped to [ownerId]'s
/// trust store. Returns [RecipientLookupFailed] (never throws) so the caller
/// renders a message rather than handling exceptions inline.
Future<RecipientLookup> resolveRecipient(WidgetRef ref, String email) async {
  final client = ref.read(apiClientProvider);
  final shareCrypto = ref.read(shareCryptoProvider);
  final ownerId = ref.read(activeServerUserIdProvider);
  if (client == null || shareCrypto == null || ownerId == null) {
    return RecipientLookupFailed(ambientL10n.sharesNotAuthenticated);
  }

  final DiscoveredUser? user;
  try {
    user = await client.shares.discoverUser(email);
  } on DiscoverException catch (e) {
    return RecipientLookupFailed(_discoverMessage(e.kind));
  } catch (_) {
    return RecipientLookupFailed(ambientL10n.sharesLookupFailed);
  }
  if (user == null) {
    return const RecipientLookupFailed(null);
  }

  final localFingerprint = shareCrypto.computeFingerprint(
    user.pubkey,
    keyType: user.keyType,
  );
  if (localFingerprint.toLowerCase() != user.fingerprint.toLowerCase()) {
    return RecipientLookupFailed(ambientL10n.sharesKeyFingerprintMismatch);
  }

  final trusted = await ref
      .read(databaseProvider)
      .getTrustedFingerprint(ownerId, user.userId);
  final formatted = shareCrypto.formatFingerprint(user.fingerprint);
  if (trusted == null) {
    return RecipientResolved(
      user: user,
      formattedFingerprint: formatted,
      status: ShareTrustStatus.firstSight,
    );
  }
  if (trusted.fingerprint.toLowerCase() == user.fingerprint.toLowerCase()) {
    return RecipientResolved(
      user: user,
      formattedFingerprint: formatted,
      status: ShareTrustStatus.verified,
    );
  }
  return RecipientResolved(
    user: user,
    formattedFingerprint: formatted,
    status: ShareTrustStatus.mismatch,
    cachedFingerprint: shareCrypto.formatFingerprint(trusted.fingerprint),
  );
}

String _discoverMessage(DiscoverErrorKind kind) => switch (kind) {
  DiscoverErrorKind.cannotDiscoverSelf => ambientL10n.sharesCannotShareWithSelf,
  DiscoverErrorKind.rateLimited => ambientL10n.sharesTooManyLookups,
  DiscoverErrorKind.sharingDisabled => ambientL10n.sharesSharingDisabled,
};
