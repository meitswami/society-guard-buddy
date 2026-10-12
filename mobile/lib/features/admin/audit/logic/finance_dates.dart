import 'js_compat.dart';

/// Port of `src/lib/financeDates.ts`.

/// Date the row was entered in the system (always "today" when saving).
String todayRecordingDate([DateTime? now]) => ymdOfDate(now ?? DateTime.now());

/// Billing / transaction date on a payment row (`due_date`, first 10 chars).
String paymentBillingDate(String? dueDate) => slice10(dueDate ?? '');

DateTime? _strictYmd(String s) {
  final m = RegExp(r'^(\d{1,4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!),
      mo = int.parse(m.group(2)!),
      d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// Calendar month `yyyy-MM` from a billing date `yyyy-MM-dd` (today's month when invalid).
String billingMonthFromDate(String billingYmd, [DateTime? now]) {
  final d = _strictYmd(slice10(billingYmd));
  return ymOfDate(d ?? (now ?? DateTime.now()));
}

/// Ledger entry month must contain the billing date.
bool isBillingDateInEntryMonth(String billingYmd, String entryMonthYm) {
  if (billingYmd.isEmpty || entryMonthYm.isEmpty) return false;
  return billingMonthFromDate(billingYmd) == jsSlice(entryMonthYm, 0, 7);
}

/// `transaction_date` → `${entry_month}-01` → `created_at` (first 10 chars).
String ledgerTransactionDate(
    {String? transactionDate, String? entryMonth, String? createdAt}) {
  if (transactionDate != null && transactionDate.isNotEmpty)
    return slice10(transactionDate);
  if (entryMonth != null && entryMonth.isNotEmpty) return '$entryMonth-01';
  return slice10(createdAt ?? '');
}

String ledgerEntryMonthFromBilling(String billingYmd) =>
    billingMonthFromDate(billingYmd);

/// `iso` falls inside `[fromYmd 00:00, toYmd 23:59:59.999]` (local time).
bool dateInInclusiveRange(String iso, String fromYmd, String toYmd) {
  final t = jsTimeMs(iso);
  if (t == null) return false;
  final from = parseJsDate(fromYmd), to = parseJsDate(toYmd);
  if (from == null || to == null) return false;
  final fromMs =
      DateTime(from.year, from.month, from.day).millisecondsSinceEpoch;
  final toMs = DateTime(to.year, to.month, to.day, 23, 59, 59, 999)
      .millisecondsSinceEpoch;
  return t >= fromMs && t <= toMs;
}

bool isDateBefore(String iso, String beforeYmd) {
  final t = jsTimeMs(iso);
  if (t == null) return false;
  final b = parseJsDate(beforeYmd);
  if (b == null) return false;
  return t < DateTime(b.year, b.month, b.day).millisecondsSinceEpoch;
}

String addDaysYmd(String ymd, int days) {
  final d = _strictYmd(slice10(ymd));
  if (d == null) return slice10(ymd);
  return ymdOfDate(DateTime(d.year, d.month, d.day + days));
}
