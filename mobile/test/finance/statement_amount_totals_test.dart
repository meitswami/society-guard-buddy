// Port of src/lib/statementAmountTotals.test.ts
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/statement_amount_totals.dart';

void main() {
  group('statementAmountTotals', () {
    test('sums row amounts', () {
      expect(sumAmountRows(const [AmountRow(amount: 100), AmountRow(amount: -30), AmountRow()]), 70);
    });

    test('groups by month from dateIso', () {
      const rows = [
        AmountRow(amount: 500, dateIso: '2026-04-05'),
        AmountRow(amount: 200, dateIso: '2026-04-20'),
        AmountRow(amount: 100, dateIso: '2026-05-01'),
      ];
      expect(monthlyAmountTotals(rows), const [
        MonthlyAmountTotal(monthKey: '2026-04', label: '04/2026', total: 700, count: 2),
        MonthlyAmountTotal(monthKey: '2026-05', label: '05/2026', total: 100, count: 1),
      ]);
    });

    test('parses display dates when dateIso is missing', () {
      expect(monthlyAmountTotals(const [AmountRow(amount: 50, date: '15/03/2026')]), const [
        MonthlyAmountTotal(monthKey: '2026-03', label: '03/2026', total: 50, count: 1),
      ]);
    });

    test('uses the date part of ISO timestamps', () {
      expect(monthlyAmountTotals(const [AmountRow(amount: 10, dateIso: '2026-06-30T23:00:00Z')]).single.monthKey, '2026-06');
    });
  });
}
