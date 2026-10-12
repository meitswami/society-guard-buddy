// Port of src/lib/financePeriodReport.test.ts (Finance → Totals private copy).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/cash_bank_channel.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_period_report.dart';

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
      final r = financeReportingMonthRange('2026-02');
      expect(r.from, '2026-02-01');
      expect(r.to, '2026-02-28');
    });

    test('finds latest anchor before period start', () {
      const anchors = [
        OpeningBalanceAnchor(asOnDate: '2026-01-31', bankAmount: 10000),
        OpeningBalanceAnchor(asOnDate: '2026-02-28', bankAmount: 18145),
      ];
      expect(findApplicableOpeningAnchor(anchors, '2026-03-01')?.asOnDate, '2026-02-28');
      expect(findApplicableOpeningAnchor(anchors, '2026-02-28')?.asOnDate, '2026-01-31');
      expect(findApplicableOpeningAnchor(anchors, '2026-01-31'), isNull);
    });

    test('uses manual bank anchor for period starting after anchor date', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-03-01',
        periodTo: '2026-03-31',
        payments: const [],
        ledgerEntries: const [],
        openingBalanceAnchors: const [OpeningBalanceAnchor(asOnDate: '2026-02-28', bankAmount: 18145)],
      );
      expect(report.openingBank, 18145);
      expect(report.openingBankFromManualAnchor, isTrue);
      expect(report.appliedOpeningAnchor?.bankAmount, 18145);
    });

    test('uses manual cash anchor of zero for period starting after anchor date', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-03-01',
        periodTo: '2026-03-31',
        payments: const [],
        ledgerEntries: const [],
        openingBalanceAnchors: const [OpeningBalanceAnchor(asOnDate: '2026-02-28', cashAmount: 0)],
      );
      expect(report.openingCash, 0);
      expect(report.openingCashFromManualAnchor, isTrue);
    });

    test('adds bank movement between anchor and period start', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePayment(paymentStatus: 'verified', amount: 500, paymentMethod: 'upi', dueDate: '2026-03-15'),
        ],
        ledgerEntries: const [],
        openingBalanceAnchors: const [OpeningBalanceAnchor(asOnDate: '2026-02-28', bankAmount: 18145)],
      );
      expect(report.openingBank, 18645);
    });
  });

  group('finance period report head-wise columns', () {
    test('groups verified receipts by head with cash, bank, and total columns', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePayment(
            paymentStatus: 'verified',
            amount: 1000,
            paymentMethod: 'cash',
            dueDate: '2026-04-05',
            chargeId: 'ch-maint',
          ),
          FinancePayment(
            paymentStatus: 'verified',
            amount: 2500,
            paymentMethod: 'upi',
            dueDate: '2026-04-10',
            chargeId: 'ch-corpus',
          ),
        ],
        ledgerEntries: const [
          FinanceLedgerRow(
            id: 'fe-ledger',
            destination: 'current_month_maintenance',
            totalAmount: 500,
            paymentMethod: 'cash',
            transactionDate: '2026-04-12',
          ),
        ],
        chargeMajorHeadById: const {'ch-maint': 'OPERATION & MAINTENANCE', 'ch-corpus': 'SOCIETY CORPUS FUND'},
      );

      expect(report.receiptByHead.map((e) => e.key).toList(), ['SOCIETY CORPUS FUND', 'OPERATION & MAINTENANCE']);
      expect(report.receiptByHead[0].value, ChannelByHeadRow(bank: 2500, total: 2500));
      expect(report.receiptByHead[1].value, ChannelByHeadRow(cash: 1500, total: 1500));
      expect(report.receiptByMethod, ChannelTotals(cash: 1500, bank: 2500));
      expect(report.totalReceipts, 4000);
    });

    test('groups separate-entry expenses by head with cash, bank, and total columns', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [],
        ledgerEntries: const [
          FinanceLedgerRow(
            id: 'fe-1',
            destination: 'separate_entry',
            totalAmount: 800,
            paymentMethod: 'cash',
            title: 'Electricity',
            transactionDate: '2026-04-03',
          ),
          FinanceLedgerRow(
            id: 'fe-2',
            destination: 'separate_entry',
            totalAmount: 1200,
            paymentMethod: 'upi',
            title: 'Electricity',
            transactionDate: '2026-04-08',
          ),
          FinanceLedgerRow(
            id: 'fe-3',
            destination: 'separate_entry',
            totalAmount: 300,
            paymentMethod: 'cash',
            title: 'Security salary',
            transactionDate: '2026-04-15',
          ),
        ],
      );

      expect(report.expenseByHead.map((e) => e.key).toList(), ['Electricity', 'Security salary']);
      expect(report.expenseByHead[0].value, ChannelByHeadRow(cash: 800, bank: 1200, total: 2000));
      expect(report.expenseByHead[1].value, ChannelByHeadRow(cash: 300, total: 300));
      expect(report.expenseByMethod, ChannelTotals(cash: 1100, bank: 1200));
      expect(report.totalExpenses, 2300);
    });

    test('includes February 2026 society expenses in the Feb period report', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-02-01',
        periodTo: '2026-02-28',
        payments: const [],
        ledgerEntries: const [
          FinanceLedgerRow(
            id: 'fe-feb-1',
            destination: 'separate_entry',
            totalAmount: 100000,
            paymentMethod: 'bank_transfer',
            entryMonth: '2026-02',
            transactionDate: '2026-02-10',
          ),
          FinanceLedgerRow(
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
      expect(report.expenseByMethod, ChannelTotals(cash: 68751, bank: 100000));
    });

    test('linked ledger inflows are not double counted', () {
      final report = computeFinancePeriodReport(
        periodFrom: '2026-04-01',
        periodTo: '2026-04-30',
        payments: const [
          FinancePayment(
            paymentStatus: 'verified',
            amount: 1000,
            paymentMethod: 'cash',
            dueDate: '2026-04-05',
            financeEntryId: 'fe-1',
          ),
        ],
        ledgerEntries: const [
          FinanceLedgerRow(id: 'fe-1', destination: 'current_month_maintenance', totalAmount: 1000, transactionDate: '2026-04-05'),
        ],
      );
      expect(report.totalReceipts, 1000);
      expect(report.extraLedgerReceipt, 0);
      expect(report.receiptByHead.single.key, 'Uncategorized');
    });
  });
}
