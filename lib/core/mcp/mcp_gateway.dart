import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../crypto/file_crypto.dart';
import '../providers.dart';
import '../services/file_operations.dart';

/// Narrow interface the MCP tool handler uses for storage, crypto, and
/// upload/download calls. Carved out of [ApiClient], [FileOperations], and
/// [FileCrypto] so the handler has one well-defined dependency instead of
/// three tangled ones — and so tests can substitute the whole surface
/// without subclassing Dio-backed production classes.
abstract class McpGateway {
  Future<void> ensureFreshSession();

  Future<StorageResponse> listFiles({String? dirId, bool editable = false});

  Future<Map<String, dynamic>> getFileMetadata(String fileId);

  Future<List<FileItem>> searchFiles({
    required String query,
    String? dirId,
    int? limit,
  });

  Future<Map<String, dynamic>> getStats();

  Future<Uint8List> downloadFile(FileItem file, {required Uint8List fileKey});

  Future<void> uploadFileBytes({
    required String name,
    required Uint8List bytes,
    String? parentDirId,
  });

  Future<void> createFolder(String name, {String? parentDirId});

  Future<void> deleteFile(String fileId);

  Future<void> renameFile(
    FileItem file,
    String newName, {
    required Uint8List fileKey,
  });

  Future<void> moveFiles(List<String> fileIds, {String? targetDirId});

  Future<String> createNote(String name, String content, {String? parentDirId});

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
  Future<StorageResponse> listFiles({String? dirId, bool editable = false}) {
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
  }) {
    // The MCP tool hands over a plaintext query; it stops here. Tokenized and
    // tagged on-device so only tags reach the wire, same as the search UI.
    final fileCrypto = _ref.read(fileCryptoProvider);
    if (fileCrypto == null) {
      throw StateError('Cannot search without an unlocked private key');
    }

    return _client().search.searchFiles(
      rootTags: fileCrypto.queryTags(fileCrypto.searchRootKey, query),
      hash: SearchClient.hashLookup(query),
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
  Future<void> uploadFileBytes({
    required String name,
    required Uint8List bytes,
    String? parentDirId,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final stagingDir = Directory(
      p.join(tempDir.path, 'mcp_upload_${const Uuid().v4()}'),
    );
    await stagingDir.create();
    final stagedPath = p.join(stagingDir.path, name);
    try {
      await File(stagedPath).writeAsBytes(bytes);
      await _ops().uploadFile(stagedPath, parentDirId: parentDirId);
    } finally {
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> createFolder(String name, {String? parentDirId}) =>
      _ops().createFolder(name, parentDirId: parentDirId);

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
  Future<String> createNote(
    String name,
    String content, {
    String? parentDirId,
  }) {
    return _ops().createNote(name, content, parentDirId: parentDirId);
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
