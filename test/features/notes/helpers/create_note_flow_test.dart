import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/crypto_service.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:hoodik_app/features/notes/helpers/create_note_flow.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/src/rust/api.dart' as rust;
import 'package:hoodik_app/src/rust/frb_generated.dart';

const _crypto = CryptoService();
const _newNoteId = 'note-aaaa';
const _parentDir = 'parent-dir';

class _FakeFileOperations extends Fake implements FileOperations {
  String? createdParentDir;

  @override
  Future<String> createNote(
    String name,
    String content, {
    String? parentDirId,
  }) async {
    createdParentDir = parentDirId;
    return _newNoteId;
  }
}

class _FakeFilesClient extends Fake implements FilesClient {
  _FakeFilesClient(this.metadata);

  final Map<String, dynamic> metadata;

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async => metadata;
}

class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient(this._files);

  final FilesClient _files;

  @override
  FilesClient get files => _files;
}

class _RecordingFilesNotifier extends FilesNotifier {
  final List<String?> loadedDirs = [];
  String? _arg;

  @override
  FilesState build(String? arg) {
    _arg = arg;
    return const FilesState(loading: false);
  }

  @override
  Future<void> load() async => loadedDirs.add(_arg);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('creating a note refreshes the files list for its parent dir', (
    tester,
  ) async {
    final keypair = rust.generateRsaKeypair();
    final fileKey = _crypto.generateSymmetricKey();
    final fileCrypto = FileCrypto(privateKeyPem: keypair.privateKeyPem);
    final wrap = fileCrypto.encryptFileKey(
      fileKey: fileKey,
      publicKeyPem: keypair.publicKeyPem,
    );
    final encryptedName = fileCrypto.encryptFileName(
      name: 'note.md',
      fileKey: fileKey,
      cipher: 'aegis128l',
    );

    final ops = _FakeFileOperations();
    final filesClient = _FakeFilesClient({
      'id': _newNoteId,
      'mime': 'text/markdown',
      'encrypted_name': encryptedName,
      'encrypted_key': wrap,
      'cipher': 'aegis128l',
    });
    final notifier = _RecordingFilesNotifier();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => createNoteAndOpen(
                  context: context,
                  ref: ref,
                  parentDirId: _parentDir,
                ),
                child: const Text('create'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/editor/:fileId',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileOperationsProvider.overrideWithValue(ops),
          apiClientProvider.overrideWithValue(_FakeApiClient(filesClient)),
          fileCryptoProvider.overrideWithValue(fileCrypto),
          filesNotifierProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('create'));
    await tester.pumpAndSettle();

    // Name the note in the prompt dialog and confirm.
    await tester.enterText(find.byType(EditableText), 'note');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(ops.createdParentDir, _parentDir);
    expect(notifier.loadedDirs, [_parentDir]);
  });
}
