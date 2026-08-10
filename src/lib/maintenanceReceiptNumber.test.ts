import { describe, expect, it } from 'vitest';

/** Mirror of DB format_maintenance_receipt_number for client display checks. */
function formatMaintenanceReceiptNumber(seq: number): string {
  return `MR-${String(seq).padStart(6, '0')}`;
}

describe('maintenance receipt serial format', () => {
  it('pads sequential numbers to 6 digits', () => {
    expect(formatMaintenanceReceiptNumber(1)).toBe('MR-000001');
    expect(formatMaintenanceReceiptNumber(186)).toBe('MR-000186');
    expect(formatMaintenanceReceiptNumber(187)).toBe('MR-000187');
  });
});
