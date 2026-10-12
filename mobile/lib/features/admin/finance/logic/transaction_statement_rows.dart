// Transaction statement rows — port of `buildTransactionExportRows` & cell helpers in
// `src/lib/transactionStatementExport.ts`.

import 'finance_dates.dart';
import 'finance_format.dart';
import 'finance_models.dart';
import 'statement_amount_totals.dart';

class TransactionExportRow {
  const TransactionExportRow({
    required this.date,
    required this.dateIso,
    required this.type,
    required this.flat,
    required this.description,
    required this.counterparty,
    required this.method,
    required this.transactionId,
    required this.amount,
    required this.status,
    required this.notes,
  });

  final String date;
  final String dateIso;
  final String type;
  final String flat;
  final String description;
  final String counterparty;
  final String method;
  final String transactionId;
  final double amount;
  final String status;
  final String notes;

  AmountRow get amountRow => AmountRow(amount: amount, dateIso: dateIso, date: date);
}

const List<String> kTransactionHeaders = [
  'Date',
  'Type',
  'Flat',
  'Description',
  'Counterparty',
  'Method',
  'Transaction ID',
  'Amount',
  'Status',
  'Notes',
];

List<String> transactionRowToCells(TransactionExportRow r) => [
      r.date,
      r.type,
      r.flat,
      r.description,
      r.counterparty,
      r.method,
      r.transactionId,
      moneyInr(r.amount),
      r.status,
      r.notes,
    ];

List<Object?> transactionRowToRawCells(TransactionExportRow r) => [
      r.date,
      r.type,
      r.flat,
      r.description,
      r.counterparty,
      r.method,
      r.transactionId,
      r.amount,
      r.status,
      r.notes,
    ];

/// One visible line in Finance → Transactions (maintenance payment or ledger-only entry).
class ReceiptLineItem {
  const ReceiptLineItem.payment(FinancePayment this.payment)
      : entry = null,
        kind = 'mp';
  const ReceiptLineItem.ledger(FinanceLedgerRow this.entry)
      : payment = null,
        kind = 'ledger';

  /// `mp` | `ledger`
  final String kind;
  final FinancePayment? payment;
  final FinanceLedgerRow? entry;

  String get createdAt => payment?.createdAt ?? entry?.createdAt ?? '';

  /// Selection key (`mp-<id>` / `ledger-<id>`).
  String get key => payment != null ? 'mp-${payment!.id}' : 'ledger-${entry!.id}';
}

List<TransactionExportRow> buildTransactionExportRows({
  required List<ReceiptLineItem> items,
  required Map<String, String> chargeTitleById,
}) {
  final rows = <TransactionExportRow>[];
  for (final item in items) {
    final p = item.payment;
    final e = item.entry;
    if (p != null) {
      final title = chargeTitleById[p.chargeId ?? ''];
      rows.add(TransactionExportRow(
        date: fmtDateLocal(p.createdAt),
        dateIso: p.createdAt,
        type: 'Maintenance receipt',
        flat: p.flatNumber,
        description: (title == null || title.isEmpty) ? 'Unknown charge' : title,
        counterparty: p.residentName ?? '',
        method: p.paymentMethod.toUpperCase(),
        transactionId: p.transactionId ?? '',
        amount: p.amount,
        status: p.paymentStatus,
        notes: p.notes ?? '',
      ));
    } else if (e != null) {
      final flats = e.allocations.map((a) => a.flatNumber).join(', ');
      final description = (e.title ?? e.recordMode ?? 'Ledger entry').replaceAll('_', ' ');
      rows.add(TransactionExportRow(
        date: fmtDateLocal(e.createdAt),
        dateIso: e.createdAt,
        type: (e.destination ?? 'ledger').replaceAll('_', ' '),
        flat: flats.isEmpty ? '—' : flats,
        description: description,
        counterparty: e.counterparty?.name ?? '',
        method: e.paymentMethod.toUpperCase(),
        transactionId: e.transactionId ?? '',
        amount: e.totalAmount,
        status: e.paymentStatus,
        notes: e.notes ?? '',
      ));
    }
  }
  return rows;
}
