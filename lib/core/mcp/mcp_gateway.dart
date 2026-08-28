import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../crypto/off_ui_crypto.dart';
import '../providers.dart';
import '../services/file_operations.dart';

/// Narrow interface the MCP tool handler uses for storage, crypto, and
/// upload/download calls. Carved out of [ApiClient], [FileOperations], and
/// [FileCrypto] so the handler has one well-defined dependency instead of
/// three tangled ones — and so tests can substitute the whole surface
/// without subclassing Dio-backed production classes.
abstract class McpGateway {
  Future<void> ensureFreshSession();

  Future<StorageResponse> listFiles({String? dirId, bool? editable});

  Future<Map<String, dynamic>> getFileMetadata(String fileId);

  Future<List<FileItem>> searchFiles({
    required String query,
    String? dirId,
    int? limit,
  });

  Future<Map<String, dynamic>> getStats();

  Future<Uint8List> downloadFile(FileItem file, {required Uint8List fileKey});

  /// Upload a binary file. Returns the file id and whether it already existed.
  ///
  /// A name collision does not overwrite binary content: the existing id is
  /// returned with `existed: true`. There is no in-place update for binaries.
  Future<({String id, bool existed})> uploadFileBytes({
    required String name,
    required Uint8List bytes,
    String? parentDirId,
  });

  Future<String> createFolder(String name, {String? parentDirId});

  Future<List<String>> decryptFileNames(List<FileItem> files);

  Future<void> deleteFile(String fileId);

  Future<void> renameFile(
    FileItem file,
    String newName, {
    required Uint8List fileKey,
  });

  Future<void> moveFiles(List<String> fileIds, {String? targetDirId});

  /// Create a markdown note, or upsert if a note with [name] already exists
  /// in [parentDirId]. `existed: true` means the existing note was updated.
  Future<({String id, bool existed})> createNote(
    String name,
    String content, {
    String? parentDirId,
  });

  Future<void> updateNote(String fileId, String content, {String? name});

  /// RSA-decrypt the per-file symmetric key, then decrypt the file's name
  /// using that key. Returns a best-effort display name, or a sentinel if
  /// decryption fails so the tool response still tells the caller something.
  String decryptFileNameBestEffort(FileItem file);

  /// Decrypt the per-file symmetric key. Throws if the file has no key.
  Uint8List decryptFileKey(FileItem file);
}

/// Wires [McpGateway] to the real services behind [apiClientProvider],
/// [fileOperationsProvider], and [fileCryptoProvider].
///
/// Each call resolves the provider on demand because the MCP server may
/// outlive a given login session — if the user signs out between tool
/// invocations we want a clean "Not authenticated" error, not a captured
/// stale reference.
class ProductionMcpGateway implements McpGateway {
  final Ref _ref;

  ProductionMcpGateway(this._ref);

  ApiClient _client() {
    final c = _ref.read(apiClientProvider);
    if (c == null) throw Exception('Not authenticated');
    return c;
  }

  FileOperations _ops() {
    final o = _ref.read(fileOperationsProvider);
    if (o == null) throw Exception('Not authenticated');
    return o;
  }

  FileCrypto _crypto() {
    final c = _ref.read(fileCryptoProvider);
    if (c == null) throw Exception('Not authenticated');
    return c;
  }

  @override
  Future<void> ensureFreshSession() => _client().ensureFreshSession();

  @override
  Future<StorageResponse> listFiles({String? dirId, bool? editable}) {
    return _client().files.listFiles(dirId: dirId, editable: editable);
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) =>
      _client().files.getFileMetadata(fileId);

  @override
  Future<List<FileItem>> searchFiles({
    required String query,
    String? dirId,
    int? limit,
  }) async {
    // The MCP tool hands over a plaintext query; it stops here. Tokenized and
    // tagged on-device so only tags reach the wire, same as the search UI.
    final fileCrypto = _ref.read(fileCryptoProvider);
    if (fileCrypto == null) {
      throw StateError('Cannot search without an unlocked private key');
    }

    // Files shared with this account are tagged under each file's own key, so
    // without these the agent would quietly see only what the user owns and
    // report shared files as missing.
    final sharedKeys = await _ref.read(incomingSearchKeysProvider.future);

    // One exact-match tag per scope rides along, same as the search UI —
    // what lets the agent find a file by pasting its content digest.
    final exact = query.trim().toLowerCase();
    final rootKey = fileCrypto.searchRootKey;

    return _client().search.searchFiles(
      rootTags: [
        ...fileCrypto.queryTags(rootKey, query),
        fileCrypto.exactTag(rootKey, exact),
      ],
      // Hashed the way create hashes names — raw and case-preserving — so a
      // pasted filename matches the stored name_hash byte for byte and the
      // server ranks that file first.
      nameHash: fileCrypto.hashFileName(query.trim()),
      fileTags: sharedKeys.expand((key) {
        final fileKey = fileCrypto.searchFileKeyHex(key);
        return [
          ...fileCrypto.queryTags(fileKey, query),
          fileCrypto.exactTag(fileKey, exact),
        ];
      }).toList(),
      dirId: dirId,
      limit: limit ?? 20,
    );
  }

  @override
  Future<Map<String, dynamic>> getStats() => _client().storage.getStats();

  @override
  Future<Uint8List> downloadFile(FileItem file, {required Uint8List fileKey}) {
    return _ops().downloadFile(file, fileKey: fileKey, showInTransfers: false);
  }

  @override
  Future<({String id, bool existed})> uploadFileBytes({
    required String name,
    required Uint8List bytes,
    String? parentDirId,
  }) async {
    final existing = await _existingChildId(
      name,
      parentDirId,
      directory: false,
    );
    if (existing != null) {
      return (id: existing, existed: true);
    }

    final tempDir = await getTemporaryDirectory();
    final stagingDir = Directory(
      p.join(tempDir.path, 'mcp_upload_${const Uuid().v4()}'),
    );
    await stagingDir.create();
    final stagedPath = p.join(stagingDir.path, name);
    try {
      await File(stagedPath).writeAsBytes(bytes);
      await _ops().uploadFile(stagedPath, parentDirId: parentDirId);
    } catch (e) {
      // UploadResume / HTTP 409 / serviceFileAlreadyExists: name is taken.
      // Do not overwrite binary content; return the existing id instead of
      // a dead 409.
      final raced = await _existingChildId(name, parentDirId, directory: false);
      if (raced != null) return (id: raced, existed: true);
      rethrow;
    } finally {
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    }

    final id = await _existingChildId(name, parentDirId, directory: false);
    if (id == null) {
      throw Exception('Upload completed but file id was not found');
    }
    return (id: id, existed: false);
  }

  @override
  Future<String> createFolder(String name, {String? parentDirId}) async {
    try {
      return await _ops().createFolder(name, parentDirId: parentDirId);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 400 && status != 409 && status != 500) rethrow;
      final existing = await _existingDirId(name, parentDirId);
      if (existing != null) return existing;
      rethrow;
    }
  }

  Future<String?> _existingDirId(String name, String? parentDirId) =>
      _existingChildId(name, parentDirId, directory: true);

  Future<String?> _existingChildId(
    String name,
    String? parentDirId, {
    required bool directory,
  }) async {
    final listing = await listFiles(dirId: parentDirId);
    final names = await decryptFileNames(listing.children);
    for (var i = 0; i < listing.children.length; i++) {
      final f = listing.children[i];
      if (f.isDir != directory) continue;
      if (names[i] == name) return f.id;
    }
    return null;
  }

  @override
  Future<List<String>> decryptFileNames(List<FileItem> files) async {
    if (files.isEmpty) return const [];
    final crypto = _crypto();
    return decryptNamesOffUi(
      privateKeyPem: crypto.privateKeyPem,
      wrappingPrivateKeyPem: crypto.wrappingPrivateKeyPem,
      files: [
        for (final f in files)
          (
            encryptedName: f.encryptedName,
            encryptedKey: f.encryptedKey,
            cipher: f.cipher,
          ),
      ],
    );
  }

  @override
  Future<void> deleteFile(String fileId) => _ops().delete(fileId);

  @override
  Future<void> renameFile(
    FileItem file,
    String newName, {
    required Uint8List fileKey,
  }) {
    return _ops().rename(file, newName, fileKey: fileKey);
  }

  @override
  Future<void> moveFiles(List<String> fileIds, {String? targetDirId}) =>
      _ops().moveMany(fileIds, targetDirId: targetDirId);

  @override
  Future<({String id, bool existed})> createNote(
    String name,
    String content, {
    String? parentDirId,
  }) async {
    final existing = await _existingChildId(
      name,
      parentDirId,
      directory: false,
    );
    if (existing != null) {
      await updateNote(existing, content);
      return (id: existing, existed: true);
    }
    try {
      final id = await _ops().createNote(
        name,
        content,
        parentDirId: parentDirId,
      );
      return (id: id, existed: false);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 400 && status != 409 && status != 500) rethrow;
      final raced = await _existingChildId(name, parentDirId, directory: false);
      if (raced != null) {
        await updateNote(raced, content);
        return (id: raced, existed: true);
      }
      rethrow;
    }
  }

  @override
  Future<void> updateNote(String fileId, String content, {String? name}) {
    return _ops().updateNoteContent(fileId, content, name: name);
  }

  @override
  String decryptFileNameBestEffort(FileItem file) {
    try {
      if (file.encryptedKey == null) return '(encrypted)';
      final key = _crypto().decryptFileKey(file.encryptedKey!);
      return _crypto().decryptFileName(
        encryptedNameHex: file.encryptedName,
        fileKey: key,
        cipher: file.cipher,
      );
    } catch (_) {
      return '(decryption failed)';
    }
  }

  @override
  Uint8List decryptFileKey(FileItem file) {
    if (file.encryptedKey == null) {
      throw Exception('File has no encryption key');
    }
    return _crypto().decryptFileKey(file.encryptedKey!);
  }
}
