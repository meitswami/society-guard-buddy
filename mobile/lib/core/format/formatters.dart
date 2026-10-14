import 'package:intl/intl.dart';

/// Date / money formatting identical to the web app (`src/lib/dateFormat.ts`).
abstract final class Fmt {
  static final _date = DateFormat('dd/MM/yyyy');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final _dateTimeFull = DateFormat('dd/MM/yyyy HH:mm:ss');
  static final _time = DateFormat('hh:mm a');
  static final _month = DateFormat('MMMM yyyy');
  static final _iso = DateFormat('yyyy-MM-dd');

  static DateTime? _parse(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  /// `dd/MM/yyyy`
  static String date(Object? value) {
    final d = _parse(value);
    return d == null ? '' : _date.format(d);
  }

  /// `dd/MM/yyyy HH:mm`
  static String dateTime(Object? value) {
    final d = _parse(value);
    return d == null ? '' : _dateTime.format(d);
  }

  /// `dd/MM/yyyy HH:mm:ss`
  static String dateTimeFull(Object? value) {
    final d = _parse(value);
    return d == null ? '' : _dateTimeFull.format(d);
  }

  /// `hh:mm a`
  static String time(Object? value) {
    final d = _parse(value);
    return d == null ? '' : _time.format(d);
  }

  /// `MMMM yyyy`
  static String month(Object? value) {
    final d = _parse(value);
    return d == null ? '' : _month.format(d);
  }

  /// `yyyy-MM-dd` (DB date columns).
  static String isoDate(DateTime d) => _iso.format(d);

  /// Today as `yyyy-MM-dd` in local time.
  static String todayIso() => _iso.format(DateTime.now());

  /// `yyyy-MM-dd` → `dd/MM/yyyy`.
  static String isoToDisplay(String? iso) {
    if (iso == null || iso.length < 10) return iso ?? '';
    final d = DateTime.tryParse(iso.substring(0, 10));
    return d == null ? iso : _date.format(d);
  }

  /// `dd/MM/yyyy` or `yyyy-MM-dd` → `yyyy-MM-dd` (null when invalid).
  static String? displayToIso(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (iso != null) return s;
    final m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return _iso.format(dt);
  }

  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _num = NumberFormat.decimalPattern('en_IN');

  /// `₹1,23,456` (rounded) — Indian digit grouping like the web `toLocaleString('en-IN')`.
  static String inr(num? amount) => _inr.format(amount ?? 0);

  /// `₹1,23,456.50`
  static String inr2(num? amount) => _inr2.format(amount ?? 0);

  /// `1,23,456`
  static String number(num? n) => _num.format(n ?? 0);
}

/// Safe numeric reads from Supabase JSON (numeric columns may arrive as String).
double asDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int asInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

String asString(Object? v) => v == null ? '' : v.toString();
