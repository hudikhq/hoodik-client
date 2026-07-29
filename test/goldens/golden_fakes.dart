import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/preferences.dart';
import 'package:hoodik_app/core/storage/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart' show goldenNow, timestampForDaysAgo;

/// Deterministic [Account] for golden fixtures — enough fields to hydrate
/// the auth provider stack without touching real crypto material or the DB.
Account fakeAccount({
  String id = 'acct_primary',
  String email = 'alex@example.com',
  String serverId = 'srv_home',
  String? role,
  int? quota,
}) {
  return Account(
    id: id,
    serverId: serverId,
    userId: 'uid_$id',
    email: email,
    fingerprint: 'AA:BB:CC:DD',
    publicKey: 'FAKE_PUB_KEY_PEM',
    encryptedPrivateKey: 'FAKE_ENC_KEY',
    pinEncryptedPrivateKey: null,
    biometricPin: null,
    quota: quota,
    role: role,
    isActive: true,
    createdAt: goldenNow.subtract(const Duration(days: 30)),
    lastUsedAt: goldenNow,
    cacheLimitBytes: null,
    headerJwt: null,
    headerRefreshToken: null,
  );
}

/// Second account — renders the switcher past its solo-user collapse path.
Account fakeSecondaryAccount() => fakeAccount(
  id: 'acct_secondary',
  email: 'alex@work.example',
  serverId: 'srv_work',
);

/// Deterministic [Server] for the active-server provider.
Server fakeServer({
  String id = 'srv_home',
  String name = 'home.hoodik.example',
}) {
  return Server(
    id: id,
    url: 'https://$name',
    name: name,
    trustSelfSignedCerts: false,
    useHeaderAuth: false,
    createdAt: goldenNow.subtract(const Duration(days: 30)),
  );
}

Server fakeSecondaryServer() =>
    fakeServer(id: 'srv_work', name: 'work.hoodik.example');

/// The five fake files per spec §7: folder, PDF, image-with-thumbnail,
/// text, markdown-note.
List<FileItem> fakeFileList() {
  FileItem file(
    String id,
    String mime, {
    int? size,
    int daysAgo = 0,
    bool editable = false,
    String? encryptedThumbnail,
  }) {
    return FileItem(
      id: id,
      encryptedName: 'enc_$id',
      encryptedThumbnail: encryptedThumbnail,
      mime: mime,
      size: size,
      createdAt: timestampForDaysAgo(daysAgo),
      finishedUploadAt: timestampForDaysAgo(daysAgo),
      chunks: mime == 'dir' ? null : 1,
      chunksStored: mime == 'dir' ? null : 1,
      editable: editable,
    );
  }

  return [
    file('f_folder_projects', 'dir', daysAgo: 7),
    file('f_budget_pdf', 'application/pdf', size: 2_400_000, daysAgo: 2),
    file(
      'f_sunset_jpg',
      'image/jpeg',
      size: 1_200_000,
      daysAgo: 5,
      encryptedThumbnail: 'enc_thumb',
    ),
    file('f_readme_txt', 'text/plain', size: 4 * 1024, daysAgo: 1),
    file('f_notes_md', 'text/markdown', size: 18 * 1024, editable: true),
  ];
}

/// Display names for every entry returned by [fakeFileList] — mirrors the
/// post-decrypt cache the real `FilesNotifier` hydrates.
Map<String, String> fakeFileDisplayNames() => const {
  'f_folder_projects': 'Projects',
  'f_budget_pdf': 'budget-2026.pdf',
  'f_sunset_jpg': 'sunset.jpg',
  'f_readme_txt': 'readme.txt',
  'f_notes_md': 'notes.md',
};

/// Per-file symmetric keys (zeroed stand-ins). Populating this map
/// signals to widgets that the post-decrypt state has been reached so
/// enabled affordances render.
Map<String, Uint8List> fakeFileKeys() {
  return {for (final id in fakeFileDisplayNames().keys) id: Uint8List(32)};
}

/// A seeded 16×16 RGBA checkerboard encoded as PNG — the thumbnail for
/// the image row in the files list. Generated at test startup so every
/// run emits bit-identical goldens without shipping a binary fixture.
Future<Uint8List> checkerboardThumbnail({int side = 16}) async {
  final pixels = Uint8List(side * side * 4);
  for (int y = 0; y < side; y++) {
    for (int x = 0; x < side; x++) {
      final even = ((x ~/ 2) + (y ~/ 2)) % 2 == 0;
      final base = (y * side + x) * 4;
      pixels[base] = even ? 0xFF : 0x20;
      pixels[base + 1] = even ? 0x8A : 0x20;
      pixels[base + 2] = even ? 0x65 : 0x20;
      pixels[base + 3] = 0xFF;
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    side,
    side,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) throw StateError('checkerboard PNG encode returned null');
  return bytes.buffer.asUint8List();
}

/// Shared [Preferences] override seeded with empty mock SharedPreferences
/// so providers that read it synchronously in `build` don't throw.
Future<Preferences> fakePreferences() async {
  SharedPreferences.setMockInitialValues({});
  return Preferences.load();
}

/// Create a fresh in-memory [AppDatabase] — callers close it in a
/// `addTearDown`. Used by screens that transitively read the DB.
AppDatabase fakeInMemoryDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());
