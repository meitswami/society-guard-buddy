import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/events/data/events_models.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/expense_balances.dart';

/// `ExpenseSplitter` balances / paid-by parsing parity.
void main() {
  ExpenseRow exp(String id, {Object? paidBy, String paidByFlat = '', String split = 'equal_all', String? status}) =>
      ExpenseRow(
        id: id,
        groupId: 'g',
        title: id,
        totalAmount: 0,
        paidByFlat: paidByFlat,
        paidByFlatsRaw: paidBy,
        splitType: split,
        recordStatus: status,
      );

  ExpenseSplit sp(String expId, String flat, double amount, {bool settled = false}) =>
      ExpenseSplit(id: '$expId-$flat', expenseId: expId, flatNumber: flat, amount: amount, isSettled: settled);

  group('parsePaidByFlats', () {
    test('array wins, then legacy single flat', () {
      expect(parsePaidByFlats(['101', 102], 'X'), ['101', '102']);
      expect(parsePaidByFlats(const [], '103'), ['103']);
      expect(parsePaidByFlats(null, '104'), ['104']);
      expect(parsePaidByFlats(null, ''), isEmpty);
      expect(parsePaidByFlats({'a': 1}, ''), isEmpty);
    });
  });

  group('computeFlatBalances', () {
    test('creditors gain each unsettled share; debtors owe it', () {
      final balances = computeFlatBalances(
        flatNumbers: const ['101', '102', '103'],
        expenses: [exp('e1', paidBy: const ['101'])],
        splits: [sp('e1', '101', 100), sp('e1', '102', 100), sp('e1', '103', 100, settled: true)],
      );
      expect(balances, {'101': 100.0, '102': -100.0, '103': 0.0});
      expect(nonZeroBalances(balances).map((e) => e.key).toList(), ['101', '102']);
    });

    test('shares are divided between several creditors', () {
      final balances = computeFlatBalances(
        flatNumbers: const ['101', '102', '103'],
        expenses: [exp('e1', paidBy: const ['101', '102'])],
        splits: [sp('e1', '101', 50), sp('e1', '102', 50), sp('e1', '103', 50)],
      );
      expect(balances, {'101': 25.0, '102': 25.0, '103': -50.0});
    });

    test('archived, society-fund and creditor-less expenses are ignored', () {
      final balances = computeFlatBalances(
        flatNumbers: const ['101', '102'],
        expenses: [
          exp('a', paidBy: const ['101'], status: 'archived'),
          exp('s', paidBy: const [], paidByFlat: 'SOCIETY', split: 'society_fund'),
          exp('n'),
        ],
        splits: [sp('a', '102', 10), sp('s', '102', 10), sp('n', '102', 10)],
      );
      expect(balances.values.every((v) => v == 0), isTrue);
    });

    test('flats outside the society list are appended (JS object semantics)', () {
      final balances = computeFlatBalances(
        flatNumbers: const ['B-1'],
        expenses: [exp('e', paidBy: const ['B-1'])],
        splits: [sp('e', 'Z-9', 30)],
      );
      expect(balances.keys.toList(), ['B-1', 'Z-9']);
      expect(balances['Z-9'], -30);
    });

    test('Object.entries order puts integer-like flat numbers first', () {
      final ordered = nonZeroBalances({'A-1': 1, '102': 2, '101': 3, '0': 4, '007': 5});
      expect(ordered.map((e) => e.key).toList(), ['0', '101', '102', 'A-1', '007']);
    });
  });

  test('splitTypeFor', () {
    expect(splitTypeFor(splitMode: 'custom', hasSplitFlats: true), 'custom');
    expect(splitTypeFor(splitMode: 'by_headcount', hasSplitFlats: false), 'by_headcount');
    expect(splitTypeFor(splitMode: 'even', hasSplitFlats: true), 'equal_selected');
    expect(splitTypeFor(splitMode: 'even', hasSplitFlats: false), 'equal_all');
  });

  test('attachmentFileName strips the uuid prefix and decodes', () {
    expect(
      attachmentFileName('https://x.supabase.co/storage/v1/object/public/notification-media/expense-bills/g/'
          '0f8c2a3e-1b2c-4d5e-8f90-123456789abc_Caterer%20bill.pdf'),
      'Caterer bill.pdf',
    );
    expect(attachmentFileName('https://x/'), 'Attachment');
    expect(attachmentFileName('https://x/%E0%A4%'), '%E0%A4%');
  });
}
