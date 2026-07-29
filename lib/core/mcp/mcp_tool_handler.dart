import 'dart:convert';
import 'dart:typed_data';

import '../api/api_client.dart';
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

  McpToolHandler(this._gateway);

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
      await _gateway.ensureFreshSession();
      final result = await _dispatch(toolName, args);
      return mcpResponse(request.id, {
        'content': [
          {'type': 'text', 'text': jsonEncode(result)},
        ],
      });
    } catch (e) {
      return mcpResponse(request.id, {
        'content': [
          {'type': 'text', 'text': 'Error: $e'},
        ],
        'isError': true,
      });
    }
  }

  Future<Object> _dispatch(String tool, Map<String, dynamic> args) async {
    switch (tool) {
      case 'list_files':
        return _listFiles(args);
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
      case 'create_note':
        return _createNote(args);
      case 'update_note':
        return _updateNote(args);
      default:
        throw Exception('Unknown tool: $tool');
    }
  }

  Future<List<Map<String, dynamic>>> _listFiles(
    Map<String, dynamic> args,
  ) async {
    final dirId = args['dir_id'] as String?;
    final response = await _gateway.listFiles(dirId: dirId);
    return [for (final f in response.children) _fileSummary(f)];
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
    final name = _gateway.decryptFileNameBestEffort(file);
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
    final dirId = args['dir_id'] as String?;

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

    await _gateway.uploadFileBytes(
      name: name,
      bytes: bytes,
      parentDirId: dirId,
    );

    return {'success': true, 'name': name, 'size': bytes.length};
  }

  Future<Map<String, dynamic>> _createDirectory(
    Map<String, dynamic> args,
  ) async {
    final name = args['name'] as String?;
    if (name == null) throw Exception('name is required');

    final dirId = args['dir_id'] as String?;
    await _gateway.createFolder(name, parentDirId: dirId);

    return {'success': true, 'name': name};
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

    return [
      for (final f in files)
        {
          'id': f.id,
          'name': _gateway.decryptFileNameBestEffort(f),
          'mime': f.mime,
          'is_dir': f.isDir,
          'size': f.size,
        },
    ];
  }

  Future<Map<String, dynamic>> _storageStats() async {
    final stats = await _gateway.getStats();
    final root = await _gateway.listFiles();
    return {'used_space': root.usedSpace, 'quota': root.quota, 'stats': stats};
  }

  Future<List<Map<String, dynamic>>> _listNotes(
    Map<String, dynamic> args,
  ) async {
    final dirId = args['dir_id'] as String?;
    final response = await _gateway.listFiles(dirId: dirId, editable: true);
    return [
      for (final f in response.children)
        {
          'id': f.id,
          'name': _gateway.decryptFileNameBestEffort(f),
          'size': f.size,
          'created_at': f.createdAt,
          'finished_upload_at': f.finishedUploadAt,
        },
    ];
  }

  /// Notes are rendered as text files; the read path is identical.
  Future<Map<String, dynamic>> _readNote(Map<String, dynamic> args) =>
      _readFile(args);

  Future<Map<String, dynamic>> _createNote(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    final content = args['content'] as String?;
    if (name == null) throw Exception('name is required');
    if (content == null) throw Exception('content is required');

    final dirId = args['dir_id'] as String?;
    final fileId = await _gateway.createNote(name, content, parentDirId: dirId);
    return {'success': true, 'file_id': fileId, 'name': name};
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

  Map<String, dynamic> _fileSummary(FileItem file) {
    return {
      'id': file.id,
      'name': _gateway.decryptFileNameBestEffort(file),
      'mime': file.mime,
      'is_dir': file.isDir,
      'size': file.size,
      'created_at': file.createdAt,
      'finished_upload_at': file.finishedUploadAt,
    };
  }
}
