// Port of src/lib/financePeriodReport.test.ts (+ helper coverage).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/finance_dates.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/finance_heads.dart';
import 'package:kutumbika_mobile/features/admin/reports/logic/finance_period_report.dart';

FinanceOpeningBalanceAnchor anchor(String date,
        {double? cash, double? bank, double? other}) =>
    FinanceOpeningBalanceAnchor(
        asOnDate: date, cashAmount: cash, bankAmount: bank, otherAmount: other);

ChannelByHeadRow row(double cash, double bank, double other, double total) =>
    ChannelByHeadRow(cash: cash, bank: bank, other: other, total: total);

void main() {
  group('finance opening balance anchors', () {
    test('shows manual setup UI for Feb–Mar 2026 go-live period starts', () {
      expect(isManualOpeningBalanceSetupPeriod('2026-02-01'), isTrue);
      expect(isManualOpeningBalanceSetupPeriod('2026-03-01'), isTrue);
      expect(isManualOpeningBalanceSetupPeriod('2026-03-31'), isTrue);
      expect(isManualOpeningBalanceSetupPeriod('2026-04-01'), isFalse);
    });

    test('defines Feb 2026 as the earliest reporting month', () {
      expect(kFinanceReportingEarliestMonth, '2026-02');
      expect(financeReportingMonthRange('2026-02'),
          (from: '2026-02-01', to: '2026-02-28'));
    });

    test('finds latest anchor before period start', () {
      final anchors = [
        anchor('2026-01-31', bank: 10000),
        anchor('2026-02-28', bank: 18145)
      ];
      expect(findApplicableOpeningAnchor(anchors, '2026-03-01')?.asOnDate,
          '2026-02-28');
      expect(findApplicableOpeningAnchor(anchors, '2026-02-28')?.asOnDate,
          '2026-01-31');
      expect(findApplicableOpeningAnchor(anchors, '2026-01-31'), isNull);
    });

    test('uses manual bank anchor for period starting after anchor date', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-03-01',
        periodTo: '2026-03-31',
        payments: const [],
        ledgerEntries: const [],
        openingBalanceAnchors: [anchor('2026-02-28', bank: 18145)],
      );
      expect(report.openingBank, 18145);
      expect(report.openingBankFromManualAnchor, isTrue);
      expect(report.appliedOpeningAnchor?.bankAmount, 18145);
    });

    test(
        'uses manual cash anchor of zero for period starting after anchor date',
        () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-03-01',
        periodTo: '2026-03-31',
        payments: const [],
        ledgerEntries: const [],
        openingBalanceAnchors: [anchor('2026-02-28', cash: 0)],
      );
      expect(report.openingCash, 0);
      expect(report.openingCashFromManualAnchor, isTrue);
    });

    test('adds bank movement between anchor and period start', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePeriodPayment(
              paymentStatus: 'verified',
              amount: 500,
              paymentMethod: 'upi',
              dueDate: '2026-03-15'),
        ],
        ledgerEntries: const [],
        openingBalanceAnchors: [anchor('2026-02-28', bank: 18145)],
      );
      expect(report.openingBank, 18645);
    });
  });

  group('finance period report head-wise columns', () {
    test('groups verified receipts by head with cash, bank, and total columns',
        () {
      final chargeMajorHeadById = {
        'ch-maint': 'OPERATION & MAINTENANCE',
        'ch-corpus': 'SOCIETY CORPUS FUND'
      };
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePeriodPayment(
            paymentStatus: 'verified',
            amount: 1000,
            paymentMethod: 'cash',
            dueDate: '2026-04-05',
            chargeId: 'ch-maint',
          ),
          FinancePeriodPayment(
            paymentStatus: 'verified',
            amount: 2500,
            paymentMethod: 'upi',
            dueDate: '2026-04-10',
            chargeId: 'ch-corpus',
          ),
        ],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(
            id: 'fe-ledger',
            destination: 'current_month_maintenance',
            totalAmount: 500,
            paymentMethod: 'cash',
            transactionDate: '2026-04-12',
          ),
        ],
        chargeMajorHeadById: chargeMajorHeadById,
      );

      expect(report.receiptByHead, [
        HeadAmount('SOCIETY CORPUS FUND', row(0, 2500, 0, 2500)),
        HeadAmount('OPERATION & MAINTENANCE', row(1500, 0, 0, 1500)),
      ]);
      expect(report.receiptByMethod,
          ChannelTotals(cash: 1500, bank: 2500, other: 0));
      expect(report.totalReceipts, 4000);
    });

    test(
        'groups separate-entry expenses by head with cash, bank, and total columns',
        () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(
            id: 'fe-1',
            destination: 'separate_entry',
            totalAmount: 800,
            paymentMethod: 'cash',
            title: 'Electricity',
            transactionDate: '2026-04-03',
          ),
          FinancePeriodLedgerEntry(
            id: 'fe-2',
            destination: 'separate_entry',
            totalAmount: 1200,
            paymentMethod: 'upi',
            title: 'Electricity',
            transactionDate: '2026-04-08',
          ),
          FinancePeriodLedgerEntry(
            id: 'fe-3',
            destination: 'separate_entry',
            totalAmount: 300,
            paymentMethod: 'cash',
            title: 'Security salary',
            transactionDate: '2026-04-15',
          ),
        ],
      );

      expect(report.expenseByHead, [
        HeadAmount('Electricity', row(800, 1200, 0, 2000)),
        HeadAmount('Security salary', row(300, 0, 0, 300)),
      ]);
      expect(report.expenseByMethod,
          ChannelTotals(cash: 1100, bank: 1200, other: 0));
      expect(report.totalExpenses, 2300);
    });

    test('includes February 2026 society expenses in the Feb period report',
        () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-02-01',
        periodTo: '2026-02-28',
        payments: const [],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(
            id: 'fe-feb-1',
            destination: 'separate_entry',
            totalAmount: 100000,
            paymentMethod: 'bank_transfer',
            entryMonth: '2026-02',
            transactionDate: '2026-02-10',
          ),
          FinancePeriodLedgerEntry(
            id: 'fe-feb-2',
            destination: 'separate_entry',
            totalAmount: 68751,
            paymentMethod: 'cash',
            entryMonth: '2026-02',
            transactionDate: '2026-02-20',
          ),
        ],
      );

      expect(report.totalExpenses, 168751);
      expect(report.expenseByMethod,
          ChannelTotals(cash: 68751, bank: 100000, other: 0));
      // Untitled separate entries fall back to the "Society expense" head.
      expect(report.expenseByHead.single.head, 'Society expense');
    });
  });

  group('period report rules (extra coverage)', () {
    test('linked ledger rows are not double counted; pending rows are ignored',
        () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-05-01',
        periodTo: '2026-05-31',
        payments: const [
          FinancePeriodPayment(
            paymentStatus: 'verified',
            amount: 1000,
            paymentMethod: 'cash',
            dueDate: '2026-05-02',
            financeEntryId: 'fe-linked',
            chargeId: 'c1',
          ),
          FinancePeriodPayment(
              paymentStatus: 'pending',
              amount: 999,
              paymentMethod: 'cash',
              dueDate: '2026-05-03'),
        ],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(
            id: 'fe-linked',
            destination: 'current_month_maintenance',
            totalAmount: 1000,
            paymentMethod: 'cash',
            transactionDate: '2026-05-02',
          ),
          FinancePeriodLedgerEntry(
            id: 'fe-corpus',
            destination: 'corpus',
            totalAmount: 700,
            paymentMethod: 'neft',
            transactionDate: '2026-05-20',
          ),
          FinancePeriodLedgerEntry(
            id: 'fe-pending',
            destination: 'separate_entry',
            totalAmount: 5000,
            paymentMethod: 'cash',
            paymentStatus: 'pending',
            transactionDate: '2026-05-21',
          ),
        ],
      );
      expect(report.verifiedPaymentCount, 1);
      expect(report.maintenanceReceipts, 1000);
      expect(report.extraLedgerReceipt, 700);
      expect(report.corpusReceipts, 700);
      expect(report.totalReceipts, 1700);
      expect(report.totalExpenses, 0);
      // Without chargeMajorHeadById, payments land in "Uncategorized" (web Reports behaviour).
      expect(report.receiptByHead.map((h) => h.head),
          ['Uncategorized', 'SOCIETY CORPUS FUND']);
      expect(report.cashInHand, 1000);
      expect(report.cashInBank, 700);
      expect(report.totalBalance, 1700);
    });

    test(
        'opening balance is computed from earlier rows and closing adds the period net',
        () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-06-01',
        periodTo: '2026-06-30',
        payments: const [
          FinancePeriodPayment(
              paymentStatus: 'verified',
              amount: 2000,
              paymentMethod: 'cash',
              dueDate: '2026-05-10'),
          FinancePeriodPayment(
              paymentStatus: 'verified',
              amount: 300,
              paymentMethod: 'cash',
              dueDate: '2026-06-10'),
        ],
        ledgerEntries: const [
          FinancePeriodLedgerEntry(
            id: 'x1',
            destination: 'separate_entry',
            totalAmount: 500,
            paymentMethod: 'cash',
            transactionDate: '2026-05-15',
          ),
          FinancePeriodLedgerEntry(
            id: 'x2',
            destination: 'separate_entry',
            totalAmount: 100,
            paymentMethod: 'cheque',
            transactionDate: '2026-06-15',
          ),
        ],
      );
      expect(report.openingCash, 1500);
      expect(report.openingBank, 0);
      expect(report.openingBalance, 1500);
      expect(report.cashInHand, 300);
      expect(report.cashInBank, -100);
      expect(report.closingCash, 1800);
      expect(report.closingBank, -100);
      expect(report.closingBalance, 1700);
      expect(report.appliedOpeningAnchor, isNull);
    });

    test('event food ledger rows are filtered out of the society ledger', () {
      const entries = [
        FinancePeriodLedgerEntry(
            id: 'a',
            destination: 'separate_entry',
            title: 'Event food — Diwali'),
        FinancePeriodLedgerEntry(
            id: 'b', destination: 'separate_entry', expenseId: 'e-food'),
        FinancePeriodLedgerEntry(
            id: 'c',
            destination: 'separate_entry',
            expenseId: 'e-pay',
            title: 'Event food — x'),
        FinancePeriodLedgerEntry(
            id: 'd', destination: 'corpus', title: 'Event contribution — Holi'),
        FinancePeriodLedgerEntry(
            id: 'e', destination: 'corpus', title: 'Head adjustment — fix'),
        FinancePeriodLedgerEntry(
            id: 'f', destination: 'separate_entry', title: 'Electricity'),
      ];
      final kept = filterSocietyLedgerEntries(
          entries, {'e-food': 'food', 'e-pay': 'payment'});
      expect(kept.map((e) => e.id), ['c', 'f']);
    });

    test('fromJson reads numeric strings and embedded allocations', () {
      final e = FinancePeriodLedgerEntry.fromJson({
        'id': 'fe1',
        'destination': 'current_month_maintenance',
        'total_amount': '1250.50',
        'payment_method': 'upi',
        'payment_status': null,
        'entry_month': '2026-04',
        'aggregate_flat_count': 3,
        'finance_entry_allocations': [
          {'flat_number': '101', 'amount': 500, 'flat_id': 'f1'},
        ],
      });
      expect(e.totalAmount, 1250.5);
      expect(e.isVerified, isTrue);
      expect(e.ledgerDate, '2026-04-01');
      expect(e.allocations.single.flatNumber, '101');
      final p = FinancePeriodPayment.fromJson({
        'payment_status': 'verified',
        'amount': '700',
        'due_date': '2026-04-09T00:00:00'
      });
      expect(p.amount, 700);
      expect(p.billingDate, '2026-04-09');
    });

    test('summary message mirrors the web send panel copy', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePeriodPayment(
              paymentStatus: 'verified',
              amount: 123456,
              paymentMethod: 'cash',
              dueDate: '2026-04-05'),
        ],
        ledgerEntries: const [],
      );
      expect(
        financePeriodSummaryMessage(report, '04/2026'),
        'Receipts ₹1,23,456 · Expenses ₹0 · Net ₹1,23,456 for 04/2026.',
      );
    });
  });

  group('payment channel + heads + dates', () {
    test('normalizePaymentChannel matches the web classification', () {
      expect(normalizePaymentChannel(null), PaymentChannel.cash);
      expect(normalizePaymentChannel('Cash'), PaymentChannel.cash);
      expect(normalizePaymentChannel('UPI'), PaymentChannel.bank);
      expect(normalizePaymentChannel('bank_transfer'), PaymentChannel.bank);
      expect(normalizePaymentChannel('Net Banking'), PaymentChannel.bank);
      expect(normalizePaymentChannel('cheque'), PaymentChannel.bank);
      expect(normalizePaymentChannel('bank'), PaymentChannel.other);
      expect(normalizePaymentChannel(''), PaymentChannel.other);
      expect(normalizePaymentChannel('other'), PaymentChannel.other);
    });

    test('expense head parsing handles legacy bracket titles', () {
      expect(financeExpenseHeadFromLedgerTitle('[Electricity] March bill'),
          'Electricity');
      expect(financeExpenseHeadFromLedgerTitle('[Events & Functions] Tent'),
          'Tent');
      expect(financeExpenseHeadFromLedgerTitle('  '), 'Society expense');
      expect(financeExpenseHeadFromLedgerTitle(null), 'Society expense');
      expect(financeExpenseHeadFromLedgerEntry('[Caterer] Dinner', 'food'),
          'Event food — Caterer');
      expect(inferMajorHeadFromGroupName('Security guard salary'),
          'SALARY & WAGES');
      expect(
          inferMajorHeadFromGroupName('Lift AMC'), 'OPERATION & MAINTENANCE');
      expect(inferMajorHeadFromGroupName('Corpus legal fund'),
          'CORPUS FUND (LEGAL)');
      expect(inferMajorHeadFromGroupName(''), 'MISCELLANEOUS');
    });

    test('date helpers', () {
      expect(addDaysYmd('2026-02-28', 1), '2026-03-01');
      expect(addDaysYmd('2026-03-01', -1), '2026-02-28');
      expect(dateInInclusiveRange('2026-04-30', '2026-04-01', '2026-04-30'),
          isTrue);
      expect(dateInInclusiveRange('2026-05-01', '2026-04-01', '2026-04-30'),
          isFalse);
      expect(dateInInclusiveRange('not-a-date', '2026-04-01', '2026-04-30'),
          isFalse);
      expect(isDateBefore('2026-03-31', '2026-04-01'), isTrue);
      expect(isDateBefore('2026-04-01', '2026-04-01'), isFalse);
      expect(
        ledgerTransactionDate(
            transactionDate: null,
            entryMonth: null,
            createdAt: '2026-01-09T10:00:00Z'),
        '2026-01-09',
      );
      expect(clampFinancePeriodFrom('2025-12-01'), '2026-02-01');
      expect(defaultFinancePeriodFrom(DateTime(2026, 7, 19)), '2026-07-01');
      expect(defaultFinancePeriodTo(DateTime(2026, 7, 9)), '2026-07-09');
      expect(financeReportingMonthRange('2028-02'),
          (from: '2028-02-01', to: '2028-02-29'));
    });

    test('opening anchor form helpers', () {
      final form = createDefaultOpeningAnchorForm();
      expect(form.asOnDate, kDefaultOpeningAnchorDate);
      expect(form.cashAmount, '0');
      expect(parseOptionalAnchorAmount(' '), isNull);
      expect(parseOptionalAnchorAmount('12.5'), 12.5);
      expect(parseOptionalAnchorAmount('abc'), isNull);
      final f2 = openingAnchorRowToForm(anchor('2026-02-28', bank: 18145));
      expect(f2.bankAmount, '18145');
      expect(f2.cashAmount, '');
    });
  });
}
