import 'dart:convert';
import 'dart:typed_data';

import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/mcp/mcp_gateway.dart';

/// Stateful in-memory stand-in for the real encrypted Hoodik backend.
///
/// Each "file" here is stored as plaintext bytes plus a tiny bit of metadata.
/// The fake's job is to behave correctly w.r.t. the [McpGateway] contract —
/// create / list / read / write / rename / move / delete — not to actually
/// encrypt anything, because the crypto path requires the real Rust FFI
/// which isn't available in a `flutter test` harness. The absence of real
/// crypto is exactly why the tool-level behaviour tests live at the gateway
/// seam instead of driving the handler through a real [ApiClient].
class FakeMcpGateway implements McpGateway {
  final Map<String, FileItem> files = {};
  final Map<String, Uint8List> bodies = {};
  final Map<String, String> plaintextNames = {};

  /// Records whether [ensureFreshSession] was invoked, so tests can assert
  /// the handler is being careful about pre-dispatch auth.
  bool ensuredFreshSession = false;

  /// Counter used by test helpers to mint unique ids without the test
  /// having to plumb sequential numbers through every call.
  int _idCounter = 0;
  String _nextId() => 'id-${++_idCounter}';

  /// If set, the named tool throws this exception instead of running.
  /// Used by the "error path" test to verify audit captures failures.
  String? throwOnTool;

  @override
  Future<void> ensureFreshSession() async {
    ensuredFreshSession = true;
  }

  @override
  Future<StorageResponse> listFiles({
    String? dirId,
    bool editable = false,
  }) async {
    final children = files.values.where((f) {
      final parentMatches = dirId == null
          ? f.fileId == null
          : f.fileId == dirId;
      if (!parentMatches) return false;
      if (editable && !f.editable) return false;
      return true;
    }).toList();

    return StorageResponse(
      children: children,
      usedSpace: bodies.values.fold<int>(0, (sum, b) => sum + b.length),
      quota: 1024 * 1024 * 1024,
    );
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(String fileId) async {
    final file = files[fileId];
    if (file == null) throw Exception('File not found: $fileId');
    return {
      'id': file.id,
      'file_id': file.fileId,
      'encrypted_name': file.encryptedName,
      'encrypted_key': file.encryptedKey,
      'mime': file.mime,
      'size': file.size,
      'cipher': file.cipher,
      'editable': file.editable,
      'created_at': file.createdAt,
      'finished_upload_at': file.finishedUploadAt,
    };
  }

  @override
  Future<List<FileItem>> searchFiles({
    required String query,
    String? dirId,
    int? limit,
  }) async {
    final lower = query.toLowerCase();
    final matches = files.values.where((f) {
      final name = plaintextNames[f.id] ?? '';
      return name.toLowerCase().contains(lower);
    }).toList();
    if (limit != null && matches.length > limit) {
      return matches.sublist(0, limit);
    }
    return matches;
  }

  @override
  Future<Map<String, dynamic>> getStats() async {
    final byMime = <String, Map<String, int>>{};
    for (final f in files.values) {
      final bucket = byMime.putIfAbsent(f.mime, () => {'size': 0, 'count': 0});
      bucket['size'] = bucket['size']! + (f.size ?? 0);
      bucket['count'] = bucket['count']! + 1;
    }
    return {'by_mime': byMime};
  }

  @override
  Future<Uint8List> downloadFile(
    FileItem file, {
    required Uint8List fileKey,
  }) async {
    _maybeThrow('read_file');
    final body = bodies[file.id];
    if (body == null) throw Exception('No body stored for ${file.id}');
    return body;
  }

  @override
  Future<void> uploadFileBytes({
    required String name,
    required Uint8List bytes,
    String? parentDirId,
  }) async {
    _maybeThrow('write_file');
    final id = _nextId();
    files[id] = FileItem(
      id: id,
      fileId: parentDirId,
      encryptedName: 'enc:$name',
      encryptedKey: 'key:$id',
      mime: _inferMime(name),
      size: bytes.length,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      finishedUploadAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    bodies[id] = Uint8List.fromList(bytes);
    plaintextNames[id] = name;
  }

  @override
  Future<void> createFolder(String name, {String? parentDirId}) async {
    _maybeThrow('create_directory');
    final id = _nextId();
    files[id] = FileItem(
      id: id,
      fileId: parentDirId,
      encryptedName: 'enc:$name',
      encryptedKey: 'key:$id',
      mime: 'dir',
      size: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    plaintextNames[id] = name;
  }

  @override
  Future<void> deleteFile(String fileId) async {
    _maybeThrow('delete_file');
    if (!files.containsKey(fileId)) {
      throw Exception('File not found: $fileId');
    }
    files.remove(fileId);
    bodies.remove(fileId);
    plaintextNames.remove(fileId);
  }

  @override
  Future<void> renameFile(
    FileItem file,
    String newName, {
    required Uint8List fileKey,
  }) async {
    _maybeThrow('rename_file');
    final current = files[file.id];
    if (current == null) throw Exception('File not found: ${file.id}');
    files[file.id] = FileItem(
      id: current.id,
      fileId: current.fileId,
      encryptedName: 'enc:$newName',
      encryptedKey: current.encryptedKey,
      mime: current.mime,
      size: current.size,
      cipher: current.cipher,
      editable: current.editable,
      createdAt: current.createdAt,
      finishedUploadAt: current.finishedUploadAt,
    );
    plaintextNames[file.id] = newName;
  }

  @override
  Future<void> moveFiles(List<String> fileIds, {String? targetDirId}) async {
    _maybeThrow('move_files');
    for (final id in fileIds) {
      final current = files[id];
      if (current == null) continue;
      files[id] = FileItem(
        id: current.id,
        fileId: targetDirId,
        encryptedName: current.encryptedName,
        encryptedKey: current.encryptedKey,
        mime: current.mime,
        size: current.size,
        cipher: current.cipher,
        editable: current.editable,
        createdAt: current.createdAt,
        finishedUploadAt: current.finishedUploadAt,
      );
    }
  }

  @override
  Future<String> createNote(
    String name,
    String content, {
    String? parentDirId,
  }) async {
    _maybeThrow('create_note');
    final id = _nextId();
    final bytes = Uint8List.fromList(utf8.encode(content));
    files[id] = FileItem(
      id: id,
      fileId: parentDirId,
      encryptedName: 'enc:$name',
      encryptedKey: 'key:$id',
      mime: 'text/markdown',
      size: bytes.length,
      editable: true,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      finishedUploadAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    bodies[id] = bytes;
    plaintextNames[id] = name;
    return id;
  }

  @override
  Future<void> updateNote(String fileId, String content, {String? name}) async {
    _maybeThrow('update_note');
    final current = files[fileId];
    if (current == null) throw Exception('Note not found: $fileId');
    final bytes = Uint8List.fromList(utf8.encode(content));
    files[fileId] = FileItem(
      id: current.id,
      fileId: current.fileId,
      encryptedName: name != null ? 'enc:$name' : current.encryptedName,
      encryptedKey: current.encryptedKey,
      mime: current.mime,
      size: bytes.length,
      cipher: current.cipher,
      editable: current.editable,
      createdAt: current.createdAt,
      finishedUploadAt: current.finishedUploadAt,
    );
    bodies[fileId] = bytes;
    if (name != null) plaintextNames[fileId] = name;
  }

  @override
  String decryptFileNameBestEffort(FileItem file) {
    return plaintextNames[file.id] ?? '(unknown)';
  }

  @override
  Uint8List decryptFileKey(FileItem file) {
    if (file.encryptedKey == null) {
      throw Exception('File has no encryption key');
    }
    return Uint8List.fromList(utf8.encode(file.encryptedKey!));
  }

  String _inferMime(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return 'application/octet-stream';
    switch (name.substring(dot + 1).toLowerCase()) {
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'json':
        return 'application/json';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  void _maybeThrow(String tool) {
    if (throwOnTool == tool) {
      throw Exception('forced failure for $tool');
    }
  }
}
