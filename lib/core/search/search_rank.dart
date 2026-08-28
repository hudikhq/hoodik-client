/// Client-side refinement of server search results.
///
/// The server ranks opaque tags; this side holds the plaintext — the raw
/// query, every decrypted name, and the hydrated bodies of candidate notes —
/// so precision lives here. Scoring is tiered so a stronger kind of evidence
/// always beats any amount of a weaker kind: an exact name match outranks
/// every substring match, any name evidence outranks body evidence, and
/// server tag counts only order rows nothing textual separates.
///
/// The same tiers are implemented in the web's `services/storage/rank.ts`;
/// the two share the golden expectations in their test suites the same way
/// the tag vector is shared. Change them together.
library;

/// Query words the way the index tokenizes: alphanumeric runs, two chars up.
List<String> queryWords(String query) {
  return query
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.length >= 2)
      .toList();
}

/// One row under scoring: the decrypted [name], the server's ranking
/// evidence, and the hydrated [body] when the row is a note that loaded.
class RankableRow {
  final String id;
  final String name;
  final int? searchHits;
  final int? searchNameHits;
  final int recency;
  final String? body;

  const RankableRow({
    required this.id,
    required this.name,
    this.searchHits,
    this.searchNameHits,
    this.recency = 0,
    this.body,
  });
}

int scoreRow(String query, RankableRow row) {
  final raw = query.trim().toLowerCase();
  final words = queryWords(query);
  final name = row.name.toLowerCase();

  var score = 0;

  if (raw.isNotEmpty && name == raw) {
    score += 1000000;
  } else if (raw.isNotEmpty && name.startsWith(raw)) {
    score += 500000;
  } else if (raw.isNotEmpty && name.contains(raw)) {
    score += 250000;
  }

  if (words.isNotEmpty) {
    final inName = words.where(name.contains).length;
    if (inName == words.length) {
      score += 100000;
    }
    score += (10000 * inName / words.length).round();
  }

  final body = row.body;
  if (body != null) {
    final text = body.toLowerCase();
    if (raw.isNotEmpty && text.contains(raw)) {
      score += 50000;
    }
    if (words.isNotEmpty) {
      final inBody = words.where(text.contains).length;
      if (inBody == words.length) {
        score += 25000;
      }
      score += (5000 * inBody / words.length).round();
    }
  }

  if ((row.searchNameHits ?? 0) > 0) {
    score += 2000;
  }
  final hits = row.searchHits ?? 0;
  score += (hits > 99 ? 99 : hits) * 10;

  return score;
}

/// Indexes of [rows] ordered by refined score, newest first among ties.
List<int> rankSearchResults(String query, List<RankableRow> rows) {
  final order = List<int>.generate(rows.length, (i) => i);
  final scores = [for (final row in rows) scoreRow(query, row)];

  order.sort((a, b) {
    final diff = scores[b] - scores[a];
    if (diff != 0) return diff;
    return rows[b].recency.compareTo(rows[a].recency);
  });

  return order;
}
