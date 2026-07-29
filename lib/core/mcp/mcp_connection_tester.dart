import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mcp_protocol.dart';

/// Result of a connection-test probe against the local MCP server. The UI
/// renders either [error] or [capabilities] depending on which is non-null.
class McpTestResult {
  final bool success;
  final String? error;
  final String? serverName;
  final String? serverVersion;
  final String? protocolVersion;

  /// Top-level capability keys the server advertised back (e.g. `tools`).
  /// The wizard renders these verbatim as a compact summary.
  final List<String> capabilities;

  const McpTestResult({
    required this.success,
    this.error,
    this.serverName,
    this.serverVersion,
    this.protocolVersion,
    this.capabilities = const [],
  });

  factory McpTestResult.failure(String error) =>
      McpTestResult(success: false, error: error);
}

/// Closure that performs a `POST /mcp` with the provided headers and body,
/// returning the decoded JSON. Exposed so tests can exercise the tester
/// without binding a real socket.
typedef McpHttpPost =
    Future<Map<String, dynamic>> Function({
      required Uri uri,
      required Map<String, String> headers,
      required String body,
    });

/// Runs the `initialize` handshake against a running local MCP server and
/// summarises the response for the connect-wizard UI.
///
/// Kept in the core layer rather than the widget so we can drive it from
/// golden tests and future CLI tooling without dragging a Flutter binding
/// along for the ride.
class McpConnectionTester {
  final McpHttpPost _post;

  McpConnectionTester({McpHttpPost? post}) : _post = post ?? _defaultPost;

  Future<McpTestResult> probe({
    required int port,
    required String bearerToken,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (bearerToken.isEmpty) {
      return McpTestResult.failure('Bearer token is missing.');
    }

    final uri = Uri.parse('http://127.0.0.1:$port/mcp');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'initialize',
      'id': 1,
      'params': {
        'protocolVersion': mcpProtocolVersion,
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'hoodik-connect-wizard', 'version': '1.0'},
      },
    });

    try {
      final response = await _post(
        uri: uri,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $bearerToken',
        },
        body: body,
      ).timeout(timeout);

      if (response['error'] != null) {
        final err = response['error'] as Map<String, dynamic>;
        return McpTestResult.failure(
          err['message']?.toString() ?? 'Unknown error',
        );
      }

      final result = response['result'] as Map<String, dynamic>?;
      if (result == null) return McpTestResult.failure('Empty response');

      final serverInfo = result['serverInfo'] as Map<String, dynamic>? ?? {};
      final caps =
          (result['capabilities'] as Map<String, dynamic>?)?.keys
              .map((k) => k.toString())
              .toList() ??
          const [];

      return McpTestResult(
        success: true,
        serverName: serverInfo['name']?.toString(),
        serverVersion: serverInfo['version']?.toString(),
        protocolVersion: result['protocolVersion']?.toString(),
        capabilities: caps,
      );
    } on TimeoutException {
      return McpTestResult.failure('Timed out after ${timeout.inSeconds}s.');
    } catch (e) {
      return McpTestResult.failure(e.toString());
    }
  }
}

/// Default transport: real `dart:io` HttpClient POST. Kept outside the class
/// so tests can replace it without hooking into the binding.
Future<Map<String, dynamic>> _defaultPost({
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close();
    final raw = await utf8.decoder.bind(response).join();
    return jsonDecode(raw) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}
