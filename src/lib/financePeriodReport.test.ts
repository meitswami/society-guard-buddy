import { describe, expect, it } from 'vitest';
import {
  computeFinancePeriodReport,
  findApplicableOpeningAnchor,
  financeReportingMonthRange,
  FINANCE_REPORTING_EARLIEST_MONTH,
  isManualOpeningBalanceSetupPeriod,
} from '@/lib/financePeriodReport';

describe('finance opening balance anchors', () => {
  it('shows manual setup UI for Feb–Mar 2026 go-live period starts', () => {
    expect(isManualOpeningBalanceSetupPeriod('2026-02-01')).toBe(true);
    expect(isManualOpeningBalanceSetupPeriod('2026-03-01')).toBe(true);
    expect(isManualOpeningBalanceSetupPeriod('2026-03-31')).toBe(true);
    expect(isManualOpeningBalanceSetupPeriod('2026-04-01')).toBe(false);
  });

  it('defines Feb 2026 as the earliest reporting month', () => {
    expect(FINANCE_REPORTING_EARLIEST_MONTH).toBe('2026-02');
    expect(financeReportingMonthRange('2026-02')).toEqual({ from: '2026-02-01', to: '2026-02-28' });
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

describe('finance period report head-wise columns', () => {
  it('groups verified receipts by head with cash, bank, and total columns', () => {
    const chargeMajorHeadById = new Map([
      ['ch-maint', 'OPERATION & MAINTENANCE'],
      ['ch-corpus', 'SOCIETY CORPUS FUND'],
    ]);
    const report = computeFinancePeriodReport({
      periodFrom: '2026-04-01',
      periodTo: '2026-04-30',
      payments: [
        {
          payment_status: 'verified',
          amount: 1000,
          payment_method: 'cash',
          due_date: '2026-04-05',
          charge_id: 'ch-maint',
        },
        {
          payment_status: 'verified',
          amount: 2500,
          payment_method: 'upi',
          due_date: '2026-04-10',
          charge_id: 'ch-corpus',
        },
      ],
      ledgerEntries: [
        {
          id: 'fe-ledger',
          destination: 'current_month_maintenance',
          total_amount: 500,
          payment_method: 'cash',
          transaction_date: '2026-04-12',
        },
      ],
      chargeMajorHeadById,
    });

    expect(report.receiptByHead).toEqual([
      ['SOCIETY CORPUS FUND', { cash: 0, bank: 2500, other: 0, total: 2500 }],
      ['OPERATION & MAINTENANCE', { cash: 1500, bank: 0, other: 0, total: 1500 }],
    ]);
    expect(report.receiptByMethod).toEqual({ cash: 1500, bank: 2500, other: 0 });
    expect(report.totalReceipts).toBe(4000);
  });

  it('groups separate-entry expenses by head with cash, bank, and total columns', () => {
    const report = computeFinancePeriodReport({
      periodFrom: '2026-04-01',
      periodTo: '2026-04-30',
      payments: [],
      ledgerEntries: [
        {
          id: 'fe-1',
          destination: 'separate_entry',
          total_amount: 800,
          payment_method: 'cash',
          title: 'Electricity',
          transaction_date: '2026-04-03',
        },
        {
          id: 'fe-2',
          destination: 'separate_entry',
          total_amount: 1200,
          payment_method: 'upi',
          title: 'Electricity',
          transaction_date: '2026-04-08',
        },
        {
          id: 'fe-3',
          destination: 'separate_entry',
          total_amount: 300,
          payment_method: 'cash',
          title: 'Security salary',
          transaction_date: '2026-04-15',
        },
      ],
    });

    expect(report.expenseByHead).toEqual([
      ['Electricity', { cash: 800, bank: 1200, other: 0, total: 2000 }],
      ['Security salary', { cash: 300, bank: 0, other: 0, total: 300 }],
    ]);
    expect(report.expenseByMethod).toEqual({ cash: 1100, bank: 1200, other: 0 });
    expect(report.totalExpenses).toBe(2300);
  });

  it('includes February 2026 society expenses in the Feb period report', () => {
    const report = computeFinancePeriodReport({
      periodFrom: '2026-02-01',
      periodTo: '2026-02-28',
      payments: [],
      ledgerEntries: [
        {
          id: 'fe-feb-1',
          destination: 'separate_entry',
          total_amount: 100000,
          payment_method: 'bank_transfer',
          entry_month: '2026-02',
          transaction_date: '2026-02-10',
        },
        {
          id: 'fe-feb-2',
          destination: 'separate_entry',
          total_amount: 68751,
          payment_method: 'cash',
          entry_month: '2026-02',
          transaction_date: '2026-02-20',
        },
      ],
    });

    expect(report.totalExpenses).toBe(168751);
    expect(report.expenseByMethod).toEqual({ cash: 68751, bank: 100000, other: 0 });
  });
});
