import 'dart:typed_data';

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

  const _CacheEntry({required this.fingerprint, required this.bytes});
}

class PreviewCache {
  final Map<String, _CacheEntry> _entries = {};

  /// Return cached bytes if the file hasn't changed, otherwise null.
  Uint8List? get(FileItem file) {
    final entry = _entries[file.id];
    if (entry == null) return null;
    if (!entry.fingerprint.matches(file)) {
      _entries.remove(file.id);
      return null;
    }
    return entry.bytes;
  }

  /// Store decrypted bytes in the cache.
  void put(FileItem file, Uint8List bytes) {
    _entries[file.id] = _CacheEntry(
      fingerprint: _CacheFingerprint(file.size, file.finishedUploadAt),
      bytes: bytes,
    );
  }

  /// Remove a single entry (e.g. after file deletion).
  void remove(String fileId) => _entries.remove(fileId);

  /// Clear everything — call on logout.
  Future<void> dispose() async {
    _entries.clear();
  }
}
