import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/audit/logic/finance_audit_detection.dart';
import 'package:kutumbika_mobile/features/admin/audit/logic/integrity_audit_engine.dart';
import 'package:kutumbika_mobile/features/admin/audit/logic/js_compat.dart';
import 'package:kutumbika_mobile/features/admin/audit/logic/manual_trace_engine.dart';

AuditPaymentRow pay({
  required String id,
  String chargeId = 'c1',
  String flat = 'A-101',
  double amount = 1000,
  String method = 'cash',
  String status = 'verified',
  String? due = '2026-03-01',
  String createdAt = '2026-03-02T00:00:00Z',
  String? fe,
}) =>
    AuditPaymentRow(
      id: id,
      chargeId: chargeId,
      flatNumber: flat,
      amount: amount,
      paymentMethod: method,
      paymentStatus: status,
      dueDate: due,
      createdAt: createdAt,
      financeEntryId: fe,
    );

AuditLedgerRow led({
  required String id,
  String mode = 'flats_only',
  String dest = 'current_month_maintenance',
  double total = 1000,
  String method = 'cash',
  String status = 'verified',
  String? month = '2026-03',
  String createdAt = '2026-03-05T00:00:00Z',
  String? title,
  int? flats,
}) =>
    AuditLedgerRow(
      id: id,
      recordMode: mode,
      destination: dest,
      totalAmount: total,
      paymentMethod: method,
      paymentStatus: status,
      entryMonth: month,
      createdAt: createdAt,
      title: title,
      aggregateFlatCount: flats,
    );

void main() {
  test('normalizePaymentChannel', () {
    expect(normalizePaymentChannel(null), PaymentChannel.cash);
    expect(normalizePaymentChannel('Cash'), PaymentChannel.cash);
    expect(normalizePaymentChannel('bank_transfer'), PaymentChannel.bank);
    // Web strips whitespace: "Bank Transfer" → "banktransfer" is not a bank key.
    expect(normalizePaymentChannel('Bank Transfer'), PaymentChannel.other);
    expect(normalizePaymentChannel('UPI'), PaymentChannel.bank);
    expect(normalizePaymentChannel('barter'), PaymentChannel.other);
  });

  test('js helpers', () {
    expect(jsLocale(1234567.5), '12,34,567.5');
    expect(jsInr(-500), '₹-500');
    expect(fmtIsoMonthToDisplay('2026-03'), '03/2026');
    expect(fmtIsoMonthToDisplay('unknown'), 'unknown');
    expect(fmtIsoDateToDisplay('2026-03-31T20:00:00+00:00'), '31/03/2026');
    expect(jsRawValue({'amount': 5000.0}), '{"amount":5000}');
    expect(jsRawValue(5000.0), '5000');
    expect(jsLocaleCompare('a-1', 'B-1'), lessThan(0));
    expect(jsLocaleCompare('2026-01', '2026-02'), lessThan(0));
  });

  test('findDuplicatePaymentGroups across charges', () {
    final rows = [
      pay(id: '1', chargeId: 'c1', method: 'cash'),
      pay(id: '2', chargeId: 'c2', method: 'upi', due: '2026-03-15'),
      pay(id: '3', flat: 'B-1'),
      pay(id: '4', status: 'rejected'),
    ];
    final groups = findDuplicatePaymentGroups(
        rows, {'c1': 'Maint', 'c2': 'Maint UPI'},
        chargeIds: ['c1', 'c2'], groupAcrossCharges: true);
    expect(groups, hasLength(1));
    expect(groups.single.chargeTitle, 'Maint + Maint UPI');
    expect(groups.single.paymentMethod, 'mixed');
    expect(groups.single.totalAmount, 2000);
    expect(groups.single.month, '2026-03');
  });

  test('findReceiptHeadLookupGroups includes single entries and filters', () {
    final rows = [pay(id: '1'), pay(id: '2', flat: 'B-1', due: '2026-04-01')];
    final r = findReceiptHeadLookupGroups(rows, {'c1': 'Maint'},
        const ReceiptHeadLookupFilter(flatNumber: 'a-101'));
    expect(r, hasLength(1));
    expect(r.single.count, 1);
    final byMonth = findReceiptHeadLookupGroups(
        rows, {}, const ReceiptHeadLookupFilter(month: '2026-04'));
    expect(byMonth.single.flatNumber, 'B-1');
    expect(byMonth.single.chargeTitle, 'Unknown receipt head');
  });

  test('receipt head conflicts', () {
    final existing = [pay(id: '1'), pay(id: '2', chargeId: 'c2')];
    final c = findReceiptHeadConflicts(existing, const [
      ReceiptHeadRecordingTarget(
          flatNumber: 'A-101', dueDate: '2026-03-20', chargeId: 'c1')
    ]);
    expect(c.map((p) => p.id), ['1']);
    final m = findMonthlyMaintenanceMonthConflicts(
        existing, ['c1', 'c2'], [(flatNumber: 'A-101', dueDate: '2026-03-09')]);
    expect(m, hasLength(2));
  });

  test(
      'analyzeLedgerOvercountByMonth flags unlinked receipts and date boundary',
      () {
    final payments = [
      pay(id: 'p1', fe: 'fe-linked'),
      pay(id: 'p2', due: '2026-04-01', fe: 'fe-boundary')
    ];
    final ledger = [
      led(id: 'fe-linked'),
      led(id: 'fe-orphan', title: 'Extra', total: 500),
      led(id: 'fe-boundary', month: '2026-03'),
      led(id: 'exp', dest: 'separate_entry', total: 9999),
    ];
    final issues = analyzeLedgerOvercountByMonth(payments, ledger);
    expect(issues, hasLength(1));
    final march = issues.single;
    expect(march.month, '2026-03');
    expect(march.excess, 500);
    expect(march.unlinkedLedger.single.id, 'fe-orphan');
    expect(march.dateBoundary.single.payment.id, 'p2');
    expect(march.dateBoundary.single.entryMonth, '2026-03');
  });

  test('traceChannelBalanceDeficit finds the fault date', () {
    final txns = buildChannelTransactions(
      [pay(id: 'r1', due: '2026-03-01', amount: 1000)],
      [
        led(id: 'e1', dest: 'separate_entry', month: '2026-03', total: 400),
        led(id: 'e2', dest: 'separate_entry', month: '2026-04', total: 800)
      ],
      <String>{},
    );
    final t = traceChannelBalanceDeficit(txns, PaymentChannel.cash)!;
    expect(t.firstNegativeDate, '2026-04-01');
    expect(t.balanceBeforeFault, 600);
    expect(t.finalBalance, -200);
    expect(t.monthlyBreakdown.map((m) => m.closingBalance), [600, -200]);
    expect(formatChannelBalanceFaultTrace(t),
        contains('Fault origin: 2026-04-01'));
    expect(traceChannelBalanceDeficit(txns, PaymentChannel.bank), isNull);
  });

  test('analyzeRecordingMismatchByMonth', () {
    final issues = analyzeRecordingMismatchByMonth(
      [pay(id: 'p1'), pay(id: 'p2', flat: 'B-1', fe: 'fe1')],
      [led(id: 'fe1'), led(id: 'fe2', total: 3000, title: 'Bulk')],
    );
    expect(issues.single.difference, -2000);
    expect(issues.single.sources.map((s) => s.kind),
        [MismatchSourceKind.orphanPayment, MismatchSourceKind.orphanLedger]);
    expect(formatRecordingMismatchFaultTrace(issues),
        contains('ledger exceeds payments'));
  });

  test('computeIntegrityAudit end-to-end', () {
    final result = computeIntegrityAudit(
      IntegrityAuditInput(
        charges: const [
          AuditChargeRow(
              id: 'c1', title: 'Maint', amount: 1000, frequency: 'Monthly')
        ],
        payments: [
          pay(id: 'p1', fe: 'fe1'),
          pay(id: 'p2', fe: 'fe1', amount: 1200),
          pay(id: 'p3', status: 'pending', createdAt: '2026-01-01T00:00:00Z'),
        ],
        ledger: [
          led(id: 'fe1', total: 2200, flats: 3),
          led(id: 'x', dest: 'separate_entry', total: 5000)
        ],
        flats: const [
          AuditFlatRow(id: 'f1', flatNumber: 'A-101', isOccupied: true),
          AuditFlatRow(id: 'f2', flatNumber: 'B-1', isOccupied: null)
        ],
      ),
      now: DateTime(2026, 3, 20),
    );
    final titles = result.findings.map((f) => f.title).toList();
    expect(titles.first, startsWith('Negative Cash Balance: ₹2,800'));
    expect(titles, contains('1 Duplicate Payment Group Found'));
    expect(titles, contains('1 Ledger Entries with Flat Count Mismatch'));
    expect(titles, contains('1 Payment with Non-Standard Amount'));
    expect(titles, contains('1 Payment Pending > 7 Days'));
    expect(titles, contains('1 Flat Unpaid This Month (03/2026)'));
    expect(result.summary.critical, 2);
    expect(result.fixQueue, isNotEmpty);
  });

  test('computeManualTrace', () {
    final r = computeManualTrace(
      charges: const [
        AuditChargeRow(
            id: 'c1', title: 'Maint', amount: 1000, frequency: 'monthly')
      ],
      payments: [pay(id: 'p1', fe: 'fe1'), pay(id: 'p2')],
      ledger: [led(id: 'fe1'), led(id: 'orphan', total: 700, title: 'Extra')],
      month: '2026-03',
      expectedAmount: '2000',
      source: TraceSource.periodReport,
    );
    expect(r.computedTotal, 2700);
    expect(r.difference, 700);
    expect(r.findings.first.title, '1 Unlinked Ledger Entry/Entries — ₹700');
    expect(r.findings.last.title, 'Discrepancy Breakdown: +₹700');
    final clean = computeManualTrace(
        charges: const [],
        payments: const [],
        ledger: const [],
        month: '2026-03',
        expectedAmount: '',
        source: TraceSource.flatReport);
    expect(clean.expectedTotal, isNull);
    expect(clean.findings.single.title, 'No structural issues found');
  });
}
