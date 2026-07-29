import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/share_event_models.dart';
import 'package:hoodik_app/core/api/share_events_client.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/providers/audit_log_notifier.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;

const _cryptoService = CryptoService();

String auditUuid(int byte) {
  final hex = byte.toRadixString(16).padLeft(2, '0') * 16;
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// A real RSA keypair plus the fixed UUID the server would assign — the
/// identity an audit row is signed and verified against.
class AuditParty {
  AuditParty(this.userId) : keyPair = rust.generateRsaKeypair();

  final String userId;
  final rust.RsaKeyPair keyPair;

  String get pubkey => keyPair.publicKeyPem;
  ShareCrypto get crypto => ShareCrypto(privateKeyPem: keyPair.privateKeyPem);
  String get fingerprint =>
      _cryptoService.rsaFingerprintPublic(publicKeyPem: pubkey);
}

/// Flip one byte of a base64 blob so it decodes to a different value of the
/// same length — corrupts a hash or signature without breaking base64.
String flipBase64(String b64) {
  final bytes = Uint8List.fromList(base64.decode(b64));
  bytes[0] ^= 0xff;
  return base64.encode(bytes);
}

class StubEventsClient extends Fake implements ShareEventsClient {
  StubEventsClient(this.page);
  ShareEventPage page;
  @override
  Future<ShareEventPage> getEvents(ShareEventQuery query) async => page;
}

class FakeAuditApiClient extends Fake implements ApiClient {
  FakeAuditApiClient(this._events);
  final ShareEventsClient _events;
  @override
  ShareEventsClient get shareEvents => _events;
}

/// Builds audit pages the way the server's `events_for_user` does: a per-sender
/// hash chain (newest-first on the wire) with each row's `this_event_hash` and
/// `sender_signature` produced by the real crypto, so the notifier's verify
/// pass is exercised end-to-end rather than against canned booleans.
class AuditFixture {
  AuditFixture()
    : alice = AuditParty(auditUuid(0xA1)),
      bob = AuditParty(auditUuid(0xB2)),
      fileKey = FileCrypto(privateKeyPem: '').generateFileKey();

  final AuditParty alice;
  final AuditParty bob;
  final Uint8List fileKey;

  /// The file id every row in these pages targets.
  String get fileId => auditUuid(0xF0);

  Map<String, AuditUserRef> get users => {
    alice.userId: AuditUserRef(
      id: alice.userId,
      email: 'alice@example.test',
      pubkey: alice.pubkey,
      fingerprint: alice.fingerprint,
    ),
    bob.userId: AuditUserRef(
      id: bob.userId,
      email: 'bob@example.test',
      pubkey: bob.pubkey,
      fingerprint: bob.fingerprint,
    ),
  };

  /// One properly chained + signed `grant` event from [alice] to [bob].
  /// [prevHashB64] threads the previous row's hash (null for a chain head).
  /// [withDecryptMaterial] wraps the file key for the caller and encrypts the
  /// name so the notifier resolves a plaintext label; when false the JOIN
  /// columns are null and the label falls back to the bare id.
  AppShareEvent grant({
    required String id,
    required int createdAt,
    String? prevHashB64,
    required bool withDecryptMaterial,
    String name = 'budget.xlsx',
  }) {
    final row = ShareEventRow(
      id: id,
      senderId: alice.userId,
      recipientId: bob.userId,
      fileId: fileId,
      action: AuditEventAction.grant,
      shareRoleBefore: null,
      shareRoleAfter: ShareRole.editor,
      createdAt: createdAt,
      prevEventHash: prevHashB64,
      thisEventHash: '',
      senderSignature: null,
    );
    final thisHash = alice.crypto.recomputeChainHash(row, prevHashB64);
    final signature = alice.crypto.signAuditEvent(
      AuditEventSigInput(
        senderId: alice.userId,
        recipientId: bob.userId,
        fileId: fileId,
        action: AuditEventAction.grant,
        shareRoleBefore: null,
        shareRoleAfter: ShareRole.editor,
        timestamp: createdAt,
      ),
    );

    String? encryptedName;
    String? encryptedKey;
    String? cipher;
    if (withDecryptMaterial) {
      final builder = FileCrypto(privateKeyPem: '');
      encryptedName = builder.encryptFileName(
        name: name,
        fileKey: fileKey,
        cipher: 'aegis128l',
      );
      // The caller (bob) unwraps this with his private key in the notifier.
      encryptedKey = builder.encryptFileKey(
        fileKey: fileKey,
        publicKeyPem: bob.pubkey,
      );
      cipher = 'aegis128l';
    }

    return AppShareEvent(
      id: id,
      senderId: alice.userId,
      recipientId: bob.userId,
      fileId: fileId,
      action: AuditEventAction.grant,
      shareRoleBefore: null,
      shareRoleAfter: ShareRole.editor,
      createdAt: createdAt,
      prevEventHash: prevHashB64,
      thisEventHash: thisHash,
      senderSignature: signature,
      encryptedName: encryptedName,
      cipher: cipher,
      encryptedKey: encryptedKey,
    );
  }

  /// A server-attributed cascade row: null sender, null signature, but still a
  /// valid self-hash so the chain math passes.
  AppShareEvent systemEvict({
    required String id,
    required int createdAt,
    String? prevHashB64,
  }) {
    final row = ShareEventRow(
      id: id,
      senderId: null,
      recipientId: bob.userId,
      fileId: fileId,
      action: AuditEventAction.sharedFolderEvict,
      shareRoleBefore: null,
      shareRoleAfter: null,
      createdAt: createdAt,
      prevEventHash: prevHashB64,
      thisEventHash: '',
      senderSignature: null,
    );
    final thisHash = alice.crypto.recomputeChainHash(row, prevHashB64);
    return AppShareEvent(
      id: id,
      senderId: null,
      recipientId: bob.userId,
      fileId: fileId,
      action: AuditEventAction.sharedFolderEvict,
      shareRoleBefore: null,
      shareRoleAfter: null,
      createdAt: createdAt,
      prevEventHash: prevHashB64,
      thisEventHash: thisHash,
      senderSignature: null,
      encryptedName: null,
      cipher: null,
      encryptedKey: null,
    );
  }

  /// A cascade-revoke row: the server's `shared_by_co_owner_revoked` system
  /// action — null sender, null signature, valid self-hash. The enum lacking
  /// this variant is what crashed the whole page parse (bug 7.1a); this builds
  /// a faithful one so the notifier load is exercised against it.
  AppShareEvent systemCoOwnerRevoked({
    required String id,
    required int createdAt,
    String? prevHashB64,
  }) {
    final row = ShareEventRow(
      id: id,
      senderId: null,
      recipientId: bob.userId,
      fileId: fileId,
      action: AuditEventAction.sharedByCoOwnerRevoked,
      shareRoleBefore: ShareRole.reader,
      shareRoleAfter: null,
      createdAt: createdAt,
      prevEventHash: prevHashB64,
      thisEventHash: '',
      senderSignature: null,
    );
    final thisHash = alice.crypto.recomputeChainHash(row, prevHashB64);
    return AppShareEvent(
      id: id,
      senderId: null,
      recipientId: bob.userId,
      fileId: fileId,
      action: AuditEventAction.sharedByCoOwnerRevoked,
      shareRoleBefore: ShareRole.reader,
      shareRoleAfter: null,
      createdAt: createdAt,
      prevEventHash: prevHashB64,
      thisEventHash: thisHash,
      senderSignature: null,
      encryptedName: null,
      cipher: null,
      encryptedKey: null,
    );
  }

  /// A two-row alice chain (oldest then newest) returned newest-first like the
  /// wire. Returns `(wireEvents, oldestHash, newestHash)`.
  (List<AppShareEvent>, String, String) twoRowChain({
    bool withDecryptMaterial = true,
  }) {
    final oldest = grant(
      id: 'evt-1',
      createdAt: 1700000000,
      prevHashB64: null,
      withDecryptMaterial: withDecryptMaterial,
    );
    final newest = grant(
      id: 'evt-2',
      createdAt: 1700000100,
      prevHashB64: oldest.thisEventHash,
      withDecryptMaterial: withDecryptMaterial,
    );
    return ([newest, oldest], oldest.thisEventHash, newest.thisEventHash);
  }

  ShareEventPage page(List<AppShareEvent> events) => ShareEventPage(
    events: events,
    users: users,
    total: events.length,
    limit: auditLogPageSize,
    offset: 0,
  );
}
