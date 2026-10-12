// Port of src/lib/financeLedgerDisplay.test.ts (+ head summary helpers).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_ledger_display.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';

void main() {
  group('formatLedgerFieldLabel', () {
    test('formats snake_case enums', () {
      expect(formatLedgerFieldLabel('society_pool'), 'society pool');
      expect(formatLedgerFieldLabel('current_month_maintenance'), 'current month maintenance');
    });

    test('returns fallback for nullish values', () {
      expect(formatLedgerFieldLabel(null), '—');
      expect(formatLedgerFieldLabel(''), '—');
      expect(formatLedgerFieldLabel('', 'unknown'), 'unknown');
    });
  });

  group('ledger month helpers', () {
    test('uses transaction_date, then entry_month, then created_at', () {
      expect(ledgerMonthValue(const FinanceLedgerRow(transactionDate: '2026-05-09', entryMonth: '2026-04')), '2026-05');
      expect(ledgerMonthValue(const FinanceLedgerRow(entryMonth: '2026-04')), '2026-04');
      expect(ledgerMonthValue(const FinanceLedgerRow(createdAt: '2026-03-02T10:00:00Z')), '2026-03');
      expect(ledgerMonthDisplay(const FinanceLedgerRow(entryMonth: '2026-04')), '04/2026');
    });

    test('payment month label', () {
      expect(paymentMonthLabel(const FinancePayment(dueDate: '2026-07-19')), '07/2026');
      expect(paymentMonthLabel(const FinancePayment()), 'Unknown month');
    });
  });

  group('transaction head summary', () {
    test('accumulates per head and channel, sorted by total', () {
      final map = <String, TransactionHeadSummaryRow>{};
      addTransactionHeadRow(map, 'OPERATION & MAINTENANCE', 1000, 'cash');
      addTransactionHeadRow(map, 'OPERATION & MAINTENANCE', 500, 'upi');
      addTransactionHeadRow(map, '', 3000, 'cheque');
      addTransactionHeadRow(map, 'SOCIETY CORPUS FUND', 200, 'barter');
      final rows = transactionHeadSummaryRows(map);
      expect(rows.map((r) => r.head).toList(), ['Uncategorized', 'OPERATION & MAINTENANCE', 'SOCIETY CORPUS FUND']);
      expect(rows[1].entries, 2);
      expect(rows[1].byChannel.cash, 1000);
      expect(rows[1].byChannel.bank, 500);
      expect(rows[0].byChannel.bank, 3000);
      expect(rows[2].byChannel.other, 200);
    });
  });
}
