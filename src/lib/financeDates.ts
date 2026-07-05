import { format, isValid, parse } from 'date-fns';

/** Date the row was entered in the system (always “today” when saving). Not used in period/month reports. */
export function todayRecordingDate(): string {
  return format(new Date(), 'yyyy-MM-dd');
}

/** Billing / transaction date on a payment row. */
export function paymentBillingDate(p: { due_date?: string | null }): string {
  return (p.due_date || '').toString().slice(0, 10);
}

/** Calendar month `yyyy-MM` from a billing date `yyyy-MM-dd`. */
export function billingMonthFromDate(billingYmd: string): string {
  const d = parse(billingYmd.slice(0, 10), 'yyyy-MM-dd', new Date());
  return isValid(d) ? format(d, 'yyyy-MM') : format(new Date(), 'yyyy-MM');
}

/** Ledger entry month must contain the billing date. */
export function isBillingDateInEntryMonth(billingYmd: string, entryMonthYm: string): boolean {
  if (!billingYmd || !entryMonthYm) return false;
  return billingMonthFromDate(billingYmd) === entryMonthYm.slice(0, 7);
}

export function ledgerTransactionDate(e: {
  transaction_date?: string | null;
  entry_month?: string | null;
  created_at?: string;
}): string {
  if (e.transaction_date) return String(e.transaction_date).slice(0, 10);
  if (e.entry_month) return `${e.entry_month}-01`;
  return (e.created_at || '').slice(0, 10);
}

export function ledgerEntryMonthFromBilling(billingYmd: string): string {
  return billingMonthFromDate(billingYmd);
}

export function dateInInclusiveRange(iso: string, fromYmd: string, toYmd: string): boolean {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return false;
  const fromMs = new Date(`${fromYmd}T00:00:00`).getTime();
  const toMs = new Date(`${toYmd}T23:59:59.999`).getTime();
  return t >= fromMs && t <= toMs;
}

export function isDateBefore(iso: string, beforeYmd: string): boolean {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return false;
  return t < new Date(`${beforeYmd}T00:00:00`).getTime();
}
