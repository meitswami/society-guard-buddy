// Port of src/lib/financeFlatReport.test.ts
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_flat_report.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';

void main() {
  const flats = [
    SocietyFlatRow(
        id: 'f1', flatNumber: 'A-101', ownerName: 'Owner', isOccupied: true)
  ];

  test('aggregates verified maintenance payments in range', () {
    final rows = buildFlatReportRows(
      from: '2026-03-01',
      to: '2026-03-31',
      selectedFlat: 'all',
      payments: const [
        FinancePayment(
          paymentStatus: 'verified',
          flatNumber: 'A-101',
          amount: 1000,
          chargeId: 'c1',
          paymentMethod: 'cash',
          dueDate: '2026-03-10',
        ),
      ],
      ledgerEntries: const [],
      flatReportExpenses: const [],
      flatReportSplits: const [],
      flats: flats,
      primaryByFlatId: const {'f1': 'Ravi'},
      charges: const [FinanceCharge(id: 'c1', title: 'March Maintenance')],
    );

    expect(rows, hasLength(1));
    expect(rows[0].maintenancePaid, 1000);
    expect(rows[0].residentName, 'Ravi');
    expect(rows[0].netPosition, 1000);
    expect(rows[0].details.single.title, 'March Maintenance');
  });

  test('filters by selected flat', () {
    final rows = buildFlatReportRows(
      from: '2026-03-01',
      to: '2026-03-31',
      selectedFlat: 'B-202',
      payments: const [
        FinancePayment(
            paymentStatus: 'verified',
            flatNumber: 'A-101',
            amount: 1000,
            dueDate: '2026-03-10'),
      ],
      ledgerEntries: const [],
      flatReportExpenses: const [],
      flatReportSplits: const [],
      flats: const [
        SocietyFlatRow(id: 'f1', flatNumber: 'A-101', isOccupied: true),
        SocietyFlatRow(id: 'f2', flatNumber: 'B-202', isOccupied: true),
      ],
      primaryByFlatId: const {},
      charges: const [],
    );

    expect(rows, isEmpty);
  });

  test('subtracts expense splits from net position', () {
    final rows = buildFlatReportRows(
      from: '2026-03-01',
      to: '2026-03-31',
      selectedFlat: 'all',
      payments: const [
        FinancePayment(
            paymentStatus: 'verified',
            flatNumber: 'A-101',
            amount: 2000,
            dueDate: '2026-03-10'),
      ],
      ledgerEntries: const [],
      flatReportExpenses: const [
        FlatReportExpense(
            id: 'e1',
            title: 'Lift repair',
            expenseDate: '2026-03-15',
            paymentMethod: 'cash',
            groupName: 'Repairs'),
      ],
      flatReportSplits: const [
        FlatReportSplit(
            expenseId: 'e1', flatNumber: 'A-101', amount: 500, isSettled: true)
      ],
      flats: flats,
      primaryByFlatId: const {},
      charges: const [],
    );

    expect(rows[0].expenseShare, 500);
    expect(rows[0].settledAmount, 500);
    expect(rows[0].netPosition, 1500);
    expect(rows[0].residentName, 'Owner');
  });

  test(
      'counts ledger allocations but skips flats_only entries already linked to payments',
      () {
    final rows = buildFlatReportRows(
      from: '2026-03-01',
      to: '2026-03-31',
      selectedFlat: 'all',
      payments: const [
        FinancePayment(
          paymentStatus: 'verified',
          flatNumber: 'A-101',
          amount: 1000,
          dueDate: '2026-03-10',
          financeEntryId: 'fe-1',
        ),
      ],
      ledgerEntries: const [
        FinanceLedgerRow(
          id: 'fe-1',
          recordMode: 'flats_only',
          destination: 'current_month_maintenance',
          transactionDate: '2026-03-10',
          allocations: [FinanceAllocation(flatNumber: 'A-101', amount: 1000)],
        ),
        FinanceLedgerRow(
          id: 'fe-2',
          recordMode: 'outsider_only',
          destination: 'current_month_maintenance',
          transactionDate: '2026-03-12',
          title: 'Sponsor',
          allocations: [
            FinanceAllocation(flatNumber: 'A-101', amount: 250),
            FinanceAllocation(flatNumber: 'SOCIETY', amount: 250),
          ],
        ),
        FinanceLedgerRow(
          id: 'fe-3',
          destination: 'separate_entry',
          transactionDate: '2026-03-12',
          allocations: [FinanceAllocation(flatNumber: 'A-101', amount: 999)],
        ),
      ],
      flatReportExpenses: const [],
      flatReportSplits: const [],
      flats: flats,
      primaryByFlatId: const {},
      charges: const [],
    );

    expect(rows.single.maintenancePaid, 1250);
    expect(rows.single.maintenanceCount, 2);
    expect(rows.single.details.first.date, '2026-03-12');
  });
}
