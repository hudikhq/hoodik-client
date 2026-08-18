/// Presigned URLs for a file's chunks, ordered by chunk index.
///
/// Handed to the Rust transfer pipeline, which builds requests from them
/// carrying no cookie, bearer token or refresh header — see `ChunkTarget` in
/// the transfer crate.
class ChunkUrlsResponse {
  const ChunkUrlsResponse({required this.urls, required this.expiresAt});

  /// Indexed by chunk number. A gap stays empty rather than shifting the rest
  /// along, so an index the server did not cover falls back to fetching
  /// through the server instead of silently reading the wrong chunk.
  final List<String> urls;

  /// Unix seconds after which every URL above stops working.
  final int expiresAt;

  /// Empty when the response carries nothing usable, which callers treat the
  /// same as no manifest at all.
  bool get isEmpty => urls.isEmpty;

  factory ChunkUrlsResponse.fromJson(Map<String, dynamic> json) {
    final entries = (json['urls'] as List<dynamic>?) ?? const [];

    var highest = -1;
    final byIndex = <int, String>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final chunk = entry['chunk'] as int?;
      final url = entry['url'] as String?;
      if (chunk == null || url == null || chunk < 0) continue;
      byIndex[chunk] = url;
      if (chunk > highest) highest = chunk;
    }

    return ChunkUrlsResponse(
      urls: highest < 0
          ? const []
          : List<String>.generate(
              highest + 1,
              (i) => byIndex[i] ?? '',
              growable: false,
            ),
      expiresAt: (json['expires_at'] as int?) ?? 0,
    );
  }
}
