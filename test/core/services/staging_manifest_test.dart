import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/services/staging_manifest.dart';
import 'package:path/path.dart' as p;

/// The manifest is what lets a killed upload skip the re-encrypt on its next
/// attempt — and what must refuse to, the moment anything about the staged
/// ciphertext stops matching the upload that wants to reuse it.
void main() {
  late Directory dir;
  final key = Uint8List.fromList(List.generate(32, (i) => i));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('staging-manifest-test');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  Future<void> writeChunks(int count) async {
    for (var i = 0; i < count; i++) {
      File(
        p.join(dir.path, '${i.toString().padLeft(6, '0')}.enc'),
      ).writeAsBytesSync([i]);
    }
  }

  const modifiedAt = 1700000000000;

  Future<void> writeManifest({
    Uint8List? withKey,
    int chunks = 3,
    int sourceModifiedAt = modifiedAt,
  }) {
    return StagingManifest.write(
      stagingDir: dir.path,
      fileKey: withKey ?? key,
      sha256: 'abc',
      checksums: {0: 'aa', 1: 'bb', 2: 'cc'},
      totalChunks: chunks,
      fileSize: 300,
      sourceModifiedAt: sourceModifiedAt,
    );
  }

  test('a complete staging round-trips and skips the encrypt', () async {
    await writeChunks(3);
    await writeManifest();

    final reused = await StagingManifest.tryReuse(
      stagingDir: dir.path,
      fileKey: key,
      totalChunks: 3,
      fileSize: 300,
      sourceModifiedAt: modifiedAt,
    );

    expect(reused, isNotNull);
    expect(reused!.sha256, 'abc');
    expect(reused.checksums, {0: 'aa', 1: 'bb', 2: 'cc'});
  });

  test('no manifest means encrypt again', () async {
    await writeChunks(3);

    expect(
      await StagingManifest.tryReuse(
        stagingDir: dir.path,
        fileKey: key,
        totalChunks: 3,
        fileSize: 300,
        sourceModifiedAt: modifiedAt,
      ),
      isNull,
    );
  });

  // The bug this guards: an in-place edit that leaves the byte count the same.
  // Size and chunk count still match, so without the mtime check the stale
  // ciphertext would ride along and the server would end up with the previous
  // content while the queue reports success.
  test('a same-size edit with a newer mtime voids the manifest', () async {
    await writeChunks(3);
    await writeManifest();

    expect(
      await StagingManifest.tryReuse(
        stagingDir: dir.path,
        fileKey: key,
        totalChunks: 3,
        fileSize: 300,
        sourceModifiedAt: modifiedAt + 1,
      ),
      isNull,
    );
  });

  // A kill mid-encrypt leaves chunks but no manifest; a kill mid-upload
  // leaves both. This is the case in between: manifest present, a chunk
  // file missing — trust nothing.
  test('a missing chunk file voids the manifest', () async {
    await writeChunks(3);
    await writeManifest();
    File(p.join(dir.path, '000001.enc')).deleteSync();

    expect(
      await StagingManifest.tryReuse(
        stagingDir: dir.path,
        fileKey: key,
        totalChunks: 3,
        fileSize: 300,
        sourceModifiedAt: modifiedAt,
      ),
      isNull,
    );
    expect(File(p.join(dir.path, 'manifest.json')).existsSync(), isFalse);
  });

  // The retry that could not adopt a server row generates a fresh key;
  // ciphertext under the old key must never ride along.
  test('a different file key voids the manifest', () async {
    await writeChunks(3);
    await writeManifest();

    expect(
      await StagingManifest.tryReuse(
        stagingDir: dir.path,
        fileKey: Uint8List.fromList(List.filled(32, 9)),
        totalChunks: 3,
        fileSize: 300,
        sourceModifiedAt: modifiedAt,
      ),
      isNull,
    );
  });

  test('a changed source file voids the manifest', () async {
    await writeChunks(3);
    await writeManifest();

    expect(
      await StagingManifest.tryReuse(
        stagingDir: dir.path,
        fileKey: key,
        totalChunks: 3,
        fileSize: 999,
        sourceModifiedAt: modifiedAt,
      ),
      isNull,
    );
  });

  test('corrupt json voids the manifest instead of throwing', () async {
    await writeChunks(3);
    File(p.join(dir.path, 'manifest.json')).writeAsStringSync('{nope');

    expect(
      await StagingManifest.tryReuse(
        stagingDir: dir.path,
        fileKey: key,
        totalChunks: 3,
        fileSize: 300,
        sourceModifiedAt: modifiedAt,
      ),
      isNull,
    );
  });

  test('manifest content stays valid json with int-keyed checksums', () async {
    await writeChunks(3);
    await writeManifest();

    final raw =
        jsonDecode(File(p.join(dir.path, 'manifest.json')).readAsStringSync())
            as Map<String, dynamic>;
    expect(raw['checksums'], {'0': 'aa', '1': 'bb', '2': 'cc'});
    expect(raw['key_fingerprint'], StagingManifest.keyFingerprint(key));
  });
}
