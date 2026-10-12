// Port of `src/lib/financeLedgerDisplay.ts`.

import 'cash_bank_channel.dart';
import 'finance_dates.dart';
import 'finance_format.dart';
import 'finance_models.dart';

String ledgerTransactionDate(FinanceLedgerRow e) => ledgerTransactionDateOf(
      transactionDate: e.transactionDate,
      entryMonth: e.entryMonth,
      createdAt: e.createdAt,
    );

/// `yyyy-MM` of the ledger transaction date.
String ledgerMonthValue(FinanceLedgerRow e) => billingMonthFromDate(ledgerTransactionDate(e));

/// `MM/yyyy` of the ledger transaction date.
String ledgerMonthDisplay(FinanceLedgerRow e) => isoMonthToDisplay(ledgerMonthValue(e));

/// Human-readable ledger enum (record_mode, destination, …) — safe when the DB value is null.
String formatLedgerFieldLabel(String? value, [String fallback = '—']) {
  if (value == null || value.isEmpty) return fallback;
  return value.replaceAll('_', ' ');
}

/// `MM/yyyy` of the payment billing date (or [unknownLabel]).
String paymentMonthLabel(FinancePayment p, {String unknownLabel = 'Unknown month'}) {
  final raw = paymentBillingDate(p.dueDate);
  if (raw.isEmpty) return unknownLabel;
  return isoMonthToDisplay(billingMonthFromDate(raw));
}

String paymentVerifiedAtOrDate(FinancePayment p) {
  if ((p.paymentDate ?? '').isNotEmpty) return p.paymentDate!;
  if ((p.verifiedAt ?? '').isNotEmpty) return p.verifiedAt!;
  return p.createdAt;
}

/// Label for an event contribution receipt row.
String eventContribRefLabel(EventContribRefRow c) {
  final flat = c.flatNumber;
  if (c.receiptBasis == 'non_flat' || flat == null || flat.isEmpty) {
    for (final v in [c.batchLabel, c.outsiderName, c.residentName]) {
      if (v != null && v.isNotEmpty) return v;
    }
    return 'Receipt (no flat)';
  }
  final parts = ['Flat $flat'];
  if (c.residentName != null && c.residentName!.isNotEmpty) parts.add(c.residentName!);
  if (c.splitMode == 'headcount') parts.add('headcount');
  return parts.join(' · ');
}

bool isGroupExpenseLedgerEntry(FinanceLedgerRow e) => e.expenseId != null && e.expenseId!.isNotEmpty;

/// Receipt still sitting in the society pool (not split across flats yet).
bool isLedgerInSocietyPool(FinanceLedgerRow e) {
  if (isGroupExpenseLedgerEntry(e)) return false;
  if (e.distributedAt != null && e.distributedAt!.isNotEmpty) return false;
  final allocCount = e.allocations.length;
  if (e.recordMode == 'society_pool') return allocCount == 0;
  return e.allocationStyle == 'none' && allocCount == 0 && e.aggregateFlatCount == 0;
}

/// Head-wise summary row (web `TransactionHeadSummaryRow`).
class TransactionHeadSummaryRow {
  TransactionHeadSummaryRow({required this.head, this.total = 0, this.entries = 0, ChannelTotals? byChannel})
      : byChannel = byChannel ?? ChannelTotals();

  final String head;
  double total;
  int entries;
  final ChannelTotals byChannel;
}

void addTransactionHeadRow(
  Map<String, TransactionHeadSummaryRow> map,
  String head,
  double amount,
  String? paymentMethod,
) {
  final label = head.trim().isEmpty ? 'Uncategorized' : head.trim();
  final cur = map.putIfAbsent(label, () => TransactionHeadSummaryRow(head: label));
  final amt = amount.isNaN ? 0.0 : amount;
  cur.total += amt;
  cur.entries += 1;
  addToChannel(cur.byChannel, paymentMethod, amt);
}

List<TransactionHeadSummaryRow> transactionHeadSummaryRows(Map<String, TransactionHeadSummaryRow> map) {
  final rows = [...map.values];
  rows.sort((a, b) {
    final byTotal = b.total.compareTo(a.total);
    if (byTotal != 0) return byTotal;
    return compareText(a.head, b.head);
  });
  return rows;
}
