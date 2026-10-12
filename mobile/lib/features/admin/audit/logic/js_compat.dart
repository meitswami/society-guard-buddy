import 'dart:convert';

import 'package:intl/intl.dart';

/// Small helpers that reproduce the JavaScript / date-fns semantics the web
/// audit code relies on (`slice`, `new Date(...)`, `toLocaleString('en-IN')`,
/// `localeCompare`, stable `Array.prototype.sort`, `String(v)`, `JSON.stringify`).
/// Pure Dart — safe to use from unit tests.

/// JS `String.prototype.slice(start, end)` for non-negative indices.
String jsSlice(String? s, int start, [int? end]) {
  if (s == null) return '';
  final len = s.length;
  final st = start.clamp(0, len);
  final en = (end ?? len).clamp(0, len);
  return en <= st ? '' : s.substring(st, en);
}

/// First 10 characters (`yyyy-MM-dd` part of a timestamp).
String slice10(String? s) => jsSlice(s, 0, 10);

final RegExp _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `new Date(s)` for database strings.
///
/// A bare `yyyy-MM-dd` is treated as that calendar day (what the web app sees in
/// India, where UTC midnight is still the same date); timestamps are converted
/// to local time like the browser does. Returns `null` for invalid input.
DateTime? parseJsDate(String? s) {
  if (s == null) return null;
  final v = s.trim();
  if (v.isEmpty) return null;
  final m = _dateOnly.firstMatch(v);
  if (m != null) {
    final y = int.parse(m.group(1)!),
        mo = int.parse(m.group(2)!),
        d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }
  return DateTime.tryParse(v)?.toLocal();
}

final DateFormat _ymFmt = DateFormat('yyyy-MM');
final DateFormat _ymdFmt = DateFormat('yyyy-MM-dd');

/// date-fns `format(new Date(s), 'yyyy-MM')`; `null` when the date is invalid.
String? ymOf(String? s) {
  final d = parseJsDate(s);
  return d == null ? null : _ymFmt.format(d);
}

/// `yyyy-MM` of a [DateTime].
String ymOfDate(DateTime d) => _ymFmt.format(d);

/// `yyyy-MM-dd` of a [DateTime].
String ymdOfDate(DateTime d) => _ymdFmt.format(d);

/// Milliseconds since epoch for [s] (JS `new Date(s).getTime()`), `null` when invalid.
int? jsTimeMs(String? s) => parseJsDate(s)?.millisecondsSinceEpoch;

/// Local-time bounds used by the web period checks:
/// `new Date('${month}-01T00:00:00')` … `new Date('${month}-${lastDay}T23:59:59.999')`.
({int fromMs, int toMs})? monthBoundsMs(String month) {
  final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(month);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return null;
  final lastDay = DateTime(y, mo + 1, 0).day;
  final from = DateTime(y, mo, 1);
  final to = DateTime(y, mo, lastDay, 23, 59, 59, 999);
  return (fromMs: from.millisecondsSinceEpoch, toMs: to.millisecondsSinceEpoch);
}

final NumberFormat _enIn = NumberFormat.decimalPattern('en_IN');

/// JS `n.toLocaleString('en-IN')` (Indian grouping, up to 3 decimals).
String jsLocale(num n) => _enIn.format(n);

/// `₹${n.toLocaleString('en-IN')}`
String jsInr(num n) => '₹${jsLocale(n)}';

/// JS `String(n)` for numbers (integral doubles print without `.0`).
String jsNumStr(num n) {
  if (n is int) return n.toString();
  final d = n.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? 'Infinity' : '-Infinity';
  if (d == d.truncateToDouble() && d.abs() < 1e21) return d.toInt().toString();
  return d.toString();
}

/// JS `String(v)` (maps are shown as JSON instead of `[object Object]`).
String jsString(Object? v) {
  if (v == null) return 'null';
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return jsNumStr(v);
  if (v is String) return v;
  if (v is List) return v.map((e) => e == null ? '' : jsString(e)).join(',');
  if (v is Map) return jsJson(v);
  return v.toString();
}

Object? _jsonSafe(Object? v) {
  if (v is double) {
    if (v.isNaN || v.isInfinite) return null;
    if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt();
    return v;
  }
  if (v is Map)
    return {for (final e in v.entries) e.key.toString(): _jsonSafe(e.value)};
  if (v is Iterable) return [for (final e in v) _jsonSafe(e)];
  if (v == null || v is num || v is String || v is bool) return v;
  return v.toString();
}

/// `JSON.stringify(v)` / `JSON.stringify(v, null, indent)` with JS number formatting.
String jsJson(Object? v, {String? indent}) {
  final safe = _jsonSafe(v);
  return indent == null
      ? jsonEncode(safe)
      : JsonEncoder.withIndent(indent).convert(safe);
}

/// `typeof v === 'object' ? JSON.stringify(v) : String(v)` — raw-data rows on the web.
String jsRawValue(Object? v, {String? indent}) {
  if (v == null || v is Map || v is Iterable) return jsJson(v, indent: indent);
  return jsString(v);
}

int _charGroup(int c) {
  if (c >= 48 && c <= 57) return 1; // digits
  if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) return 2; // latin letters
  if (c < 128) return 0; // whitespace / punctuation / symbols
  return 3; // everything else (Devanagari …)
}

int _primary(int c) => (c >= 65 && c <= 90) ? c + 32 : c;

/// Approximation of `a.localeCompare(b)` (ICU root collation): punctuation <
/// digits < letters (case-insensitive), then lower-case before upper-case.
int jsLocaleCompare(String a, String b) {
  final ca = a.codeUnits, cb = b.codeUnits;
  final n = ca.length < cb.length ? ca.length : cb.length;
  for (var i = 0; i < n; i++) {
    final x = ca[i], y = cb[i];
    final gx = _charGroup(x), gy = _charGroup(y);
    if (gx != gy) return gx < gy ? -1 : 1;
    final px = _primary(x), py = _primary(y);
    if (px != py) return px < py ? -1 : 1;
  }
  if (ca.length != cb.length) return ca.length < cb.length ? -1 : 1;
  for (var i = 0; i < n; i++) {
    final x = ca[i], y = cb[i];
    if (x == y) continue;
    final xl = x >= 97 && x <= 122, yl = y >= 97 && y <= 122;
    if (xl != yl) return xl ? -1 : 1;
    return x < y ? -1 : 1;
  }
  return 0;
}

/// Stable sort (JS `Array.prototype.sort` is stable; Dart's `List.sort` is not).
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.toList().asMap().entries.toList();
  indexed.sort((x, y) {
    final c = compare(x.value, y.value);
    return c != 0 ? c : x.key.compareTo(y.key);
  });
  return [for (final e in indexed) e.value];
}

int _sign(num n) => n > 0 ? 1 : (n < 0 ? -1 : 0);

/// Comparator helper for `(a, b) => b.x - a.x` style numeric sorts.
int numDesc(num a, num b) => _sign(b - a);

/// `yyyy-MM` → `MM/yyyy` (web `fmtIsoMonthToDisplay`).
String fmtIsoMonthToDisplay(String? ym) {
  if (ym == null || ym.isEmpty) return '';
  final s = jsSlice(ym, 0, 7);
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(s);
  if (m == null) return ym;
  final mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return ym;
  return '${m.group(2)}/${m.group(1)}';
}

/// `yyyy-MM-dd` (or a timestamp) → `dd/MM/yyyy` (web `fmtIsoDateToDisplay`).
String fmtIsoDateToDisplay(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final s = slice10(iso);
  final m = _dateOnly.firstMatch(s);
  if (m == null) return iso;
  final y = int.parse(m.group(1)!),
      mo = int.parse(m.group(2)!),
      d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return iso;
  return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

/// Safe numeric read (numeric columns may arrive as int, double or String).
double jsNumber(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  final s = v.toString().trim();
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? 0;
}

/// Nullable string read (empty strings stay empty, null stays null).
String? jsStrOrNull(Object? v) => v?.toString();
