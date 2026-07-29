import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';

void main() {
  group('McpRequest.fromJson', () {
    test('parses a standard request', () {
      final req = McpRequest.fromJson({
        'jsonrpc': '2.0',
        'method': 'tools/list',
        'id': 1,
        'params': {'cursor': null},
      });

      expect(req.jsonrpc, '2.0');
      expect(req.method, 'tools/list');
      expect(req.id, 1);
      expect(req.params, {'cursor': null});
      expect(req.isNotification, false);
    });

    test('parses a notification (no id)', () {
      final req = McpRequest.fromJson({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });

      expect(req.method, 'notifications/initialized');
      expect(req.id, isNull);
      expect(req.isNotification, true);
      expect(req.params, isNull);
    });

    test('defaults jsonrpc and method when missing', () {
      final req = McpRequest.fromJson({});

      expect(req.jsonrpc, '2.0');
      expect(req.method, '');
    });

    test('handles string id', () {
      final req = McpRequest.fromJson({
        'jsonrpc': '2.0',
        'method': 'ping',
        'id': 'abc-123',
      });

      expect(req.id, 'abc-123');
      expect(req.isNotification, false);
    });
  });

  group('parseRequests', () {
    test('parses a single request object', () {
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'initialize',
        'id': 1,
        'params': {
          'protocolVersion': '2025-03-26',
          'clientInfo': {'name': 'test', 'version': '1.0'},
        },
      });

      final requests = parseRequests(body);
      expect(requests, hasLength(1));
      expect(requests.first.method, 'initialize');
      expect(requests.first.id, 1);
    });

    test('parses a batch request (array)', () {
      final body = jsonEncode([
        {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        {'jsonrpc': '2.0', 'method': 'tools/list', 'id': 2},
      ]);

      final requests = parseRequests(body);
      expect(requests, hasLength(2));
      expect(requests[0].method, 'ping');
      expect(requests[1].method, 'tools/list');
    });

    test('skips non-object items in batch', () {
      final body = jsonEncode([
        {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        'not an object',
        42,
      ]);

      final requests = parseRequests(body);
      expect(requests, hasLength(1));
      expect(requests.first.method, 'ping');
    });

    test('throws FormatException on invalid JSON', () {
      expect(() => parseRequests('{not valid json'), throwsFormatException);
    });

    test('throws FormatException on non-object non-array JSON', () {
      expect(() => parseRequests('"just a string"'), throwsFormatException);
    });
  });

  group('mcpResponse', () {
    test('builds a success response', () {
      final resp = mcpResponse(1, {'tools': []});

      expect(resp['jsonrpc'], '2.0');
      expect(resp['id'], 1);
      expect(resp['result'], {'tools': []});
    });

    test('defaults result to empty map when null', () {
      final resp = mcpResponse(1, null);

      expect(resp['result'], {});
    });

    test('preserves string id', () {
      final resp = mcpResponse('abc', {});

      expect(resp['id'], 'abc');
    });
  });

  group('mcpErrorResponse', () {
    test('builds an error response', () {
      final resp = mcpErrorResponse(1, -32601, 'Method not found');

      expect(resp['jsonrpc'], '2.0');
      expect(resp['id'], 1);
      expect(resp['error']['code'], -32601);
      expect(resp['error']['message'], 'Method not found');
      expect(resp['error'].containsKey('data'), false);
    });

    test('includes optional data', () {
      final resp = mcpErrorResponse(
        2,
        -32602,
        'Invalid params',
        data: {'field': 'name'},
      );

      expect(resp['error']['data'], {'field': 'name'});
    });

    test('works with null id (for parse errors)', () {
      final resp = mcpErrorResponse(null, jsonRpcParseError, 'Parse error');

      expect(resp['id'], isNull);
      expect(resp['error']['code'], jsonRpcParseError);
    });
  });

  group('handleInitialize', () {
    test('returns protocol version and capabilities', () {
      final req = McpRequest(
        jsonrpc: '2.0',
        method: 'initialize',
        id: 1,
        params: {
          'protocolVersion': '2025-03-26',
          'clientInfo': {'name': 'claude-code', 'version': '1.0.0'},
        },
      );

      final resp = handleInitialize(req);

      expect(resp['id'], 1);
      final result = resp['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], mcpProtocolVersion);
      expect(result['serverInfo'], mcpServerInfo);
      expect(result['capabilities']['tools']['listChanged'], false);
    });
  });

  group('handlePing', () {
    test('returns empty result', () {
      final req = McpRequest(jsonrpc: '2.0', method: 'ping', id: 42);

      final resp = handlePing(req);

      expect(resp['id'], 42);
      expect(resp['result'], {});
    });
  });

  group('constants', () {
    test('protocol version is set', () {
      expect(mcpProtocolVersion, '2025-03-26');
    });

    test('server info is correct', () {
      expect(mcpServerInfo['name'], 'hoodik');
      expect(mcpServerInfo['version'], isNotEmpty);
    });

    test('JSON-RPC error codes are standard', () {
      expect(jsonRpcParseError, -32700);
      expect(jsonRpcInvalidRequest, -32600);
      expect(jsonRpcMethodNotFound, -32601);
      expect(jsonRpcInvalidParams, -32602);
      expect(jsonRpcInternalError, -32603);
    });
  });
}
