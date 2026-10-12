// Port of `src/lib/financeTotalsBreakdown.ts` (+ `computeLedgerInflowGroups` from reportAggregations.ts).

import 'cash_bank_channel.dart';
import 'finance_expense_head.dart';
import 'finance_format.dart';
import 'finance_ledger_display.dart';
import 'finance_models.dart';

class LedgerInflowGroup {
  const LedgerInflowGroup({
    required this.recordMode,
    required this.destination,
    required this.total,
    required this.flatUnits,
    required this.count,
  });

  final String recordMode;
  final String destination;
  final double total;
  final int flatUnits;
  final int count;
}

String _modeKey(FinanceLedgerRow e) => e.recordMode ?? '';

String _destKey(FinanceLedgerRow e) => e.destination ?? '';

/// Group ledger inflows by record_mode + destination (Report page + Finance totals).
List<LedgerInflowGroup> computeLedgerInflowGroups(List<FinanceLedgerRow> entries, {bool excludeSeparateEntry = false}) {
  final map = <String, ({double total, int flatUnits, int count, String mode, String dest})>{};
  for (final e in entries) {
    if (excludeSeparateEntry && e.destination == 'separate_entry') continue;
    final key = '${_modeKey(e)}||${_destKey(e)}';
    final cur = map[key] ?? (total: 0.0, flatUnits: 0, count: 0, mode: _modeKey(e), dest: _destKey(e));
    map[key] = (
      total: cur.total + e.totalAmount,
      flatUnits: cur.flatUnits + e.aggregateFlatCount,
      count: cur.count + 1,
      mode: cur.mode,
      dest: cur.dest,
    );
  }
  return [
    for (final v in map.values)
      LedgerInflowGroup(recordMode: v.mode, destination: v.dest, total: v.total, flatUnits: v.flatUnits, count: v.count),
  ];
}

class TotalsInflowRow {
  const TotalsInflowRow({
    required this.mode,
    required this.destination,
    required this.total,
    required this.flatUnits,
    required this.entries,
    required this.byChannel,
  });

  final String mode;
  final String destination;
  final double total;
  final int flatUnits;
  final int entries;
  final ChannelTotals byChannel;
}

class TotalsOutflowRow {
  const TotalsOutflowRow({
    required this.head,
    required this.total,
    required this.flatUnits,
    required this.entries,
    required this.byChannel,
  });

  final String head;
  final double total;
  final int flatUnits;
  final int entries;
  final ChannelTotals byChannel;
}

List<TotalsInflowRow> computeTotalsInflowBreakdown(List<FinanceLedgerRow> ledgerEntries, String totalsMonth) {
  final filtered = ledgerEntries.where((e) => ledgerMonthValue(e) == totalsMonth).toList();
  final rows = computeLedgerInflowGroups(filtered, excludeSeparateEntry: true).map((g) {
    final byChannel = emptyChannelTotals();
    for (final e in filtered) {
      if (_modeKey(e) == g.recordMode && _destKey(e) == g.destination) {
        addToChannel(byChannel, e.paymentMethod, e.totalAmount);
      }
    }
    return TotalsInflowRow(
      mode: g.recordMode,
      destination: g.destination,
      total: g.total,
      flatUnits: g.flatUnits,
      entries: g.count,
      byChannel: byChannel,
    );
  }).toList();
  rows.sort((a, b) => compareText('${a.mode}${a.destination}', '${b.mode}${b.destination}'));
  return rows;
}

List<TotalsOutflowRow> computeTotalsOutflowBreakdown(
  List<FinanceLedgerRow> societyLedgerEntries,
  String totalsMonth,
  Map<String, String> expenseCategoryById,
) {
  final map = <String, ({double total, int flatUnits, int entries, ChannelTotals byChannel})>{};
  for (final e in societyLedgerEntries) {
    if (ledgerMonthValue(e) != totalsMonth) continue;
    if (e.destination != 'separate_entry') continue;
    final head = financeExpenseHeadFromLedgerEntry(e.title, e.expenseId != null ? expenseCategoryById[e.expenseId] : null);
    final cur = map[head] ?? (total: 0.0, flatUnits: 0, entries: 0, byChannel: emptyChannelTotals());
    addToChannel(cur.byChannel, e.paymentMethod, e.totalAmount);
    map[head] = (
      total: cur.total + e.totalAmount,
      flatUnits: cur.flatUnits + e.aggregateFlatCount,
      entries: cur.entries + 1,
      byChannel: cur.byChannel,
    );
  }
  final rows = [
    for (final entry in map.entries)
      TotalsOutflowRow(
        head: entry.key,
        total: entry.value.total,
        flatUnits: entry.value.flatUnits,
        entries: entry.value.entries,
        byChannel: entry.value.byChannel,
      ),
  ];
  rows.sort((a, b) => compareText(a.head, b.head));
  return rows;
}

/// Everything `useFinanceTotalsBreakdown` returns.
class FinanceTotalsBreakdown {
  FinanceTotalsBreakdown._({
    required this.totalsBreakdown,
    required this.totalsMonthReceiptChannels,
    required this.totalsMonthNet,
    required this.totalsOutflowBreakdown,
    required this.totalsMonthPaymentChannels,
    required this.totalsMonthOutflow,
  });

  factory FinanceTotalsBreakdown.compute({
    required List<FinanceLedgerRow> ledgerEntries,
    required List<FinanceLedgerRow> societyLedgerEntries,
    required String totalsMonth,
    required Map<String, String> expenseCategoryById,
  }) {
    final inflow = computeTotalsInflowBreakdown(ledgerEntries, totalsMonth);
    final outflow = computeTotalsOutflowBreakdown(societyLedgerEntries, totalsMonth, expenseCategoryById);
    return FinanceTotalsBreakdown._(
      totalsBreakdown: inflow,
      totalsMonthReceiptChannels: sumChannelRows(inflow.map((r) => r.byChannel)),
      totalsMonthNet: inflow.fold(0.0, (s, r) => s + r.total),
      totalsOutflowBreakdown: outflow,
      totalsMonthPaymentChannels: sumChannelRows(outflow.map((r) => r.byChannel)),
      totalsMonthOutflow: outflow.fold(0.0, (s, r) => s + r.total),
    );
  }

  final List<TotalsInflowRow> totalsBreakdown;
  final ChannelTotals totalsMonthReceiptChannels;
  final double totalsMonthNet;
  final List<TotalsOutflowRow> totalsOutflowBreakdown;
  final ChannelTotals totalsMonthPaymentChannels;
  final double totalsMonthOutflow;
}
