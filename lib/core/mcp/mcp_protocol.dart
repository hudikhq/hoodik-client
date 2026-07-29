import 'dart:convert';

/// MCP protocol version supported by this server.
const String mcpProtocolVersion = '2025-03-26';

/// Server info returned during initialization.
const Map<String, String> mcpServerInfo = {
  'name': 'hoodik',
  'version': '1.0.0',
};

const int jsonRpcParseError = -32700;
const int jsonRpcInvalidRequest = -32600;
const int jsonRpcMethodNotFound = -32601;
const int jsonRpcInvalidParams = -32602;
const int jsonRpcInternalError = -32603;

/// A parsed JSON-RPC request.
class McpRequest {
  final String jsonrpc;
  final String method;

  /// Null for notifications (no response expected).
  final Object? id;
  final Map<String, dynamic>? params;

  bool get isNotification => id == null;

  McpRequest({
    required this.jsonrpc,
    required this.method,
    this.id,
    this.params,
  });

  factory McpRequest.fromJson(Map<String, dynamic> json) {
    return McpRequest(
      jsonrpc: json['jsonrpc'] as String? ?? '2.0',
      method: json['method'] as String? ?? '',
      id: json['id'],
      params: json['params'] as Map<String, dynamic>?,
    );
  }
}

/// Build a successful JSON-RPC response.
Map<String, dynamic> mcpResponse(Object? id, Object? result) {
  return {'jsonrpc': '2.0', 'id': id, 'result': result ?? {}};
}

/// Build a JSON-RPC error response.
Map<String, dynamic> mcpErrorResponse(
  Object? id,
  int code,
  String message, {
  Object? data,
}) {
  return {
    'jsonrpc': '2.0',
    'id': id,
    'error': {
      'code': code,
      'message': message,
      if (data != null) 'data': data, // ignore: use_null_aware_elements
    },
  };
}

/// Handle the `initialize` method — capability negotiation.
Map<String, dynamic> handleInitialize(McpRequest request) {
  return mcpResponse(request.id, {
    'protocolVersion': mcpProtocolVersion,
    'capabilities': {
      'tools': {'listChanged': false},
    },
    'serverInfo': mcpServerInfo,
  });
}

/// Handle the `ping` method.
Map<String, dynamic> handlePing(McpRequest request) {
  return mcpResponse(request.id, {});
}

/// Parse a JSON string into one or more [McpRequest]s.
///
/// Returns a list because JSON-RPC supports batch requests (arrays).
/// Throws [FormatException] on invalid JSON.
List<McpRequest> parseRequests(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) McpRequest.fromJson(item),
    ];
  }
  if (decoded is Map<String, dynamic>) {
    return [McpRequest.fromJson(decoded)];
  }
  throw const FormatException('Invalid JSON-RPC body');
}
