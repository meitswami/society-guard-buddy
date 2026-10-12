// Port of src/lib/bankReconciliation.test.ts (+ extra coverage for the Dart port).
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/audit/logic/bank_reconciliation.dart';

ReconPaymentInput _payment({
  required String id,
  required String flat,
  required double amount,
  required String due,
  String? txn,
  String method = 'upi',
  String status = 'verified',
}) =>
    ReconPaymentInput(
      id: id,
      flatNumber: flat,
      amount: amount,
      paymentMethod: method,
      paymentStatus: status,
      dueDate: due,
      paymentDate: null,
      createdAt: due,
      transactionId: txn,
    );

void main() {
  group('parseBankStatementCsv', () {
    test('parses standard date,amount,description,reference CSV', () {
      const csv = 'date,amount,description,reference\n'
          '2026-04-01,5000,UPI Flat A-101,UTR123456789\n'
          '2026-04-02,-12000,Vendor payment,NEFT987654';
      final rows = parseBankStatementCsv(csv);
      expect(rows, hasLength(2));
      expect(rows[0].lineDate, '2026-04-01');
      expect(rows[0].amount, 5000);
      expect(rows[0].reference, 'UTR123456789');
      expect(rows[1].amount, -12000);
    });

    test('parses debit/credit column format', () {
      const csv = 'Transaction Date,Narration,Debit,Credit,Ref No\n'
          '01/04/2026,Electricity bill,15000,,NEFT111\n'
          '02/04/2026,Maintenance credit,,8000,UPI222';
      final rows = parseBankStatementCsv(csv);
      expect(rows, hasLength(2));
      expect(rows[0].amount, -15000);
      expect(rows[1].amount, 8000);
      expect(rows[0].lineDate, '2026-04-01');
      expect(rows[0].description, 'Electricity bill');
      expect(rows[1].reference, 'UPI222');
    });

    test('throws when date column is missing', () {
      expect(
        () => parseBankStatementCsv('amount,description\n100,test'),
        throwsA(isA<BankCsvException>().having((e) => e.message, 'message', matches(RegExp('date column', caseSensitive: false)))),
      );
    });

    test('throws when amount and debit/credit columns are missing', () {
      expect(
        () => parseBankStatementCsv('date,narration\n2026-04-01,test'),
        throwsA(isA<BankCsvException>().having((e) => e.code, 'code', 'missing_amount')),
      );
    });

    test('handles quoted cells, rupee symbols, brackets and BOM', () {
      const csv = '﻿Date,Amount,Description\n'
          '"01-Apr-2026","₹1,500.50","UPI, A-101 ""maint"""\n'
          '02/04/2026,(2000),Refund\n'
          '03/04/2026,0,Zero row\n'
          'not-a-date,100,Skipped';
      final rows = parseBankStatementCsv(csv);
      expect(rows, hasLength(2));
      expect(rows[0].lineDate, '2026-04-01');
      expect(rows[0].amount, 1500.5);
      expect(rows[0].description, 'UPI, A-101 "maint"');
      expect(rows[1].amount, -2000);
      expect(rows[0].rawRow['Amount'], '₹1,500.50');
    });

    test('returns empty for header-only CSV', () {
      expect(parseBankStatementCsv('date,amount\n'), isEmpty);
    });
  });

  group('parseFlexibleDate', () {
    test('supports the web formats', () {
      expect(parseFlexibleDate('2026-04-01'), '2026-04-01');
      expect(parseFlexibleDate('1/4/2026'), '2026-04-01');
      expect(parseFlexibleDate('01-04-2026'), '2026-04-01');
      expect(parseFlexibleDate('01-Apr-2026'), '2026-04-01');
      expect(parseFlexibleDate('Apr 01, 2026'), '2026-04-01');
      expect(parseFlexibleDate('01/04/26', DateTime(2026, 10, 12)), '2026-04-01');
      expect(parseFlexibleDate(''), isNull);
      expect(parseFlexibleDate('31/02/2026'), isNull);
    });
  });

  group('computeMatchConfidence', () {
    const line = StatementLineForMatch(
      id: 'sl-1',
      lineDate: '2026-04-01',
      amount: 5000,
      description: 'UPI/FLAT A-101 maintenance',
      reference: 'UTR123456789',
    );

    const payment = ReconcilablePayment(
      id: 'p-1',
      amount: 5000,
      date: '2026-04-01',
      paymentMethod: 'upi',
      transactionId: 'UTR123456789',
      flatNumber: 'A-101',
      label: 'Flat A-101',
    );

    test('returns zero when amounts differ', () {
      const other = ReconcilablePayment(
        id: 'p-1',
        amount: 4999,
        date: '2026-04-01',
        paymentMethod: 'upi',
        transactionId: 'UTR123456789',
        flatNumber: 'A-101',
        label: 'Flat A-101',
      );
      expect(computeMatchConfidence(line, other).confidence, 0);
    });

    test('scores high when amount, date, and UTR align', () {
      final r = computeMatchConfidence(line, payment);
      expect(r.confidence, greaterThanOrEqualTo(0.8));
      expect(r.reasons, contains('Exact amount'));
      expect(r.reasons, contains('Reference / UTR match'));
      expect(r.confidence, lessThanOrEqualTo(1));
    });

    test('date tolerance and title matching for ledger entries', () {
      const entry = ReconcilableLedgerEntry(
        id: 'fe-1',
        amount: -12000,
        date: '2026-04-04',
        paymentMethod: 'neft',
        transactionId: null,
        title: 'Vendor ABC repairs',
        destination: 'separate_entry',
        label: 'Expense — Vendor ABC repairs — ₹12,000',
        labelAmount: 12000,
      );
      const debit = StatementLineForMatch(id: 'l2', lineDate: '2026-04-02', amount: -12000, description: 'NEFT Vendor ABC', reference: null);
      final r = computeMatchConfidence(debit, entry);
      expect(r.reasons, contains('Date within ±3 days'));
      expect(r.reasons, contains('Title in narration'));
      expect(r.confidence, closeTo(0.5 + 0.15 + 0.08, 1e-9));
    });
  });

  group('suggestMatches', () {
    test('pairs one-to-one by best confidence', () {
      const lines = [
        StatementLineForMatch(id: 'l1', lineDate: '2026-04-01', amount: 5000, description: 'A-101', reference: 'UTR1'),
        StatementLineForMatch(id: 'l2', lineDate: '2026-04-02', amount: 3000, description: 'B-202', reference: 'UTR2'),
      ];
      final targets = buildReconcilableTargets(
        [
          _payment(id: 'p1', flat: 'A-101', amount: 5000, due: '2026-04-01', txn: 'UTR1'),
          _payment(id: 'p2', flat: 'B-202', amount: 3000, due: '2026-04-02', txn: 'UTR2'),
        ],
        const [],
        <String>{},
        <String>{},
      );
      final suggestions = suggestMatches(lines, targets);
      expect(suggestions, hasLength(2));
      expect(suggestions[0].maintenancePaymentId, isNotNull);
    });

    test('never reuses a target for two lines', () {
      const lines = [
        StatementLineForMatch(id: 'l1', lineDate: '2026-04-01', amount: 5000),
        StatementLineForMatch(id: 'l2', lineDate: '2026-04-01', amount: 5000),
      ];
      final targets = buildReconcilableTargets(
        [_payment(id: 'p1', flat: 'A-101', amount: 5000, due: '2026-04-01')],
        const [],
        <String>{},
        <String>{},
      );
      expect(suggestMatches(lines, targets), hasLength(1));
    });
  });

  group('buildReconcilableTargets', () {
    test('keeps only verified bank-channel rows not already matched', () {
      final targets = buildReconcilableTargets(
        [
          _payment(id: 'cash', flat: 'A-1', amount: 100, due: '2026-04-01', method: 'cash'),
          _payment(id: 'pending', flat: 'A-2', amount: 100, due: '2026-04-01', status: 'pending'),
          _payment(id: 'matched', flat: 'A-3', amount: 100, due: '2026-04-01'),
          _payment(id: 'ok', flat: 'A-4', amount: 100, due: '2026-04-01', method: 'NEFT'),
        ],
        const [
          ReconLedgerInput(
            id: 'fe-exp',
            totalAmount: 900,
            paymentMethod: 'bank_transfer',
            paymentStatus: 'verified',
            transactionDate: '2026-04-03',
            createdAt: '2026-04-05T10:00:00Z',
            destination: 'separate_entry',
            title: 'Lift AMC',
          ),
        ],
        {'matched'},
        <String>{},
      );
      expect(targets.map((t) => t.id), ['ok', 'fe-exp']);
      expect(targets.last.amount, -900);
      expect(targets.last.date, '2026-04-03');
      expect(targets.last.label, 'Expense — Lift AMC — ₹900');
      expect(targets.first.label, 'Flat A-4 — Maintenance — ₹100');
      expect(targetKey(targets.first), 'maintenance_payment:ok');
    });
  });

  group('filterTargetsToPeriod', () {
    const targets = <ReconcilableTarget>[
      ReconcilablePayment(id: 'p1', amount: 1000, date: '2026-04-01', paymentMethod: 'upi', transactionId: null, flatNumber: 'A-101', label: 'in'),
      ReconcilablePayment(id: 'p2', amount: 2000, date: '2026-06-01', paymentMethod: 'upi', transactionId: null, flatNumber: 'B-202', label: 'out'),
    ];

    test('keeps targets within period plus tolerance', () {
      final filtered = filterTargetsToPeriod(targets, '2026-04-01', '2026-04-30', 3);
      expect(filtered, hasLength(1));
      expect(filtered[0].id, 'p1');
    });
  });

  group('rankCandidatesForLine', () {
    test('returns amount-matching targets sorted by confidence', () {
      const line = StatementLineForMatch(id: 'l1', lineDate: '2026-04-01', amount: 5000, description: 'A-101', reference: 'UTR1');
      final targets = buildReconcilableTargets(
        [
          _payment(id: 'p1', flat: 'A-101', amount: 5000, due: '2026-04-01', txn: 'UTR1'),
          _payment(id: 'p2', flat: 'B-202', amount: 5000, due: '2026-04-05'),
        ],
        const [],
        <String>{},
        <String>{},
      );
      final ranked = rankCandidatesForLine(line, targets);
      expect(ranked.length, greaterThanOrEqualTo(1));
      expect(ranked[0].maintenancePaymentId, 'p1');
    });

    test('skips used targets', () {
      const line = StatementLineForMatch(id: 'l1', lineDate: '2026-04-01', amount: 5000);
      final targets = buildReconcilableTargets(
        [_payment(id: 'p1', flat: 'A-101', amount: 5000, due: '2026-04-01')],
        const [],
        <String>{},
        <String>{},
      );
      expect(rankCandidatesForLine(line, targets, usedTargetKeys: {'maintenance_payment:p1'}), isEmpty);
    });
  });

  group('computeReconciliationSummary', () {
    test('computes matched vs unmatched totals', () {
      final lines = [(id: 'l1', amount: 5000.0), (id: 'l2', amount: -2000.0), (id: 'l3', amount: 1000.0)];
      final summary = computeReconciliationSummary(lines, {'l1': 'confirmed', 'l2': 'suggested'});
      expect(summary.statementCredits, 6000);
      expect(summary.statementDebits, 2000);
      expect(summary.matchedCredits, 5000);
      expect(summary.matchedCount, 1);
      expect(summary.suggestedCount, 1);
      expect(summary.exceptionCount, 2);
      expect(summary.unmatchedCredits, 1000);
      expect(summary.unmatchedDebits, 2000);
    });
  });

  group('helpers', () {
    test('reconLineStatus', () {
      final statuses = {'a': 'manual', 'b': 'rejected', 'c': 'suggested'};
      expect(reconLineStatus('a', statuses, const {}), 'confirmed');
      expect(reconLineStatus('b', statuses, const {'b'}), 'rejected');
      expect(reconLineStatus('c', statuses, const {}), 'suggested');
      expect(reconLineStatus('d', statuses, const {'d'}), 'suggested');
      expect(reconLineStatus('e', statuses, const {}), 'unmatched');
    });

    test('exceptions CSV escapes quotes', () {
      final csv = bankReconExceptionsCsv([
        (lineDate: '2026-04-01', amount: 5000.0, description: 'UPI "A-101"', reference: null, status: 'unmatched'),
      ]);
      expect(csv, 'date,amount,description,reference,status\n2026-04-01,5000,"UPI ""A-101""","",unmatched');
    });

    test('reason labels translate to Hindi', () {
      expect(reconReasonLabel('Exact amount'), 'Exact amount');
      expect(reconReasonLabel('Date within ±3 days', hi: true), 'तिथि ±3 दिन के भीतर');
    });

    test('template is the web template', () {
      expect(bankReconCsvTemplate().split('\n').first, 'date,amount,description,reference');
      expect(parseBankStatementCsv(bankReconCsvTemplate()), hasLength(2));
    });
  });
}
