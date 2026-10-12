// Port of `src/lib/financeDates.ts` + the date helpers of `src/lib/dateFormat.ts`
// that finance needs (pure Dart, no Flutter).

String _two(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd` for a local date.
String ymdOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// `yyyy-MM` for a local date.
String ymOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}';

/// Strict `yyyy-MM-dd` parse (date-fns `parse` + `isValid`): null when invalid.
DateTime? parseYmd(String? raw) {
  if (raw == null) return null;
  final s = raw.length >= 10 ? raw.substring(0, 10) : raw;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// JS `new Date(iso)` → local DateTime (null when invalid).
DateTime? parseIsoLoose(String? iso) {
  if (iso == null) return null;
  final s = iso.trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// Date the row was entered in the system (always "today" when saving). Not used in period reports.
String todayRecordingDate([DateTime? now]) => ymdOf(now ?? DateTime.now());

/// Billing / transaction date on a payment row (`due_date` → `yyyy-MM-dd`).
String paymentBillingDate(String? dueDate) {
  final s = dueDate ?? '';
  return s.length > 10 ? s.substring(0, 10) : s;
}

/// Calendar month `yyyy-MM` from a billing date `yyyy-MM-dd` (current month when invalid).
String billingMonthFromDate(String billingYmd, [DateTime? now]) {
  final d = parseYmd(billingYmd);
  return d != null ? ymOf(d) : ymOf(now ?? DateTime.now());
}

/// Ledger entry month must contain the billing date.
bool isBillingDateInEntryMonth(String billingYmd, String entryMonthYm) {
  if (billingYmd.isEmpty || entryMonthYm.isEmpty) return false;
  final ym = entryMonthYm.length > 7 ? entryMonthYm.substring(0, 7) : entryMonthYm;
  return billingMonthFromDate(billingYmd) == ym;
}

/// `transaction_date` → `${entry_month}-01` → `created_at` date.
String ledgerTransactionDateOf({String? transactionDate, String? entryMonth, String? createdAt}) {
  if (transactionDate != null && transactionDate.isNotEmpty) {
    return transactionDate.length > 10 ? transactionDate.substring(0, 10) : transactionDate;
  }
  if (entryMonth != null && entryMonth.isNotEmpty) return '$entryMonth-01';
  final c = createdAt ?? '';
  return c.length > 10 ? c.substring(0, 10) : c;
}

String ledgerEntryMonthFromBilling(String billingYmd) => billingMonthFromDate(billingYmd);

/// Web `dateInInclusiveRange` (local day bounds).
bool dateInInclusiveRange(String iso, String fromYmd, String toYmd) {
  final t = parseIsoLoose(iso);
  final from = parseYmd(fromYmd);
  final to = parseYmd(toYmd);
  if (t == null || from == null || to == null) return false;
  final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
  return !t.isBefore(from) && !t.isAfter(toEnd);
}

/// Web `isDateBefore` (strictly before local midnight of [beforeYmd]).
bool isDateBefore(String iso, String beforeYmd) {
  final t = parseIsoLoose(iso);
  final b = parseYmd(beforeYmd);
  if (t == null || b == null) return false;
  return t.isBefore(b);
}

/// Web `addDaysYmd`.
String addDaysYmd(String ymd, int days) {
  final d = parseYmd(ymd);
  if (d == null) return ymd.length > 10 ? ymd.substring(0, 10) : ymd;
  return ymdOf(DateTime(d.year, d.month, d.day + days));
}

/// Web `fmtIsoMonthToDisplay`: `yyyy-MM` → `MM/yyyy`.
String isoMonthToDisplay(String? ym) {
  if (ym == null || ym.isEmpty) return '';
  final s = ym.length > 7 ? ym.substring(0, 7) : ym;
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(s);
  if (m == null) return ym;
  final mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return ym;
  return '${m.group(2)}/${m.group(1)}';
}

/// Web `fmtIsoDateToDisplay`: `yyyy-MM-dd` → `dd/MM/yyyy` (input returned when not a date).
String isoDateToDisplay(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final s = iso.length > 10 ? iso.substring(0, 10) : iso;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return iso;
  final d = parseYmd(s);
  if (d == null) return iso;
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// Web `parseDisplayDateToIso`: `dd/MM/yyyy` or `yyyy-MM-dd` → `yyyy-MM-dd`.
String? parseDisplayDateToIso(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s.substring(0, 10))) {
    return parseYmd(s.substring(0, 10)) == null ? null : s.substring(0, 10);
  }
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m == null) return null;
  final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return ymdOf(dt);
}

/// Web `fmtDate` (local `dd/MM/yyyy` from any ISO / date string).
String fmtDateLocal(String? value) {
  final d = parseIsoLoose(value);
  if (d == null) return '';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// Web `fmtDateTimeFull` (`dd/MM/yyyy HH:mm:ss`).
String fmtDateTimeFullLocal(String? value) {
  final d = parseIsoLoose(value);
  if (d == null) return '';
  return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
}

/// Web `fmtTime` (`hh:mm a`).
String fmtTimeLocal(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h12)}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// English month name (date-fns `MMMM`).
String englishMonthName(int month) => _monthNames[(month - 1).clamp(0, 11)];

/// Days in a month.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
