import 'package:intl/intl.dart';

/// Small helpers that reproduce the JavaScript number semantics the web
/// components rely on (`Number(text)`, `x.toFixed(2)`, `toLocaleString('en-IN')`).

/// JS `Number(text)`: empty / whitespace → 0, invalid → NaN.
double jsNumber(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final s = value.toString().trim();
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? double.nan;
}

/// JS `Number(text) || fallback` (0 and NaN fall back).
double jsNumberOr(Object? value, double fallback) {
  final n = jsNumber(value);
  return (n == 0 || n.isNaN) ? fallback : n;
}

/// JS truthiness + `> 0` check used by the web validations (`!amount || amount <= 0`).
bool jsPositive(double v) => !v.isNaN && v > 0;

/// JS `Number(x.toFixed(2))`.
double round2(num x) => double.parse(x.toStringAsFixed(2));

/// JS `String(number)` for amounts: `319` not `319.0`, `5172.41` stays as is.
String jsNumStr(num? v) {
  if (v == null) return '0';
  final d = v.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d.isNegative ? '-Infinity' : 'Infinity';
  if (d == d.truncateToDouble() && d.abs() < 1e21) {
    final i = d.toInt();
    return i == 0 ? '0' : '$i';
  }
  return d.toString();
}

final NumberFormat _enIn = NumberFormat.decimalPattern('en_IN');

/// JS `n.toLocaleString('en-IN')` (Indian grouping, up to 3 decimals).
String jsLocaleIn(num? v) {
  final d = (v ?? 0).toDouble();
  if (d == 0) return '0';
  return _enIn.format(d);
}

/// `₹{n.toLocaleString('en-IN')}`.
String rupeeLoc(num? v) => '₹${jsLocaleIn(v)}';

/// `₹{n}` (raw JS number print).
String rupeeRaw(num? v) => '₹${jsNumStr(v)}';

/// Stable sort (JS `Array.prototype.sort` is stable; Dart's `List.sort` is not guaranteed).
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = items.toList().asMap().entries.toList();
  indexed.sort((a, b) {
    final c = compare(a.value, b.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return [for (final e in indexed) e.value];
}

/// Approximation of `a.localeCompare(b)` (case-insensitive first, then case).
int localeCompare(String a, String b) {
  final la = a.toLowerCase();
  final lb = b.toLowerCase();
  final c = la.compareTo(lb);
  if (c != 0) return c;
  // ICU puts lowercase before uppercase at the tertiary level.
  return b.compareTo(a);
}

/// Approximation of `a.localeCompare(b, undefined, { numeric: true })`.
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+|\D+)');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  final n = pa.length < pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = pa[i];
    final y = pb[i];
    final dx = _isDigits(x);
    final dy = _isDigits(y);
    if (dx && dy) {
      final bx = BigInt.parse(x);
      final by = BigInt.parse(y);
      final c = bx.compareTo(by);
      if (c != 0) return c;
      continue;
    }
    if (dx != dy) return dx ? -1 : 1; // digits sort before letters
    final c = x.toLowerCase().compareTo(y.toLowerCase());
    if (c != 0) return c;
  }
  if (pa.length != pb.length) return pa.length.compareTo(pb.length);
  return localeCompare(a, b);
}

bool _isDigits(String s) => s.isNotEmpty && RegExp(r'^\d+$').hasMatch(s);

/// JS `Object.entries(obj)` key order: integer-like keys ascending first, then insertion order.
List<MapEntry<String, V>> jsObjectEntries<V>(Map<String, V> map) {
  final ints = <MapEntry<String, V>>[];
  final rest = <MapEntry<String, V>>[];
  for (final e in map.entries) {
    if (_isArrayIndex(e.key)) {
      ints.add(e);
    } else {
      rest.add(e);
    }
  }
  ints.sort((a, b) => BigInt.parse(a.key).compareTo(BigInt.parse(b.key)));
  return [...ints, ...rest];
}

bool _isArrayIndex(String k) {
  if (k.isEmpty) return false;
  if (k == '0') return true;
  if (!RegExp(r'^[1-9]\d*$').hasMatch(k)) return false;
  return BigInt.parse(k) < BigInt.from(4294967295);
}
