import 'package:intl/intl.dart';

/// Small helpers that reproduce JavaScript semantics the web report code relies on
/// (`new Date(iso)`, `Number(x)`, `String(n)`, `toLocaleString('en-IN')`,
/// `localeCompare(…, { numeric: true })`). Keeping them in one place lets the
/// report maths below stay a line-by-line port of the TypeScript.

final RegExp _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _yearMonth = RegExp(r'^(\d{4})-(\d{2})$');
final RegExp _yearOnly = RegExp(r'^(\d{4})$');

/// `new Date(iso).getTime()` — `null` when JS would produce `NaN`.
///
/// JS parses ISO date-only strings (`yyyy-MM-dd`, `yyyy-MM`, `yyyy`) as **UTC**
/// midnight, date-times without an offset as **local** time, and honours `Z` /
/// `±hh:mm` offsets. Dart's `DateTime.parse` treats date-only strings as local,
/// so they are handled explicitly here.
int? jsDateMs(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is num) return value.isFinite ? value.toInt() : null;
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  var m = _dateOnly.firstMatch(s);
  if (m != null) {
    final y = int.parse(m.group(1)!),
        mo = int.parse(m.group(2)!),
        d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, mo, d).millisecondsSinceEpoch;
  }
  m = _yearMonth.firstMatch(s);
  if (m != null) {
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
    if (mo < 1 || mo > 12) return null;
    return DateTime.utc(y, mo).millisecondsSinceEpoch;
  }
  m = _yearOnly.firstMatch(s);
  if (m != null) {
    return DateTime.utc(int.parse(m.group(1)!)).millisecondsSinceEpoch;
  }
  return DateTime.tryParse(s)?.millisecondsSinceEpoch;
}

/// `new Date(value)` as a local [DateTime] (null when invalid).
DateTime? jsDate(Object? value) {
  final ms = jsDateMs(value);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// Local midnight / end-of-day of a `yyyy-MM-dd` string, like
/// `new Date('${ymd}T00:00:00')` (null when the date is malformed).
int? localDayStartMs(String ymd) {
  final m = _dateOnly.firstMatch(ymd.length >= 10 ? ymd.substring(0, 10) : ymd);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!))
      .millisecondsSinceEpoch;
}

/// `new Date('${ymd}T23:59:59.999').getTime()`.
int? localDayEndMs(String ymd) {
  final m = _dateOnly.firstMatch(ymd.length >= 10 ? ymd.substring(0, 10) : ymd);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
          int.parse(m.group(3)!), 23, 59, 59, 999)
      .millisecondsSinceEpoch;
}

/// JS `Number(value)` — `double.nan` when not numeric. `null`, `''`, `false` → 0.
double jsNumber(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1 : 0;
  final s = value.toString().trim();
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? double.nan;
}

/// `Number(value || 0)` — the amount idiom used throughout the web finance code.
double jsAmount(Object? value) {
  final n = jsNumber(value);
  return n.isNaN ? 0 : n;
}

/// JS truthiness for values that came from JSON.
bool jsTruthy(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true;
}

/// JS `String(n)` for numbers: `1500` not `1500.0`.
String jsNumberString(num n) {
  if (n is int) return n.toString();
  if (n.isNaN) return 'NaN';
  if (n.isInfinite) return n > 0 ? 'Infinity' : '-Infinity';
  if (n == n.truncateToDouble() && n.abs() < 1e21) return n.toInt().toString();
  return n.toString();
}

/// JS `String(value)` for JSON values (`null` → `'null'` is avoided: returns '').
String jsString(Object? v) {
  if (v == null) return '';
  if (v is num) return jsNumberString(v);
  return v.toString();
}

final Map<int, NumberFormat> _localeFormats = {};

/// `n.toLocaleString('en-IN', { maximumFractionDigits })` — Indian digit grouping,
/// up to [maxFractionDigits] decimals (JS default is 3), trailing zeros trimmed.
String toLocaleIn(num n, {int maxFractionDigits = 3}) {
  final f = _localeFormats.putIfAbsent(maxFractionDigits, () {
    final fmt = NumberFormat.decimalPattern('en_IN');
    fmt.maximumFractionDigits = maxFractionDigits;
    fmt.minimumFractionDigits = 0;
    return fmt;
  });
  if (n is double && (n.isNaN || n.isInfinite)) return jsNumberString(n);
  // Avoid "-0".
  if (n == 0) return '0';
  return f.format(n);
}

// ─── localeCompare ──────────────────────────────────────────────────────────

int _charClass(int c) {
  // ICU root collation order: whitespace < punctuation/symbols < digits < letters.
  if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0) return 0;
  if (c >= 0x30 && c <= 0x39) return 2;
  final ch = String.fromCharCode(c);
  if (ch.toLowerCase() != ch.toUpperCase()) return 3; // cased letters
  if (c >= 0x0900) {
    return 3; // Devanagari & other scripts sort after Latin symbols
  }
  return 1;
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// Approximation of `a.localeCompare(b, undefined, { numeric })` (ICU root
/// collation): case-insensitive primary comparison with digit runs compared by
/// value when [numeric] is true; lower-case sorts before upper-case on ties.
/// When [baseOnly] is true (`sensitivity: 'base'`) case differences compare equal.
int jsLocaleCompare(String a, String b,
    {bool numeric = false, bool baseOnly = false}) {
  final ac = a.codeUnits, bc = b.codeUnits;
  var i = 0, j = 0;
  while (i < ac.length && j < bc.length) {
    final ca = ac[i], cb = bc[j];
    if (numeric && _isDigit(ca) && _isDigit(cb)) {
      var ie = i, je = j;
      while (ie < ac.length && _isDigit(ac[ie])) {
        ie++;
      }
      while (je < bc.length && _isDigit(bc[je])) {
        je++;
      }
      final da = String.fromCharCodes(ac.sublist(i, ie))
          .replaceFirst(RegExp(r'^0+(?=\d)'), '');
      final db = String.fromCharCodes(bc.sublist(j, je))
          .replaceFirst(RegExp(r'^0+(?=\d)'), '');
      if (da.length != db.length) return da.length < db.length ? -1 : 1;
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp < 0 ? -1 : 1;
      i = ie;
      j = je;
      continue;
    }
    final ka = _charClass(ca), kb = _charClass(cb);
    if (ka != kb) return ka < kb ? -1 : 1;
    final la = String.fromCharCode(ca).toLowerCase(),
        lb = String.fromCharCode(cb).toLowerCase();
    final cmp = la.compareTo(lb);
    if (cmp != 0) return cmp < 0 ? -1 : 1;
    i++;
    j++;
  }
  final remA = ac.length - i, remB = bc.length - j;
  if (remA != remB) return remA < remB ? -1 : 1;
  if (baseOnly) return 0;
  // Tertiary: lower-case before upper-case at the first case difference.
  for (var k = 0; k < ac.length && k < bc.length; k++) {
    if (ac[k] == bc[k]) continue;
    final sa = String.fromCharCode(ac[k]), sb = String.fromCharCode(bc[k]);
    if (sa.toLowerCase() == sb.toLowerCase()) {
      final aLower = sa == sa.toLowerCase();
      final bLower = sb == sb.toLowerCase();
      if (aLower != bLower) return aLower ? -1 : 1;
    }
  }
  return a == b ? 0 : (a.compareTo(b) < 0 ? -1 : 1);
}

/// Pads a number to two digits.
String pad2(int n) => n.toString().padLeft(2, '0');

/// `format(date, 'yyyy-MM-dd')` in local time.
String ymdOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${pad2(d.month)}-${pad2(d.day)}';

/// `format(date, 'yyyy-MM')` in local time.
String ymOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${pad2(d.month)}';
