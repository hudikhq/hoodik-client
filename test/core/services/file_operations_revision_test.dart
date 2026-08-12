import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

class _MutationsClient extends Fake implements FilesClient {
  _MutationsClient({this.failing = false});

  final bool failing;

  void _maybeFail() {
    if (failing) throw Exception('server said no');
  }

  @override
  Future<Map<String, dynamic>> createDirectory({
    required String encryptedKey,
    required String nameHash,
    required String encryptedName,
    String? parentDirId,
    String? cipher,
    List<String>? searchTokensHashed,
  }) async {
    _maybeFail();
    return {'id': 'dir-id'};
  }

  @override
  Future<void> deleteFile(String fileId) async => _maybeFail();

  @override
  Future<void> deleteMany(List<String> fileIds) async => _maybeFail();
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files);

  final FilesClient _files;

  @override
  FilesClient get files => _files;

  @override
  Future<void> ensureFreshSession() async {}
}

/// The recent-notes panel is built once inside the shell's IndexedStack and
/// never remounted, so it held a list that could outlive the files in it — a
/// note deleted from the sidebar stayed on screen for the rest of the
/// session. Rather than make every mutation site remember to notify every
/// listing, the one service they all route through reports that it changed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  const crypto = CryptoService();

  FileOperations build({bool failing = false}) {
    final keys = rust.generateRsaKeypair();
    return FileOperations(
      client: _FakeApiClient(_MutationsClient(failing: failing)),
      privateKeyPem: keys.privateKeyPem,
      publicKeyPem: keys.publicKeyPem,
      crypto: crypto,
    );
  }

  test('starts at zero', () {
    expect(build().revision.value, 0);
  });

  test('a delete ticks it', () async {
    final ops = build();
    await ops.delete('file-1');
    expect(ops.revision.value, 1);
  });

  test('creating a folder ticks it', () async {
    final ops = build();
    await ops.createFolder('Travel');
    expect(ops.revision.value, 1);
  });

  test('every mutation ticks, so listeners see each one', () async {
    final ops = build();
    await ops.createFolder('Travel');
    await ops.delete('file-1');
    await ops.deleteMany(['file-2', 'file-3']);
    expect(ops.revision.value, 3);
  });

  test('a failed mutation changed nothing, so it does not tick', () async {
    final ops = build(failing: true);
    await expectLater(ops.delete('file-1'), throwsA(anything));
    expect(ops.revision.value, 0);
  });
}
