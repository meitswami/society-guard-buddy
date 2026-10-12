// Port of `src/lib/financeExpenseHead.ts`.

import 'finance_format.dart';
import 'finance_models.dart';

/// Chart-of-accounts major heads for Finance → Record payment (stored in `expense_groups.major_head`).
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

const String kUncategorizedHead = 'Uncategorized';

final RegExp _genericEventGroup = RegExp(
  r'^(other\s+)?events?\s*(and|&|\/)\s*functions?|events?\s*&\s*functions?|event\s*\/\s*function|general\s+events?$',
  caseSensitive: false,
);

String? joinNoteLines(List<String?> parts) {
  final lines = parts
      .map((p) => p?.trim())
      .whereType<String>()
      .where((p) => p.isNotEmpty)
      .toList();
  return lines.isEmpty ? null : lines.join('\n');
}

bool _has(String pattern, String s) => RegExp(pattern).hasMatch(s);

/// Guess major head from an existing sub-head / group name (legacy rows).
String inferMajorHeadFromGroupName(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return 'MISCELLANEOUS';
  if (_has(r'corpus.*legal|legal.*corpus', n)) return 'CORPUS FUND (LEGAL)';
  if (_has(r'corpus|society fund', n)) return 'SOCIETY CORPUS FUND';
  if (_has(r'fixed deposit|\bfd\b', n)) return 'FIXED DEPOSIT';
  if (_has(r'^bank\b|bank account', n)) return 'BANK';
  if (_has(r'^cash\b|petty cash', n)) return 'CASH';
  if (_has(r'legal|professional|audit|advocate|lawyer', n)) {
    return 'LEGAL & PROFESSIONAL FEES';
  }
  if (_has(
      r'fixed asset|furniture|chair|equipment|machine|softner|softener|installation|asset',
      n)) {
    return 'FIXED ASSETS';
  }
  if (_has(
      r'salary|wage|security|guard|sweeper|cleaning|garden|housekeeping|house keeping|labour|labor',
      n)) {
    return 'SALARY & WAGES';
  }
  if (_has(
      r'electric|water|wifi|cctv|dg set|diesel|printing|maintenance|repair|insurance|lift|amc|utility',
      n)) {
    return 'OPERATION & MAINTENANCE';
  }
  return 'MISCELLANEOUS';
}

/// Stored major head when valid, else inferred from the name.
String resolveGroupMajorHead(String name, String? majorHead) {
  final stored = majorHead?.trim();
  if (stored != null &&
      stored.isNotEmpty &&
      kSocietyPaymentMajorHeads.contains(stored)) {
    return stored;
  }
  return inferMajorHeadFromGroupName(name);
}

String resolveGroupMajorHeadOf(PaymentExpenseGroup g) =>
    resolveGroupMajorHead(g.name, g.majorHead);

bool groupMatchesPaymentHeadSearch(PaymentExpenseGroup group, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final major = resolveGroupMajorHeadOf(group);
  return group.name.toLowerCase().contains(q) ||
      major.toLowerCase().contains(q) ||
      (group.description ?? '').toLowerCase().contains(q);
}

/// Groups bucketed by major head (each bucket sorted by name).
Map<String, List<PaymentExpenseGroup>> paymentGroupsByMajorHead(
    List<PaymentExpenseGroup> groups) {
  final map = <String, List<PaymentExpenseGroup>>{
    for (final h in kSocietyPaymentMajorHeads) h: []
  };
  for (final g in groups) {
    map[resolveGroupMajorHeadOf(g)]!.add(g);
  }
  for (final h in kSocietyPaymentMajorHeads) {
    map[h]!.sort((a, b) => compareText(a.name, b.name));
  }
  return map;
}

/// Ledger title + extra note lines for group-linked expenses.
({String ledgerTitle, String? detailNote}) buildGroupExpenseLedgerTitle({
  required String expenseCategory,
  required String groupName,
  required String expenseTitle,
  String? eventTitle,
}) {
  final group = groupName.trim();
  final line = expenseTitle.trim();
  if (expenseCategory == 'food') {
    final eventLabel = eventTitle?.trim();
    final ledgerTitle = (eventLabel != null && eventLabel.isNotEmpty)
        ? 'Event food — $eventLabel'
        : group.isNotEmpty
            ? 'Event food — $group'
            : 'Event food';
    final detailNote = line.isNotEmpty ? 'Item: $line' : null;
    return (ledgerTitle: ledgerTitle, detailNote: detailNote);
  }
  final head =
      group.isNotEmpty ? group : (line.isNotEmpty ? line : 'Society payment');
  final detailNote = line.isNotEmpty && line.toLowerCase() != head.toLowerCase()
      ? 'Detail: $line'
      : null;
  return (ledgerTitle: head, detailNote: detailNote);
}

final RegExp _eventFoodPrefix =
    RegExp(r'^event food\s*[—–-]', caseSensitive: false);
final RegExp _eventContributionPrefix =
    RegExp(r'^event contribution\s*[—–-]', caseSensitive: false);
final RegExp _headContributionPrefix =
    RegExp(r'^head contribution\s*[—–-]', caseSensitive: false);
final RegExp _headAdjustmentPrefix =
    RegExp(r'^head adjustment\s*[—–-]', caseSensitive: false);

/// Head for period report / totals — not the raw ledger title.
String financeExpenseHeadFromLedgerTitle(String? rawTitle) {
  final trimmed = (rawTitle ?? '').trim();
  final t = trimmed.isEmpty ? 'Society expense' : trimmed;
  if (_eventFoodPrefix.hasMatch(t)) return t;
  final bracket = RegExp(r'^\[([^\]]+)\]\s*(.*)$').firstMatch(t);
  if (bracket != null) {
    final group = bracket.group(1)!.trim();
    final rest = bracket.group(2)!.trim();
    if (_genericEventGroup.hasMatch(group)) {
      return rest.isNotEmpty ? rest : group;
    }
    return group;
  }
  return t;
}

/// Major receipt head for period report / head-wise summaries.
String financeReceiptHeadFromLedgerEntry(
  String? destination,
  String? title,
  String? chargeId, [
  Map<String, String>? chargeMajorHeadById,
]) {
  if (chargeId != null && chargeId.isNotEmpty) {
    final fromCharge = chargeMajorHeadById?[chargeId];
    if (fromCharge != null && fromCharge.isNotEmpty) return fromCharge;
  }
  if (destination == 'corpus') return 'SOCIETY CORPUS FUND';
  if (destination == 'current_month_maintenance') {
    return 'OPERATION & MAINTENANCE';
  }
  final t = (title ?? '').trim();
  if (t.isNotEmpty) return inferMajorHeadFromGroupName(t);
  return kUncategorizedHead;
}

String financeReceiptHeadForPayment(String? chargeId,
    [Map<String, String>? chargeMajorHeadById]) {
  if (chargeId != null && chargeId.isNotEmpty) {
    return chargeMajorHeadById?[chargeId] ?? kUncategorizedHead;
  }
  return kUncategorizedHead;
}

String financeExpenseHeadFromLedgerEntry(String? rawTitle,
    [String? expenseCategory]) {
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

bool isEventFoodLedgerTitle(String? title) =>
    _eventFoodPrefix.hasMatch((title ?? '').trim());

bool isEventContributionLedgerTitle(String? title) =>
    _eventContributionPrefix.hasMatch((title ?? '').trim());

bool isHeadScopedLedgerTitle(String? title) {
  final t = (title ?? '').trim();
  return _headContributionPrefix.hasMatch(t) ||
      _headAdjustmentPrefix.hasMatch(t);
}

bool isEventFoodLedgerEntry(
    String? expenseId, String? title, Map<String, String> expenseCategoryById) {
  if (expenseId != null && expenseId.isNotEmpty) {
    return isEventFoodExpenseCategory(expenseCategoryById[expenseId]);
  }
  return isEventFoodLedgerTitle(title) ||
      isEventContributionLedgerTitle(title) ||
      isHeadScopedLedgerTitle(title);
}
