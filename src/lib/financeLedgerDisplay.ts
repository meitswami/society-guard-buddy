import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import { billingMonthFromDate, ledgerTransactionDate, paymentBillingDate } from '@/lib/financeDates';
import { addToChannel, type ChannelTotals } from '@/lib/cashBankChannel';
import type {
  EventContribRefRow,
  FinanceLedgerRow,
  TransactionHeadSummaryRow,
} from '@/lib/financeManagerTypes';

export const ledgerMonthValue = (e: FinanceLedgerRow) => billingMonthFromDate(ledgerTransactionDate(e));

export const ledgerMonthDisplay = (e: FinanceLedgerRow) => fmtIsoMonthToDisplay(ledgerMonthValue(e));

export const paymentMonthLabel = (payment: { payment_date?: string; verified_at?: string; created_at?: string }) => {
  const raw = paymentBillingDate(payment);
  if (!raw) return 'Unknown month';
  return fmtIsoMonthToDisplay(billingMonthFromDate(raw));
};

export const paymentVerifiedAtOrDate = (p: { payment_date?: string; verified_at?: string; created_at?: string }) =>
  String(p.payment_date || p.verified_at || p.created_at || '');

export const dateInInclusiveRange = (iso: string, fromYmd: string, toYmd: string) => {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return false;
  const fromMs = new Date(`${fromYmd}T00:00:00`).getTime();
  const toMs = new Date(`${toYmd}T23:59:59.999`).getTime();
  return t >= fromMs && t <= toMs;
};

export const eventContribRefLabel = (c: EventContribRefRow): string => {
  if (c.receipt_basis === 'non_flat' || !c.flat_number) {
    return c.batch_label || c.outsider_name || c.resident_name || 'Receipt (no flat)';
  }
  const parts = [`Flat ${c.flat_number}`];
  if (c.resident_name) parts.push(c.resident_name);
  if (c.split_mode === 'headcount') parts.push('headcount');
  return parts.join(' · ');
};

export const isGroupExpenseLedgerEntry = (e: FinanceLedgerRow) => Boolean(e.expense_id);

export const isLedgerInSocietyPool = (e: FinanceLedgerRow) => {
  if (isGroupExpenseLedgerEntry(e)) return false;
  if (e.distributed_at) return false;
  const allocCount = e.finance_entry_allocations?.length ?? 0;
  if (e.record_mode === 'society_pool') return allocCount === 0;
  return e.allocation_style === 'none' && allocCount === 0 && e.aggregate_flat_count === 0;
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
    byChannel: { cash: 0, bank: 0, other: 0 } as ChannelTotals,
  };
  const amt = Number(amount || 0);
  cur.total += amt;
  cur.entries += 1;
  addToChannel(cur.byChannel, paymentMethod, amt);
  map.set(label, cur);
}

export function transactionHeadSummaryRows(map: Map<string, TransactionHeadSummaryRow>) {
  return [...map.values()].sort((a, b) => b.total - a.total || a.head.localeCompare(b.head));
}
