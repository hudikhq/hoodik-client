import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/mcp/mcp_protocol.dart';
import 'package:hoodik_app/core/mcp/mcp_server.dart';
import 'package:hoodik_app/core/mcp/mcp_tool_handler.dart';

/// Records what reached the dispatcher so a test can prove a request was
/// rejected at the transport layer rather than merely answered with an error.
class _RecordingDispatcher implements McpToolDispatcher {
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> handleToolCall(McpRequest request) async {
    calls.add((request.params?['name'] as String?) ?? '<none>');
    return mcpResponse(request.id, {'content': <Object>[]});
  }
}

void main() {
  group('McpServer HTTP transport', () {
    late McpServer server;
    late _RecordingDispatcher dispatcher;
    late HttpClient client;
    const token = 'test-token-abc';

    setUp(() async {
      dispatcher = _RecordingDispatcher();
      server = McpServer.withDispatcher(dispatcher);
      // Port 0 asks the OS for a free port; the server adopts it so `port`
      // reports where it actually bound.
      await server.start(port: 0, bearerToken: token);
      client = HttpClient();
    });

    tearDown(() async {
      client.close();
      await server.stop();
    });

    Uri url([String path = '/mcp']) =>
        Uri.parse('http://127.0.0.1:${server.port}$path');

    Future<HttpClientResponse> send(
      String method,
      Uri uri, {
      Map<String, dynamic>? body,
      String? authToken,
      String? origin,
      String? sessionId,
    }) async {
      final request = await client.openUrl(method, uri);
      if (authToken != null) {
        request.headers.set('authorization', 'Bearer $authToken');
      }
      if (origin != null) request.headers.set('origin', origin);
      if (sessionId != null) request.headers.set('mcp-session-id', sessionId);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      return request.close();
    }

    test('reports the ephemeral port it actually bound', () {
      expect(server.port, greaterThan(0));
      expect(server.isRunning, isTrue);
    });

    test('a valid call reaches the dispatcher', () async {
      final response = await send(
        'POST',
        url(),
        authToken: token,
        body: {
          'jsonrpc': '2.0',
          'method': 'tools/call',
          'id': 1,
          'params': {'name': 'list_files', 'arguments': <String, dynamic>{}},
        },
      );

      expect(response.statusCode, 200);
      expect(dispatcher.calls, ['list_files']);
    });

    group('bearer auth', () {
      test('POST without a token never reaches the dispatcher', () async {
        final response = await send(
          'POST',
          url(),
          body: {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        );

        expect(response.statusCode, 401);
        expect(dispatcher.calls, isEmpty);
      });

      test('POST with the wrong token is rejected', () async {
        final response = await send(
          'POST',
          url(),
          authToken: 'wrong',
          body: {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        );

        expect(response.statusCode, 401);
        expect(dispatcher.calls, isEmpty);
      });

      test('a token that is a prefix of the real one is rejected', () async {
        final response = await send(
          'POST',
          url(),
          authToken: token.substring(0, token.length - 1),
          body: {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        );

        expect(response.statusCode, 401);
      });

      test('DELETE requires auth too', () async {
        // Session teardown used to be reachable anonymously.
        final response = await send('DELETE', url(), sessionId: 'whatever');

        expect(response.statusCode, 401);
      });

      test('DELETE with a valid token closes the session', () async {
        final response = await send(
          'DELETE',
          url(),
          authToken: token,
          sessionId: 'whatever',
        );

        expect(response.statusCode, 204);
      });
    });

    group('origin validation', () {
      test('a request with no Origin is allowed (native clients)', () async {
        final response = await send(
          'POST',
          url(),
          authToken: token,
          body: {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        );

        expect(response.statusCode, 200);
      });

      test('a loopback Origin is allowed and reflected', () async {
        final response = await send(
          'POST',
          url(),
          authToken: token,
          origin: 'http://localhost:3000',
          body: {'jsonrpc': '2.0', 'method': 'ping', 'id': 1},
        );

        expect(response.statusCode, 200);
        expect(
          response.headers.value('access-control-allow-origin'),
          'http://localhost:3000',
        );
      });

      test('a remote Origin is refused before auth is even read', () async {
        final response = await send(
          'POST',
          url(),
          authToken: token,
          origin: 'https://evil.example.com',
          body: {
            'jsonrpc': '2.0',
            'method': 'tools/call',
            'id': 1,
            'params': {'name': 'list_files'},
          },
        );

        expect(response.statusCode, 403);
        expect(dispatcher.calls, isEmpty);
      });

      test('a remote Origin cannot preflight its way in', () async {
        final response = await send(
          'OPTIONS',
          url(),
          origin: 'https://evil.example.com',
        );

        expect(response.statusCode, 403);
        expect(
          response.headers.value('access-control-allow-origin'),
          isNull,
          reason: 'a refused origin must never be granted access by a browser',
        );
      });

      test('never answers with a wildcard origin', () async {
        final response = await send(
          'OPTIONS',
          url(),
          origin: 'http://127.0.0.1:5173',
        );

        expect(response.statusCode, 204);
        expect(
          response.headers.value('access-control-allow-origin'),
          isNot('*'),
        );
      });
    });

    test('non-/mcp paths are 404', () async {
      final response = await send('POST', url('/other'), authToken: token);
      expect(response.statusCode, 404);
    });

    test('GET is not allowed', () async {
      final response = await send('GET', url(), authToken: token);
      expect(response.statusCode, 405);
    });
  });

  group('isAllowedMcpOrigin', () {
    test('allows absent and opaque origins used by native clients', () {
      expect(isAllowedMcpOrigin(null), isTrue);
      expect(isAllowedMcpOrigin(''), isTrue);
      expect(isAllowedMcpOrigin('null'), isTrue);
      expect(isAllowedMcpOrigin('file://'), isTrue);
    });

    test('allows loopback hosts on either scheme', () {
      expect(isAllowedMcpOrigin('http://localhost'), isTrue);
      expect(isAllowedMcpOrigin('http://localhost:19548'), isTrue);
      expect(isAllowedMcpOrigin('http://127.0.0.1:3000'), isTrue);
      expect(isAllowedMcpOrigin('https://localhost:8443'), isTrue);
    });

    test('refuses remote hosts', () {
      expect(isAllowedMcpOrigin('https://evil.example.com'), isFalse);
      expect(isAllowedMcpOrigin('http://192.168.1.10'), isFalse);
    });

    test('refuses hosts that merely embed a loopback name', () {
      expect(isAllowedMcpOrigin('http://localhost.evil.com'), isFalse);
      expect(isAllowedMcpOrigin('http://127.0.0.1.evil.com'), isFalse);
      expect(isAllowedMcpOrigin('http://notlocalhost'), isFalse);
    });

    test('refuses non-http schemes that could carry a payload', () {
      expect(isAllowedMcpOrigin('ws://localhost:19548'), isFalse);
      expect(isAllowedMcpOrigin('javascript:alert(1)'), isFalse);
    });
  });
}
