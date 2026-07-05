import { describe, expect, it } from 'vitest';
import {
  computeFinancePeriodReport,
  findApplicableOpeningAnchor,
  isManualOpeningBalanceSetupPeriod,
} from '@/lib/financePeriodReport';

describe('finance opening balance anchors', () => {
  it('shows manual setup UI only for March 2026 or earlier period starts', () => {
    expect(isManualOpeningBalanceSetupPeriod('2026-03-01')).toBe(true);
    expect(isManualOpeningBalanceSetupPeriod('2026-03-31')).toBe(true);
    expect(isManualOpeningBalanceSetupPeriod('2026-04-01')).toBe(false);
  });

  it('finds latest anchor before period start', () => {
    const anchors = [
      { as_on_date: '2026-01-31', cash_amount: null, bank_amount: 10000, other_amount: null },
      { as_on_date: '2026-02-28', cash_amount: null, bank_amount: 18145, other_amount: null },
    ];
    expect(findApplicableOpeningAnchor(anchors, '2026-03-01')?.as_on_date).toBe('2026-02-28');
    expect(findApplicableOpeningAnchor(anchors, '2026-02-28')?.as_on_date).toBe('2026-01-31');
    expect(findApplicableOpeningAnchor(anchors, '2026-01-31')).toBeNull();
  });

  it('uses manual bank anchor for period starting after anchor date', () => {
    const report = computeFinancePeriodReport({
      periodFrom: '2026-03-01',
      periodTo: '2026-03-31',
      payments: [],
      ledgerEntries: [],
      openingBalanceAnchors: [
        { as_on_date: '2026-02-28', cash_amount: null, bank_amount: 18145, other_amount: null },
      ],
    });
    expect(report.openingBank).toBe(18145);
    expect(report.openingBankFromManualAnchor).toBe(true);
    expect(report.appliedOpeningAnchor?.bank_amount).toBe(18145);
  });

  it('uses manual cash anchor of zero for period starting after anchor date', () => {
    const report = computeFinancePeriodReport({
      periodFrom: '2026-03-01',
      periodTo: '2026-03-31',
      payments: [],
      ledgerEntries: [],
      openingBalanceAnchors: [
        { as_on_date: '2026-02-28', cash_amount: 0, bank_amount: null, other_amount: null },
      ],
    });
    expect(report.openingCash).toBe(0);
    expect(report.openingCashFromManualAnchor).toBe(true);
  });

  it('adds bank movement between anchor and period start', () => {
    const report = computeFinancePeriodReport({
      periodFrom: '2026-04-01',
      periodTo: '2026-04-30',
      payments: [
        {
          payment_status: 'verified',
          amount: 500,
          payment_method: 'upi',
          due_date: '2026-03-15',
        },
      ],
      ledgerEntries: [],
      openingBalanceAnchors: [
        { as_on_date: '2026-02-28', cash_amount: null, bank_amount: 18145, other_amount: null },
      ],
    });
    expect(report.openingBank).toBe(18645);
  });
});
