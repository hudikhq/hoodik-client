// Cross-runtime fixture test for the Sharing v1 ASN.1 DER encoders.
//
// Mirrors `hoodik/hoodik/tests/shares_asn1_fixtures.rs` (native) and
// `hoodik/web/tests/shares/asn1_fixtures.test.ts` (WASM). The reference
// bytes are the same committed `.der` fixtures under
// `integration_test/fixtures/`; they're inlined here as base64 so the
// assertions run identically on host (`flutter test`) and on device
// (Patrol), without polluting `pubspec.yaml`'s production asset bundle.
//
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

const String _shareRequestB64 =
    'MIGYAgEBBBARERERERERERERERERERERBBAiIiIiIiIiIiIiIiIiIiIiBCAzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMwoBAQQQRERERERERERERERERERERAQgVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVUCBGd0hYAEEGZmZmZmZmZmZmZmZmZmZmY=';

const String _memberSigB64 =
    'MIIBUgIBAQQQd3d3d3d3d3d3d3d3d3d3dwSCAQ6qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqoEIIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiICgECAgRndIXk';

const String _auditEventB64 =
    'MEkCAQEEEKqqqqqqqqqqqqqqqqqqqqoEELu7u7u7u7u7u7u7u7u7u7sEEMzMzMzMzMzMzMzMzMzMzMwEBWdyYW50CgEAAgRndIZI';

const String _folderMemberListB64 =
    'MIIBGgIBAQQQ8PDw8PDw8PDw8PDw8PDw8AQQERERERERERERERERERERETCB6jBMBBARERERERERERERERERERERBCChoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoaGhoQoBAAEB/wQQERERERERERERERERERERETBMBBAiIiIiIiIiIiIiIiIiIiIiBCCysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysgoBAgEBAAQQERERERERERERERERERERETBMBBAzMzMzMzMzMzMzMzMzMzMzBCDDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDw8PDwwoBAQEBAAQQIiIiIiIiIiIiIiIiIiIiIgIEZ3lCAA==';

const String _auditEventSigInputB64 =
    'ME4CAQEEEKqqqqqqqqqqqqqqqqqqqqqgEgQQu7u7u7u7u7u7u7u7u7u7uwQQzMzMzMzMzMzMzMzMzMzMzAoBAqEDCgEAogMKAQECBGd0hqw=';

Uint8List _decode(String b64) => Uint8List.fromList(base64.decode(b64));

Uint8List _repeat(int byte, int length) =>
    Uint8List.fromList(List.filled(length, byte));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  group('cryptfns::asn1 FFI exports', () {
    testWidgets('share_payload_encode_v1 matches committed fixture', (
      WidgetTester tester,
    ) async {
      final bytes = rust.sharePayloadEncodeV1(
        senderId: _repeat(0x11, 16),
        recipientId: _repeat(0x22, 16),
        recipientPubkeyFingerprint: _repeat(0x33, 32),
        shareRole: 1,
        rootFileId: _repeat(0x44, 16),
        entriesHash: _repeat(0x55, 32),
        timestamp: 1735689600,
        nonce: _repeat(0x66, 16),
      );
      expect(bytes, equals(_decode(_shareRequestB64)));
    });

    testWidgets('member_sig_encode_v1 matches committed fixture', (
      WidgetTester tester,
    ) async {
      final bytes = rust.memberSigEncodeV1(
        userId: _repeat(0x77, 16),
        pubkeyDer: _repeat(0xAA, 270),
        fingerprint: _repeat(0x88, 32),
        shareRole: 2,
        signedAt: 1735689700,
      );
      expect(bytes, equals(_decode(_memberSigB64)));
    });

    testWidgets('audit_event_encode_v1 matches committed fixture', (
      WidgetTester tester,
    ) async {
      final bytes = rust.auditEventEncodeV1(
        senderId: _repeat(0xAA, 16),
        recipientId: _repeat(0xBB, 16),
        fileId: _repeat(0xCC, 16),
        action: 'grant',
        shareRole: 0,
        createdAt: 1735689800,
      );
      expect(bytes, equals(_decode(_auditEventB64)));
    });

    testWidgets('folder_member_list_encode_v1 matches committed fixture', (
      WidgetTester tester,
    ) async {
      // Members supplied out of order (0x33, 0x11, 0x22) so the encoder's
      // canonical user_id sort runs — mirrors the WASM and Rust fixtures.
      final userIds = Uint8List(3 * 16)
        ..setRange(0, 16, _repeat(0x33, 16))
        ..setRange(16, 32, _repeat(0x11, 16))
        ..setRange(32, 48, _repeat(0x22, 16));
      final fingerprints = Uint8List(3 * 32)
        ..setRange(0, 32, _repeat(0xC3, 32))
        ..setRange(32, 64, _repeat(0xA1, 32))
        ..setRange(64, 96, _repeat(0xB2, 32));
      final signedBy = Uint8List(3 * 16)
        ..setRange(0, 16, _repeat(0x22, 16))
        ..setRange(16, 32, _repeat(0x11, 16))
        ..setRange(32, 48, _repeat(0x11, 16));

      final bytes = rust.folderMemberListEncodeV1(
        folderId: _repeat(0xF0, 16),
        folderOwnerId: _repeat(0x11, 16),
        userIds: userIds,
        pubkeyFingerprints: fingerprints,
        shareRoles: Uint8List.fromList([1, 0, 2]),
        isOwnerFlags: Uint8List.fromList([0, 1, 0]),
        signedByUserIds: signedBy,
        membersSignedAt: 1736000000,
      );
      expect(bytes, equals(_decode(_folderMemberListB64)));
    });

    testWidgets('audit_event_sig_input_encode_v1 matches committed fixture', (
      WidgetTester tester,
    ) async {
      final bytes = rust.auditEventSigInputEncodeV1(
        senderId: _repeat(0xAA, 16),
        recipientId: _repeat(0xBB, 16),
        fileId: _repeat(0xCC, 16),
        action: 2,
        shareRoleBefore: 0,
        shareRoleAfter: 1,
        timestamp: 1735689900,
      );
      expect(bytes, equals(_decode(_auditEventSigInputB64)));
    });

    testWidgets('entries_encode_v1 is order-independent', (
      WidgetTester tester,
    ) async {
      final fileIdsForward = Uint8List(2 * 16)
        ..setRange(0, 16, _repeat(0xDD, 16))
        ..setRange(16, 32, _repeat(0x99, 16));
      final fileIdsReversed = Uint8List(2 * 16)
        ..setRange(0, 16, _repeat(0x99, 16))
        ..setRange(16, 32, _repeat(0xDD, 16));
      final keysForward = Uint8List(2 * 256)
        ..setRange(0, 256, _repeat(0x11, 256))
        ..setRange(256, 512, _repeat(0x22, 256));
      final keysReversed = Uint8List(2 * 256)
        ..setRange(0, 256, _repeat(0x22, 256))
        ..setRange(256, 512, _repeat(0x11, 256));

      final forward = rust.entriesEncodeV1(
        fileIds: fileIdsForward,
        encryptedKeysFlat: keysForward,
        encryptedKeyLengths: [256, 256],
      );
      final reversed = rust.entriesEncodeV1(
        fileIds: fileIdsReversed,
        encryptedKeysFlat: keysReversed,
        encryptedKeyLengths: [256, 256],
      );
      expect(reversed, equals(forward));
    });
  });

  group('sign ↔ verify roundtrip per domain prefix', () {
    final cases = <String, Uint8List>{
      'hoodik-share-v1\x00': _decode(_shareRequestB64),
      'hoodik-folder-mem-v1\x00': _decode(_memberSigB64),
      'hoodik-folder-list-v1\x00': _decode(_folderMemberListB64),
      'hoodik-audit-v1\x00': _decode(_auditEventB64),
      'hoodik-audit-sig-v1\x00': _decode(_auditEventSigInputB64),
    };

    cases.forEach((prefix, payloadDer) {
      testWidgets('$prefix verifies and rejects a tampered payload', (
        WidgetTester tester,
      ) async {
        final kp = rust.generateRsaKeypair();
        final prefixBytes = utf8.encode(prefix);

        Uint8List signingInput(Uint8List der) {
          final out = Uint8List(prefixBytes.length + der.length);
          out.setRange(0, prefixBytes.length, prefixBytes);
          out.setRange(prefixBytes.length, out.length, der);
          return out;
        }

        final signature = rust.rsaSignBytes(
          message: signingInput(payloadDer),
          privateKeyPem: kp.privateKeyPem,
        );
        expect(
          rust.rsaVerifyBytes(
            message: signingInput(payloadDer),
            signature: signature,
            publicKeyPem: kp.publicKeyPem,
          ),
          isTrue,
        );

        final tampered = Uint8List.fromList(payloadDer);
        tampered[20] ^= 0xFF;
        expect(
          rust.rsaVerifyBytes(
            message: signingInput(tampered),
            signature: signature,
            publicKeyPem: kp.publicKeyPem,
          ),
          isFalse,
        );
      });
    });
  });

  group('fingerprint parity', () {
    testWidgets('rsa_fingerprint_public matches the keypair fingerprint', (
      WidgetTester tester,
    ) async {
      final kp = rust.generateRsaKeypair();
      expect(
        rust.rsaFingerprintPublic(publicKeyPem: kp.publicKeyPem),
        equals(kp.fingerprint),
      );
    });
  });
}
