import 'js_compat.dart';

/// Port of the parts of `src/lib/financeExpenseHead.ts` used by the expense splitter.

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

/// Join trimmed non-empty lines with `\n` (null when nothing remains).
String? joinNoteLines(List<String?> parts) {
  final lines = [
    for (final p in parts)
      if (p != null && p.trim().isNotEmpty) p.trim(),
  ];
  return lines.isEmpty ? null : lines.join('\n');
}

bool _has(String n, String pattern) => RegExp(pattern).hasMatch(n);

/// Guess major head from an existing sub-head / group name (legacy rows).
String inferMajorHeadFromGroupName(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return 'MISCELLANEOUS';
  if (_has(n, r'corpus.*legal|legal.*corpus')) return 'CORPUS FUND (LEGAL)';
  if (_has(n, r'corpus|society fund')) return 'SOCIETY CORPUS FUND';
  if (_has(n, r'fixed deposit|\bfd\b')) return 'FIXED DEPOSIT';
  if (_has(n, r'^bank\b|bank account')) return 'BANK';
  if (_has(n, r'^cash\b|petty cash')) return 'CASH';
  if (_has(n, r'legal|professional|audit|advocate|lawyer')) return 'LEGAL & PROFESSIONAL FEES';
  if (_has(n, r'fixed asset|furniture|chair|equipment|machine|softner|softener|installation|asset')) return 'FIXED ASSETS';
  if (_has(n, r'salary|wage|security|guard|sweeper|cleaning|garden|housekeeping|house keeping|labour|labor')) {
    return 'SALARY & WAGES';
  }
  if (_has(n, r'electric|water|wifi|cctv|dg set|diesel|printing|maintenance|repair|insurance|lift|amc|utility')) {
    return 'OPERATION & MAINTENANCE';
  }
  return 'MISCELLANEOUS';
}

String resolveGroupMajorHead({required String name, String? majorHead}) {
  final stored = majorHead?.trim();
  if (stored != null && stored.isNotEmpty && kSocietyPaymentMajorHeads.contains(stored)) return stored;
  return inferMajorHeadFromGroupName(name);
}

bool groupMatchesPaymentHeadSearch({
  required String name,
  String? description,
  String? majorHead,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final major = resolveGroupMajorHead(name: name, majorHead: majorHead);
  return name.toLowerCase().contains(q) || major.toLowerCase().contains(q) || (description ?? '').toLowerCase().contains(q);
}

/// Groups by resolved major head, each list sorted by name (web `paymentGroupsByMajorHead`).
Map<String, List<T>> paymentGroupsByMajorHead<T>(
  List<T> groups, {
  required String Function(T) nameOf,
  required String? Function(T) majorHeadOf,
}) {
  final map = <String, List<T>>{for (final h in kSocietyPaymentMajorHeads) h: <T>[]};
  for (final g in groups) {
    final major = resolveGroupMajorHead(name: nameOf(g), majorHead: majorHeadOf(g));
    map[major]!.add(g);
  }
  for (final h in kSocietyPaymentMajorHeads) {
    map[h] = stableSorted(map[h]!, (a, b) => localeCompare(nameOf(a), nameOf(b)));
  }
  return map;
}

class GroupLedgerTitle {
  const GroupLedgerTitle(this.ledgerTitle, this.detailNote);

  final String ledgerTitle;
  final String? detailNote;
}

/// Ledger title + extra note lines for group-linked expenses.
GroupLedgerTitle buildGroupExpenseLedgerTitle({
  required String expenseCategory,
  required String groupName,
  required String expenseTitle,
  String? eventTitle,
}) {
  final group = groupName.trim();
  final line = expenseTitle.trim();

  if (expenseCategory == 'food') {
    final eventLabel = eventTitle?.trim();
    final hasEvent = eventLabel != null && eventLabel.isNotEmpty;
    final ledgerTitle = hasEvent
        ? 'Event food — $eventLabel'
        : group.isNotEmpty
            ? 'Event food — $group'
            : 'Event food';
    final detailNote = line.isNotEmpty ? 'Item: $line' : null;
    return GroupLedgerTitle(ledgerTitle, detailNote);
  }

  final head = group.isNotEmpty ? group : (line.isNotEmpty ? line : 'Society payment');
  final detailNote = line.isNotEmpty && line.toLowerCase() != head.toLowerCase() ? 'Detail: $line' : null;
  return GroupLedgerTitle(head, detailNote);
}
