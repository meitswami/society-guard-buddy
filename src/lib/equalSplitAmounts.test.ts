import { describe, expect, it } from 'vitest';
import { adjustSplitRemainder, computeEqualSplitAmounts } from './equalSplitAmounts';

describe('computeEqualSplitAmounts', () => {
  it('sums exactly to total when equal split does not divide evenly', () => {
    const flats = Array.from({ length: 29 }, (_, i) => String(100 + i));
    const rows = computeEqualSplitAmounts(150_000, flats);
    const sum = Number(rows.reduce((s, r) => s + r.amount, 0).toFixed(2));
    expect(sum).toBe(150_000);
    expect(rows[0].amount).toBe(5172.41);
    expect(rows[28].amount).toBe(5172.52);
  });

  it('returns equal shares when total divides evenly', () => {
    const flats = Array.from({ length: 29 }, (_, i) => String(i));
    const rows = computeEqualSplitAmounts(9251, flats);
    const sum = Number(rows.reduce((s, r) => s + r.amount, 0).toFixed(2));
    expect(sum).toBe(9251);
    expect(rows.every((r) => r.amount === 319)).toBe(true);
  });
});

describe('adjustSplitRemainder', () => {
  it('fixes a small rounding gap on the last amount', () => {
    const adjusted = adjustSplitRemainder(150_000, Array(29).fill(5172.41));
    expect(Number(adjusted.reduce((a, b) => a + b, 0).toFixed(2))).toBe(150_000);
    expect(adjusted[28]).toBe(5172.52);
  });
});
