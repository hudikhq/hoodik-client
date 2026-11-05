import 'dart:collection';
import 'dart:typed_data';

const int kPreviewChunkSize = 4 * 1024 * 1024;

abstract class PreviewRangeSource {
  int get length;

  Stream<Uint8List> read(int start, int end);

  Future<void> close();
}

class ChunkedPreviewSource implements PreviewRangeSource {
  ChunkedPreviewSource({
    required this.length,
    required this.chunkSize,
    required Future<Uint8List> Function(int index) fetchChunk,
    int cachedChunks = 8,
  }) : _fetchChunk = fetchChunk,
       _maxCached = cachedChunks < 1 ? 1 : cachedChunks;

  @override
  final int length;

  final int chunkSize;

  final Future<Uint8List> Function(int index) _fetchChunk;
  final int _maxCached;

  final LinkedHashMap<int, Uint8List> _cache = LinkedHashMap();
  final Map<int, Future<Uint8List>> _inFlight = {};

  @override
  Stream<Uint8List> read(int start, int end) async* {
    if (length <= 0 || chunkSize <= 0 || start < 0 || start > end) return;
    if (start >= length) return;
    final last = end >= length ? length - 1 : end;

    final firstChunk = start ~/ chunkSize;
    final lastChunk = last ~/ chunkSize;

    for (var index = firstChunk; index <= lastChunk; index++) {
      final data = await _chunk(index);
      if (data.isEmpty) continue;

      final chunkStart = index * chunkSize;
      final from = start > chunkStart ? start - chunkStart : 0;
      final to = last < chunkStart + data.length - 1
          ? last - chunkStart
          : data.length - 1;
      if (from <= to) {
        yield Uint8List.sublistView(data, from, to + 1);
      }
    }
  }

  Future<Uint8List> _chunk(int index) {
    final cached = _cache.remove(index);
    if (cached != null) {
      _cache[index] = cached;
      return Future.value(cached);
    }

    final pending = _inFlight[index];
    if (pending != null) return pending;

    final future = _fetchChunk(index).then((data) {
      _remember(index, data);
      return data;
    });
    _inFlight[index] = future;
    future.whenComplete(() => _inFlight.remove(index));
    return future;
  }

  void _remember(int index, Uint8List data) {
    _cache[index] = data;
    while (_cache.length > _maxCached) {
      _cache.remove(_cache.keys.first);
    }
  }

  @override
  Future<void> close() async {
    _cache.clear();
    _inFlight.clear();
  }
}
