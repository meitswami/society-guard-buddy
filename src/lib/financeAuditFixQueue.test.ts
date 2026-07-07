import { describe, expect, it } from 'vitest';
import {
  buildAuditFixQueue,
  type AuditPaymentRow,
  type DuplicatePaymentGroup,
  type LedgerOvercountMonth,
  type RecordingMismatchMonth,
} from './financeAuditDetection';

const pay = (overrides: Partial<AuditPaymentRow> & { id: string }): AuditPaymentRow => ({
  charge_id: 'c1',
  flat_number: 'A-101',
  amount: 1000,
  payment_method: 'cash',
  payment_status: 'verified',
  due_date: '2024-01-01',
  payment_date: null,
  created_at: '2024-01-02T00:00:00Z',
  finance_entry_id: null,
  ...overrides,
});

describe('buildAuditFixQueue', () => {
  it('orders entries from earliest discrepancy date to latest', () => {
    const duplicateGroups: DuplicatePaymentGroup[] = [
      {
        flat_number: 'A-101',
        charge_id: 'c1',
        charge_title: 'Maintenance',
        month: '2024-03',
        payment_method: 'cash',
        count: 2,
        total_amount: 2000,
        payments: [
          pay({ id: 'p-old', due_date: '2024-03-01', created_at: '2024-03-01' }),
          pay({ id: 'p-new', due_date: '2024-03-01', created_at: '2024-03-15' }),
        ],
      },
    ];

    const ledgerOvercountIssues: LedgerOvercountMonth[] = [
      {
        month: '2024-02',
        paymentTotal: 1000,
        reportTotal: 2000,
        excess: 1000,
        unlinkedLedger: [
          {
            id: 'fe-1',
            title: 'Extra receipt',
            total_amount: 1000,
            entry_month: '2024-02',
            record_mode: 'flats_only',
            destination: 'current_month_maintenance',
            payment_method: 'cash',
            created_at: '2024-02-10',
          },
        ],
        dateBoundary: [],
      },
    ];

    const recordingMismatchMonths: RecordingMismatchMonth[] = [
      {
        month: '2024-04',
        paymentsTotal: 2000,
        ledgerTotal: 1000,
        difference: 1000,
        sources: [
          {
            kind: 'orphan_payment',
            id: 'p-orphan',
            date: '2024-04-05',
            label: 'Flat B-202 — no ledger link',
            amount: 1000,
          },
        ],
      },
    ];

    const queue = buildAuditFixQueue({
      duplicateGroups,
      ledgerOvercountIssues,
      recordingMismatchMonths,
      orphanedPayments: [],
      cashTrace: null,
      bankTrace: null,
    });

    expect(queue.length).toBeGreaterThanOrEqual(4);
    const dates = queue.map((q) => q.sortDate);
    expect(dates).toEqual([...dates].sort());
    expect(queue[0].sortDate).toBe('2024-02-01');
    expect(queue[0].entryId).toBe('fe-1');
    expect(queue.find((q) => q.entryId === 'p-new')?.action).toBe('delete');
    expect(queue.find((q) => q.entryId === 'p-old')?.action).toBe('review');
  });

  it('deduplicates the same entry across recording mismatch and orphan lists', () => {
    const orphaned = [pay({ id: 'same-id', due_date: '2023-06-01' })];
    const recordingMismatchMonths: RecordingMismatchMonth[] = [
      {
        month: '2023-06',
        paymentsTotal: 1000,
        ledgerTotal: 0,
        difference: 1000,
        sources: [
          {
            kind: 'orphan_payment',
            id: 'same-id',
            date: '2023-06-01',
            label: 'Flat A-101 — no ledger link',
            amount: 1000,
          },
        ],
      },
    ];

    const queue = buildAuditFixQueue({
      duplicateGroups: [],
      ledgerOvercountIssues: [],
      recordingMismatchMonths,
      orphanedPayments: orphaned,
      cashTrace: null,
      bankTrace: null,
    });

    expect(queue.filter((q) => q.entryId === 'same-id')).toHaveLength(1);
  });
});
