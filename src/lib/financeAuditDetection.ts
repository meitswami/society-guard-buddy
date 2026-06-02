import { format } from 'date-fns';

export type PaymentChannel = 'cash' | 'bank' | 'other';

export const normalizePaymentChannel = (method: unknown): PaymentChannel => {
  const x = String(method ?? 'cash').toLowerCase().replace(/\s/g, '');
  if (x === 'cash') return 'cash';
  if (
    ['upi', 'bank_transfer', 'razorpay', 'online', 'card', 'neft', 'rtgs', 'imps', 'netbanking', 'cheque', 'dd'].some(
      (k) => x === k || x.includes(k),
    )
  )
    return 'bank';
  return 'other';
};

export type AuditPaymentRow = {
  id: string;
  charge_id: string;
  flat_number: string;
  amount: number;
  payment_method: string;
  payment_status: string;
  due_date: string | null;
  payment_date: string | null;
  created_at: string;
  transaction_id?: string | null;
  notes?: string | null;
  finance_entry_id: string | null;
};

export type AuditLedgerRow = {
  id: string;
  record_mode: string;
  destination: string;
  total_amount: number;
  payment_method: string;
  payment_status: string;
  entry_month: string | null;
  created_at: string;
  title: string | null;
  charge_id?: string | null;
  aggregate_flat_count?: number | null;
};

export type DuplicatePaymentGroup = {
  flat_number: string;
  charge_id: string;
  charge_title: string;
  month: string;
  payment_method: PaymentChannel;
  count: number;
  total_amount: number;
  payments: AuditPaymentRow[];
};

/** Same flat + charge + calendar month + channel (verified or pending). */
export function paymentDuplicateGroupKey(p: AuditPaymentRow): string {
  const dateStr = p.due_date || p.payment_date || p.created_at || '';
  const month = dateStr ? format(new Date(dateStr), 'yyyy-MM') : 'unknown';
  const channel = normalizePaymentChannel(p.payment_method);
  return `${p.flat_number}||${p.charge_id}||${month}||${channel}`;
}

export function findDuplicatePaymentGroups(
  payments: AuditPaymentRow[],
  chargeTitleById: Map<string, string>,
  options?: { chargeIds?: string[] },
): DuplicatePaymentGroup[] {
  const allowed = options?.chargeIds ? new Set(options.chargeIds) : null;
  const groups = new Map<string, AuditPaymentRow[]>();

  for (const p of payments) {
    if (p.payment_status !== 'verified' && p.payment_status !== 'pending') continue;
    if (allowed && !allowed.has(p.charge_id)) continue;
    const key = paymentDuplicateGroupKey(p);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(p);
  }

  const duplicates: DuplicatePaymentGroup[] = [];
  for (const [key, group] of groups) {
    if (group.length <= 1) continue;
    const [flat_number, charge_id, month, payment_method] = key.split('||') as [string, string, string, PaymentChannel];
    duplicates.push({
      flat_number,
      charge_id,
      charge_title: chargeTitleById.get(charge_id) ?? 'Unknown charge',
      month,
      payment_method,
      count: group.length,
      total_amount: group.reduce((sum, row) => sum + Number(row.amount || 0), 0),
      payments: group,
    });
  }

  duplicates.sort((a, b) => {
    if (a.month !== b.month) return b.month.localeCompare(a.month);
    return a.flat_number.localeCompare(b.flat_number);
  });

  return duplicates;
}

export type LedgerOvercountEntry = {
  id: string;
  title: string | null;
  total_amount: number;
  entry_month: string | null;
  record_mode: string;
  destination: string;
  payment_method: string;
  created_at: string;
};

export type DateBoundaryMismatch = {
  payment: AuditPaymentRow;
  paymentMonth: string;
  entryMonth: string;
  entryTitle: string | null;
  entryId: string;
};

export type LedgerOvercountMonth = {
  month: string;
  paymentTotal: number;
  reportTotal: number;
  excess: number;
  unlinkedLedger: LedgerOvercountEntry[];
  dateBoundary: DateBoundaryMismatch[];
};

const isReceiptDestination = (destination: string) =>
  destination === 'current_month_maintenance' || destination === 'corpus';

/** Matches FinanceManager period report receipt logic for a calendar month. */
export function analyzeLedgerOvercountByMonth(
  verifiedPayments: AuditPaymentRow[],
  allLedger: AuditLedgerRow[],
): LedgerOvercountMonth[] {
  const linkedFeIds = new Set<string>();
  for (const p of verifiedPayments) {
    if (p.finance_entry_id) linkedFeIds.add(p.finance_entry_id);
  }

  const ledgerById = new Map(allLedger.map((e) => [e.id, e]));

  const monthlyPaymentTotals = new Map<string, number>();
  for (const p of verifiedPayments) {
    const d = p.due_date || p.payment_date || p.created_at || '';
    if (!d) continue;
    const month = format(new Date(d), 'yyyy-MM');
    monthlyPaymentTotals.set(month, (monthlyPaymentTotals.get(month) || 0) + Number(p.amount || 0));
  }

  const months = new Set<string>([...monthlyPaymentTotals.keys()]);
  for (const e of allLedger) {
    if (!isReceiptDestination(e.destination)) continue;
    const m = e.entry_month || (e.created_at ? format(new Date(e.created_at), 'yyyy-MM') : '');
    if (m) months.add(m);
  }

  const issues: LedgerOvercountMonth[] = [];

  for (const month of months) {
    const fromYmd = `${month}-01`;
    const lastDay = new Date(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0).getDate();
    const toYmd = `${month}-${String(lastDay).padStart(2, '0')}`;
    const fromMs = new Date(`${fromYmd}T00:00:00`).getTime();
    const toMs = new Date(`${toYmd}T23:59:59.999`).getTime();

    let reportTotal = 0;
    for (const p of verifiedPayments) {
      const d = p.due_date || p.payment_date || p.created_at || '';
      if (!d) continue;
      const t = new Date(d).getTime();
      if (t >= fromMs && t <= toMs) reportTotal += Number(p.amount || 0);
    }

    const unlinkedLedger: LedgerOvercountEntry[] = [];
    for (const e of allLedger) {
      if (!isReceiptDestination(e.destination)) continue;
      const ledgerDate = e.entry_month ? `${e.entry_month}-01` : e.created_at;
      const t = new Date(ledgerDate).getTime();
      if (t < fromMs || t > toMs) continue;
      if (!linkedFeIds.has(e.id)) {
        reportTotal += Number(e.total_amount || 0);
        unlinkedLedger.push({
          id: e.id,
          title: e.title,
          total_amount: Number(e.total_amount || 0),
          entry_month: e.entry_month,
          record_mode: e.record_mode,
          destination: e.destination,
          payment_method: e.payment_method,
          created_at: e.created_at,
        });
      }
    }

    const paymentTotal = monthlyPaymentTotals.get(month) || 0;
    const excess = reportTotal - paymentTotal;
    if (excess <= 1) continue;

    const dateBoundary: DateBoundaryMismatch[] = [];
    for (const p of verifiedPayments) {
      if (!p.finance_entry_id) continue;
      const entry = ledgerById.get(p.finance_entry_id);
      if (!entry) continue;
      const pDate = p.due_date || p.payment_date || p.created_at || '';
      const pMonth = pDate ? format(new Date(pDate), 'yyyy-MM') : '';
      const eMonth = entry.entry_month || '';
      if (pMonth && eMonth && pMonth !== eMonth && (pMonth === month || eMonth === month)) {
        dateBoundary.push({
          payment: p,
          paymentMonth: pMonth,
          entryMonth: eMonth,
          entryTitle: entry.title,
          entryId: entry.id,
        });
      }
    }

    issues.push({
      month,
      paymentTotal,
      reportTotal,
      excess,
      unlinkedLedger,
      dateBoundary,
    });
  }

  issues.sort((a, b) => b.month.localeCompare(a.month));
  return issues;
}
