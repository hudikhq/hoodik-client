import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';

/// Fingerprint derived from file metadata to detect changes.
///
/// If a file is re-uploaded its size and/or finishedUploadAt will change.
class _CacheFingerprint {
  final int? size;
  final int? finishedUploadAt;

  const _CacheFingerprint(this.size, this.finishedUploadAt);

  bool matches(FileItem file) =>
      size == file.size && finishedUploadAt == file.finishedUploadAt;
}

class _CacheEntry {
  final _CacheFingerprint fingerprint;
  final Uint8List bytes;
  final String? tempPath;

  const _CacheEntry({
    required this.fingerprint,
    required this.bytes,
    this.tempPath,
  });
}

/// Session-scoped cache for decrypted preview data.
///
/// Stores decrypted file bytes in memory so re-opening a preview doesn't
/// re-download and re-decrypt the file. Entries are invalidated when the
/// file's size or finishedUploadAt changes (i.e. the file was re-uploaded).
///
/// For video/PDF previews, also manages temp files on disk that persist
/// across preview screen opens but are cleaned up on [dispose] (logout).
class PreviewCache {
  final Map<String, _CacheEntry> _entries = {};

  /// Return cached bytes if the file hasn't changed, otherwise null.
  Uint8List? get(FileItem file) {
    final entry = _entries[file.id];
    if (entry == null) return null;
    if (!entry.fingerprint.matches(file)) {
      // File changed — evict stale entry and its temp file
      _evict(file.id);
      return null;
    }
    return entry.bytes;
  }

  /// Return cached temp file path for video/PDF if still valid and exists.
  String? getTempPath(FileItem file) {
    final entry = _entries[file.id];
    if (entry == null) return null;
    if (!entry.fingerprint.matches(file)) {
      _evict(file.id);
      return null;
    }
    final path = entry.tempPath;
    if (path != null && File(path).existsSync()) return path;
    return null;
  }

  /// Store decrypted bytes in the cache.
  void put(FileItem file, Uint8List bytes) {
    _evict(file.id); // clean any old temp file first
    _entries[file.id] = _CacheEntry(
      fingerprint: _CacheFingerprint(file.size, file.finishedUploadAt),
      bytes: bytes,
    );
  }

  /// Store decrypted bytes and write a temp file for video/PDF playback.
  ///
  /// Returns the temp file path.
  Future<String> putWithTempFile(
    FileItem file,
    Uint8List bytes,
    String extension,
  ) async {
    _evict(file.id);
    final dir = await getTemporaryDirectory();
    if (!dir.existsSync()) await dir.create(recursive: true);
    final tempPath = p.join(dir.path, 'hoodik_preview_${file.id}.$extension');
    await File(tempPath).writeAsBytes(bytes);

    _entries[file.id] = _CacheEntry(
      fingerprint: _CacheFingerprint(file.size, file.finishedUploadAt),
      bytes: bytes,
      tempPath: tempPath,
    );
    return tempPath;
  }

  /// Register an existing temp file path for video/PDF previews.
  ///
  /// Unlike [putWithTempFile], this does NOT read the file into memory —
  /// only the path is cached.  Use this for large files where keeping the
  /// full content in memory is wasteful.
  void putTempPath(FileItem file, String tempPath) {
    _evict(file.id);
    _entries[file.id] = _CacheEntry(
      fingerprint: _CacheFingerprint(file.size, file.finishedUploadAt),
      bytes: Uint8List(0),
      tempPath: tempPath,
    );
  }

  /// Remove a single entry (e.g. after file deletion).
  void remove(String fileId) => _evict(fileId);

  /// Clear everything — call on logout.
  Future<void> dispose() async {
    for (final entry in _entries.values) {
      await _deleteTempFile(entry.tempPath);
    }
    _entries.clear();
  }

  void _evict(String fileId) {
    final old = _entries.remove(fileId);
    if (old?.tempPath != null) {
      _deleteTempFile(old!.tempPath!);
    }
  }

  static Future<void> _deleteTempFile(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
