import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers.dart';
import '../utils/logger.dart';
import 'mcp_dispatcher_pipeline.dart';
import 'mcp_protocol.dart';
import 'mcp_rate_limiting_dispatcher.dart';
import 'mcp_tool_handler.dart';
import 'mcp_tool_registry.dart';

/// Default port for the MCP server.
const int kDefaultMcpPort = 19548;

/// JSON-RPC -32000 message for a missing or invalid bearer token. Written so
/// an agent can act: check the AI Access snippet; the token is not rotated
/// automatically.
const String kMcpUnauthorizedMessage =
    'Invalid or missing bearer token. Check the AI Access snippet in Hoodik; '
    'the token is not rotated automatically.';

const Logger _log = Logger('mcp.server');

/// Compares two strings without leaking their common prefix length through
/// timing. The bearer token is 122 bits of `Random.secure()`, so a timing
/// oracle is not a practical threat — but auth comparisons are the one place
/// where "not practical" is a bad reason to use `==`.
bool _secureEquals(String a, String b) {
  final ab = utf8.encode(a);
  final bb = utf8.encode(b);
  // Fold the length difference into the result instead of returning early,
  // then compare over a fixed span so the loop count never depends on `a`.
  var mismatch = ab.length ^ bb.length;
  for (var i = 0; i < ab.length; i++) {
    mismatch |= ab[i] ^ (i < bb.length ? bb[i] : 0);
  }
  return mismatch == 0;
}

/// Whether an `Origin` header may talk to the server.
///
/// The MCP specification requires local servers to validate `Origin` so a web
/// page the user happens to be visiting cannot drive the server through the
/// browser (DNS rebinding). Native clients send no `Origin` at all, which is
/// why absence is allowed; anything that does send one must be loopback.
bool isAllowedMcpOrigin(String? origin) {
  if (origin == null || origin.isEmpty) return true;
  if (origin == 'null' || origin == 'file://') return true;

  final uri = Uri.tryParse(origin);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  return uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '::1';
}

/// Embedded MCP server that exposes Hoodik file operations to external AI
/// agents via the MCP Streamable HTTP transport.
///
/// macOS only — binds to localhost and requires a bearer token for auth.
/// Starts when the user is logged in and has enabled AI Access in settings.
class McpServer {
  late final McpToolDispatcher _toolHandler;

  /// The rate-limit decorator inside [_toolHandler]. Held separately so
  /// `regenerateToken` can wipe per-session buckets without rebuilding the
  /// whole pipeline.
  RateLimitingMcpToolDispatcher? _rateLimiter;
  HttpServer? _server;

  String? _bearerToken;
  int _port = kDefaultMcpPort;
  bool _running = false;
  bool _starting = false;

  /// Active MCP sessions (session ID → last activity time).
  final Map<String, DateTime> _sessions = {};

  static const _sessionTimeout = Duration(minutes: 30);
  Timer? _cleanupTimer;

  bool get isRunning => _running;
  int get port => _port;

  McpServer(Ref ref) {
    final built = buildMcpDispatcherPipeline(
      ref: ref,
      hooks: McpPipelineHooks(
        bearerTokenResolver: () => _bearerToken ?? '',
        accountIdResolver: () => ref.read(activeAccountProvider)?.id,
      ),
    );
    _toolHandler = built.dispatcher;
    _rateLimiter = built.rateLimiter;
  }

  /// Test-only constructor that accepts a pre-built dispatcher. Used by the
  /// tool-integration tests to plug in a handler backed by a fake gateway,
  /// optionally wrapped in the production auditing decorator.
  McpServer.withDispatcher(McpToolDispatcher dispatcher)
    : _toolHandler = dispatcher;

  Future<void> start({required int port, required String bearerToken}) async {
    if (_running || _starting) return;
    _starting = true;

    final tokenChanged = _bearerToken != null && _bearerToken != bearerToken;
    _port = port;
    _bearerToken = bearerToken;
    if (tokenChanged) _rateLimiter?.resetSessions();

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
      // Passing port 0 asks the OS for an ephemeral port; adopt whatever it
      // handed out so `port` reports where the server actually listens.
      _port = _server!.port;
      _running = true;

      _log.info(
        'mcp server started',
        fields: {'port': _port, 'endpoint': 'http://127.0.0.1:$_port/mcp'},
      );

      _server!.listen(
        (request) {
          unawaited(
            _handleRequest(request).catchError((Object e) {
              _log.error('mcp request failed', fields: {'error': e.toString()});
            }),
          );
        },
        onError: (e) {
          _log.error(
            'mcp server socket error',
            fields: {'error': e.toString()},
          );
        },
      );

      _cleanupTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _cleanupSessions(),
      );
    } catch (e) {
      _running = false;
      _log.error('mcp server failed to start', fields: {'error': e.toString()});
      rethrow;
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _sessions.clear();
    _rateLimiter?.resetSessions();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _running = false;
      _log.info('mcp server stopped');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      await _handleAuthorizedRequest(request);
    } catch (e) {
      _log.error('mcp request failed', fields: {'error': e.toString()});
      try {
        await _respondJson(
          request,
          200,
          mcpErrorResponse(null, jsonRpcInternalError, 'Internal error'),
        );
      } catch (_) {}
    }
  }

  Future<void> _handleAuthorizedRequest(HttpRequest request) async {
    final origin = request.headers.value('origin');
    if (!isAllowedMcpOrigin(origin)) {
      _log.warn('mcp request denied: disallowed origin');
      request.response.statusCode = 403;
      await request.response.close();
      return;
    }

    _setCorsHeaders(request.response, origin);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }

    if (request.uri.path != '/mcp') {
      await _respond(request, 404, 'Not found');
      return;
    }

    // Auth gates every method that touches server state, DELETE included —
    // tearing down another client's session is not an anonymous operation.
    if (request.method == 'DELETE' || request.method == 'POST') {
      if (!_isAuthorized(request)) {
        _log.warn('mcp request denied: unauthorized');
        final rpcId = await _tryParseJsonRpcId(request);
        await _respondJson(
          request,
          401,
          mcpErrorResponse(rpcId, -32000, kMcpUnauthorizedMessage),
        );
        return;
      }
    }

    if (request.method == 'DELETE') {
      final sessionId = request.headers.value('mcp-session-id');
      if (sessionId != null) {
        _sessions.remove(sessionId);
        _log.info('mcp session closed by client');
      }
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }

    if (request.method != 'POST') {
      await _respond(request, 405, 'Method not allowed');
      return;
    }

    await _handleJsonRpc(request);
  }

  bool _isAuthorized(HttpRequest request) {
    final token = _bearerToken;
    // A server started without a token accepts nothing, rather than matching
    // the literal string "Bearer null".
    if (token == null || token.isEmpty) return false;

    final authHeader = request.headers.value('authorization');
    if (authHeader == null) return false;
    return _secureEquals(authHeader, 'Bearer $token');
  }

  Future<void> _handleJsonRpc(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();

    List<McpRequest> requests;
    try {
      requests = parseRequests(body);
    } catch (e) {
      await _respondJson(
        request,
        400,
        mcpErrorResponse(null, jsonRpcParseError, 'Parse error: $e'),
      );
      return;
    }

    final responses = <Map<String, dynamic>>[];
    String? sessionId = request.headers.value('mcp-session-id');

    for (final req in requests) {
      Map<String, dynamic>? resp;
      try {
        resp = await _processRequest(req, sessionId);
      } catch (e) {
        _log.error(
          'mcp rpc failed',
          fields: {'method': req.method, 'error': e.toString()},
        );
        if (req.isNotification) continue;
        resp = mcpErrorResponse(req.id, jsonRpcInternalError, 'Internal error');
      }
      if (resp != null) {
        responses.add(resp);

        if (req.method == 'initialize' && resp['result'] != null) {
          sessionId = const Uuid().v4();
          _sessions[sessionId] = DateTime.now();
          _log.info('mcp session created');
        }
      }
    }

    if (sessionId != null) {
      request.response.headers.set('Mcp-Session-Id', sessionId);
    }

    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.json;

    if (responses.length == 1) {
      request.response.write(jsonEncode(responses.first));
    } else if (responses.isNotEmpty) {
      request.response.write(jsonEncode(responses));
    }

    await request.response.close();
  }

  Future<Map<String, dynamic>?> _processRequest(
    McpRequest request,
    String? sessionId,
  ) async {
    if (sessionId != null && _sessions.containsKey(sessionId)) {
      _sessions[sessionId] = DateTime.now();
    }

    switch (request.method) {
      case 'initialize':
        return handleInitialize(request);

      case 'notifications/initialized':
        return null;

      case 'ping':
        return handlePing(request);

      case 'tools/list':
        return mcpResponse(request.id, {'tools': mcpTools});

      case 'tools/call':
        return _dispatchTool(request);

      default:
        if (request.isNotification) return null;
        return mcpErrorResponse(
          request.id,
          jsonRpcMethodNotFound,
          'Method not found: ${request.method}',
        );
    }
  }

  Future<Map<String, dynamic>> _dispatchTool(McpRequest request) async {
    final params = request.params ?? {};
    final toolName = params['name'] as String? ?? '<unknown>';
    final sw = Stopwatch()..start();
    _log.debug('mcp tool invoke', fields: {'tool': toolName});

    try {
      final response = await _toolHandler.handleToolCall(request);
      sw.stop();
      _log.info(
        'mcp tool done',
        fields: {'tool': toolName, 'duration_ms': sw.elapsedMilliseconds},
      );
      return response;
    } catch (e) {
      sw.stop();
      _log.error(
        'mcp tool failed',
        fields: {
          'tool': toolName,
          'duration_ms': sw.elapsedMilliseconds,
          'error': e.toString(),
        },
      );
      return mcpErrorResponse(
        request.id,
        jsonRpcInternalError,
        'Internal error',
      );
    }
  }

  void _cleanupSessions() {
    final now = DateTime.now();
    final before = _sessions.length;
    _sessions.removeWhere((_, lastActive) {
      return now.difference(lastActive) > _sessionTimeout;
    });
    final removed = before - _sessions.length;
    if (removed > 0) {
      _log.info('mcp sessions expired', fields: {'count': removed});
    }
  }

  /// Reflects the caller's origin rather than answering `*`, so only the
  /// loopback origins that passed [isAllowedMcpOrigin] are ever granted access
  /// by a browser. Requests with no `Origin` are native clients, which ignore
  /// CORS entirely and so need no header.
  void _setCorsHeaders(HttpResponse response, String? origin) {
    if (origin != null && origin.isNotEmpty) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Vary', 'Origin');
    }
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, Mcp-Session-Id',
    );
    response.headers.set('Access-Control-Expose-Headers', 'Mcp-Session-Id');
    response.headers.set(
      'Access-Control-Allow-Methods',
      'POST, OPTIONS, DELETE',
    );
  }

  /// Best-effort JSON-RPC id from a request body we are about to reject.
  /// Auth runs before [_handleJsonRpc], so we consume the body here only on
  /// the 401 path. Missing, empty, or unparseable bodies yield a null id.
  Future<Object?> _tryParseJsonRpcId(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded['id'];
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) return first['id'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _respond(HttpRequest request, int status, String body) async {
    request.response.statusCode = status;
    request.response.write(body);
    await request.response.close();
  }

  Future<void> _respondJson(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}
