import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_registry.dart';

void main() {
  group('mcpTools registry', () {
    test('contains exactly the expected tools', () {
      final toolNames = mcpTools.map((t) => t['name'] as String).toList();

      expect(toolNames, [
        'list_files',
        'read_file',
        'write_file',
        'create_directory',
        'delete_file',
        'rename_file',
        'move_files',
        'search_files',
        'storage_stats',
        'list_notes',
        'read_note',
        'create_note',
        'update_note',
      ]);
    });

    test('every tool has name, description, and object inputSchema', () {
      for (final tool in mcpTools) {
        final name = tool['name'] as String;
        expect(name.isNotEmpty, true, reason: 'Tool name must not be empty');

        final desc = tool['description'] as String;
        expect(
          desc.isNotEmpty,
          true,
          reason: '$name: description must not be empty',
        );

        final schema = tool['inputSchema'] as Map;
        expect(
          schema['type'],
          'object',
          reason: '$name: inputSchema.type must be "object"',
        );
      }
    });

    test('tools with required params declare them correctly', () {
      final expected = {
        'read_file': ['file_id'],
        'write_file': ['name', 'content'],
        'create_directory': ['name'],
        'delete_file': ['file_id'],
        'rename_file': ['file_id', 'new_name'],
        'move_files': ['file_ids'],
        'search_files': ['query'],
        'read_note': ['file_id'],
        'create_note': ['name', 'content'],
        'update_note': ['file_id', 'content'],
      };

      for (final entry in expected.entries) {
        final tool = mcpTools.firstWhere((t) => t['name'] == entry.key);
        final required = tool['inputSchema']['required'] as List;
        expect(
          required,
          containsAll(entry.value),
          reason: '${entry.key} should require ${entry.value}',
        );
      }
    });

    test(
      'list_files, storage_stats, and list_notes have no required params',
      () {
        for (final name in ['list_files', 'storage_stats', 'list_notes']) {
          final tool = mcpTools.firstWhere((t) => t['name'] == name);
          expect(
            tool['inputSchema'].containsKey('required'),
            false,
            reason: '$name should have no required params',
          );
        }
      },
    );

    test('write_file encoding enum has text and base64', () {
      final tool = mcpTools.firstWhere((t) => t['name'] == 'write_file');
      final encoding =
          (tool['inputSchema']['properties'] as Map)['encoding'] as Map;

      expect(encoding['type'], 'string');
      expect(encoding['enum'], ['text', 'base64']);
    });

    test('move_files file_ids is array of strings', () {
      final tool = mcpTools.firstWhere((t) => t['name'] == 'move_files');
      final fileIds =
          (tool['inputSchema']['properties'] as Map)['file_ids'] as Map;

      expect(fileIds['type'], 'array');
      expect(fileIds['items'], {'type': 'string'});
    });

    test('search_files limit is integer', () {
      final tool = mcpTools.firstWhere((t) => t['name'] == 'search_files');
      final limit = (tool['inputSchema']['properties'] as Map)['limit'] as Map;

      expect(limit['type'], 'integer');
    });
  });

  group('tool call response format', () {
    test('successful tool result wraps content in MCP format', () {
      // The handler returns this shape on success.
      final result = {'id': 'file-1', 'name': 'test.md', 'size': 1024};
      final response = mcpResponse(1, {
        'content': [
          {'type': 'text', 'text': jsonEncode(result)},
        ],
      });

      expect(response['jsonrpc'], '2.0');
      expect(response['id'], 1);

      final content = response['result']['content'] as List;
      expect(content, hasLength(1));
      expect(content[0]['type'], 'text');

      // The text field should be valid JSON.
      final parsed = jsonDecode(content[0]['text'] as String);
      expect(parsed['name'], 'test.md');
    });

    test('error tool result includes isError flag', () {
      final response = mcpResponse(1, {
        'content': [
          {'type': 'text', 'text': 'Error: Not authenticated'},
        ],
        'isError': true,
      });

      expect(response['result']['isError'], true);
      expect(
        response['result']['content'][0]['text'],
        contains('Not authenticated'),
      );
    });
  });

  group('tools/list response', () {
    test('matches MCP spec structure', () {
      final response = mcpResponse(1, {'tools': mcpTools});

      expect(response['jsonrpc'], '2.0');
      expect(response['id'], 1);

      final tools = response['result']['tools'] as List;
      expect(tools, hasLength(13));

      for (final tool in tools) {
        final t = tool as Map;
        expect(t.containsKey('name'), true);
        expect(t.containsKey('description'), true);
        expect(t.containsKey('inputSchema'), true);
      }
    });
  });
}
