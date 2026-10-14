import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/expense_heads.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/finance_dates.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/flat_options.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/js_compat.dart';

void main() {
  group('js compat', () {
    test('Number(text)', () {
      expect(jsNumber(''), 0);
      expect(jsNumber(' 12.5 '), 12.5);
      expect(jsNumber('abc').isNaN, isTrue);
      expect(jsNumberOr('0', 1), 1);
      expect(jsNumberOr('x', 0.5), 0.5);
      expect(jsNumberOr('2', 1), 2);
      expect(jsPositive(double.nan), isFalse);
    });

    test('number printing like JS', () {
      expect(jsNumStr(319.0), '319');
      expect(jsNumStr(5172.41), '5172.41');
      expect(jsNumStr(0.1 + 0.2), '0.30000000000000004');
      expect(jsNumStr(null), '0');
      expect(rupeeRaw(1500), '₹1500');
    });

    test("toLocaleString('en-IN')", () {
      expect(jsLocaleIn(5172.413), '5,172.413');
      expect(jsLocaleIn(150000), '1,50,000');
      expect(jsLocaleIn(-1234), '-1,234');
      expect(jsLocaleIn(0.5), '0.5');
      expect(jsLocaleIn(1234567.891), '12,34,567.891');
      expect(jsLocaleIn(12.3456), '12.346');
      expect(jsLocaleIn(0), '0');
      expect(rupeeLoc(2500), '₹2,500');
    });

    test('stable sort keeps equal items in input order', () {
      final out = stableSorted([3, 1, 2, 1, 3], (a, b) => 0);
      expect(out, [3, 1, 2, 1, 3]);
    });
  });

  group('flat options', () {
    test('numeric flat order', () {
      final sorted = sortFlatsByNumber(['102', 'A-10', '11', 'A-9', '101', 'a-2'], (s) => s);
      expect(sorted, ['11', '101', '102', 'a-2', 'A-9', 'A-10']);
      expect(compareFlatNumbers('B-101', 'B-99'), greaterThan(0));
    });

    test('primary member label, else owner name', () {
      const flats = [
        FlatLite(id: '2', flatNumber: '102', ownerName: '  Owner Two '),
        FlatLite(id: '1', flatNumber: '101', ownerName: 'Owner One'),
        FlatLite(id: '3', flatNumber: '103', ownerName: ' '),
      ];
      final opts = flatOptionsWithPrimaryLabel(flats, const {'1': ' Ravi '});
      expect(opts.map((o) => o.flatNumber).toList(), ['101', '102', '103']);
      expect(opts.map((o) => o.subtitle).toList(), ['Ravi', 'Owner Two', null]);
      expect(residentLabelForFlatRow('1', 'Owner One', const {'1': 'Ravi'}), 'Ravi');
      expect(residentLabelForFlatRow(null, ' Owner ', const {}), 'Owner');
      expect(residentLabelForFlatRow('9', '', const {}), isNull);
    });
  });

  group('expense heads', () {
    test('inferMajorHeadFromGroupName', () {
      expect(inferMajorHeadFromGroupName('Electricity bill'), 'OPERATION & MAINTENANCE');
      expect(inferMajorHeadFromGroupName('Security guards'), 'SALARY & WAGES');
      expect(inferMajorHeadFromGroupName('Corpus legal fund'), 'CORPUS FUND (LEGAL)');
      expect(inferMajorHeadFromGroupName('Society fund top-up'), 'SOCIETY CORPUS FUND');
      expect(inferMajorHeadFromGroupName('SBI FD'), 'FIXED DEPOSIT');
      expect(inferMajorHeadFromGroupName('Bank charges'), 'BANK');
      expect(inferMajorHeadFromGroupName('Petty cash'), 'CASH');
      expect(inferMajorHeadFromGroupName('Audit fees'), 'LEGAL & PROFESSIONAL FEES');
      expect(inferMajorHeadFromGroupName('Water softener'), 'FIXED ASSETS');
      expect(inferMajorHeadFromGroupName('Diwali'), 'MISCELLANEOUS');
      expect(inferMajorHeadFromGroupName(''), 'MISCELLANEOUS');
    });

    test('resolve / search / group by major head', () {
      expect(resolveGroupMajorHead(name: 'Lift AMC', majorHead: 'BANK'), 'BANK');
      expect(resolveGroupMajorHead(name: 'Lift AMC', majorHead: 'Unknown'), 'OPERATION & MAINTENANCE');
      expect(groupMatchesPaymentHeadSearch(name: 'Lift AMC', query: 'operation'), isTrue);
      expect(groupMatchesPaymentHeadSearch(name: 'Lift AMC', description: 'Otis', query: 'otis'), isTrue);
      expect(groupMatchesPaymentHeadSearch(name: 'Lift AMC', query: 'salary'), isFalse);
      final grouped = paymentGroupsByMajorHead<List<String?>>(
        [
          ['Water bill', null],
          ['Electricity', null],
          ['Guards', null],
          ['zeta', 'BANK'],
        ],
        nameOf: (g) => g[0]!,
        majorHeadOf: (g) => g[1],
      );
      expect(grouped.keys.toList(), kSocietyPaymentMajorHeads);
      expect(grouped['OPERATION & MAINTENANCE']!.map((g) => g[0]).toList(), ['Electricity', 'Water bill']);
      expect(grouped['SALARY & WAGES']!.single[0], 'Guards');
      expect(grouped['BANK']!.single[0], 'zeta');
    });

    test('ledger titles', () {
      final food = buildGroupExpenseLedgerTitle(
        expenseCategory: 'food',
        groupName: 'Holi lunch',
        expenseTitle: 'Catering',
        eventTitle: 'Holi 2026',
      );
      expect(food.ledgerTitle, 'Event food — Holi 2026');
      expect(food.detailNote, 'Item: Catering');
      expect(buildGroupExpenseLedgerTitle(expenseCategory: 'food', groupName: 'G', expenseTitle: '').ledgerTitle, 'Event food — G');
      final pay = buildGroupExpenseLedgerTitle(expenseCategory: 'payment', groupName: 'Electricity', expenseTitle: 'electricity');
      expect(pay.ledgerTitle, 'Electricity');
      expect(pay.detailNote, isNull);
      final pay2 = buildGroupExpenseLedgerTitle(expenseCategory: 'payment', groupName: '', expenseTitle: 'Plumber');
      expect(pay2.ledgerTitle, 'Plumber');
      expect(joinNoteLines([' a ', null, '', 'b']), 'a\nb');
      expect(joinNoteLines([null, ' ']), isNull);
    });
  });

  group('finance dates', () {
    final now = DateTime(2026, 10, 12);
    test('billing month & entry month', () {
      expect(billingMonthFromDate('2026-03-15', now), '2026-03');
      expect(billingMonthFromDate('', now), '2026-10');
      expect(billingMonthFromDate('2026-02-30', now), '2026-10');
      expect(isBillingDateInEntryMonth('2026-03-15', '2026-03'), isTrue);
      expect(isBillingDateInEntryMonth('', '2026-03'), isFalse);
      expect(entryMonthFromExpenseDate('2026-07-01', now), '2026-07');
      expect(todayRecordingDate(now), '2026-10-12');
    });

    test('display helpers', () {
      expect(fmtIsoDateToDisplay('2026-03-05'), '05/03/2026');
      expect(fmtIsoDateToDisplay('2026-03-05T10:00:00Z'), '05/03/2026');
      expect(fmtIsoDateToDisplay('hello'), 'hello');
      expect(fmtIsoDateToDisplay(null), '');
      expect(fmtIsoMonthToDisplay('2026-03'), '03/2026');
      expect(fmtIsoMonthToDisplay('x'), 'x');
    });
  });
}
