// Number formatting + natural sort used by finance (pure Dart).

import 'package:intl/intl.dart';

final NumberFormat _locale3 = NumberFormat('#,##,##0.###', 'en_IN');
final NumberFormat _locale2 = NumberFormat('#,##,##0.##', 'en_IN');

String _fmt(NumberFormat f, num n) {
  if (n.isNaN) return 'NaN';
  final s = f.format(n);
  // `-0` from rounding tiny negatives.
  return s == '-0' ? '0' : s;
}

/// JS `n.toLocaleString('en-IN')` (max 3 fraction digits, Indian grouping).
String localeNumber(num n) => _fmt(_locale3, n);

/// Web `` `₹${n.toLocaleString('en-IN')}` ``.
String inrLocale(num n) => '₹${localeNumber(n)}';

/// Web `moneyInr` / `money()` (max 2 fraction digits).
String moneyInr(num n) => '₹${_fmt(_locale2, n)}';

/// Web `fmtSigned`: `−₹1,234` for negatives.
String inrSigned(num n) => '${n < 0 ? '−' : ''}₹${localeNumber(n.abs())}';

/// Web template `₹{amount}` without grouping (raw JS number toString).
String inrRaw(num n) {
  if (n == n.roundToDouble()) return '₹${n.round()}';
  return '₹$n';
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');

int _classOf(int c) {
  // ICU-like primary ordering: whitespace / punctuation < symbols < digits < letters.
  if (_isDigit(c)) return 2;
  final lower = c | 0x20;
  if ((lower >= 0x61 && lower <= 0x7A) || c >= 0xC0) return 3;
  if (c <= 0x2F || (c >= 0x3A && c <= 0x40) || (c >= 0x5B && c <= 0x60) || (c >= 0x7B && c <= 0x7E)) return 0;
  return 1;
}

int _lowerUnit(int c) => (c >= 0x41 && c <= 0x5A) ? c + 0x20 : c;

/// JS `a.localeCompare(b, undefined, { numeric: true })` approximation:
/// digit runs compare numerically, letters case-insensitively, punctuation before digits.
int compareNatural(String a, String b) {
  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    final ca = a.codeUnitAt(i), cb = b.codeUnitAt(j);
    if (_isDigit(ca) && _isDigit(cb)) {
      var ei = i, ej = j;
      while (ei < a.length && _isDigit(a.codeUnitAt(ei))) {
        ei++;
      }
      while (ej < b.length && _isDigit(b.codeUnitAt(ej))) {
        ej++;
      }
      // Compare digit runs numerically without overflow: strip leading zeros, then length, then lexically.
      final sa = a.substring(i, ei).replaceFirst(_leadingZeros, '');
      final sb = b.substring(j, ej).replaceFirst(_leadingZeros, '');
      if (sa.length != sb.length) return sa.length.compareTo(sb.length);
      final c = sa.compareTo(sb);
      if (c != 0) return c;
      i = ei;
      j = ej;
      continue;
    }
    final ka = _classOf(ca), kb = _classOf(cb);
    if (ka != kb) return ka.compareTo(kb);
    final c = _lowerUnit(ca).compareTo(_lowerUnit(cb));
    if (c != 0) return c;
    i++;
    j++;
  }
  final rest = (a.length - i).compareTo(b.length - j);
  if (rest != 0) return rest;
  // Tertiary tie-break like ICU: lowercase sorts before uppercase.
  return -a.compareTo(b);
}

/// JS `a.localeCompare(b)` approximation for labels.
int compareText(String a, String b) => compareNatural(a, b);
