// Port of src/lib/financeAuditFixQueue.test.ts.
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/audit/logic/finance_audit_detection.dart';

AuditPaymentRow pay({
  required String id,
  String chargeId = 'c1',
  String flatNumber = 'A-101',
  double amount = 1000,
  String paymentMethod = 'cash',
  String paymentStatus = 'verified',
  String? dueDate = '2024-01-01',
  String? paymentDate,
  String createdAt = '2024-01-02T00:00:00Z',
  String? financeEntryId,
}) =>
    AuditPaymentRow(
      id: id,
      chargeId: chargeId,
      flatNumber: flatNumber,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      dueDate: dueDate,
      paymentDate: paymentDate,
      createdAt: createdAt,
      financeEntryId: financeEntryId,
    );

void main() {
  group('buildAuditFixQueue', () {
    test('orders entries from earliest discrepancy date to latest', () {
      final duplicateGroups = [
        DuplicatePaymentGroup(
          flatNumber: 'A-101',
          chargeId: 'c1',
          chargeTitle: 'Maintenance',
          month: '2024-03',
          paymentMethod: 'cash',
          count: 2,
          totalAmount: 2000,
          payments: [
            pay(id: 'p-old', dueDate: '2024-03-01', createdAt: '2024-03-01'),
            pay(id: 'p-new', dueDate: '2024-03-01', createdAt: '2024-03-15'),
          ],
        ),
      ];

      const ledgerOvercountIssues = [
        LedgerOvercountMonth(
          month: '2024-02',
          paymentTotal: 1000,
          reportTotal: 2000,
          excess: 1000,
          unlinkedLedger: [
            LedgerOvercountEntry(
              id: 'fe-1',
              title: 'Extra receipt',
              totalAmount: 1000,
              entryMonth: '2024-02',
              recordMode: 'flats_only',
              destination: 'current_month_maintenance',
              paymentMethod: 'cash',
              createdAt: '2024-02-10',
            ),
          ],
          dateBoundary: [],
        ),
      ];

      const recordingMismatchMonths = [
        RecordingMismatchMonth(
          month: '2024-04',
          paymentsTotal: 2000,
          ledgerTotal: 1000,
          difference: 1000,
          sources: [
            RecordingMismatchSource(
              kind: MismatchSourceKind.orphanPayment,
              id: 'p-orphan',
              date: '2024-04-05',
              label: 'Flat B-202 — no ledger link',
              amount: 1000,
            ),
          ],
        ),
      ];

      final queue = buildAuditFixQueue(AuditFixQueueInput(
        duplicateGroups: duplicateGroups,
        ledgerOvercountIssues: ledgerOvercountIssues,
        recordingMismatchMonths: recordingMismatchMonths,
        orphanedPayments: const [],
        cashTrace: null,
        bankTrace: null,
      ));

      expect(queue.length, greaterThanOrEqualTo(4));
      final dates = queue.map((q) => q.sortDate).toList();
      expect(dates, [...dates]..sort());
      expect(queue[0].sortDate, '2024-02-01');
      expect(queue[0].entryId, 'fe-1');
      expect(queue.firstWhere((q) => q.entryId == 'p-new').action,
          AuditFixAction.delete);
      expect(queue.firstWhere((q) => q.entryId == 'p-old').action,
          AuditFixAction.review);
    });

    test(
        'deduplicates the same entry across recording mismatch and orphan lists',
        () {
      final orphaned = [pay(id: 'same-id', dueDate: '2023-06-01')];
      const recordingMismatchMonths = [
        RecordingMismatchMonth(
          month: '2023-06',
          paymentsTotal: 1000,
          ledgerTotal: 0,
          difference: 1000,
          sources: [
            RecordingMismatchSource(
              kind: MismatchSourceKind.orphanPayment,
              id: 'same-id',
              date: '2023-06-01',
              label: 'Flat A-101 — no ledger link',
              amount: 1000,
            ),
          ],
        ),
      ];

      final queue = buildAuditFixQueue(AuditFixQueueInput(
        duplicateGroups: const [],
        ledgerOvercountIssues: const [],
        recordingMismatchMonths: recordingMismatchMonths,
        orphanedPayments: orphaned,
        cashTrace: null,
        bankTrace: null,
      ));

      expect(queue.where((q) => q.entryId == 'same-id'), hasLength(1));
    });

    test(
        'critical items come before warnings on the same date; channel culprits are reviews',
        () {
      final txns = buildChannelTransactions(
        [pay(id: 'r1', dueDate: '2024-05-01', amount: 100)],
        const [
          AuditLedgerRow(
            id: 'e1',
            recordMode: 'society_pool',
            destination: 'separate_entry',
            totalAmount: 500,
            paymentMethod: 'cash',
            paymentStatus: 'verified',
            entryMonth: '2024-05',
            createdAt: '2024-05-01T00:00:00Z',
            title: 'Diesel',
          ),
        ],
        <String>{},
      );
      final cashTrace = traceChannelBalanceDeficit(txns, PaymentChannel.cash);
      final queue = buildAuditFixQueue(AuditFixQueueInput(
        duplicateGroups: const [],
        ledgerOvercountIssues: const [],
        recordingMismatchMonths: const [],
        orphanedPayments: [pay(id: 'orphan', dueDate: '2024-05-01')],
        cashTrace: cashTrace,
        bankTrace: null,
      ));
      expect(queue.map((q) => q.entryId), ['e1', 'orphan']);
      expect(queue.first.severity, FixSeverity.critical);
      expect(queue.first.action, AuditFixAction.review);
      expect(queue.first.issueLabel, 'Negative cash balance');
      expect(queue.last.severity, FixSeverity.warning);
    });

    test('Hindi copy', () {
      final queue = buildAuditFixQueue(
        AuditFixQueueInput(
          duplicateGroups: const [],
          ledgerOvercountIssues: const [],
          recordingMismatchMonths: const [],
          orphanedPayments: [pay(id: 'o1', dueDate: null, createdAt: '')],
          cashTrace: null,
          bankTrace: null,
        ),
        hi: true,
      );
      expect(queue.single.issueLabel, 'बिना लिंक भुगतान');
      expect(queue.single.sortDate, '9999-12-31');
      expect(queue.single.month, 'unknown');
    });
  });
}
