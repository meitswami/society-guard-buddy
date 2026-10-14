import 'package:intl/intl.dart';

/// Ports of `src/lib/financeDates.ts`, `entryMonthFromExpenseDate` and the date display helpers
/// from `src/lib/dateFormat.ts` used by the events / splitter screens.

final DateFormat _ymd = DateFormat('yyyy-MM-dd');
final DateFormat _ym = DateFormat('yyyy-MM');

/// Strict `yyyy-MM-dd` parse (date-fns `parse(…, 'yyyy-MM-dd')` + `isValid`).
DateTime? parseYmd(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

String _slice(String s, int n) => s.length > n ? s.substring(0, n) : s;

/// Date the row was entered in the system (always "today" when saving).
String todayRecordingDate([DateTime? now]) => _ymd.format(now ?? DateTime.now());

/// Calendar month `yyyy-MM` from a billing date `yyyy-MM-dd` (current month when invalid).
String billingMonthFromDate(String billingYmd, [DateTime? now]) {
  final d = parseYmd(_slice(billingYmd, 10));
  return d != null ? _ym.format(d) : _ym.format(now ?? DateTime.now());
}

/// Ledger entry month must contain the billing date.
bool isBillingDateInEntryMonth(String billingYmd, String entryMonthYm) {
  if (billingYmd.isEmpty || entryMonthYm.isEmpty) return false;
  return billingMonthFromDate(billingYmd) == _slice(entryMonthYm, 7);
}

/// `groupExpenseFinanceLedger.entryMonthFromExpenseDate`.
String entryMonthFromExpenseDate(String expenseDate, [DateTime? now]) {
  final d = parseYmd(expenseDate);
  return d != null ? _ym.format(d) : _ym.format(now ?? DateTime.now());
}

/// `fmtIsoDateToDisplay` — `yyyy-MM-dd…` → `dd/MM/yyyy` (input returned unchanged when not ISO).
String fmtIsoDateToDisplay(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final s = _slice(iso, 10);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return iso;
  final d = parseYmd(s);
  return d == null ? iso : DateFormat('dd/MM/yyyy').format(d);
}

/// `fmtIsoMonthToDisplay` — `yyyy-MM` → `MM/yyyy`.
String fmtIsoMonthToDisplay(String? ym) {
  if (ym == null || ym.isEmpty) return '';
  final s = _slice(ym, 7);
  if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(s)) return ym;
  final d = parseYmd('$s-01');
  return d == null ? ym : DateFormat('MM/yyyy').format(d);
}

/// `fmtDate` for timestamps (`verified_at`) → local `dd/MM/yyyy`.
String fmtTimestampDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final d = DateTime.tryParse(value);
  if (d == null) return '';
  return DateFormat('dd/MM/yyyy').format(d.toLocal());
}
