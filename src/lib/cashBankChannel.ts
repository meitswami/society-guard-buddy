import { normalizePaymentChannel, type PaymentChannel } from '@/lib/financeAuditDetection';

export type ChannelTotals = Record<PaymentChannel, number>;

export { normalizePaymentChannel, type PaymentChannel };

export const emptyChannelTotals = (): ChannelTotals => ({ cash: 0, bank: 0, other: 0 });

export function addToChannel(totals: ChannelTotals, method: unknown, amount: number): void {
  const ch = normalizePaymentChannel(method);
  totals[ch] += Number(amount) || 0;
}

export function sumByChannel<T>(
  items: Iterable<T>,
  getAmount: (item: T) => number,
  getMethod: (item: T) => unknown,
): ChannelTotals {
  const totals = emptyChannelTotals();
  for (const item of items) {
    addToChannel(totals, getMethod(item), getAmount(item));
  }
  return totals;
}

export function netChannels(receipts: ChannelTotals, payments: ChannelTotals): ChannelTotals {
  return {
    cash: receipts.cash - payments.cash,
    bank: receipts.bank - payments.bank,
    other: receipts.other - payments.other,
  };
}

export function channelTotal(t: ChannelTotals): number {
  return t.cash + t.bank + t.other;
}

export function channelDisplayLabel(method: unknown): string {
  const ch = normalizePaymentChannel(method);
  if (ch === 'cash') return 'Cash';
  if (ch === 'bank') return 'Bank / UPI';
  return String(method || 'Other');
}

export function formatChannelParts(t: ChannelTotals, prefix = '₹'): string {
  const parts: string[] = [];
  if (t.cash > 0) parts.push(`Cash ${prefix}${t.cash.toLocaleString('en-IN')}`);
  if (t.bank > 0) parts.push(`Bank ${prefix}${t.bank.toLocaleString('en-IN')}`);
  if (t.other > 0) parts.push(`Other ${prefix}${t.other.toLocaleString('en-IN')}`);
  return parts.length ? parts.join(' · ') : `${prefix}0`;
}
