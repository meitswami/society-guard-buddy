import { describe, it, expect } from 'vitest';
import { formatLedgerFieldLabel } from '@/lib/financeLedgerDisplay';

describe('formatLedgerFieldLabel', () => {
  it('formats snake_case enums', () => {
    expect(formatLedgerFieldLabel('society_pool')).toBe('society pool');
    expect(formatLedgerFieldLabel('current_month_maintenance')).toBe('current month maintenance');
  });

  it('returns fallback for nullish values', () => {
    expect(formatLedgerFieldLabel(null)).toBe('—');
    expect(formatLedgerFieldLabel(undefined)).toBe('—');
    expect(formatLedgerFieldLabel('', 'unknown')).toBe('unknown');
  });
});
