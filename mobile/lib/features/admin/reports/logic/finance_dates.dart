import 'js_compat.dart';

/// Port of `src/lib/financeDates.ts` (dates are `yyyy-MM-dd` strings like the web).

/// Date the row was entered in the system ("today").
String todayRecordingDate() => ymdOf(DateTime.now());

/// Billing / transaction date on a payment row (`due_date`, first 10 chars).
String paymentBillingDate(String? dueDate) {
  final s = (dueDate ?? '').toString();
  return s.length > 10 ? s.substring(0, 10) : s;
}

DateTime? _parseYmdLocal(String ymd) {
  final s = ymd.length >= 10 ? ymd.substring(0, 10) : ymd;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// Calendar month `yyyy-MM` from a billing date `yyyy-MM-dd` (current month when invalid).
String billingMonthFromDate(String billingYmd) {
  final d = _parseYmdLocal(billingYmd);
  return ymOf(d ?? DateTime.now());
}

/// Ledger entry month must contain the billing date.
bool isBillingDateInEntryMonth(String billingYmd, String entryMonthYm) {
  if (billingYmd.isEmpty || entryMonthYm.isEmpty) return false;
  final em = entryMonthYm.length > 7 ? entryMonthYm.substring(0, 7) : entryMonthYm;
  return billingMonthFromDate(billingYmd) == em;
}

/// `transaction_date` → `${entry_month}-01` → `created_at` (first 10 chars).
String ledgerTransactionDate({String? transactionDate, String? entryMonth, String? createdAt}) {
  if (transactionDate != null && transactionDate.isNotEmpty) {
    return transactionDate.length > 10 ? transactionDate.substring(0, 10) : transactionDate;
  }
  if (entryMonth != null && entryMonth.isNotEmpty) return '$entryMonth-01';
  final c = createdAt ?? '';
  return c.length > 10 ? c.substring(0, 10) : c;
}

String ledgerEntryMonthFromBilling(String billingYmd) => billingMonthFromDate(billingYmd);

/// `dateInInclusiveRange(iso, fromYmd, toYmd)` — `iso` parsed like JS `new Date(iso)`,
/// bounds are local start / end of day.
bool dateInInclusiveRange(String iso, String fromYmd, String toYmd) {
  final t = jsDateMs(iso);
  if (t == null) return false;
  final fromMs = localDayStartMs(fromYmd);
  final toMs = localDayEndMs(toYmd);
  if (fromMs == null || toMs == null) return false;
  return t >= fromMs && t <= toMs;
}

/// `isDateBefore(iso, beforeYmd)` — strictly before local midnight of `beforeYmd`.
bool isDateBefore(String iso, String beforeYmd) {
  final t = jsDateMs(iso);
  if (t == null) return false;
  final before = localDayStartMs(beforeYmd);
  if (before == null) return false;
  return t < before;
}

/// `addDaysYmd('2026-02-28', 1)` → `'2026-03-01'` (input returned unchanged when invalid).
String addDaysYmd(String ymd, int days) {
  final d = _parseYmdLocal(ymd);
  if (d == null) return ymd.length > 10 ? ymd.substring(0, 10) : ymd;
  return ymdOf(DateTime(d.year, d.month, d.day + days));
}
