// Scan plaintext note content for a query and return excerpted matches.
//
// Used by the `find_in_note` MCP tool so agents can locate a string inside
// a note without dumping the whole body. Kept out of `notes_workspace.dart`
// (that file is CI-capped) — this is the MCP analog of in-editor find, not
// the UI find bar.

const int kFindInNoteDefaultMaxMatches = 20;
const int kFindInNoteMaxMatchesCap = 50;
const int kFindInNoteDefaultContext = 80;
const int kFindInNoteContextCap = 200;

class FindInNoteMatch {
  final int index;
  final int offset;
  final int line;
  final String excerpt;

  const FindInNoteMatch({
    required this.index,
    required this.offset,
    required this.line,
    required this.excerpt,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'offset': offset,
    'line': line,
    'excerpt': excerpt,
  };
}

class FindInNoteScan {
  final List<FindInNoteMatch> matches;
  final bool truncated;

  const FindInNoteScan({required this.matches, required this.truncated});

  int get matchCount => matches.length;
}

/// Clamp `max_matches` to the documented default and cap.
int clampFindInNoteMaxMatches(int? value) {
  final n = value ?? kFindInNoteDefaultMaxMatches;
  if (n < 1) return 1;
  if (n > kFindInNoteMaxMatchesCap) return kFindInNoteMaxMatchesCap;
  return n;
}

/// Clamp `context` (excerpt padding chars) to the documented default and cap.
int clampFindInNoteContext(int? value) {
  final n = value ?? kFindInNoteDefaultContext;
  if (n < 0) return 0;
  if (n > kFindInNoteContextCap) return kFindInNoteContextCap;
  return n;
}

/// Find non-overlapping occurrences of [query] in [plaintext].
///
/// Throws [ArgumentError] when [query] is empty. Offsets are 0-based Dart
/// string indexes; [FindInNoteMatch.line] is 1-based.
FindInNoteScan findInNotePlaintext({
  required String plaintext,
  required String query,
  int? maxMatches,
  int? context,
  bool caseSensitive = false,
}) {
  if (query.isEmpty) {
    throw ArgumentError('query must not be empty');
  }

  final cap = clampFindInNoteMaxMatches(maxMatches);
  final pad = clampFindInNoteContext(context);
  final haystack = caseSensitive ? plaintext : plaintext.toLowerCase();
  final needle = caseSensitive ? query : query.toLowerCase();

  final matches = <FindInNoteMatch>[];
  var from = 0;
  var truncated = false;

  while (true) {
    final offset = haystack.indexOf(needle, from);
    if (offset < 0) break;
    if (matches.length >= cap) {
      truncated = true;
      break;
    }
    matches.add(
      FindInNoteMatch(
        index: matches.length,
        offset: offset,
        line: lineNumberAt(plaintext, offset),
        excerpt: excerptAround(
          plaintext,
          offset: offset,
          matchLength: query.length,
          context: pad,
        ),
      ),
    );
    from = offset + needle.length;
  }

  return FindInNoteScan(matches: matches, truncated: truncated);
}

/// 1-based line number of the character at [offset] (newline-separated).
int lineNumberAt(String text, int offset) {
  var line = 1;
  final end = offset < text.length ? offset : text.length;
  for (var i = 0; i < end; i++) {
    if (text.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

/// Slice of [text] around a match, padded by [context] chars, with `...`
/// when the window does not reach a string edge.
String excerptAround(
  String text, {
  required int offset,
  required int matchLength,
  required int context,
}) {
  final start = offset - context < 0 ? 0 : offset - context;
  var end = offset + matchLength + context;
  if (end > text.length) end = text.length;
  final prefix = start > 0 ? '...' : '';
  final suffix = end < text.length ? '...' : '';
  return '$prefix${text.substring(start, end)}$suffix';
}
