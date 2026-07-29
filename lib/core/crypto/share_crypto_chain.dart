part of 'share_crypto.dart';

/// Audit hash-chain orchestration. Split out of [ShareCrypto] for file size;
/// shares its private FFI helpers as part of the same library.
extension ShareCryptoChain on ShareCrypto {
  /// Recompute one row's chain hash:
  /// `sha256(prefix ‖ prev_hash ‖ encode_audit_event_v1(row))`. The previous
  /// hash for a chain head is 32 zero bytes. Returns base64.
  String recomputeChainHash(ShareEventRow row, String? prevHashB64) {
    final senderBytes = row.senderId != null
        ? ShareCrypto._uuidToBytes(row.senderId!)
        : Uint8List(16);
    final recipientBytes = row.recipientId != null
        ? ShareCrypto._uuidToBytes(row.recipientId!)
        : Uint8List(16);
    final wireRole = row.shareRoleAfter?.wire ?? ShareCrypto._wireRoleAbsent;
    final fileBytes = row.fileId.isEmpty
        ? Uint8List(16)
        : ShareCrypto._uuidToBytes(row.fileId);
    final eventDer = _crypto.auditEventEncodeV1(
      senderId: senderBytes,
      recipientId: recipientBytes,
      fileId: fileBytes,
      action: row.action.wireString,
      shareRole: wireRole,
      createdAt: row.createdAt,
    );
    final prev = prevHashB64 != null
        ? base64.decode(prevHashB64)
        : Uint8List(32);
    final prefix = ShareCrypto._auditEventPrefix;
    final input = Uint8List(prefix.length + prev.length + eventDer.length);
    input.setRange(0, prefix.length, prefix);
    input.setRange(prefix.length, prefix.length + prev.length, prev);
    input.setRange(prefix.length + prev.length, input.length, eventDer);
    return base64.encode(hex_utils.hexDecode(_crypto.sha256(data: input)));
  }

  /// Walk the per-sender chain over a page of newest-first events. Each sender
  /// bucket (plus the NULL-sender bucket) is re-ordered `(created_at, id)`
  /// ascending. A row whose `prevEventHash` is missing from the in-page bucket
  /// is a page boundary (its real predecessor fell outside the slice); a row
  /// that disagrees on `prevEventHash` with its visible predecessor is a
  /// broken link.
  ChainVerification verifyChain(List<ShareEventRow> events) {
    final chainOk = List<bool>.filled(events.length, false);
    final rowStatus = List<ChainRowStatus>.filled(
      events.length,
      ChainRowStatus.selfHashMismatch,
    );
    if (events.isEmpty) {
      return ChainVerification(
        chainOk: chainOk,
        rowStatus: rowStatus,
        firstBreakIndex: -1,
      );
    }

    final byBucket = <String, List<int>>{};
    for (var i = 0; i < events.length; i++) {
      final bucket = events[i].senderId ?? '__system__';
      (byBucket[bucket] ??= <int>[]).add(i);
    }

    for (final indices in byBucket.values) {
      indices.sort((a, b) {
        final ar = events[a];
        final br = events[b];
        if (ar.createdAt != br.createdAt) {
          return ar.createdAt.compareTo(br.createdAt);
        }
        return ar.id.compareTo(br.id);
      });

      final seenHashes = <String>{};
      String? lastVerifiedHash;
      for (final idx in indices) {
        final row = events[idx];
        final prevHash = row.prevEventHash;

        if (recomputeChainHash(row, prevHash) != row.thisEventHash) {
          chainOk[idx] = false;
          rowStatus[idx] = ChainRowStatus.selfHashMismatch;
          continue;
        }

        final predecessorInPage =
            prevHash != null && seenHashes.contains(prevHash);
        if (predecessorInPage &&
            lastVerifiedHash != null &&
            prevHash != lastVerifiedHash) {
          chainOk[idx] = false;
          rowStatus[idx] = ChainRowStatus.linkBroken;
          continue;
        }

        chainOk[idx] = true;
        rowStatus[idx] = predecessorInPage
            ? ChainRowStatus.linked
            : ChainRowStatus.pageBoundary;
        seenHashes.add(row.thisEventHash);
        lastVerifiedHash = row.thisEventHash;
      }
    }

    return ChainVerification(
      chainOk: chainOk,
      rowStatus: rowStatus,
      firstBreakIndex: chainOk.indexOf(false),
    );
  }

  /// Verify the per-row `senderSignature` over `AuditEventSigInputV1`. Returns
  /// false for system-cascade rows (NULL sender or signature). When the sender
  /// rotated keys after signing, [senderTransition] carries the old key the
  /// pre-migration signature falls back to.
  bool verifyEventSignature(
    ShareEventRow row,
    String senderPubkey, {
    String senderKeyType = 'rsa',
    KeyTransition? senderTransition,
  }) {
    final signature = row.senderSignature;
    final senderId = row.senderId;
    if (signature == null || senderId == null) return false;
    return verifyAuditEvent(
      input: AuditEventSigInput(
        senderId: senderId,
        recipientId: row.recipientId,
        fileId: row.fileId,
        action: row.action,
        shareRoleBefore: row.shareRoleBefore,
        shareRoleAfter: row.shareRoleAfter,
        timestamp: row.createdAt,
      ),
      signature: signature,
      senderPubkey: senderPubkey,
      senderKeyType: senderKeyType,
      senderTransition: senderTransition,
    );
  }
}
