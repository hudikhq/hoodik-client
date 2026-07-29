import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/file_item.dart';
import '../providers.dart';
import '../storage/database.dart';

/// Lazily resolves file thumbnails for rows whose listing arrived
/// without the blob (a `compact` listing carries only `has_thumbnail`).
///
/// Resolution order per file: the inline row ciphertext (older servers,
/// single-file lookups), then the offline cache, then the thumbnail
/// route — and a fetched blob is written back into the cached row so
/// offline listings keep their thumbnails. Results are memoized for the
/// provider's lifetime, and concurrent requests for the same file
/// collapse into one fetch.
class ThumbnailLoader {
  ThumbnailLoader(this._ref);

  final Ref _ref;

  final Map<String, String?> _dataUrls = {};
  final Map<String, Uint8List?> _bytes = {};
  final Map<String, Future<String?>> _inFlight = {};

  /// Decrypted thumbnail as its original data URL (`data:image/...`),
  /// or null when the file has none or decryption isn't possible.
  Future<String?> loadDataUrl(FileItem file, Uint8List fileKey) async {
    if (_dataUrls.containsKey(file.id)) return _dataUrls[file.id];

    final pending = _inFlight[file.id];
    if (pending != null) return pending;

    final loading = _load(file, fileKey);
    _inFlight[file.id] = loading;
    try {
      final dataUrl = await loading;
      _dataUrls[file.id] = dataUrl;
      return dataUrl;
    } finally {
      unawaited(_inFlight.remove(file.id));
    }
  }

  /// Decrypted thumbnail as decoded image bytes, ready for `Image.memory`.
  Future<Uint8List?> loadBytes(FileItem file, Uint8List fileKey) async {
    if (_bytes.containsKey(file.id)) return _bytes[file.id];

    final bytes = decodeDataUrl(await loadDataUrl(file, fileKey));
    _bytes[file.id] = bytes;
    return bytes;
  }

  Future<String?> _load(FileItem file, Uint8List fileKey) async {
    final fileCrypto = _ref.read(fileCryptoProvider);
    if (fileCrypto == null) return null;

    final ciphertext = await _ciphertextFor(file);
    if (ciphertext == null) return null;

    return fileCrypto.decryptThumbnail(
      encryptedThumbnailHex: ciphertext,
      fileKey: fileKey,
      cipher: file.cipher,
    );
  }

  Future<String?> _ciphertextFor(FileItem file) async {
    final inline = file.encryptedThumbnail;
    if (inline != null && inline.isNotEmpty) return inline;
    if (!file.hasThumbnail) return null;

    final account = _ref.read(activeAccountProvider);
    final db = _ref.read(databaseProvider);

    if (account != null) {
      final cached = await db.getCachedFileById(account.id, file.id);
      final cachedThumbnail = cached?.encryptedThumbnail;
      if (cachedThumbnail != null && cachedThumbnail.isNotEmpty) {
        return cachedThumbnail;
      }
    }

    final client = _ref.read(apiClientProvider);
    if (client == null) return null;

    final fetched = await client.files.fetchThumbnail(file.id);
    if (fetched == null) return null;

    if (account != null) {
      await (db.update(db.cachedFiles)..where(
            (row) => row.accountId.equals(account.id) & row.id.equals(file.id),
          ))
          .write(CachedFilesCompanion(encryptedThumbnail: Value(fetched)));
    }

    return fetched;
  }

  /// Extract the base64 payload of a `data:image/...;base64,` URL.
  static Uint8List? decodeDataUrl(String? dataUrl) {
    if (dataUrl == null) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return base64Decode(dataUrl.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}

/// Rebuilt on account switch so one account's decrypted thumbnails are
/// never served to another.
final thumbnailLoaderProvider = Provider<ThumbnailLoader>((ref) {
  ref.watch(activeAccountProvider.select((account) => account?.id));
  return ThumbnailLoader(ref);
});
