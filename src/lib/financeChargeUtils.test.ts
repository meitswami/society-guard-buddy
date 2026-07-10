import { describe, expect, it } from 'vitest';
import {
  buildCurrentMonthChargeTitle,
  isCurrentMonthChargeTitle,
  isMonthlyMaintenanceCharge,
  normalizeChargeTitle,
  paymentMonthValue,
} from '@/lib/financeChargeUtils';
import { eventContribRefLabel, isLedgerInSocietyPool } from '@/lib/financeLedgerUtils';
import type { FinanceLedgerRow } from '@/services/finance/types';

describe('financeChargeUtils', () => {
  it('detects monthly maintenance charges', () => {
    expect(isMonthlyMaintenanceCharge({ title: 'April Monthly Maintenance', frequency: 'monthly' })).toBe(true);
    expect(isMonthlyMaintenanceCharge({ title: 'Lift repair', frequency: 'once' })).toBe(false);
  });

  it('builds current month charge title', () => {
    const title = buildCurrentMonthChargeTitle(new Date('2026-04-15'));
    expect(title).toBe('April Monthly Maintenance');
    expect(isCurrentMonthChargeTitle(title, new Date('2026-04-15'))).toBe(true);
  });

  it('normalizes charge titles', () => {
    expect(normalizeChargeTitle('  Hello World ')).toBe('hello world');
  });

  it('derives payment month value from billing date', () => {
    expect(paymentMonthValue({ due_date: '2026-03-10', created_at: '2026-01-01' })).toBe('2026-03');
  });
});

describe('financeLedgerUtils', () => {
  const baseLedger = {
    id: '1',
    society_id: 's1',
    record_mode: 'society_pool',
    destination: 'current_month_maintenance',
    allocation_style: 'none',
    include_vacant: false,
    entry_month: '2026-03',
    transaction_date: '2026-03-01',
    total_amount: 1000,
    aggregate_flat_count: 0,
    charge_id: null,
    expense_id: null,
    distributed_at: null,
    title: null,
    notes: null,
    screenshot_url: null,
    transaction_id: null,
    payment_method: 'cash',
    payment_status: 'verified',
    created_by: null,
    created_at: '2026-03-01',
    finance_entry_counterparties: null,
    finance_entry_allocations: null,
  } satisfies FinanceLedgerRow;

  it('identifies society pool ledger rows', () => {
    expect(isLedgerInSocietyPool(baseLedger)).toBe(true);
    expect(isLedgerInSocietyPool({ ...baseLedger, expense_id: 'exp-1' })).toBe(false);
    expect(isLedgerInSocietyPool({ ...baseLedger, distributed_at: '2026-03-02' })).toBe(false);
  });

  it('formats event contribution labels', () => {
    expect(
      eventContribRefLabel({
        id: 'c1',
        event_id: 'e1',
        flat_number: 'A-101',
        amount: 500,
        payment_method: 'cash',
        verified_at: null,
        resident_name: 'Ravi',
        receipt_basis: 'flat',
        batch_label: null,
        outsider_name: null,
        split_mode: 'headcount',
        screenshot_url: null,
      }),
    ).toBe('Flat A-101 · Ravi · headcount');
  });
});
