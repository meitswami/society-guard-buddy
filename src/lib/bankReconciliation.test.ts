import { describe, expect, it } from 'vitest';
import {
  buildReconcilableTargets,
  computeMatchConfidence,
  computeReconciliationSummary,
  filterTargetsToPeriod,
  parseBankStatementCsv,
  rankCandidatesForLine,
  suggestMatches,
  type ReconcilablePayment,
  type ReconcilableTarget,
  type StatementLineForMatch,
} from './bankReconciliation';

describe('parseBankStatementCsv', () => {
  it('parses standard date,amount,description,reference CSV', () => {
    const csv = `date,amount,description,reference
2026-04-01,5000,UPI Flat A-101,UTR123456789
2026-04-02,-12000,Vendor payment,NEFT987654`;
    const rows = parseBankStatementCsv(csv);
    expect(rows).toHaveLength(2);
    expect(rows[0]).toMatchObject({
      line_date: '2026-04-01',
      amount: 5000,
      reference: 'UTR123456789',
    });
    expect(rows[1].amount).toBe(-12000);
  });

  it('parses debit/credit column format', () => {
    const csv = `Transaction Date,Narration,Debit,Credit,Ref No
01/04/2026,Electricity bill,15000,,NEFT111
02/04/2026,Maintenance credit,,8000,UPI222`;
    const rows = parseBankStatementCsv(csv);
    expect(rows).toHaveLength(2);
    expect(rows[0].amount).toBe(-15000);
    expect(rows[1].amount).toBe(8000);
  });

  it('throws when date column is missing', () => {
    expect(() => parseBankStatementCsv('amount,description\n100,test')).toThrow(/date column/i);
  });
});

describe('computeMatchConfidence', () => {
  const line: StatementLineForMatch = {
    id: 'sl-1',
    line_date: '2026-04-01',
    amount: 5000,
    description: 'UPI/FLAT A-101 maintenance',
    reference: 'UTR123456789',
  };

  const payment: ReconcilablePayment = {
    kind: 'maintenance_payment',
    id: 'p-1',
    amount: 5000,
    date: '2026-04-01',
    payment_method: 'upi',
    transaction_id: 'UTR123456789',
    flat_number: 'A-101',
    label: 'Flat A-101',
  };

  it('returns zero when amounts differ', () => {
    const { confidence } = computeMatchConfidence(line, { ...payment, amount: 4999 });
    expect(confidence).toBe(0);
  });

  it('scores high when amount, date, and UTR align', () => {
    const { confidence, reasons } = computeMatchConfidence(line, payment);
    expect(confidence).toBeGreaterThanOrEqual(0.8);
    expect(reasons).toContain('Exact amount');
    expect(reasons).toContain('Reference / UTR match');
  });
});

describe('suggestMatches', () => {
  it('pairs one-to-one by best confidence', () => {
    const lines: StatementLineForMatch[] = [
      { id: 'l1', line_date: '2026-04-01', amount: 5000, description: 'A-101', reference: 'UTR1' },
      { id: 'l2', line_date: '2026-04-02', amount: 3000, description: 'B-202', reference: 'UTR2' },
    ];
    const targets = buildReconcilableTargets(
      [
        {
          id: 'p1',
          flat_number: 'A-101',
          amount: 5000,
          payment_method: 'upi',
          payment_status: 'verified',
          due_date: '2026-04-01',
          payment_date: null,
          created_at: '2026-04-01',
          transaction_id: 'UTR1',
        },
        {
          id: 'p2',
          flat_number: 'B-202',
          amount: 3000,
          payment_method: 'upi',
          payment_status: 'verified',
          due_date: '2026-04-02',
          payment_date: null,
          created_at: '2026-04-02',
          transaction_id: 'UTR2',
        },
      ],
      [],
      new Set(),
      new Set(),
    );
    const suggestions = suggestMatches(lines, targets);
    expect(suggestions).toHaveLength(2);
    expect(suggestions[0].maintenance_payment_id).toBeTruthy();
  });
});

describe('filterTargetsToPeriod', () => {
  const targets: ReconcilableTarget[] = [
    {
      kind: 'maintenance_payment',
      id: 'p1',
      amount: 1000,
      date: '2026-04-01',
      payment_method: 'upi',
      transaction_id: null,
      flat_number: 'A-101',
      label: 'in',
    },
    {
      kind: 'maintenance_payment',
      id: 'p2',
      amount: 2000,
      date: '2026-06-01',
      payment_method: 'upi',
      transaction_id: null,
      flat_number: 'B-202',
      label: 'out',
    },
  ];

  it('keeps targets within period plus tolerance', () => {
    const filtered = filterTargetsToPeriod(targets, '2026-04-01', '2026-04-30', 3);
    expect(filtered).toHaveLength(1);
    expect(filtered[0].id).toBe('p1');
  });
});

describe('rankCandidatesForLine', () => {
  it('returns amount-matching targets sorted by confidence', () => {
    const line: StatementLineForMatch = {
      id: 'l1',
      line_date: '2026-04-01',
      amount: 5000,
      description: 'A-101',
      reference: 'UTR1',
    };
    const targets = buildReconcilableTargets(
      [
        {
          id: 'p1',
          flat_number: 'A-101',
          amount: 5000,
          payment_method: 'upi',
          payment_status: 'verified',
          due_date: '2026-04-01',
          payment_date: null,
          created_at: '2026-04-01',
          transaction_id: 'UTR1',
        },
        {
          id: 'p2',
          flat_number: 'B-202',
          amount: 5000,
          payment_method: 'upi',
          payment_status: 'verified',
          due_date: '2026-04-05',
          payment_date: null,
          created_at: '2026-04-05',
          transaction_id: null,
        },
      ],
      [],
      new Set(),
      new Set(),
    );
    const ranked = rankCandidatesForLine(line, targets);
    expect(ranked.length).toBeGreaterThanOrEqual(1);
    expect(ranked[0].maintenance_payment_id).toBe('p1');
  });
});

describe('computeReconciliationSummary', () => {
  it('computes matched vs unmatched totals', () => {
    const lines = [
      { id: 'l1', amount: 5000 },
      { id: 'l2', amount: -2000 },
      { id: 'l3', amount: 1000 },
    ];
    const map = new Map([
      ['l1', { status: 'confirmed' }],
      ['l2', { status: 'suggested' }],
    ]);
    const summary = computeReconciliationSummary(lines, map);
    expect(summary.statementCredits).toBe(6000);
    expect(summary.statementDebits).toBe(2000);
    expect(summary.matchedCredits).toBe(5000);
    expect(summary.matchedCount).toBe(1);
    expect(summary.suggestedCount).toBe(1);
    expect(summary.exceptionCount).toBe(2);
  });
});
