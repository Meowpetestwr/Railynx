// Helpers that reproduce Python str behaviour the engine relies on.
// Dart's String.trim() and LineSplitter differ from Python's strip() and
// splitlines(); these match Python's definitions.

final RegExp _pyStripRe = RegExp(
  '^[\\t\\n\\x0b\\x0c\\r\\x1c-\\x1f \\x85\\xa0\\u1680\\u2000-\\u200a'
  '\\u2028\\u2029\\u202f\\u205f\\u3000]+'
  '|[\\t\\n\\x0b\\x0c\\r\\x1c-\\x1f \\x85\\xa0\\u1680\\u2000-\\u200a'
  '\\u2028\\u2029\\u202f\\u205f\\u3000]+\$',
  unicode: true,
);

final RegExp _pyLineBreakRe = RegExp(
  '\\r\\n|[\\n\\r\\x0b\\x0c\\x1c\\x1d\\x1e\\x85\\u2028\\u2029]',
  unicode: true,
);

/// Python str.strip() with no arguments (Unicode whitespace, per isspace()).
String pyStrip(String s) => s.replaceAll(_pyStripRe, '');

/// Python str.splitlines() — the first element is what the engine needs.
List<String> pySplitLines(String s) {
  if (s.isEmpty) return <String>[];
  final parts = s.split(_pyLineBreakRe);
  // Python drops a single trailing empty element produced by a final break.
  if (parts.isNotEmpty && parts.last.isEmpty) {
    parts.removeLast();
  }
  return parts;
}
