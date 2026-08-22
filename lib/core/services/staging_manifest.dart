import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

/// Record of a completed encrypt pass, written next to the chunks it
/// describes.
///
/// Encrypting a large file costs minutes of CPU; the ciphertext survives an
/// app kill in staging but the sha256 and per-chunk checksums only lived in
/// memory — so every retry paid the whole encrypt again just to relearn
/// them. This file carries them across process death. It is written only
/// after the final chunk lands, so a kill mid-encrypt leaves no manifest
/// and the next attempt restarts the encrypt from scratch, as it must.
class StagingManifest {
  static const _fileName = 'manifest.json';

  final String sha256;
  final Map<int, String> checksums;

  StagingManifest({required this.sha256, required this.checksums});

  /// Digest binding the manifest to the key its chunks were encrypted with.
  /// A retry that ends up with a different file key (no server row survived
  /// to adopt) must not upload ciphertext the row's key cannot open.
  static String keyFingerprint(Uint8List fileKey) =>
      crypto.sha256.convert(fileKey).toString();

  static Future<void> write({
    required String stagingDir,
    required Uint8List fileKey,
    required String sha256,
    required Map<int, String> checksums,
    required int totalChunks,
    required int fileSize,
    required int sourceModifiedAt,
  }) async {
    final payload = jsonEncode({
      'key_fingerprint': keyFingerprint(fileKey),
      'sha256': sha256,
      'total_chunks': totalChunks,
      'file_size': fileSize,
      'source_modified_at': sourceModifiedAt,
      'checksums': checksums.map((k, v) => MapEntry('$k', v)),
    });
    await File(
      p.join(stagingDir, _fileName),
    ).writeAsString(payload, flush: true);
  }

  /// Load the manifest when it proves the staged chunks are complete and
  /// were encrypted with [fileKey] for exactly this plaintext; null means
  /// "encrypt again". A manifest that fails any check is deleted so a
  /// half-valid one cannot survive to mislead the next attempt.
  ///
  /// [sourceModifiedAt] is what ties the stage to the plaintext: size and
  /// chunk count cannot tell an in-place edit apart from the original, and
  /// reusing the stage then ships the previous attempt's bytes — reporting
  /// the old sha256 as this upload's hash — while the queue reports success.
  static Future<StagingManifest?> tryReuse({
    required String stagingDir,
    required Uint8List fileKey,
    required int totalChunks,
    required int fileSize,
    required int sourceModifiedAt,
  }) async {
    final file = File(p.join(stagingDir, _fileName));
    if (!await file.exists()) return null;

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (data == null ||
        data['key_fingerprint'] != keyFingerprint(fileKey) ||
        data['total_chunks'] != totalChunks ||
        data['file_size'] != fileSize ||
        data['source_modified_at'] != sourceModifiedAt ||
        !await _chunksComplete(stagingDir, totalChunks)) {
      try {
        await file.delete();
      } catch (_) {}
      return null;
    }

    final checksums = (data['checksums'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), v as String),
    );
    return StagingManifest(
      sha256: data['sha256'] as String,
      checksums: checksums,
    );
  }

  static Future<bool> _chunksComplete(
    String stagingDir,
    int totalChunks,
  ) async {
    for (var i = 0; i < totalChunks; i++) {
      final chunk = File(
        p.join(stagingDir, '${i.toString().padLeft(6, '0')}.enc'),
      );
      if (!await chunk.exists()) return false;
    }
    return true;
  }
}
