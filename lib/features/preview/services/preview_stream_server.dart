import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../core/utils/logger.dart';
import 'chunked_preview_source.dart';

const _log = Logger('PreviewStreamServer');

sealed class HttpRangeOutcome {
  const HttpRangeOutcome();
}

class ServeFull extends HttpRangeOutcome {
  const ServeFull();
}

class ServeRange extends HttpRangeOutcome {
  const ServeRange(this.start, this.end);

  final int start;
  final int end;
}

class RangeUnsatisfiable extends HttpRangeOutcome {
  const RangeUnsatisfiable();
}

HttpRangeOutcome parseHttpRange(String? header, int length) {
  if (header == null || header.isEmpty) return const ServeFull();
  final trimmed = header.trim();
  if (!trimmed.toLowerCase().startsWith('bytes=')) return const ServeFull();

  final spec = trimmed.substring('bytes='.length);
  if (spec.contains(',')) return const ServeFull();

  final dash = spec.indexOf('-');
  if (dash < 0) return const ServeFull();

  final startText = spec.substring(0, dash).trim();
  final endText = spec.substring(dash + 1).trim();

  if (startText.isEmpty) {
    final suffix = int.tryParse(endText);
    if (suffix == null) return const ServeFull();
    if (suffix <= 0 || length == 0) return const RangeUnsatisfiable();
    final start = suffix >= length ? 0 : length - suffix;
    return ServeRange(start, length - 1);
  }

  final start = int.tryParse(startText);
  if (start == null || start < 0) return const ServeFull();
  if (start >= length) return const RangeUnsatisfiable();

  if (endText.isEmpty) return ServeRange(start, length - 1);
  final end = int.tryParse(endText);
  if (end == null) return const ServeFull();
  if (end < start) return const RangeUnsatisfiable();
  return ServeRange(start, end >= length ? length - 1 : end);
}

class _RegisteredSource {
  _RegisteredSource({required this.source, required this.contentType});

  final PreviewRangeSource source;
  final String contentType;
}

class PreviewStreamServer {
  PreviewStreamServer({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  HttpServer? _server;
  int? _port;
  final Map<String, _RegisteredSource> _sources = {};

  bool get isRunning => _server != null;
  int? get port => _port;

  Future<Uri> register({
    required PreviewRangeSource source,
    required String contentType,
    String? fileName,
  }) async {
    await _ensureStarted();
    final token = _uuid.v4();
    _sources[token] = _RegisteredSource(
      source: source,
      contentType: contentType.trim().isEmpty
          ? 'application/octet-stream'
          : contentType,
    );

    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _port,
      pathSegments: [
        token,
        if (fileName != null && fileName.isNotEmpty) fileName,
      ],
    );
  }

  Future<void> unregister(Uri uri) async {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    await _sources.remove(segments.first)?.source.close();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _port = null;

    for (final entry in _sources.values) {
      await entry.source.close();
    }
    _sources.clear();

    await server?.close(force: true);
    if (server != null) {
      _log.info('preview stream server stopped');
    }
  }

  Future<void> _ensureStarted() async {
    if (_server != null) return;

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _port = server.port;
    server.listen(
      (request) {
        unawaited(
          _serve(request).catchError((Object e) {
            _log.debug(
              'preview stream request failed',
              fields: {'error': e.toString()},
            );
            _destroy(request);
          }),
        );
      },
      onError: (Object e) {
        _log.warn(
          'preview stream socket error',
          fields: {'error': e.toString()},
        );
      },
    );
    _log.info('preview stream server started', fields: {'port': server.port});
  }

  void _destroy(HttpRequest request) {
    try {
      unawaited(request.response.close());
    } catch (_) {}
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;

    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    final segments = request.uri.pathSegments;
    final entry = segments.isEmpty ? null : _sources[segments.first];
    if (entry == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final source = entry.source;
    final total = source.length;

    response.headers
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(HttpHeaders.contentTypeHeader, entry.contentType)
      ..set(HttpHeaders.cacheControlHeader, 'no-store');

    final outcome = parseHttpRange(
      request.headers.value(HttpHeaders.rangeHeader),
      total,
    );

    switch (outcome) {
      case ServeFull():
        response.statusCode = HttpStatus.ok;
        response.headers.contentLength = total;
        if (request.method == 'HEAD' || total == 0) {
          await response.close();
          return;
        }
        await response.addStream(source.read(0, total - 1));
        await response.close();

      case ServeRange(:final start, :final end):
        response.statusCode = HttpStatus.partialContent;
        response.headers.contentLength = end - start + 1;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$total',
        );
        if (request.method == 'HEAD') {
          await response.close();
          return;
        }
        await response.addStream(source.read(start, end));
        await response.close();

      case RangeUnsatisfiable():
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        await response.close();
    }
  }
}
