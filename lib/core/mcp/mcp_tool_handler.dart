import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../api/api_client.dart';
import 'find_in_note.dart';
import 'mcp_gateway.dart';
import 'mcp_protocol.dart';

/// Maximum file size for read/write operations (50 MB).
const int _maxFileSize = 50 * 1024 * 1024;

const _textMimePrefixes = ['text/'];
const _textMimeExact = {
  'application/json',
  'application/xml',
  'application/javascript',
  'application/toml',
  'application/x-yaml',
};

bool _isTextMime(String mime) {
  if (_textMimeExact.contains(mime)) return true;
  return _textMimePrefixes.any((prefix) => mime.startsWith(prefix));
}

/// One-method seam for the MCP server. The server speaks only this
/// interface, which lets us drop an auditing decorator in front of the
/// real handler — see [AuditingMcpToolDispatcher] — without the server
/// growing knowledge of logging or timing.
abstract class McpToolDispatcher {
  Future<Map<String, dynamic>> handleToolCall(McpRequest request);
}

/// Executes MCP tool calls by delegating to the [McpGateway].
///
/// The gateway abstracts away the Riverpod-wired services, so in tests we
/// can substitute a fake gateway and exercise the real dispatch logic
/// without spinning up Dio/FFI/Drift.
class McpToolHandler implements McpToolDispatcher {
  final McpGateway _gateway;
  final bool Function() _isLocked;

  /// Serializes mutating tools so two in-flight encrypts cannot overlap
  /// on the FFI path (the iOS/macOS AOT SIGSEGV at 0xf).
  Future<void> _writeChain = Future<void>.value();

  static const _writeTools = {
    'write_file',
    'create_directory',
    'delete_file',
    'rename_file',
    'move_files',
    'create_note',
    'update_note',
  };

  McpToolHandler(this._gateway, {bool Function()? isLocked})
    : _isLocked = isLocked ?? (() => false);

  @override
  Future<Map<String, dynamic>> handleToolCall(McpRequest request) async {
    final params = request.params ?? {};
    final toolName = params['name'] as String?;
    final args = params['arguments'] as Map<String, dynamic>? ?? {};

    if (toolName == null || toolName.isEmpty) {
      return mcpErrorResponse(
        request.id,
        jsonRpcInvalidParams,
        'Missing tool name',
      );
    }

    try {
      // health must work while PIN-locked and does not touch the backend.
      if (toolName != 'health') {
        await _gateway.ensureFreshSession();
      }
      final result = await _dispatchSerialized(toolName, args);
      return mcpResponse(request.id, {
        'content': [
          {'type': 'text', 'text': jsonEncode(result)},
        ],
      });
    } catch (e) {
      return mcpResponse(request.id, {
        'content': [
          {'type': 'text', 'text': 'Error: ${_publicError(e)}'},
        ],
        'isError': true,
      });
    }
  }

  Future<Object> _dispatchSerialized(
    String tool,
    Map<String, dynamic> args,
  ) async {
    if (!_writeTools.contains(tool)) return _dispatch(tool, args);
    final previous = _writeChain;
    final done = Completer<void>();
    _writeChain = done.future;
    try {
      await previous;
      return await _dispatch(tool, args);
    } finally {
      done.complete();
    }
  }

  Future<Object> _dispatch(String tool, Map<String, dynamic> args) async {
    switch (tool) {
      case 'list_files':
        return _listFiles(args);
      case 'resolve_path':
        return _resolvePath(args);
      case 'read_file':
        return _readFile(args);
      case 'write_file':
        return _writeFile(args);
      case 'create_directory':
        return _createDirectory(args);
      case 'delete_file':
        return _deleteFile(args);
      case 'rename_file':
        return _renameFile(args);
      case 'move_files':
        return _moveFiles(args);
      case 'search_files':
        return _searchFiles(args);
      case 'storage_stats':
        return _storageStats();
      case 'list_notes':
        return _listNotes(args);
      case 'read_note':
        return _readNote(args);
      case 'find_in_note':
        return _findInNote(args);
      case 'create_note':
        return _createNote(args);
      case 'update_note':
        return _updateNote(args);
      case 'health':
        return _health();
      default:
        throw Exception('Unknown tool: $tool');
    }
  }

  Future<List<Map<String, dynamic>>> _listFiles(
    Map<String, dynamic> args,
  ) async {
    final dirId = _optionalId(args['dir_id']);
    final response = await _gateway.listFiles(dirId: dirId);
    final names = await _gateway.decryptFileNames(response.children);
    return [
      for (var i = 0; i < response.children.length; i++)
        _fileSummary(response.children[i], names[i]),
    ];
  }

  Future<Map<String, dynamic>> _resolvePath(Map<String, dynamic> args) async {
    final raw = args['path'];
    if (raw is! String) throw Exception('path is required');

    final names = raw
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    var currentDirId = _optionalId(args['dir_id']);
    var missed = false;
    final segments = <Map<String, dynamic>>[];

    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      if (missed) {
        segments.add({'name': name, 'exists': false});
        continue;
      }

      final listing = await _gateway.listFiles(dirId: currentDirId);
      final decrypted = await _gateway.decryptFileNames(listing.children);
      final remaining = i < names.length - 1;

      FileItem? firstMatch;
      FileItem? dirMatch;
      for (var j = 0; j < listing.children.length; j++) {
        if (decrypted[j] != name) continue;
        firstMatch ??= listing.children[j];
        if (listing.children[j].isDir) dirMatch ??= listing.children[j];
      }

      // Prefer a directory only when a later segment still needs to be walked.
      final match = remaining ? dirMatch : firstMatch;
      if (match == null) {
        missed = true;
        segments.add({'name': name, 'exists': false});
        continue;
      }

      final segment = <String, dynamic>{
        'name': name,
        'id': match.id,
        'is_dir': match.isDir,
        'exists': true,
      };
      if (!match.isDir) {
        segment['editable'] = match.editable;
      }
      segments.add(segment);

      if (match.isDir) {
        currentDirId = match.id;
      } else if (remaining) {
        missed = true;
      }
    }

    return {'path': names.join('/'), 'resolved': !missed, 'segments': segments};
  }

  Future<Map<String, dynamic>> _readFile(Map<String, dynamic> args) async {
    final fileId = args['file_id'] as String?;
    if (fileId == null) throw Exception('file_id is required');

    final metadata = await _gateway.getFileMetadata(fileId);
    final file = FileItem.fromJson(metadata);

    if (file.isDir) throw Exception('Cannot read a directory');

    final size = file.size ?? 0;
    if (size > _maxFileSize) {
      throw Exception(
        'File too large (${(size / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Maximum: ${_maxFileSize ~/ 1024 ~/ 1024} MB.',
      );
    }

    final fileKey = _gateway.decryptFileKey(file);
    final names = await _gateway.decryptFileNames([file]);
    final name = names.single;
    final bytes = await _gateway.downloadFile(file, fileKey: fileKey);

    if (_isTextMime(file.mime)) {
      return {
        'name': name,
        'mime': file.mime,
        'size': bytes.length,
        'encoding': 'text',
        'content': utf8.decode(bytes, allowMalformed: true),
      };
    }

    return {
      'name': name,
      'mime': file.mime,
      'size': bytes.length,
      'encoding': 'base64',
      'content': base64Encode(bytes),
    };
  }

  Future<Map<String, dynamic>> _writeFile(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    final content = args['content'] as String?;
    if (name == null) throw Exception('name is required');
    if (content == null) throw Exception('content is required');

    final encoding = args['encoding'] as String? ?? 'text';
    final dirId = _optionalId(args['dir_id']);

    final Uint8List bytes;
    if (encoding == 'base64') {
      bytes = base64Decode(content);
    } else {
      bytes = Uint8List.fromList(utf8.encode(content));
    }

    if (bytes.length > _maxFileSize) {
      throw Exception(
        'Content too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Maximum: ${_maxFileSize ~/ 1024 ~/ 1024} MB.',
      );
    }

    final written = await _gateway.uploadFileBytes(
      name: name,
      bytes: bytes,
      parentDirId: dirId,
    );

    return {
      'success': true,
      'id': written.id,
      'name': name,
      'size': bytes.length,
      'existed': written.existed,
    };
  }

  Future<Map<String, dynamic>> _createDirectory(
    Map<String, dynamic> args,
  ) async {
    final name = args['name'] as String?;
    if (name == null || name.isEmpty) throw Exception('name is required');

    final dirId = _optionalId(args['dir_id']);
    final id = await _gateway.createFolder(name, parentDirId: dirId);

    return {'success': true, 'id': id, 'name': name};
  }

  Future<Map<String, dynamic>> _deleteFile(Map<String, dynamic> args) async {
    final fileId = args['file_id'] as String?;
    if (fileId == null) throw Exception('file_id is required');

    await _gateway.deleteFile(fileId);
    return {'success': true};
  }

  Future<Map<String, dynamic>> _renameFile(Map<String, dynamic> args) async {
    final fileId = args['file_id'] as String?;
    final newName = args['new_name'] as String?;
    if (fileId == null) throw Exception('file_id is required');
    if (newName == null) throw Exception('new_name is required');

    final metadata = await _gateway.getFileMetadata(fileId);
    final file = FileItem.fromJson(metadata);
    final fileKey = _gateway.decryptFileKey(file);
    await _gateway.renameFile(file, newName, fileKey: fileKey);

    return {'success': true, 'new_name': newName};
  }

  Future<Map<String, dynamic>> _moveFiles(Map<String, dynamic> args) async {
    final fileIds = (args['file_ids'] as List?)?.cast<String>();
    if (fileIds == null || fileIds.isEmpty) {
      throw Exception('file_ids is required');
    }

    final targetDirId = args['target_dir_id'] as String?;
    await _gateway.moveFiles(fileIds, targetDirId: targetDirId);
    return {'success': true, 'moved': fileIds.length};
  }

  Future<List<Map<String, dynamic>>> _searchFiles(
    Map<String, dynamic> args,
  ) async {
    final query = args['query'] as String?;
    if (query == null) throw Exception('query is required');

    final dirId = args['dir_id'] as String?;
    final limit = args['limit'] as int?;

    final files = await _gateway.searchFiles(
      query: query,
      dirId: dirId,
      limit: limit,
    );

    final names = await _gateway.decryptFileNames(files);
    return [
      for (var i = 0; i < files.length; i++)
        {
          'id': files[i].id,
          'name': names[i],
          'mime': files[i].mime,
          'is_dir': files[i].isDir,
          'size': files[i].size,
        },
    ];
  }

  Future<Map<String, dynamic>> _storageStats() async {
    // The listing endpoint carries no usage figures — the stats response is
    // the only source of used_space and quota.
    final stats = await _gateway.getStats();
    return {
      'used_space': stats['used_space'],
      'quota': stats['quota'],
      'stats': stats,
    };
  }

  Future<List<Map<String, dynamic>>> _listNotes(
    Map<String, dynamic> args,
  ) async {
    // `editable: true` makes the server return every note in the account and
    // ignore dir_id. When the caller scopes to a folder, list that folder
    // normally and keep editable children.
    final dirId = _optionalId(args['dir_id']);
    final response = dirId == null
        ? await _gateway.listFiles(editable: true)
        : await _gateway.listFiles(dirId: dirId);
    final notes = [
      for (final f in response.children)
        if (f.editable && !f.isDir) f,
    ];
    final names = await _gateway.decryptFileNames(notes);
    return [
      for (var i = 0; i < notes.length; i++)
        {
          'id': notes[i].id,
          'name': names[i],
          'dir_id': notes[i].fileId,
          'size': notes[i].size,
          'created_at': notes[i].createdAt,
          'finished_upload_at': notes[i].finishedUploadAt,
        },
    ];
  }

  /// Notes are rendered as text files; the read path is identical.
  Future<Map<String, dynamic>> _readNote(Map<String, dynamic> args) =>
      _readFile(args);

  /// Locate [query] inside a note without returning the full body.
  Future<Map<String, dynamic>> _findInNote(Map<String, dynamic> args) async {
    final fileId = args['file_id'] as String?;
    if (fileId == null || fileId.isEmpty) {
      throw Exception('file_id is required');
    }
    final query = args['query'];
    if (query is! String) throw Exception('query is required');
    if (query.isEmpty) throw Exception('query must not be empty');

    final FileItem file;
    try {
      file = FileItem.fromJson(await _gateway.getFileMetadata(fileId));
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('not found') || s.contains('404')) {
        throw Exception('Note not found');
      }
      rethrow;
    }

    if (file.isDir || !file.editable) {
      throw Exception('Not a note');
    }

    final size = file.size ?? 0;
    if (size > _maxFileSize) {
      throw Exception(
        'File too large (${(size / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Maximum: ${_maxFileSize ~/ 1024 ~/ 1024} MB.',
      );
    }

    final Uint8List fileKey;
    try {
      fileKey = _gateway.decryptFileKey(file);
    } catch (_) {
      throw Exception('Cannot decrypt this note');
    }

    final Uint8List bytes;
    try {
      bytes = await _gateway.downloadFile(file, fileKey: fileKey);
    } catch (_) {
      throw Exception('Cannot decrypt this note');
    }

    final plaintext = utf8.decode(bytes, allowMalformed: true);
    final scan = findInNotePlaintext(
      plaintext: plaintext,
      query: query,
      maxMatches: _optionalInt(args['max_matches']),
      context: _optionalInt(args['context']),
      caseSensitive: args['case_sensitive'] == true,
    );

    String? name;
    try {
      name = (await _gateway.decryptFileNames([file])).single;
    } catch (_) {
      name = null;
    }

    return {
      'file_id': fileId,
      'name': ?name,
      'query': query,
      'match_count': scan.matchCount,
      'truncated': scan.truncated,
      'matches': [for (final m in scan.matches) m.toJson()],
    };
  }

  Future<Map<String, dynamic>> _createNote(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    final content = args['content'] as String?;
    if (name == null) throw Exception('name is required');
    if (content == null) throw Exception('content is required');

    if (name.isEmpty) throw Exception('name is required');
    final dirId = _optionalId(args['dir_id']);
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (bytes.length > _maxFileSize) {
      throw Exception(
        'Content too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). '
        'Maximum: ${_maxFileSize ~/ 1024 ~/ 1024} MB.',
      );
    }
    final created = await _gateway.createNote(
      name,
      content,
      parentDirId: dirId,
    );
    return {
      'success': true,
      'id': created.id,
      'file_id': created.id,
      'name': name,
      'existed': created.existed,
    };
  }

  Map<String, dynamic> _health() {
    final locked = _isLocked();
    return {'running': true, 'locked': locked, 'ready': !locked};
  }

  Future<Map<String, dynamic>> _updateNote(Map<String, dynamic> args) async {
    final fileId = args['file_id'] as String?;
    final content = args['content'] as String?;
    if (fileId == null) throw Exception('file_id is required');
    if (content == null) throw Exception('content is required');

    final name = args['name'] as String?;
    await _gateway.updateNote(fileId, content, name: name);
    return {'success': true, 'file_id': fileId};
  }

  Map<String, dynamic> _fileSummary(FileItem file, String name) {
    return {
      'id': file.id,
      'name': name,
      'mime': file.mime,
      'is_dir': file.isDir,
      'size': file.size,
      'editable': file.editable,
      'created_at': file.createdAt,
      'finished_upload_at': file.finishedUploadAt,
    };
  }

  String _publicError(Object e) {
    final s = e.toString();
    if (s.contains('DioException') || s.contains('status code of')) {
      final m = RegExp(r'status code of (\d+)').firstMatch(s);
      if (m != null) return 'Request failed (HTTP ${m.group(1)})';
      return 'Request failed';
    }
    return s;
  }

  String? _optionalId(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
