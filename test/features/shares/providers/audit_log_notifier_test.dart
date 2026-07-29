import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/share_event_models.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/features/shares/providers/audit_log_notifier.dart';
import 'package:hoodik_app/src/rust/frb_generated.dart';

import 'audit_log_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late AuditFixture fx;
  ProviderContainer? container;

  setUp(() => fx = AuditFixture());
  tearDown(() => container?.dispose());

  ProviderContainer wire(ShareEventPage page) {
    container = ProviderContainer(
      overrides: [
        decryptedPrivateKeyProvider.overrideWith(
          (ref) => fx.bob.keyPair.privateKeyPem,
        ),
        apiClientProvider.overrideWithValue(
          FakeAuditApiClient(StubEventsClient(page)),
        ),
      ],
    );
    return container!;
  }

  Future<List<AuditDisplayRow>> load(ShareEventPage page) async {
    final state = await wire(page).read(auditLogNotifierProvider.future);
    return state.rows;
  }

  test('a clean chain verifies and decrypts names', () async {
    final (events, _, _) = fx.twoRowChain();
    final rows = await load(fx.page(events));

    // Wire order is preserved: newest first.
    expect(rows.map((r) => r.event.id), ['evt-2', 'evt-1']);
    expect(rows.every((r) => r.badge == AuditRowBadge.verified), isTrue);
    // The newest row's predecessor is in-page (linked); the oldest is the
    // chain head, classified as a page boundary — both pass.
    expect(
      rows.map((r) => r.chainStatus),
      containsAll([ChainRowStatus.linked, ChainRowStatus.pageBoundary]),
    );
    expect(rows.every((r) => r.fileLabel == 'budget.xlsx'), isTrue);
    expect(rows.every((r) => r.senderEmail == 'alice@example.test'), isTrue);
    expect(rows.every((r) => r.recipientEmail == 'bob@example.test'), isTrue);
  });

  test('a single chain-head row passes as a page boundary', () async {
    final head = fx.grant(
      id: 'evt-1',
      createdAt: 1700000000,
      withDecryptMaterial: true,
    );
    final rows = await load(fx.page([head]));
    expect(rows.single.badge, AuditRowBadge.verified);
    expect(rows.single.chainStatus, ChainRowStatus.pageBoundary);
  });

  test('a tampered self-hash is flagged as a mismatch', () async {
    final (events, _, _) = fx.twoRowChain();
    // Corrupt the newest row's stored hash — its recompute won't match.
    final tampered = AppShareEvent(
      id: events[0].id,
      senderId: events[0].senderId,
      recipientId: events[0].recipientId,
      fileId: events[0].fileId,
      action: events[0].action,
      shareRoleBefore: events[0].shareRoleBefore,
      shareRoleAfter: events[0].shareRoleAfter,
      createdAt: events[0].createdAt,
      prevEventHash: events[0].prevEventHash,
      thisEventHash: flipBase64(events[0].thisEventHash),
      senderSignature: events[0].senderSignature,
      encryptedName: events[0].encryptedName,
      cipher: events[0].cipher,
      encryptedKey: events[0].encryptedKey,
    );
    final rows = await load(fx.page([tampered, events[1]]));

    final newest = rows.firstWhere((r) => r.event.id == 'evt-2');
    expect(newest.badge, AuditRowBadge.tampered);
    expect(newest.chainStatus, ChainRowStatus.selfHashMismatch);
    // The untouched head still verifies.
    expect(
      rows.firstWhere((r) => r.event.id == 'evt-1').badge,
      AuditRowBadge.verified,
    );
  });

  test('a forged chain link is flagged as a mismatch', () async {
    // A real fork in alice's chain: evt-3 points back at evt-1's hash (a
    // visible, already-seen predecessor) instead of evt-2's, while its own
    // self-hash is internally consistent with that pointer. The verifier sees
    // a seen-but-wrong predecessor — the link-broken case. (A forged pointer
    // to a hash *not* in the page is a page boundary, which passes; the break
    // is only detectable when both ends are visible.)
    final first = fx.grant(
      id: 'evt-1',
      createdAt: 1700000000,
      withDecryptMaterial: false,
    );
    final second = fx.grant(
      id: 'evt-2',
      createdAt: 1700000100,
      prevHashB64: first.thisEventHash,
      withDecryptMaterial: false,
    );
    final third = fx.grant(
      id: 'evt-3',
      createdAt: 1700000200,
      prevHashB64: first.thisEventHash,
      withDecryptMaterial: false,
    );
    final rows = await load(fx.page([third, second, first]));

    final flagged = rows.firstWhere((r) => r.event.id == 'evt-3');
    expect(flagged.badge, AuditRowBadge.tampered);
    expect(flagged.chainStatus, ChainRowStatus.linkBroken);
  });

  test('a row whose signature fails verification is flagged', () async {
    final head = fx.grant(
      id: 'evt-1',
      createdAt: 1700000000,
      withDecryptMaterial: false,
    );
    // Keep the (valid) chain hash but corrupt the signature: self-hash passes,
    // signature fails → still a mismatch, proving the sig check is independent.
    final forged = AppShareEvent(
      id: head.id,
      senderId: head.senderId,
      recipientId: head.recipientId,
      fileId: head.fileId,
      action: head.action,
      shareRoleBefore: head.shareRoleBefore,
      shareRoleAfter: head.shareRoleAfter,
      createdAt: head.createdAt,
      prevEventHash: head.prevEventHash,
      thisEventHash: head.thisEventHash,
      senderSignature: flipBase64(head.senderSignature!),
      encryptedName: null,
      cipher: null,
      encryptedKey: null,
    );
    final rows = await load(fx.page([forged]));
    expect(rows.single.badge, AuditRowBadge.tampered);
    // The chain itself is intact — the headline should attribute the failure
    // to the signature, not a chain break.
    expect(rows.single.chainStatus, ChainRowStatus.pageBoundary);
  });

  test(
    'a row signed by a different key than the page names is flagged',
    () async {
      // The signature verifies against bob's pubkey, but the page names alice as
      // the sender — a key-substitution attempt. Verified against the named
      // sender's pubkey it must fail.
      final createdAt = 1700000000;
      final row = ShareEventRow(
        id: 'evt-1',
        senderId: fx.alice.userId,
        recipientId: fx.bob.userId,
        fileId: fx.fileId,
        action: AuditEventAction.grant,
        shareRoleBefore: null,
        shareRoleAfter: ShareRole.editor,
        createdAt: createdAt,
        prevEventHash: null,
        thisEventHash: '',
        senderSignature: null,
      );
      final thisHash = fx.alice.crypto.recomputeChainHash(row, null);
      final wrongSignerSig = fx.bob.crypto.signAuditEvent(
        AuditEventSigInput(
          senderId: fx.alice.userId,
          recipientId: fx.bob.userId,
          fileId: fx.fileId,
          action: AuditEventAction.grant,
          shareRoleBefore: null,
          shareRoleAfter: ShareRole.editor,
          timestamp: createdAt,
        ),
      );
      final event = AppShareEvent(
        id: 'evt-1',
        senderId: fx.alice.userId,
        recipientId: fx.bob.userId,
        fileId: fx.fileId,
        action: AuditEventAction.grant,
        shareRoleBefore: null,
        shareRoleAfter: ShareRole.editor,
        createdAt: createdAt,
        prevEventHash: null,
        thisEventHash: thisHash,
        senderSignature: wrongSignerSig,
        encryptedName: null,
        cipher: null,
        encryptedKey: null,
      );
      final rows = await load(fx.page([event]));
      expect(rows.single.badge, AuditRowBadge.tampered);
    },
  );

  test(
    'a system row is labelled system and skips the signature check',
    () async {
      final head = fx.grant(
        id: 'evt-1',
        createdAt: 1700000000,
        withDecryptMaterial: false,
      );
      final system = fx.systemEvict(
        id: 'evt-2',
        createdAt: 1700000100,
        prevHashB64: head.thisEventHash,
      );
      final rows = await load(fx.page([system, head]));

      final sysRow = rows.firstWhere((r) => r.event.id == 'evt-2');
      expect(sysRow.badge, AuditRowBadge.system);
      expect(sysRow.senderEmail, 'system');
      // A null-sender row lives in its own `__system__` chain bucket, separate
      // from alice's — so it's the head of that bucket and classified as a page
      // boundary (its real predecessor, if any, is server-attributed elsewhere).
      // The badge is what matters here; the chain status still passes.
      expect(sysRow.chainStatus, ChainRowStatus.pageBoundary);
    },
  );

  test(
    'a cascade-revoke system row loads without throwing and badges system',
    () async {
      // Reproduces bug 7.1a: before the enum gained this variant, one such row
      // threw out of `AuditEventAction.fromWire` and blanked the entire page.
      final head = fx.grant(
        id: 'evt-1',
        createdAt: 1700000000,
        withDecryptMaterial: false,
      );
      final cascade = fx.systemCoOwnerRevoked(
        id: 'evt-2',
        createdAt: 1700000100,
        prevHashB64: head.thisEventHash,
      );
      final rows = await load(fx.page([cascade, head]));

      final cascadeRow = rows.firstWhere((r) => r.event.id == 'evt-2');
      expect(cascadeRow.badge, AuditRowBadge.system);
      expect(cascadeRow.event.action, AuditEventAction.sharedByCoOwnerRevoked);
      expect(cascadeRow.senderEmail, 'system');
    },
  );

  test('falls back to the bare file id when the wrap is absent', () async {
    final head = fx.grant(
      id: 'evt-1',
      createdAt: 1700000000,
      withDecryptMaterial: false,
    );
    final rows = await load(fx.page([head]));
    expect(rows.single.fileLabel, startsWith('file '));
    expect(rows.single.fileLabel, contains(fx.fileId.substring(0, 8)));
  });

  test('an empty page yields an empty, non-error state', () async {
    final state = await wire(
      fx.page(const []),
    ).read(auditLogNotifierProvider.future);
    expect(state.isEmpty, isTrue);
    expect(state.total, 0);
  });
}
