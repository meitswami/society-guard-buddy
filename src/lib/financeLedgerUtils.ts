import { billingMonthFromDate, ledgerTransactionDate } from '@/lib/financeDates';
import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import type { EventContribRefRow, FinanceLedgerRow } from '@/services/finance/types';
import { addToChannel, type ChannelTotals } from '@/lib/cashBankChannel';

export type { FinanceLedgerRow, EventContribRefRow };

export const eventContribRefLabel = (c: EventContribRefRow): string => {
  if (c.receipt_basis === 'non_flat' || !c.flat_number) {
    return c.batch_label || c.outsider_name || c.resident_name || 'Receipt (no flat)';
  }
  const parts = [`Flat ${c.flat_number}`];
  if (c.resident_name) parts.push(c.resident_name);
  if (c.split_mode === 'headcount') parts.push('headcount');
  return parts.join(' · ');
};

const isGroupExpenseLedgerEntry = (e: FinanceLedgerRow) => Boolean(e.expense_id);

export const isLedgerInSocietyPool = (e: FinanceLedgerRow) => {
  if (isGroupExpenseLedgerEntry(e)) return false;
  if (e.distributed_at) return false;
  const allocCount = e.finance_entry_allocations?.length ?? 0;
  if (e.record_mode === 'society_pool') return allocCount === 0;
  return e.allocation_style === 'none' && allocCount === 0 && e.aggregate_flat_count === 0;
};

export const ledgerMonthValue = (e: FinanceLedgerRow) => billingMonthFromDate(ledgerTransactionDate(e));

export const ledgerMonthDisplay = (e: FinanceLedgerRow) => fmtIsoMonthToDisplay(ledgerMonthValue(e));

export type TransactionHeadSummaryRow = {
  head: string;
  total: number;
  entries: number;
  byChannel: ChannelTotals;
};

export function addTransactionHeadRow(
  map: Map<string, TransactionHeadSummaryRow>,
  head: string,
  amount: number,
  paymentMethod: string | null | undefined,
) {
  const label = head.trim() || 'Uncategorized';
  const cur = map.get(label) ?? {
    head: label,
    total: 0,
    entries: 0,
    byChannel: { cash: 0, bank: 0, other: 0 },
  };
  const amt = Number(amount || 0);
  cur.total += amt;
  cur.entries += 1;
  addToChannel(cur.byChannel, paymentMethod, amt);
  map.set(label, cur);
}

export function transactionHeadSummaryRows(map: Map<string, TransactionHeadSummaryRow>) {
  return [...map.values()].sort((a, b) => b.total - a.total);
}
