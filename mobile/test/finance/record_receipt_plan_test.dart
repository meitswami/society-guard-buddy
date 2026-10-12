// Record receipt allocation math (web FinanceManager.recordPayment).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/record_receipt_plan.dart';

void main() {
  const flats = [
    SocietyFlatRow(
        id: 'f1', flatNumber: '101', ownerName: 'Owner 101', isOccupied: true),
    SocietyFlatRow(
        id: 'f2', flatNumber: '102', ownerName: 'Owner 102', isOccupied: true),
  ];
  const charges = [
    FinanceCharge(
        id: 'june',
        title: 'June Monthly Maintenance',
        amount: 2500,
        frequency: 'monthly')
  ];
  final now = DateTime(2026, 6, 20, 10);

  RecordReceiptBuild build(RecordReceiptInput f) => buildRecordReceiptPlan(
        f: f,
        societyId: 's1',
        adminName: 'Admin',
        flats: flats,
        charges: charges,
        primaryByFlatId: const {'f1': 'Ravi'},
        screenshotUrl: null,
        now: now,
      );

  group('validateRecordReceipt', () {
    test('pool needs a positive amount; other modes need flats', () {
      expect(
        validateRecordReceipt(
            const RecordReceiptInput(
                recordMode: kModeSocietyPool, dueDate: '2026-06-10'),
            charges),
        RecordReceiptIssue.poolAmountMissing,
      );
      expect(
        validateRecordReceipt(
            const RecordReceiptInput(
                dueDate: '2026-06-10', amount: '2500', chargeId: 'june'),
            charges),
        RecordReceiptIssue.noFlatsSelected,
      );
    });

    test('flats only without charge aborts silently like web', () {
      expect(
        validateRecordReceipt(
            const RecordReceiptInput(
                dueDate: '2026-06-10', selectedFlats: ['101']),
            charges),
        RecordReceiptIssue.silentAbort,
      );
    });

    test('billing date must match the month in the receipt type title', () {
      expect(
        validateRecordReceipt(
          const RecordReceiptInput(
              dueDate: '2026-07-10',
              selectedFlats: ['101'],
              amount: '2500',
              chargeId: 'june'),
          charges,
        ),
        RecordReceiptIssue.chargeMonthMismatch,
      );
      expect(
        validateRecordReceipt(
          const RecordReceiptInput(
              dueDate: '2026-06-10',
              selectedFlats: ['101'],
              amount: '2500',
              chargeId: 'june'),
          charges,
        ),
        isNull,
      );
    });

    test('outsider modes validate name, amount and charge', () {
      expect(
        validateRecordReceipt(
          const RecordReceiptInput(
              recordMode: kModeOutsiderOnly,
              dueDate: '2026-06-10',
              selectedFlats: ['101']),
          charges,
        ),
        RecordReceiptIssue.outsiderNameMissing,
      );
      expect(
        validateRecordReceipt(
          const RecordReceiptInput(
            recordMode: kModeOutsiderOnly,
            dueDate: '2026-06-10',
            selectedFlats: ['101'],
            outsiderName: 'Vendor',
            outsiderAmount: '600',
          ),
          charges,
        ),
        RecordReceiptIssue.outsiderChargeMissing,
      );
      expect(
        validateRecordReceipt(
          const RecordReceiptInput(
            recordMode: kModeFlatsPlusOutsider,
            dueDate: '2026-06-10',
            selectedFlats: ['101'],
            chargeId: 'june',
            amount: '2500',
          ),
          charges,
        ),
        RecordReceiptIssue.outsiderNameAndAmountMissing,
      );
    });
  });

  group('buildRecordReceiptPlan', () {
    test('flats only: same amount per flat, verified cash rows', () {
      final r = build(const RecordReceiptInput(
        dueDate: '2026-06-10',
        selectedFlats: ['101', '102'],
        amount: '2500',
        chargeId: 'june',
      ));
      final plan = r.plan!;
      expect(plan.totalAmount, 5000);
      expect(plan.entry['allocation_style'], 'same_per_flat');
      expect(plan.entry['destination'], 'current_month_maintenance');
      expect(plan.entry['aggregate_flat_count'], 2);
      expect(plan.entry['entry_month'], '2026-06');
      expect(plan.entry['transaction_date'], '2026-06-10');
      expect(plan.entryTitle, 'June Monthly Maintenance');
      expect(plan.counterparty, isNull);
      expect(plan.maintenancePayments, hasLength(2));
      expect(plan.maintenancePayments[0]['resident_name'], 'Ravi');
      expect(plan.maintenancePayments[1]['resident_name'], 'Owner 102');
      expect(plan.maintenancePayments[0]['payment_status'], 'verified');
      expect(plan.maintenancePayments[0]['recording_date'], '2026-06-20');
      expect(plan.recordedCount, 2);
    });

    test('flats only with bank transfer stays pending', () {
      final plan = build(const RecordReceiptInput(
        dueDate: '2026-06-10',
        selectedFlats: ['101'],
        amount: '2500',
        chargeId: 'june',
        paymentMethod: 'bank_transfer',
      )).plan!;
      expect(plan.entry['allocation_style'], 'none');
      expect(plan.maintenancePayments.single['payment_status'], 'pending');
    });

    test('outsider only split total equally into current month maintenance',
        () {
      final plan = build(const RecordReceiptInput(
        recordMode: kModeOutsiderOnly,
        allocationStyle: kAllocSplitTotal,
        dueDate: '2026-06-10',
        selectedFlats: ['101', '102'],
        outsiderName: 'Vendor',
        outsiderAmount: '600',
        chargeId: 'june',
      )).plan!;
      expect(plan.totalAmount, 600);
      expect(plan.allocations.map((a) => a.amount).toList(), [300, 300]);
      expect(plan.maintenancePayments.map((m) => m['amount']).toList(),
          [300, 300]);
      expect(plan.entryTitle, 'Outsider: Vendor');
      expect(plan.counterparty?.name, 'Vendor');
      expect(plan.entry['charge_id'], 'june');
    });

    test('outsider only to corpus posts no payment rows and no charge', () {
      final plan = build(const RecordReceiptInput(
        recordMode: kModeOutsiderOnly,
        destination: kDestCorpus,
        dueDate: '2026-06-10',
        selectedFlats: ['101', '102'],
        outsiderName: 'Donor',
        outsiderAmount: '100',
        chargeId: 'june',
      )).plan!;
      expect(plan.totalAmount, 200);
      expect(plan.maintenancePayments, isEmpty);
      expect(plan.entry['charge_id'], isNull);
      expect(plan.recordedCount, 2);
    });

    test('flats plus outsider adds the outsider share to each flat', () {
      final plan = build(const RecordReceiptInput(
        recordMode: kModeFlatsPlusOutsider,
        dueDate: '2026-06-10',
        selectedFlats: ['101', '102'],
        amount: '2500',
        outsiderName: 'Sponsor',
        outsiderAmount: '1000',
        allocationStyle: kAllocSplitTotal,
        chargeId: 'june',
      )).plan!;
      expect(plan.totalAmount, 6000);
      expect(plan.allocations.map((a) => a.amount).toList(), [3000, 3000]);
      expect(plan.maintenancePayments.map((m) => m['amount']).toList(),
          [3000, 3000]);
      expect(plan.entryTitle, 'June Monthly Maintenance + outsider (Sponsor)');
    });

    test('society pool keeps the receipt undistributed', () {
      final plan = build(const RecordReceiptInput(
        recordMode: kModeSocietyPool,
        destination: kDestSeparate,
        dueDate: '2026-06-10',
        amount: '9000',
        outsiderName: 'Bank interest',
      )).plan!;
      expect(plan.totalAmount, 9000);
      expect(plan.entry['destination'], 'corpus');
      expect(plan.entry['aggregate_flat_count'], 0);
      expect(plan.entryTitle, 'Receipt: Bank interest');
      expect(plan.counterparty?.name, 'Bank interest');
      expect(plan.allocations, isEmpty);
      expect(plan.recordedCount, 1);
    });

    test('invalid billing date fails the entry month check', () {
      final r = build(const RecordReceiptInput(
          dueDate: '', selectedFlats: ['101'], amount: '1', chargeId: 'june'));
      expect(r.issue, RecordReceiptIssue.entryMonthMismatch);
    });
  });

  test('distributePoolAmounts gives the remainder to the last flat', () {
    expect(distributePoolAmounts(1000, 3), [333.33, 333.33, 333.34]);
    expect(distributePoolAmounts(900, 3), [300, 300, 300]);
    expect(distributePoolAmounts(10, 0), isEmpty);
  });
}
