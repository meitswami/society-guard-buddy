// Port of src/lib/financeChargeUtils.test.ts
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_charge_helpers.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_ledger_display.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';

void main() {
  group('financeChargeHelpers', () {
    test('detects monthly maintenance charges', () {
      expect(isMonthlyMaintenanceTitleFreq('April Monthly Maintenance', 'monthly'), isTrue);
      expect(isMonthlyMaintenanceTitleFreq('Lift repair', 'once'), isFalse);
      expect(
        isMonthlyMaintenanceCharge(const FinanceCharge(id: 'c', title: 'April Monthly Maintenance', frequency: 'monthly')),
        isTrue,
      );
    });

    test('builds current month charge title', () {
      final title = buildCurrentMonthChargeTitle(DateTime(2026, 4, 15));
      expect(title, 'April Monthly Maintenance');
      expect(isCurrentMonthChargeTitle(title, DateTime(2026, 4, 15)), isTrue);
    });

    test('normalizes charge titles', () {
      expect(normalizeTitle('  Hello World '), 'hello world');
    });

    test('derives payment month value from billing date', () {
      expect(paymentMonthValue('2026-03-10'), '2026-03');
      expect(paymentMonthValue(null), '');
    });

    test('requires billing month to match month named in receipt type', () {
      expect(monthNameFromChargeTitle('June Monthly Maintenance'), 'june');
      expect(chargeTitleMatchesBillingMonth('June Monthly Maintenance', '2026-06-19'), isTrue);
      expect(chargeTitleMatchesBillingMonth('June Monthly Maintenance', '2026-07-19'), isFalse);
      expect(chargeTitleMatchesBillingMonth('Water Softner Installation', '2026-07-19'), isTrue);
    });

    test('isCurrentMonthChargeTitle accepts MM/yyyy and MM-yyyy', () {
      expect(isCurrentMonthChargeTitle('Maintenance 04/2026', DateTime(2026, 4, 1)), isTrue);
      expect(isCurrentMonthChargeTitle('Maintenance 04-2026', DateTime(2026, 4, 1)), isTrue);
      expect(isCurrentMonthChargeTitle('Maintenance 05-2026', DateTime(2026, 4, 1)), isFalse);
    });

    test('chargeForUnpaidFilters picks month-named charge', () {
      final charges = [
        const FinanceCharge(id: 'a', title: 'March Monthly Maintenance', amount: 2000, frequency: 'monthly'),
        const FinanceCharge(id: 'b', title: 'April Monthly Maintenance', amount: 2500, frequency: 'monthly'),
        const FinanceCharge(id: 'c', title: 'Lift AMC', amount: 9000, frequency: 'yearly'),
      ];
      expect(chargeForUnpaidFilters(charges, 'monthly_maintenance', '2026-04')?.amount, 2500);
      expect(chargeForUnpaidFilters(charges, 'yearly', 'all')?.title, 'Lift AMC');
      expect(chargeForUnpaidFilters(charges, 'corpus', 'all'), isNull);
      expect(chargeForUnpaidFilters(charges, 'other', 'all'), isNull);
    });
  });

  group('financeLedgerDisplay', () {
    const baseLedger = FinanceLedgerRow(
      id: '1',
      societyId: 's1',
      recordMode: 'society_pool',
      destination: 'current_month_maintenance',
      allocationStyle: 'none',
      entryMonth: '2026-03',
      transactionDate: '2026-03-01',
      totalAmount: 1000,
      aggregateFlatCount: 0,
      paymentMethod: 'cash',
      paymentStatus: 'verified',
      createdAt: '2026-03-01',
    );

    test('identifies society pool ledger rows', () {
      expect(isLedgerInSocietyPool(baseLedger), isTrue);
      expect(
        isLedgerInSocietyPool(const FinanceLedgerRow(id: '1', recordMode: 'society_pool', expenseId: 'exp-1')),
        isFalse,
      );
      expect(
        isLedgerInSocietyPool(const FinanceLedgerRow(id: '1', recordMode: 'society_pool', distributedAt: '2026-03-02')),
        isFalse,
      );
      expect(
        isLedgerInSocietyPool(const FinanceLedgerRow(
          id: '1',
          recordMode: 'society_pool',
          allocations: [FinanceAllocation(flatNumber: '101', amount: 500)],
        )),
        isFalse,
      );
    });

    test('formats event contribution labels', () {
      expect(
        eventContribRefLabel(const EventContribRefRow(
          id: 'c1',
          eventId: 'e1',
          flatNumber: 'A-101',
          amount: 500,
          paymentMethod: 'cash',
          residentName: 'Ravi',
          receiptBasis: 'flat',
          splitMode: 'headcount',
        )),
        'Flat A-101 · Ravi · headcount',
      );
      expect(
        eventContribRefLabel(const EventContribRefRow(id: 'c2', receiptBasis: 'non_flat', outsiderName: 'Sponsor')),
        'Sponsor',
      );
      expect(eventContribRefLabel(const EventContribRefRow(id: 'c3')), 'Receipt (no flat)');
    });
  });
}
