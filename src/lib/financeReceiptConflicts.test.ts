import { describe, expect, it } from 'vitest';
import {
  findMonthlyMaintenanceMonthConflicts,
  findReceiptHeadConflicts,
  paymentDuplicateGroupKey,
  type AuditPaymentRow,
} from '@/lib/financeAuditDetection';

const pay = (overrides: Partial<AuditPaymentRow> & { id: string }): AuditPaymentRow => ({
  charge_id: 'june-charge',
  flat_number: '604',
  amount: 2500,
  payment_method: 'cash',
  payment_status: 'verified',
  due_date: '2026-06-15',
  payment_date: null,
  created_at: '2026-06-15T00:00:00Z',
  finance_entry_id: null,
  ...overrides,
});

describe('receipt double-entry guards', () => {
  it('treats cash and UPI as the same receipt head for a flat/charge/month', () => {
    const existing = [pay({ id: 'p1', payment_method: 'cash', due_date: '2026-06-10' })];
    const conflicts = findReceiptHeadConflicts(existing, [
      {
        flatNumber: '604',
        chargeId: 'june-charge',
        dueDate: '2026-06-20',
        paymentMethod: 'upi',
      },
    ]);
    expect(conflicts).toHaveLength(1);
    expect(paymentDuplicateGroupKey(existing[0]!)).toBe('604||june-charge||2026-06');
  });

  it('blocks a second monthly maintenance receipt for the same flat/month across charge titles', () => {
    const existing = [
      pay({
        id: 'july-row',
        charge_id: 'july-charge',
        due_date: '2026-07-19',
        payment_method: 'upi',
      }),
    ];
    const conflicts = findMonthlyMaintenanceMonthConflicts(
      existing,
      ['june-charge', 'july-charge'],
      [{ flatNumber: '604', dueDate: '2026-07-19' }],
    );
    expect(conflicts.map((c) => c.id)).toEqual(['july-row']);
  });

  it('allows the same flat in a different billing month', () => {
    const existing = [pay({ id: 'june-row', due_date: '2026-06-15' })];
    const conflicts = findMonthlyMaintenanceMonthConflicts(
      existing,
      ['june-charge', 'july-charge'],
      [{ flatNumber: '604', dueDate: '2026-07-19' }],
    );
    expect(conflicts).toHaveLength(0);
  });
});
