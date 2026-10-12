import 'package:intl/intl.dart';

import 'js_compat.dart';

/// Formatting helpers matching `src/lib/dateFormat.ts`, `reportExportUtils.moneyInr`
/// and the `₹${n.toLocaleString('en-IN')}` idiom used on the report pages.

final DateFormat _date = DateFormat('dd/MM/yyyy');
final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final DateFormat _dateTimeFull = DateFormat('dd/MM/yyyy HH:mm:ss');
final DateFormat _time = DateFormat('hh:mm a');

/// `fmtDate` — `dd/MM/yyyy` of `new Date(value)` in local time ('' when invalid).
String fmtDate(Object? value) {
  final d = jsDate(value);
  return d == null ? '' : _date.format(d);
}

/// `fmtDateTime` — `dd/MM/yyyy HH:mm`.
String fmtDateTime(Object? value) {
  final d = jsDate(value);
  return d == null ? '' : _dateTime.format(d);
}

/// `fmtDateTimeFull` — `dd/MM/yyyy HH:mm:ss`.
String fmtDateTimeFull(Object? value) {
  final d = jsDate(value);
  return d == null ? '' : _dateTimeFull.format(d);
}

/// `fmtTime` / `format(d, 'hh:mm a')`.
String fmtTime(Object? value) {
  final d = jsDate(value);
  return d == null ? '' : _time.format(d);
}

/// `yyyy-MM-dd` → `dd/MM/yyyy` (input returned when it is not a date).
String fmtIsoDateToDisplay(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final s = iso.length > 10 ? iso.substring(0, 10) : iso;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return iso;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.month != mo || dt.day != d) return iso;
  return _date.format(dt);
}

/// `yyyy-MM` → `MM/yyyy` (web `fmtIsoMonthToDisplay`).
String fmtIsoMonthToDisplay(String? ym) {
  if (ym == null || ym.isEmpty) return '';
  final s = ym.length > 7 ? ym.substring(0, 7) : ym;
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(s);
  if (m == null) return ym;
  final mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return ym;
  return '${m.group(2)}/${m.group(1)}';
}

/// `moneyInr(n)` — `₹1,23,456.5` (max 2 decimals).
String moneyInr(num n) => '₹${toLocaleIn(n, maxFractionDigits: 2)}';

/// `₹${n.toLocaleString('en-IN')}` (max 3 decimals, JS default).
String rupees(num n) => '₹${toLocaleIn(n)}';

/// `−₹1,234` for negatives (web `fmtSigned`).
String fmtSignedRupees(num n) => '${n < 0 ? '−' : ''}₹${toLocaleIn(n.abs())}';

/// Cash-flow cell: `—` for zero, `−₹…` for negatives.
String fmtCashFlowAmount(num n) {
  if (n == 0) return '—';
  return fmtSignedRupees(n);
}

/// Human-readable ledger enum (`record_mode`, `destination`, …) — safe when null.
String formatLedgerFieldLabel(String? value, {String fallback = '—'}) {
  if (value == null || value.isEmpty) return fallback;
  return value.replaceAll('_', ' ');
}

/// `capitalize` (CSS `text-transform: capitalize` on single words / phrases).
String capitalizeWords(String s) =>
    s.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
