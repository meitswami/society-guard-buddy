import { describe, expect, it } from 'vitest';
import { monthlyAmountTotals, sumAmountRows } from '@/lib/statementAmountTotals';

describe('statementAmountTotals', () => {
  it('sums row amounts', () => {
    expect(sumAmountRows([{ amount: 100 }, { amount: -30 }, {}])).toBe(70);
  });

  it('groups by month from dateIso', () => {
    const rows = [
      { amount: 500, dateIso: '2026-04-05' },
      { amount: 200, dateIso: '2026-04-20' },
      { amount: 100, dateIso: '2026-05-01' },
    ];
    expect(monthlyAmountTotals(rows)).toEqual([
      { monthKey: '2026-04', label: '04/2026', total: 700, count: 2 },
      { monthKey: '2026-05', label: '05/2026', total: 100, count: 1 },
    ]);
  });

  it('parses display dates when dateIso is missing', () => {
    expect(monthlyAmountTotals([{ amount: 50, date: '15/03/2026' }])).toEqual([
      { monthKey: '2026-03', label: '03/2026', total: 50, count: 1 },
    ]);
  });
});
