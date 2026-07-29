import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/share_event_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/widgets/audit_event_sentence.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

Uint8List _repeat(int byte, int length) =>
    Uint8List.fromList(List.filled(length, byte));

String _uuid(int byte) {
  final hex = byte.toRadixString(16).padLeft(2, '0') * 16;
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The account-level `key_rotation` row the server appends to the owner's own
/// per-sender chain after an RSA→curve25519 migration: NULL recipient, NULL
/// file (the wire's `file_id` collapses to `''` in [AppShareEvent.fromJson]),
/// signed under `KeyRotationAuditV1` rather than the share-audit canonical.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();
  late ShareCrypto shareCrypto;

  setUp(() {
    final kp = rust.generateRsaKeypair();
    shareCrypto = ShareCrypto(privateKeyPem: kp.privateKeyPem);
  });

  ShareEventRow keyRotationRow({required String thisEventHash}) =>
      ShareEventRow(
        id: 'r1',
        senderId: _uuid(0xAA),
        recipientId: null,
        fileId: '',
        action: AuditEventAction.keyRotation,
        shareRoleBefore: null,
        shareRoleAfter: null,
        createdAt: 1234,
        prevEventHash: null,
        thisEventHash: thisEventHash,
        senderSignature: 'a2V5LXJvdGF0aW9uLXNpZw==',
      );

  // The hash the server writes: sha256(prefix ‖ 32 zero prev ‖
  // encode_audit_event_v1(sender, 16 zero recipient, 16 zero file,
  // "key_rotation", role-absent, created_at)) — see
  // auth/src/contracts/migration.rs::append_key_rotation_event.
  String serverChainHash() {
    final eventDer = rust.auditEventEncodeV1(
      senderId: _repeat(0xAA, 16),
      recipientId: Uint8List(16),
      fileId: Uint8List(16),
      action: 'key_rotation',
      shareRole: 0xff,
      createdAt: 1234,
    );
    final prefix = utf8.encode('hoodik-audit-v1\x00');
    final input = Uint8List(prefix.length + 32 + eventDer.length);
    input.setRange(0, prefix.length, prefix);
    input.setRange(prefix.length + 32, input.length, eventDer);
    return base64.encode(crypto.hexDecode(rust.sha256Digest(data: input)));
  }

  test('key_rotation row with an empty file id verifies against the chain', () {
    final row = keyRotationRow(thisEventHash: serverChainHash());

    expect(
      shareCrypto.recomputeChainHash(row, null),
      equals(row.thisEventHash),
    );

    final result = shareCrypto.verifyChain([row]);
    expect(result.chainOk, equals([true]));
    expect(result.rowStatus, equals([ChainRowStatus.pageBoundary]));
    expect(result.firstBreakIndex, -1);
  });

  test('the sentence names a key rotation without a file', () {
    final event = AppShareEvent(
      id: 'r1',
      senderId: _uuid(0xAA),
      recipientId: null,
      fileId: '',
      action: AuditEventAction.keyRotation,
      shareRoleBefore: null,
      shareRoleAfter: null,
      createdAt: 1234,
      prevEventHash: null,
      thisEventHash: serverChainHash(),
      senderSignature: 'a2V5LXJvdGF0aW9uLXNpZw==',
      encryptedName: null,
      cipher: null,
      encryptedKey: null,
    );

    expect(
      auditEventSentence(
        event: event,
        senderEmail: 'alice@example.com',
        recipientEmail: '',
        fileLabel: '',
      ),
      'alice@example.com rotated their account encryption keys',
    );
  });
}
