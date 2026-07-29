import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/share_event_models.dart';
import '../../../core/crypto/file_crypto.dart';
import '../../../core/crypto/share_crypto.dart';
import '../../../core/providers.dart';
import '../../../core/utils/l10n_lookup.dart';

/// Tri-state per-row integrity verdict, mirroring the web `ShareHubAudit`
/// classification:
///
///  - [verified] — every local check passed. The row is the signal; the UI
///    decorates it quietly.
///  - [system] — the row legitimately isn't verifiable under the share-audit
///    signature scheme here: cascade-revoke fan-outs and server-attributed
///    events carry no sender signature at all, and the account-level
///    `key_rotation` event is signed under a *different* scheme
///    (`KeyRotationAuditV1`) this view doesn't re-verify. All are still
///    cryptographically chained — the "system" label carries the meaning, not a
///    failure.
///  - [tampered] — the loud one. Fires when a non-system row fails ANY of: its
///    self-hash recompute, the chain link to a visible predecessor, or its
///    sender-signature verification. A page-boundary gap (predecessor outside
///    the loaded slice) is NOT tampering — the slice-aware verifier passes it.
enum AuditRowBadge { verified, system, tampered }

/// One audit-log row resolved for display: the verbatim event (for the action
/// sentence inputs and disclosure), the sender/recipient emails resolved from
/// the page's `users` map, the decrypted file label (or a bare-id fallback),
/// and the single integrity verdict derived from the chain walk + the
/// per-row signature check.
@immutable
class AuditDisplayRow {
  const AuditDisplayRow({
    required this.event,
    required this.senderEmail,
    required this.recipientEmail,
    required this.fileLabel,
    required this.badge,
    required this.chainStatus,
  });

  final AppShareEvent event;
  final String senderEmail;

  /// Empty when the event has no recipient (uploads, forks, system events).
  final String recipientEmail;
  final String fileLabel;
  final AuditRowBadge badge;

  /// The chain-walk classification for this row, carried alongside [badge] so
  /// the row widget can disambiguate a tampered headline (self-hash vs link)
  /// and surface a quiet page-boundary note.
  final ChainRowStatus chainStatus;
}

/// Loaded audit-log state: the display rows plus the page total, so the screen
/// can show "showing N of M" when the newest page is capped below the total.
@immutable
class AuditLogState {
  const AuditLogState({required this.rows, required this.total});

  final List<AuditDisplayRow> rows;
  final int total;

  bool get isEmpty => rows.isEmpty;
}

/// The newest-page size requested from the server. M5 ships a single newest
/// page (no infinite scroll); when [AuditLogState.total] exceeds this, the
/// screen says so rather than silently truncating. The server clamps to
/// `MAX_LIMIT = 1000` regardless, but 100 keeps the verify pass cheap and
/// matches the web `ShareHubAudit` `limit: 100`.
const int auditLogPageSize = 100;

/// Loads one newest page of the caller's audit log, verifies it client-side,
/// and exposes display rows. Verification reuses the proven crypto in
/// [ShareCryptoChain]: [ShareCrypto.verifyChain] over the page once, then
/// [ShareCrypto.verifyEventSignature] per row against the page's `users`
/// pubkey. File names are decrypted with [FileCrypto] when the wrap is present.
/// Cleared on logout alongside the other share providers.
class AuditLogNotifier extends AsyncNotifier<AuditLogState> {
  @override
  Future<AuditLogState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<AuditLogState> _load() async {
    final client = ref.read(apiClientProvider);
    final shareCrypto = ref.read(shareCryptoProvider);
    final fileCrypto = ref.read(fileCryptoProvider);
    if (client == null || shareCrypto == null || fileCrypto == null) {
      throw StateError('Not authenticated');
    }

    final page = await client.shareEvents.getEvents(
      const ShareEventQuery(limit: auditLogPageSize),
    );

    // The wire returns newest-first (`created_at DESC, id DESC`). The verifier
    // re-buckets by sender and re-sorts each bucket ascending, so the wire
    // order is exactly what it expects — we pass the rows through untouched and
    // keep them in the same order for display. `chainOk[i]`/`rowStatus[i]` map
    // 1:1 to `page.events[i]`.
    final rows = page.events.map((e) => e.toEventRow()).toList();
    final chain = shareCrypto.verifyChain(rows);

    // One decrypt per file id: a grant and its later revoke share the same
    // ciphertext (immutable for the file row's lifetime), so caching by id
    // avoids redundant RSA+symmetric work down a long history.
    final nameByFile = <String, String?>{};
    final displayRows = <AuditDisplayRow>[];
    for (var i = 0; i < page.events.length; i++) {
      final event = page.events[i];
      final badge = _badgeFor(event, shareCrypto, page.users, chain, i);
      final label = _fileLabel(event, fileCrypto, nameByFile);
      displayRows.add(
        AuditDisplayRow(
          event: event,
          senderEmail: _senderEmail(event, page.users),
          recipientEmail: _recipientEmail(event, page.users),
          fileLabel: label,
          badge: badge,
          chainStatus: chain.rowStatus[i],
        ),
      );
    }

    return AuditLogState(rows: displayRows, total: page.total);
  }

  AuditRowBadge _badgeFor(
    AppShareEvent event,
    ShareCrypto crypto,
    Map<String, AuditUserRef> users,
    ChainVerification chain,
    int index,
  ) {
    // A null sender (server-attributed cascade) carries no signature to verify;
    // a key_rotation row is signed under KeyRotationAuditV1, not the share-audit
    // canonical this view checks. Either way the chain math still ran — "system"
    // is the label, not a failure — so classify before the signature check to
    // keep the share canonical off a row it was never meant for.
    if (event.senderId == null ||
        event.senderSignature == null ||
        event.action == AuditEventAction.keyRotation) {
      return AuditRowBadge.system;
    }

    final sender = users[event.senderId];
    final signatureOk =
        sender != null &&
        crypto.verifyEventSignature(
          event.toEventRow(),
          sender.pubkey,
          senderKeyType: sender.keyType,
          senderTransition: sender.keyTransition,
        );

    final status = chain.rowStatus[index];
    final chainTampered =
        status == ChainRowStatus.selfHashMismatch ||
        status == ChainRowStatus.linkBroken;

    if (!signatureOk || chainTampered) return AuditRowBadge.tampered;
    return AuditRowBadge.verified;
  }

  /// Decrypt the file name when the joined wrap is present, falling back to a
  /// truncated id otherwise. A wrong-key decrypt (key rotation across a long
  /// history) is caught and degrades to the id too — the id is correct, just
  /// less readable, and a stale key isn't an error worth surfacing.
  String _fileLabel(
    AppShareEvent event,
    FileCrypto fileCrypto,
    Map<String, String?> cache,
  ) {
    final decrypted = cache.putIfAbsent(event.fileId, () {
      if (!event.canDecryptName) return null;
      try {
        final fileKey = fileCrypto.decryptFileKey(event.encryptedKey!);
        return fileCrypto.decryptFileName(
          encryptedNameHex: event.encryptedName!,
          fileKey: fileKey,
          cipher: event.cipher!,
        );
      } catch (_) {
        return null;
      }
    });
    return decrypted ?? _bareFileId(event.fileId);
  }

  static String _bareFileId(String fileId) {
    final head = fileId.length >= 8 ? fileId.substring(0, 8) : fileId;
    return ambientL10n.sharesAuditFileIdLabel(head);
  }

  static String _senderEmail(AppShareEvent event, Map<String, AuditUserRef> u) {
    final id = event.senderId;
    if (id == null) return ambientL10n.sharesAuditSystemSender;
    return u[id]?.email ?? _shortId(id);
  }

  static String _recipientEmail(
    AppShareEvent event,
    Map<String, AuditUserRef> u,
  ) {
    final id = event.recipientId;
    if (id == null) return '';
    return u[id]?.email ?? _shortId(id);
  }

  static String _shortId(String id) => id.length >= 8 ? id.substring(0, 8) : id;
}

final auditLogNotifierProvider =
    AsyncNotifierProvider<AuditLogNotifier, AuditLogState>(
      AuditLogNotifier.new,
    );
