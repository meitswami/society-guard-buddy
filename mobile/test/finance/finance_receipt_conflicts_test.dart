// Port of src/lib/financeReceiptConflicts.test.ts
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_receipt_conflicts.dart';

FinancePayment pay({
  required String id,
  String chargeId = 'june-charge',
  String paymentMethod = 'cash',
  String paymentStatus = 'verified',
  String dueDate = '2026-06-15',
}) =>
    FinancePayment(
      id: id,
      chargeId: chargeId,
      flatNumber: '604',
      amount: 2500,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      dueDate: dueDate,
      createdAt: '2026-06-15T00:00:00Z',
    );

void main() {
  group('receipt double-entry guards', () {
    test('treats cash and UPI as the same receipt head for a flat/charge/month',
        () {
      final existing = [
        pay(id: 'p1', paymentMethod: 'cash', dueDate: '2026-06-10')
      ];
      final conflicts = findReceiptHeadConflicts(existing, const [
        ReceiptHeadRecordingTarget(
            flatNumber: '604',
            chargeId: 'june-charge',
            dueDate: '2026-06-20',
            paymentMethod: 'upi'),
      ]);
      expect(conflicts, hasLength(1));
      expect(
          paymentDuplicateGroupKey(existing[0]), '604||june-charge||2026-06');
    });

    test(
        'blocks a second monthly maintenance receipt for the same flat/month across charge titles',
        () {
      final existing = [
        pay(
            id: 'july-row',
            chargeId: 'july-charge',
            dueDate: '2026-07-19',
            paymentMethod: 'upi')
      ];
      final conflicts = findMonthlyMaintenanceMonthConflicts(
        existing,
        const ['june-charge', 'july-charge'],
        const [(flatNumber: '604', dueDate: '2026-07-19')],
      );
      expect(conflicts.map((c) => c.id).toList(), ['july-row']);
    });

    test('allows the same flat in a different billing month', () {
      final existing = [pay(id: 'june-row', dueDate: '2026-06-15')];
      final conflicts = findMonthlyMaintenanceMonthConflicts(
        existing,
        const ['june-charge', 'july-charge'],
        const [(flatNumber: '604', dueDate: '2026-07-19')],
      );
      expect(conflicts, isEmpty);
    });

    test('ignores rejected rows', () {
      final existing = [pay(id: 'r1', paymentStatus: 'rejected')];
      expect(
        findReceiptHeadConflicts(existing, const [
          ReceiptHeadRecordingTarget(
              flatNumber: '604',
              chargeId: 'june-charge',
              dueDate: '2026-06-20'),
        ]),
        isEmpty,
      );
    });
  });
}
