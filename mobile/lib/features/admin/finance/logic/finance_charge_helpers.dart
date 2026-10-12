// Port of `src/lib/financeChargeHelpers.ts`.

import 'finance_dates.dart';
import 'finance_models.dart';

String normalizeTitle(Object? value) => (value ?? '').toString().trim().toLowerCase();

const List<String> kMonthNamesLower = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

/// Monthly charge whose title mentions maintenance ("maint").
bool isMonthlyMaintenanceTitleFreq(Object? title, Object? frequency) {
  final t = normalizeTitle(title);
  final f = normalizeTitle(frequency);
  return f == 'monthly' && t.contains('maint');
}

bool isMonthlyMaintenanceCharge(FinanceCharge c) => isMonthlyMaintenanceTitleFreq(c.title, c.frequency);

String _two(int n) => n.toString().padLeft(2, '0');

/// Title names the given month (`MMMM`, `MM/yyyy` or `MM-yyyy`).
bool isCurrentMonthChargeTitle(String title, [DateTime? date]) {
  final d = date ?? DateTime.now();
  final lower = normalizeTitle(title);
  final monthName = englishMonthName(d.month).toLowerCase();
  return lower.contains(monthName) ||
      lower.contains('${_two(d.month)}/${d.year}') ||
      lower.contains('${_two(d.month)}-${d.year}');
}

/// `"<Month> Monthly Maintenance"`.
String buildCurrentMonthChargeTitle([DateTime? date]) =>
    '${englishMonthName((date ?? DateTime.now()).month)} Monthly Maintenance';

/// Month name embedded in a charge title ("June Monthly Maintenance" → "june"), else null.
String? monthNameFromChargeTitle(String title) {
  final lower = normalizeTitle(title);
  for (final m in kMonthNamesLower) {
    if (lower.contains(m)) return m;
  }
  return null;
}

/// When a receipt type names a calendar month, the billing date must fall in that month.
bool chargeTitleMatchesBillingMonth(String title, String dueDateYmd) {
  final named = monthNameFromChargeTitle(title);
  if (named == null) return true;
  final d = parseYmd(dueDateYmd.length > 10 ? dueDateYmd.substring(0, 10) : dueDateYmd);
  if (d == null) return false;
  return englishMonthName(d.month).toLowerCase() == named;
}

/// `yyyy-MM` of the billing date (`''` when the payment has none).
String paymentMonthValue(String? dueDate) {
  final raw = paymentBillingDate(dueDate);
  if (raw.isEmpty) return '';
  return billingMonthFromDate(raw);
}

/// Charge (title + amount) the unpaid grid should show for the current filters.
({String title, double amount})? chargeForUnpaidFilters(
  List<FinanceCharge> charges,
  String paymentTypeFilter,
  String paymentMonthFilter,
) {
  if (paymentTypeFilter == 'all_payments' ||
      paymentTypeFilter == 'society_pool_pending' ||
      paymentTypeFilter == 'corpus' ||
      paymentTypeFilter == 'outsider_mixed') {
    return null;
  }

  final pool = charges.where((c) {
    if (paymentTypeFilter == 'monthly_maintenance') return isMonthlyMaintenanceCharge(c);
    if (paymentTypeFilter == 'all' || paymentTypeFilter == 'all_receipts') return true;
    if (paymentTypeFilter == 'other') return false;
    return c.frequency.toLowerCase() == paymentTypeFilter;
  }).toList();
  if (pool.isEmpty) return null;

  if (paymentMonthFilter != 'all') {
    final d = parseYmd('$paymentMonthFilter-15');
    final monthName = d == null ? 'invalid date' : englishMonthName(d.month).toLowerCase();
    FinanceCharge? match;
    for (final c in pool) {
      if (normalizeTitle(c.title).contains(monthName)) {
        match = c;
        break;
      }
    }
    if (match == null) {
      for (final c in pool) {
        if (normalizeTitle(c.title).contains(paymentMonthFilter)) {
          match = c;
          break;
        }
      }
    }
    if (match != null) return (title: match.title, amount: match.amount);
  }

  FinanceCharge? current;
  for (final c in pool) {
    if (isMonthlyMaintenanceCharge(c) && isCurrentMonthChargeTitle(c.title)) {
      current = c;
      break;
    }
  }
  current ??= pool.first;
  return (title: current.title, amount: current.amount);
}
