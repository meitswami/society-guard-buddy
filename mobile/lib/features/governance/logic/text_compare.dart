/// Ordering helpers that approximate JS `String.prototype.localeCompare`.
library;

/// `a.localeCompare(b)` approximation: case-insensitive first, lowercase before
/// uppercase on ties (ICU tertiary order).
int localeCompare(String a, String b) {
  final la = a.toLowerCase();
  final lb = b.toLowerCase();
  final c = la.compareTo(lb);
  if (c != 0) return c;
  // Same letters — lowercase sorts first in ICU root collation.
  return b.compareTo(a);
}

final RegExp _chunk = RegExp(r'(\d+|\D+)');

/// `a.localeCompare(b, undefined, { numeric: true })` approximation
/// (`A-2` < `A-10`), used for flat numbers.
int naturalCompare(String a, String b) {
  final ca = _chunk.allMatches(a).map((m) => m.group(0)!).toList();
  final cb = _chunk.allMatches(b).map((m) => m.group(0)!).toList();
  final n = ca.length < cb.length ? ca.length : cb.length;
  for (var i = 0; i < n; i++) {
    final x = ca[i];
    final y = cb[i];
    final xd = int.tryParse(x);
    final yd = int.tryParse(y);
    if (xd != null && yd != null) {
      if (xd != yd) return xd.compareTo(yd);
      continue;
    }
    final c = localeCompare(x, y);
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}
