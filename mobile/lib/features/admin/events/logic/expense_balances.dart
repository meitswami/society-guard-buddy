import '../data/events_models.dart';
import 'js_compat.dart';

/// Ports of `ExpenseSplitter.parsePaidByFlats` and the "Flat balances" computation.

/// `paid_by_flats` (JSON array) else `[paid_by_flat]`.
List<String> parsePaidByFlats(Object? paidByFlatsRaw, String paidByFlat) {
  final raw = paidByFlatsRaw;
  if (raw is List && raw.isNotEmpty) {
    return [for (final v in raw) v is num ? jsNumStr(v) : '$v'];
  }
  return paidByFlat.isNotEmpty ? [paidByFlat] : const [];
}

List<String> paidByFlatsOf(ExpenseRow e) => parsePaidByFlats(e.paidByFlatsRaw, e.paidByFlat);

/// Who owes whom after event / function expenses.
///
/// Positive = others owe this flat (it advanced money); negative = this flat owes.
/// Archived and `society_fund` expenses are ignored, as are settled split lines and the
/// creditors' own lines.
Map<String, double> computeFlatBalances({
  required List<String> flatNumbers,
  required List<ExpenseRow> expenses,
  required List<ExpenseSplit> splits,
}) {
  final balances = <String, double>{for (final f in flatNumbers) f: 0};
  final splitsByExpense = <String, List<ExpenseSplit>>{};
  for (final s in splits) {
    final id = s.expenseId;
    if (id == null) continue;
    (splitsByExpense[id] ??= <ExpenseSplit>[]).add(s);
  }
  for (final exp in expenses) {
    if (exp.recordStatus == 'archived') continue;
    if (exp.splitType == 'society_fund') continue;
    final creditors = paidByFlatsOf(exp);
    if (creditors.isEmpty) continue;
    for (final s in splitsByExpense[exp.id] ?? const <ExpenseSplit>[]) {
      if (!s.isSettled && !creditors.contains(s.flatNumber)) {
        balances[s.flatNumber] = (balances[s.flatNumber] ?? 0) - s.amount;
        final share = s.amount / creditors.length;
        for (final c in creditors) {
          balances[c] = (balances[c] ?? 0) + share;
        }
      }
    }
  }
  return balances;
}

/// Non-zero balances in the same order the web prints `Object.entries(balances)`.
List<MapEntry<String, double>> nonZeroBalances(Map<String, double> balances) =>
    [for (final e in jsObjectEntries(balances)) if (e.value != 0) e];

/// `split_type` stored on new expenses.
String splitTypeFor({required String splitMode, required bool hasSplitFlats}) {
  if (splitMode == 'custom') return 'custom';
  if (splitMode == 'by_headcount') return 'by_headcount';
  return hasSplitFlats ? 'equal_selected' : 'equal_all';
}

/// File name shown for an attachment URL (`decodeURIComponent(last segment)` minus the uuid prefix).
String attachmentFileName(String url) {
  final parts = url.split('/');
  var last = parts.isEmpty ? '' : parts.last;
  if (last.isEmpty) last = 'Attachment';
  String decoded;
  try {
    decoded = Uri.decodeComponent(last);
  } catch (_) {
    decoded = last;
  }
  return decoded.replaceFirst(RegExp(r'^[a-f0-9-]+_'), '');
}
