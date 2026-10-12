import 'js_compat.dart';
import 'report_formatters.dart';

/// Port of `src/lib/statementAmountTotals.ts`.
class AmountRow {
  const AmountRow({this.amount, this.dateIso, this.date});

  final double? amount;

  /// Preferred for grouping — `yyyy-MM-dd` or ISO timestamp.
  final String? dateIso;

  /// Display date (`dd/MM/yyyy`) when ISO is unavailable.
  final String? date;
}

class MonthlyAmountTotal {
  const MonthlyAmountTotal(
      {required this.monthKey,
      required this.label,
      required this.total,
      required this.count});

  final String monthKey;
  final String label;
  final double total;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is MonthlyAmountTotal &&
      other.monthKey == monthKey &&
      other.label == label &&
      other.total == total &&
      other.count == count;

  @override
  int get hashCode => Object.hash(monthKey, label, total, count);

  @override
  String toString() => 'MonthlyAmountTotal($monthKey, $label, $total, $count)';
}

double sumAmountRows(Iterable<double?> amounts) =>
    amounts.fold(0.0, (s, a) => s + (a ?? 0));

String? _monthKeyFromRow(AmountRow row) {
  final iso = row.dateIso;
  if (iso != null && iso.isNotEmpty) {
    final s = iso.length > 10 ? iso.substring(0, 10) : iso;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s.substring(0, 7);
  }
  final date = row.date;
  if (date != null && date.isNotEmpty) {
    final trimmed = date.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      return trimmed.substring(0, 7);
    }
    final s = trimmed.length > 10 ? trimmed.substring(0, 10) : trimmed;
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (m != null) {
      final d = int.parse(m.group(1)!),
          mo = int.parse(m.group(2)!),
          y = int.parse(m.group(3)!);
      final dt = DateTime(y, mo, d);
      if (dt.year == y && dt.month == mo && dt.day == d) {
        return '$y-${pad2(mo)}';
      }
    }
  }
  return null;
}

/// Group signed transaction amounts by calendar month (`yyyy-MM`), ascending.
List<MonthlyAmountTotal> monthlyAmountTotals(Iterable<AmountRow> rows) {
  final map = <String, ({double total, int count})>{};
  for (final row in rows) {
    final amount = row.amount;
    if (amount == null) continue;
    final key = _monthKeyFromRow(row);
    if (key == null) continue;
    final cur = map[key] ?? (total: 0.0, count: 0);
    map[key] = (total: cur.total + amount, count: cur.count + 1);
  }
  final keys = map.keys.toList()..sort();
  return [
    for (final k in keys)
      MonthlyAmountTotal(
          monthKey: k,
          label: fmtIsoMonthToDisplay(k),
          total: map[k]!.total,
          count: map[k]!.count),
  ];
}
