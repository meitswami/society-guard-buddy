import { describe, expect, it } from 'vitest';
import { buildFlatReportRows } from '@/lib/financeFlatReport';
import type { FinanceLedgerRow } from '@/lib/financeManagerTypes';

describe('buildFlatReportRows', () => {
  const flats = [{ id: 'f1', flat_number: 'A-101', owner_name: 'Owner', is_occupied: true }];

  it('aggregates verified maintenance payments in range', () => {
    const rows = buildFlatReportRows({
      from: '2026-03-01',
      to: '2026-03-31',
      selectedFlat: 'all',
      payments: [
        {
          payment_status: 'verified',
          flat_number: 'A-101',
          amount: 1000,
          charge_id: 'c1',
          payment_method: 'cash',
          due_date: '2026-03-10',
        },
      ],
      ledgerEntries: [],
      flatReportExpenses: [],
      flatReportSplits: [],
      flats,
      primaryByFlatId: new Map([['f1', 'Ravi']]),
      charges: [{ id: 'c1', title: 'March Maintenance' }],
    });

    expect(rows).toHaveLength(1);
    expect(rows[0].maintenance_paid).toBe(1000);
    expect(rows[0].resident_name).toBe('Ravi');
    expect(rows[0].net_position).toBe(1000);
  });

  it('filters by selected flat', () => {
    const rows = buildFlatReportRows({
      from: '2026-03-01',
      to: '2026-03-31',
      selectedFlat: 'B-202',
      payments: [
        {
          payment_status: 'verified',
          flat_number: 'A-101',
          amount: 1000,
          due_date: '2026-03-10',
        },
      ],
      ledgerEntries: [],
      flatReportExpenses: [],
      flatReportSplits: [],
      flats: [
        { id: 'f1', flat_number: 'A-101', owner_name: null, is_occupied: true },
        { id: 'f2', flat_number: 'B-202', owner_name: null, is_occupied: true },
      ],
      primaryByFlatId: new Map(),
      charges: [],
    });

    expect(rows).toHaveLength(0);
  });

  it('subtracts expense splits from net position', () => {
    const rows = buildFlatReportRows({
      from: '2026-03-01',
      to: '2026-03-31',
      selectedFlat: 'all',
      payments: [
        {
          payment_status: 'verified',
          flat_number: 'A-101',
          amount: 2000,
          due_date: '2026-03-10',
        },
      ],
      ledgerEntries: [],
      flatReportExpenses: [
        {
          id: 'e1',
          title: 'Lift repair',
          expense_date: '2026-03-15',
          payment_method: 'cash',
          group_name: 'Repairs',
        },
      ],
      flatReportSplits: [
        { expense_id: 'e1', flat_number: 'A-101', amount: 500, is_settled: true },
      ],
      flats,
      primaryByFlatId: new Map(),
      charges: [],
    });

    expect(rows[0].expense_share).toBe(500);
    expect(rows[0].net_position).toBe(1500);
  });
});
