import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/crypto/file_crypto.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/widgets/app_notification.dart';
import 'package:hoodik_app/features/notes/screens/version_history_screen.dart';
import 'package:hoodik_app/l10n/generated/app_localizations.dart';
import 'package:hoodik_app/core/widgets/app_icons.dart';

/// Fake [FilesClient] — only [getFileMetadata] is reached from the
/// screen's load path.
class _FakeFilesClient extends Fake implements FilesClient {
  _FakeFilesClient(this._parent);

  final _FakeApiClient _parent;

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async =>
      _parent.metadata;
}

/// Fake [VersionsClient] — backs the screen's version-history actions and
/// records them on the parent client for assertion.
class _FakeVersionsClient extends Fake implements VersionsClient {
  _FakeVersionsClient(this._parent);

  final _FakeApiClient _parent;

  @override
  Future<List<FileVersion>> list(String fileId) async => _parent.versionList;

  @override
  Future<Map<String, dynamic>> restore({
    required String fileId,
    required int version,
  }) async {
    _parent.calls.add((op: 'restore', version: version));
    return _parent.metadata;
  }

  @override
  Future<void> delete({required String fileId, required int version}) async {
    _parent.calls.add((op: 'delete', version: version));
    _parent.versionList = _parent.versionList
        .where((v) => v.version != version)
        .toList();
  }

  @override
  Future<void> purgeAll(String fileId) async {
    _parent.calls.add((op: 'purge', version: null));
    _parent.versionList = const [];
  }
}

/// Fake ApiClient — only the sub-clients VersionHistoryScreen reaches
/// into are overridden. Records calls for assertion.
class _FakeApiClient extends Fake implements ApiClient {
  _FakeApiClient({required this.metadata, this.versionList = const []}) {
    _files = _FakeFilesClient(this);
    _versions = _FakeVersionsClient(this);
  }

  Map<String, dynamic> metadata;
  List<FileVersion> versionList;

  late final _FakeFilesClient _files;
  late final _FakeVersionsClient _versions;

  /// Each entry: ('restore'|'delete'|'purge', version?). Used to check
  /// the screen wires the right action to the right call.
  final List<({String op, int? version})> calls = [];

  @override
  FilesClient get files => _files;

  @override
  VersionsClient get versions => _versions;
}

/// Fake FileCrypto — returns deterministic strings/bytes without any
/// actual cipher work, so tests don't need real RSA keys.
class _FakeFileCrypto extends Fake implements FileCrypto {
  String fakeName = 'My Note';

  @override
  Uint8List decryptFileKey(String encryptedKeyBase64) =>
      Uint8List.fromList(List.generate(16, (i) => i));

  @override
  String decryptFileName({
    required String encryptedNameHex,
    required Uint8List fileKey,
    required String cipher,
  }) => fakeName;

  @override
  String hashFileName(String name) => 'hash-$name';

  @override
  String encryptFileName({
    required String name,
    required Uint8List fileKey,
    required String cipher,
  }) => 'enc-$name';

  @override
  List<String> tokenizeForSearch(String name) => [name];

  @override
  Uint8List decryptChunk({
    required Uint8List data,
    required Uint8List fileKey,
    required String cipher,
    required int chunkIndex,
  }) => data;
}

FileItem _fileItem({
  String id = 'note-1',
  String name = 'note.md',
  bool editable = true,
  int active = 1,
}) => FileItem(
  id: id,
  encryptedName: 'enc-$name',
  encryptedKey: 'enc-key',
  mime: 'text/markdown',
  editable: editable,
  activeVersion: active,
  createdAt: 1700000000,
  finishedUploadAt: 1700000000,
  chunks: 1,
  size: 10,
);

FileVersion _fakeVersion({required int v, int chunks = 1}) => FileVersion(
  id: 'fv-$v',
  fileId: 'note-1',
  version: v,
  userId: null,
  isAnonymous: false,
  size: 100,
  chunks: chunks,
  sha256: null,
  createdAt: 1700000000 + v * 60,
);

Widget _hostedScreen({
  required ApiClient client,
  required FileCrypto crypto,
  String fileId = 'note-1',
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      fileCryptoProvider.overrideWithValue(crypto),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: VersionHistoryScreen(fileId: fileId),
    ),
  );
}

void main() {
  group('VersionHistoryScreen', () {
    testWidgets('renders empty state when no versions exist', (tester) async {
      final client = _FakeApiClient(
        metadata: _fileItem().toMockJson(),
        versionList: const [],
      );
      await tester.pumpWidget(
        _hostedScreen(client: client, crypto: _FakeFileCrypto()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No history yet. Edit the note to start building one.'),
        findsOneWidget,
      );
      // No purge button when there's nothing to clear.
      expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
    });

    testWidgets('lists versions newest-first with author + chunk count', (
      tester,
    ) async {
      final client = _FakeApiClient(
        metadata: _fileItem(active: 3).toMockJson(),
        versionList: [_fakeVersion(v: 2, chunks: 4), _fakeVersion(v: 1)],
      );
      await tester.pumpWidget(
        _hostedScreen(client: client, crypto: _FakeFileCrypto()),
      );
      await tester.pumpAndSettle();

      expect(find.text('v2'), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);
      // user_id=null + is_anonymous=false → "Unknown" (e.g. account
      // synced from a server we don't know the user for).
      expect(find.text('Unknown · 4 chunks'), findsOneWidget);
      expect(find.text('Unknown · 1 chunk'), findsOneWidget);
    });

    testWidgets('restore goes through confirmation and hits the API', (
      tester,
    ) async {
      final client = _FakeApiClient(
        metadata: _fileItem(active: 2).toMockJson(),
        versionList: [_fakeVersion(v: 1)],
      );
      await tester.pumpWidget(
        _hostedScreen(client: client, crypto: _FakeFileCrypto()),
      );
      await tester.pumpAndSettle();

      // Open the row's action menu and pick Restore.
      await tester.tap(find.byIcon(AppIcons.overflowVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore in place'));
      await tester.pumpAndSettle();

      // Confirm dialog → tap Restore.
      expect(find.text('Restore v1?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();

      expect(client.calls.where((c) => c.op == 'restore').length, 1);
      expect(client.calls.first.version, 1);
    });

    testWidgets('cancel on restore confirm does NOT call the API', (
      tester,
    ) async {
      final client = _FakeApiClient(
        metadata: _fileItem(active: 2).toMockJson(),
        versionList: [_fakeVersion(v: 1)],
      );
      await tester.pumpWidget(
        _hostedScreen(client: client, crypto: _FakeFileCrypto()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.overflowVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore in place'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(client.calls.where((c) => c.op == 'restore'), isEmpty);
    });

    testWidgets('delete removes the version from the list', (tester) async {
      final client = _FakeApiClient(
        metadata: _fileItem(active: 3).toMockJson(),
        versionList: [_fakeVersion(v: 2), _fakeVersion(v: 1)],
      );
      await tester.pumpWidget(
        _hostedScreen(client: client, crypto: _FakeFileCrypto()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.overflowVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this version'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(client.calls.where((c) => c.op == 'delete').length, 1);
      expect(client.calls.first.version, 2);
      // After reload the row should be gone.
      expect(find.text('v2'), findsNothing);
      expect(find.text('v1'), findsOneWidget);
    });

    testWidgets('purge-all sweeps every version', (tester) async {
      final client = _FakeApiClient(
        metadata: _fileItem(active: 3).toMockJson(),
        versionList: [_fakeVersion(v: 2), _fakeVersion(v: 1)],
      );
      await tester.pumpWidget(
        _hostedScreen(client: client, crypto: _FakeFileCrypto()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete all'));
      await tester.pumpAndSettle();

      expect(client.calls.where((c) => c.op == 'purge').length, 1);
      expect(find.text('v2'), findsNothing);
      expect(find.text('v1'), findsNothing);
      expect(
        find.text('No history yet. Edit the note to start building one.'),
        findsOneWidget,
      );
    });

    testWidgets('back arrow returns false when no version was restored', (
      tester,
    ) async {
      final client = _FakeApiClient(
        metadata: _fileItem().toMockJson(),
        versionList: [_fakeVersion(v: 1)],
      );

      bool? popResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            fileCryptoProvider.overrideWithValue(_FakeFileCrypto()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) =>
                            const VersionHistoryScreen(fileId: 'note-1'),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // No restore action — just back out.
      await tester.tap(find.byIcon(AppIcons.back));
      await tester.pumpAndSettle();

      expect(popResult, isFalse);
    });

    testWidgets('back arrow returns true after a restore', (tester) async {
      final client = _FakeApiClient(
        metadata: _fileItem().toMockJson(),
        versionList: [_fakeVersion(v: 1)],
      );

      bool? popResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            fileCryptoProvider.overrideWithValue(_FakeFileCrypto()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) =>
                            const VersionHistoryScreen(fileId: 'note-1'),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Restore v1 to flip activeVersionChanged.
      await tester.tap(find.byIcon(AppIcons.overflowVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore in place'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The post-restore success notification is an OverlayEntry that
      // sits over the AppBar — leave it up and the back-arrow tap
      // can't reach the IconButton. Dismiss it so the hit-test lands.
      AppNotification.dismiss();
      await tester.pump();

      await tester.tap(find.byIcon(AppIcons.back));
      await tester.pump();

      expect(popResult, isTrue);
    });
  });
}

extension _FileItemMock on FileItem {
  /// Mirror of [FileItem.fromJson] so tests can round-trip a fake
  /// without re-encoding every field by hand.
  Map<String, dynamic> toMockJson() => {
    'id': id,
    'encrypted_name': encryptedName,
    'encrypted_key': encryptedKey,
    'mime': mime,
    'editable': editable,
    'cipher': cipher,
    'active_version': activeVersion,
    'pending_version': pendingVersion,
    'pending_chunks': pendingChunks,
    'pending_size': pendingSize,
    'chunks': chunks,
    'size': size,
    'created_at': createdAt,
    'finished_upload_at': finishedUploadAt,
    if (fileId != null) 'file_id': fileId,
    if (encryptedThumbnail != null) 'encrypted_thumbnail': encryptedThumbnail,
    if (sha256 != null) 'sha256': sha256,
  };
}
