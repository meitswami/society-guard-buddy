export type ReserveTransferDirection =
  | 'operating_to_reserve'
  | 'reserve_to_operating'
  | 'reserve_to_fixed'
  | 'reserve_to_emergency';

export const RESERVE_TRANSFER_LABELS: Record<ReserveTransferDirection, string> = {
  operating_to_reserve: 'Surplus → Reserve fund',
  reserve_to_operating: 'Reserve → Monthly operating (shortfall)',
  reserve_to_fixed: 'Reserve → Fixed asset / investment',
  reserve_to_emergency: 'Reserve → Emergency / contingency',
};

type LedgerRow = {
  entry_month?: string | null;
  transaction_date?: string | null;
  destination?: string | null;
  total_amount?: number | null;
  title?: string | null;
};

type TransferRow = {
  entry_month: string;
  amount: number;
  direction: ReserveTransferDirection;
};

type PaymentRow = {
  amount?: number | null;
  due_date?: string | null;
  payment_status?: string | null;
  charge_id?: string | null;
};

type ChargeRow = {
  id: string;
  frequency?: string | null;
  expense_group_id?: string | null;
};

export function ledgerMonthValue(e: LedgerRow): string {
  if (e.entry_month?.trim()) return e.entry_month.trim().slice(0, 7);
  if (e.transaction_date) return String(e.transaction_date).slice(0, 7);
  return '';
}

/** Monthly maintenance collections — excludes one-time / head-linked receipt types. */
export function monthlyOperatingInflow(
  month: string,
  payments: PaymentRow[],
  charges: ChargeRow[],
  chargeTitleById: Map<string, string>,
): number {
  const monthlyChargeIds = new Set(
    charges
      .filter((c) => c.frequency === 'monthly' && !c.expense_group_id)
      .map((c) => c.id),
  );
  let sum = 0;
  for (const p of payments) {
    if (String(p.payment_status) !== 'verified') continue;
    const cid = p.charge_id;
    if (!cid || !monthlyChargeIds.has(cid)) continue;
    const dueMonth = String(p.due_date || '').slice(0, 7);
    const titleMonth = extractMonthFromChargeTitle(chargeTitleById.get(cid) || '');
    const pm = titleMonth || dueMonth;
    if (pm === month) sum += Number(p.amount || 0);
  }
  return sum;
}

function extractMonthFromChargeTitle(title: string): string | null {
  const m = title.match(/(\d{4})-(\d{2})/);
  if (m) return `${m[1]}-${m[2]}`;
  const months = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
    'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];
  const lower = title.toLowerCase();
  for (let i = 0; i < 12; i++) {
    if (lower.includes(months[i]) || lower.includes(months[i + 12])) {
      const yearMatch = title.match(/20\d{2}/);
      const year = yearMatch ? yearMatch[0] : String(new Date().getFullYear());
      return `${year}-${String(i + 1).padStart(2, '0')}`;
    }
  }
  return null;
}

/** Operational outflows for the month (society payment ledger, separate_entry). */
export function monthlyOperatingOutflow(
  month: string,
  ledgerEntries: LedgerRow[],
  isOutflowEntry: (e: LedgerRow) => boolean,
): number {
  let sum = 0;
  for (const e of ledgerEntries) {
    if (!isOutflowEntry(e)) continue;
    if (ledgerMonthValue(e) !== month) continue;
    sum += Number(e.total_amount || 0);
  }
  return sum;
}

export function reserveFundBalance(
  ledgerEntries: LedgerRow[],
  transfers: TransferRow[],
): number {
  let balance = 0;
  for (const e of ledgerEntries) {
    if (e.destination !== 'corpus') continue;
    if (/^reserve fund\s*[—–-]/i.test(String(e.title || ''))) continue;
    balance += Number(e.total_amount || 0);
  }
  for (const t of transfers) {
    if (t.direction === 'operating_to_reserve') balance += Number(t.amount || 0);
    else balance -= Number(t.amount || 0);
  }
  return balance;
}

export function transfersForMonth(transfers: TransferRow[], month: string) {
  return transfers.filter((t) => t.entry_month === month);
}

export function netTransferEffectForMonth(transfers: TransferRow[], month: string): number {
  let net = 0;
  for (const t of transfersForMonth(transfers, month)) {
    if (t.direction === 'operating_to_reserve') net -= Number(t.amount || 0);
    else net += Number(t.amount || 0);
  }
  return net;
}
