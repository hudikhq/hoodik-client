import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Directory manager for the upload pipeline's encrypt-then-upload staging
/// area. Lives alongside the offline cache under
/// `applicationSupportDirectory/` but in its own `upload_staging` root so
/// a failed upload can't accidentally surface partial cipher chunks as an
/// offline-available file.
///
/// Layout: `{applicationSupportDirectory}/upload_staging/{accountId}/{stagingId}/NNNNNN.enc`
///
/// The [stagingId] is either a freshly-allocated temp UUID (for brand-new
/// uploads before a server file_id exists) or the server file_id (for
/// resumes after the entry was already created). Callers can rename from
/// the temp-UUID path to the file-id path once the server assigns an id.
class UploadStaging {
  final String accountId;

  /// Override in tests so staging writes don't depend on the platform
  /// channel-backed [getApplicationSupportDirectory].
  final Future<String> Function()? supportDirOverride;

  String? _basePath;

  UploadStaging({required this.accountId, this.supportDirOverride});

  /// Return the staging directory for [stagingId], creating the parent
  /// directory chain if missing. The returned directory may or may not
  /// already contain chunks — [listExistingChunkIndices] tells you which.
  Future<String> stagingDir(String stagingId) async {
    final account = await _accountDir();
    final dir = p.join(account, stagingId);
    await Directory(dir).create(recursive: true);
    return dir;
  }

  /// Chunk indices that already exist in [stagingPath], sorted ascending.
  /// Used by the encrypt phase to skip re-encrypting chunks when resuming
  /// a previously failed upload — the file key hasn't changed (it's still
  /// the same in-memory key for this retry) so the existing ciphertexts
  /// are still valid.
  Future<List<int>> listExistingChunkIndices(String stagingPath) async {
    final dir = Directory(stagingPath);
    if (!await dir.exists()) return const [];

    final indices = <int>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.enc')) continue;
      final name = p.basenameWithoutExtension(entity.path);
      final index = int.tryParse(name);
      if (index != null) indices.add(index);
    }
    indices.sort();
    return indices;
  }

  /// Move [stagingPath] to [destinationPath]. Used after a successful
  /// upload to promote the encrypted chunks into the offline cache without
  /// re-reading them from disk.
  Future<void> moveTo(String stagingPath, String destinationPath) async {
    final destParent = Directory(p.dirname(destinationPath));
    if (!await destParent.exists()) {
      await destParent.create(recursive: true);
    }
    final dir = Directory(stagingPath);
    if (!await dir.exists()) return;
    await dir.rename(destinationPath);
  }

  /// Delete the staging directory for [stagingId]. Safe to call on a
  /// non-existent directory — used from the cleanup path after success.
  Future<void> clear(String stagingId) async {
    final account = await _accountDir();
    final dir = Directory(p.join(account, stagingId));
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<String> _accountDir() async {
    final base = await _ensureBase();
    final safe = accountId.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final dir = p.join(base, safe);
    final d = Directory(dir);
    if (!await d.exists()) await d.create(recursive: true);
    return dir;
  }

  Future<String> _ensureBase() async {
    if (_basePath != null) return _basePath!;
    final supportPath = supportDirOverride != null
        ? await supportDirOverride!()
        : (await getApplicationSupportDirectory()).path;
    _basePath = p.join(supportPath, 'upload_staging');
    return _basePath!;
  }
}
