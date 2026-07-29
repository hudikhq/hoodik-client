import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/crypto/share_crypto.dart';
import 'package:hoodik_app/features/shares/services/folder_share_subtree.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

const _crypto = CryptoService();

/// A FilesClient that serves a canned directory tree from an in-memory map of
/// dir-id → children. Only [listFiles] is exercised by the subtree walker.
class _FakeFilesClient extends Fake implements FilesClient {
  _FakeFilesClient(this.tree);

  final Map<String, List<FileItem>> tree;

  @override
  Future<StorageResponse> listFiles({
    String? dirId,
    bool? editable,
    String? orderBy,
    String? order,
  }) async {
    return StorageResponse(children: tree[dirId] ?? const []);
  }
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files);
  final FilesClient _files;
  @override
  FilesClient get files => _files;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  late rust.RsaKeyPair owner;
  late rust.RsaKeyPair recipient;
  late FileCrypto ownerFileCrypto;
  late ShareCrypto ownerShareCrypto;

  setUp(() {
    owner = rust.generateRsaKeypair();
    recipient = rust.generateRsaKeypair();
    ownerFileCrypto = FileCrypto(privateKeyPem: owner.privateKeyPem);
    ownerShareCrypto = ShareCrypto(privateKeyPem: owner.privateKeyPem);
  });

  DiscoveredUser recipientUser() => DiscoveredUser(
    userId: '00000000-0000-0000-0000-0000000000ee',
    email: 'recipient@example.test',
    pubkey: recipient.publicKeyPem,
    fingerprint: recipient.fingerprint,
  );

  /// A file the owner holds: a fresh symmetric key, wrapped under the owner's
  /// own pubkey, paired with the raw key so the test can assert the recipient's
  /// re-wrap round-trips to the same bytes.
  ({FileItem item, String keyHex}) ownedFile(
    String id, {
    String mime = 'text/plain',
  }) {
    final key = _crypto.generateSymmetricKey();
    final wrap = ownerFileCrypto.encryptFileKey(
      fileKey: key,
      publicKeyPem: owner.publicKeyPem,
    );
    return (
      item: FileItem(
        id: id,
        encryptedName: 'enc',
        encryptedKey: wrap,
        mime: mime,
      ),
      keyHex: _crypto.hexEncode(key),
    );
  }

  test('a non-directory root yields exactly itself', () async {
    final f = ownedFile('11111111-1111-1111-1111-111111111111');
    final subtree = FolderShareSubtree(
      client: _FakeApiClient(_FakeFilesClient(const {})),
      fileCrypto: ownerFileCrypto,
      shareCrypto: ownerShareCrypto,
    );
    final collected = await subtree.collect(f.item);
    expect(collected, [f.item]);
  });

  test('collect walks every descendant breadth-first', () async {
    final root = ownedFile('00000000-0000-0000-0000-000000000000', mime: 'dir');
    final sub = ownedFile('00000000-0000-0000-0000-0000000000a1', mime: 'dir');
    final fileA = ownedFile('00000000-0000-0000-0000-0000000000a2');
    final fileB = ownedFile('00000000-0000-0000-0000-0000000000b1');

    final client = _FakeApiClient(
      _FakeFilesClient({
        root.item.id: [sub.item, fileA.item],
        sub.item.id: [fileB.item],
      }),
    );
    final subtree = FolderShareSubtree(
      client: client,
      fileCrypto: ownerFileCrypto,
      shareCrypto: ownerShareCrypto,
    );
    final collected = await subtree.collect(root.item);
    expect(
      collected.map((f) => f.id).toSet(),
      {root.item.id, sub.item.id, fileA.item.id, fileB.item.id},
      reason: 'the full subtree is the set the server requires in entries',
    );
  });

  test('buildEntries re-wraps every key for the recipient', () {
    final root = ownedFile('00000000-0000-0000-0000-000000000000', mime: 'dir');
    final fileA = ownedFile('00000000-0000-0000-0000-0000000000a2');
    final subtree = FolderShareSubtree(
      client: _FakeApiClient(_FakeFilesClient(const {})),
      fileCrypto: ownerFileCrypto,
      shareCrypto: ownerShareCrypto,
    );

    var progressCalls = 0;
    final entries = subtree.buildEntries(
      [root.item, fileA.item],
      recipientUser(),
      onProgress: (_, _) => progressCalls++,
    );

    expect(entries.map((e) => e.fileId).toList(), [
      root.item.id,
      fileA.item.id,
    ]);
    expect(progressCalls, 2);
    // The recipient can unwrap each entry to the original file key.
    final keyByFile = {root.item.id: root.keyHex, fileA.item.id: fileA.keyHex};
    for (final entry in entries) {
      final unwrapped = _crypto.rsaDecrypt(
        ciphertextBase64: entry.encryptedKey,
        privateKeyPem: recipient.privateKeyPem,
      );
      expect(unwrapped, keyByFile[entry.fileId]);
    }
  });

  test('a file with no key is a hard error, never a silent skip', () {
    final keyless = FileItem(
      id: '00000000-0000-0000-0000-0000000000ff',
      encryptedName: 'enc',
      mime: 'text/plain',
    );
    final subtree = FolderShareSubtree(
      client: _FakeApiClient(_FakeFilesClient(const {})),
      fileCrypto: ownerFileCrypto,
      shareCrypto: ownerShareCrypto,
    );
    expect(
      () => subtree.buildEntries([keyless], recipientUser()),
      throwsStateError,
    );
  });

  test('a subtree above the cap throws SubtreeTooLarge', () async {
    final root = ownedFile('00000000-0000-0000-0000-000000000000', mime: 'dir');
    final children = [
      for (var i = 0; i <= subtreeHardCap; i++)
        FileItem(
          id: 'ffffffff-0000-0000-0000-${i.toString().padLeft(12, '0')}',
          encryptedName: 'e',
          mime: 'text/plain',
        ),
    ];
    final client = _FakeApiClient(_FakeFilesClient({root.item.id: children}));
    final subtree = FolderShareSubtree(
      client: client,
      fileCrypto: ownerFileCrypto,
      shareCrypto: ownerShareCrypto,
    );
    await expectLater(
      subtree.collect(root.item),
      throwsA(isA<SubtreeTooLarge>()),
    );
  });
}
