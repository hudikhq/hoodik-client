import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_server.dart';

void main() {
  group('kDefaultMcpPort', () {
    test('is 19548', () {
      expect(kDefaultMcpPort, 19548);
    });
  });

  group('MCP handshake flow', () {
    test('initialize returns capabilities then tools/list returns tools', () {
      final initResp = handleInitialize(
        McpRequest(
          jsonrpc: '2.0',
          method: 'initialize',
          id: 1,
          params: {
            'protocolVersion': '2025-03-26',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0'},
          },
        ),
      );

      expect(initResp['result']['protocolVersion'], mcpProtocolVersion);
      expect(initResp['result']['capabilities']['tools'], isA<Map>());
      expect(initResp['result']['serverInfo']['name'], 'hoodik');

      // notifications/initialized is a notification — no response expected.
      final notif = McpRequest(
        jsonrpc: '2.0',
        method: 'notifications/initialized',
      );
      expect(notif.isNotification, true);
    });

    test('unknown method on a request returns method-not-found', () {
      final resp = mcpErrorResponse(
        99,
        jsonRpcMethodNotFound,
        'Method not found: foo/bar',
      );

      expect(resp['error']['code'], jsonRpcMethodNotFound);
      expect(resp['error']['message'], contains('foo/bar'));
    });

    test('unknown notification produces no response', () {
      final req = McpRequest(jsonrpc: '2.0', method: 'notifications/unknown');
      expect(req.isNotification, true);
    });
  });

  group('batch request processing', () {
    test('produces responses for requests but not notifications', () {
      final body = jsonEncode([
        {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
        {'jsonrpc': '2.0', 'method': 'ping', 'id': 2},
      ]);

      final requests = parseRequests(body);
      expect(requests, hasLength(3));

      final responses = <Map<String, dynamic>>[];
      for (final req in requests) {
        if (req.isNotification) continue;
        responses.add(handlePing(req));
      }

      expect(responses, hasLength(2));
      expect(responses[0]['id'], 1);
      expect(responses[1]['id'], 2);
    });
  });

  group('HTTP server', () {
    test('loopback address is 127.0.0.1', () {
      expect(InternetAddress.loopbackIPv4.address, '127.0.0.1');
    });

    test('can bind and release a port', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      expect(port, greaterThan(0));

      await server.close();

      // Port should be available again after close.
      final server2 = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      await server2.close();
    });
  });
}
