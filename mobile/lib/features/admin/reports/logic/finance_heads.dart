/// Port of the head helpers in `src/lib/financeExpenseHead.ts` that the period
/// report, cash-flow statement and Reports page rely on.
library;

/// Chart-of-accounts major heads for Finance → Record payment.
const List<String> kSocietyPaymentMajorHeads = [
  'SALARY & WAGES',
  'OPERATION & MAINTENANCE',
  'FIXED ASSETS',
  'LEGAL & PROFESSIONAL FEES',
  'SOCIETY CORPUS FUND',
  'CORPUS FUND (LEGAL)',
  'FIXED DEPOSIT',
  'BANK',
  'CASH',
  'MISCELLANEOUS',
];

final RegExp _genericEventGroup = RegExp(
  r'^(other\s+)?events?\s*(and|&|\/)\s*functions?|events?\s*&\s*functions?|event\s*\/\s*function|general\s+events?$',
  caseSensitive: false,
);

bool _t(String pattern, String s) => RegExp(pattern, caseSensitive: false).hasMatch(s);

/// Guess major head from an existing sub-head / group name (legacy rows).
String inferMajorHeadFromGroupName(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  if (n.isEmpty) return 'MISCELLANEOUS';
  if (_t(r'corpus.*legal|legal.*corpus', n)) return 'CORPUS FUND (LEGAL)';
  if (_t(r'corpus|society fund', n)) return 'SOCIETY CORPUS FUND';
  if (_t(r'fixed deposit|\bfd\b', n)) return 'FIXED DEPOSIT';
  if (_t(r'^bank\b|bank account', n)) return 'BANK';
  if (_t(r'^cash\b|petty cash', n)) return 'CASH';
  if (_t(r'legal|professional|audit|advocate|lawyer', n)) return 'LEGAL & PROFESSIONAL FEES';
  if (_t(r'fixed asset|furniture|chair|equipment|machine|softner|softener|installation|asset', n)) {
    return 'FIXED ASSETS';
  }
  if (_t(r'salary|wage|security|guard|sweeper|cleaning|garden|housekeeping|house keeping|labour|labor', n)) {
    return 'SALARY & WAGES';
  }
  if (_t(r'electric|water|wifi|cctv|dg set|diesel|printing|maintenance|repair|insurance|lift|amc|utility', n)) {
    return 'OPERATION & MAINTENANCE';
  }
  return 'MISCELLANEOUS';
}

/// Stored `major_head` when valid, else inferred from the group name.
String resolveGroupMajorHead({required String name, String? majorHead}) {
  final stored = majorHead?.trim();
  if (stored != null && kSocietyPaymentMajorHeads.contains(stored)) return stored;
  return inferMajorHeadFromGroupName(name);
}

final RegExp _eventFoodPrefix = RegExp(r'^event food\s*[—–-]', caseSensitive: false);

/// Head for period report / totals — not the raw ledger title.
/// Legacy rows used `[Group] line`; generic event groups map to the line item head.
String financeExpenseHeadFromLedgerTitle(String? rawTitle) {
  var t = (rawTitle ?? '').trim();
  if (t.isEmpty) t = 'Society expense';
  if (_eventFoodPrefix.hasMatch(t)) return t;
  final bracket = RegExp(r'^\[([^\]]+)\]\s*(.*)$').firstMatch(t);
  if (bracket != null) {
    final group = bracket.group(1)!.trim();
    final rest = bracket.group(2)!.trim();
    if (_genericEventGroup.hasMatch(group)) return rest.isNotEmpty ? rest : group;
    return group;
  }
  return t;
}

/// Major receipt head for a ledger inflow row.
String financeReceiptHeadFromLedgerEntry({
  required String destination,
  String? title,
  String? chargeId,
  Map<String, String>? chargeMajorHeadById,
}) {
  if (chargeId != null && chargeId.isNotEmpty) {
    final fromCharge = chargeMajorHeadById?[chargeId];
    if (fromCharge != null && fromCharge.isNotEmpty) return fromCharge;
  }
  if (destination == 'corpus') return 'SOCIETY CORPUS FUND';
  if (destination == 'current_month_maintenance') return 'OPERATION & MAINTENANCE';
  final tt = (title ?? '').trim();
  if (tt.isNotEmpty) return inferMajorHeadFromGroupName(tt);
  return 'Uncategorized';
}

/// Receipt head for a maintenance payment (by its charge's major head).
String financeReceiptHeadForPayment(String? chargeId, [Map<String, String>? chargeMajorHeadById]) {
  if (chargeId != null && chargeId.isNotEmpty) {
    return chargeMajorHeadById?[chargeId] ?? 'Uncategorized';
  }
  return 'Uncategorized';
}

/// Expense head for a separate-entry ledger row.
String financeExpenseHeadFromLedgerEntry(String? rawTitle, [String? expenseCategory]) {
  if (expenseCategory == 'food') {
    final parsed = financeExpenseHeadFromLedgerTitle(rawTitle);
    if (_eventFoodPrefix.hasMatch(parsed)) return parsed;
    final stripped = parsed.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '').trim();
    return stripped.isNotEmpty ? 'Event food — $stripped' : 'Event food';
  }
  return financeExpenseHeadFromLedgerTitle(rawTitle);
}

/// Event / catering bills — reconciled in Events & food, not Finance → Transactions.
bool isEventFoodExpenseCategory(String? category) => category == 'food';

bool isEventFoodLedgerTitle(String? title) => _eventFoodPrefix.hasMatch((title ?? '').trim());

/// Flat contribution receipts — reconciled in Events & food.
bool isEventContributionLedgerTitle(String? title) =>
    RegExp(r'^event contribution\s*[—–-]', caseSensitive: false).hasMatch((title ?? '').trim());

bool isHeadScopedLedgerTitle(String? title) {
  final t = (title ?? '').trim();
  return RegExp(r'^head contribution\s*[—–-]', caseSensitive: false).hasMatch(t) ||
      RegExp(r'^head adjustment\s*[—–-]', caseSensitive: false).hasMatch(t);
}

/// Web `isEventFoodLedgerEntry` — rows excluded from the society ledger in reports.
bool isEventFoodLedgerEntry({String? expenseId, String? title, required Map<String, String> expenseCategoryById}) {
  if (expenseId != null && expenseId.isNotEmpty) {
    return isEventFoodExpenseCategory(expenseCategoryById[expenseId]);
  }
  return isEventFoodLedgerTitle(title) || isEventContributionLedgerTitle(title) || isHeadScopedLedgerTitle(title);
}
