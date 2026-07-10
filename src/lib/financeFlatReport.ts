import { compareFlatNumbers } from '@/lib/flatMultiSelectOptions';
import { ledgerTransactionDate, paymentBillingDate } from '@/lib/financeDates';
import type { FinanceLedgerRow, FlatReportRow, SocietyFlatRow } from '@/lib/financeManagerTypes';

export type BuildFlatReportRowsInput = {
  from: string;
  to: string;
  selectedFlat: string;
  payments: unknown[];
  ledgerEntries: FinanceLedgerRow[];
  flatReportExpenses: Array<Record<string, unknown> & { id?: string; group_name?: string }>;
  flatReportSplits: Array<Record<string, unknown> & { expense_id?: string; flat_number?: string; amount?: number; is_settled?: boolean }>;
  flats: SocietyFlatRow[];
  primaryByFlatId: Map<string, string>;
  charges: Array<{ id?: string; title?: string }>;
};

export function buildFlatReportRows(input: BuildFlatReportRowsInput): FlatReportRow[] {
  const {
    from,
    to,
    selectedFlat,
    payments,
    ledgerEntries,
    flatReportExpenses,
    flatReportSplits,
    flats,
    primaryByFlatId,
    charges,
  } = input;

  const fromMs = new Date(`${from}T00:00:00`).getTime();
  const toMs = new Date(`${to}T23:59:59.999`).getTime();
  const isInRange = (iso: string) => {
    const t = new Date(iso).getTime();
    return !Number.isNaN(t) && t >= fromMs && t <= toMs;
  };

  const flatMap = new Map<string, FlatReportRow>();
  const getRow = (flatNum: string): FlatReportRow => {
    if (!flatMap.has(flatNum)) {
      const flat = flats.find((f) => f.flat_number === flatNum);
      const resName = flat?.id ? primaryByFlatId.get(flat.id) || flat.owner_name || flatNum : flatNum;
      flatMap.set(flatNum, {
        flat_number: flatNum,
        resident_name: resName ?? flatNum,
        maintenance_paid: 0,
        maintenance_count: 0,
        expense_share: 0,
        expense_count: 0,
        settled_amount: 0,
        unsettled_amount: 0,
        net_position: 0,
        details: [],
      });
    }
    return flatMap.get(flatNum)!;
  };

  const countedFinanceEntryIds = new Set<string>();
  for (const p of payments) {
    const payment = p as {
      payment_status?: string;
      flat_number?: string;
      amount?: number;
      charge_id?: string;
      payment_method?: string;
      finance_entry_id?: string;
    };
    if (String(payment.payment_status) !== 'verified') continue;
    const d = paymentBillingDate(payment);
    if (!d || !isInRange(d)) continue;
    const flatNum = String(payment.flat_number || '');
    if (!flatNum) continue;
    const amt = Number(payment.amount || 0);
    const row = getRow(flatNum);
    row.maintenance_paid += amt;
    row.maintenance_count += 1;
    const chargeTitle = charges.find((c) => c.id === payment.charge_id)?.title ?? 'Maintenance';
    row.details.push({
      type: 'maintenance',
      title: chargeTitle,
      amount: amt,
      date: d.slice(0, 10),
      method: String(payment.payment_method || 'cash'),
      status: 'paid',
    });
    const feId = payment.finance_entry_id;
    if (typeof feId === 'string' && feId.length > 0) countedFinanceEntryIds.add(feId);
  }

  for (const e of ledgerEntries) {
    if (e.destination === 'separate_entry') continue;
    const ledgerDate = ledgerTransactionDate(e);
    if (!ledgerDate || !isInRange(ledgerDate)) continue;
    if (e.record_mode === 'flats_only' && countedFinanceEntryIds.has(e.id)) continue;
    const allocations = e.finance_entry_allocations ?? [];
    for (const alloc of allocations) {
      const flatNum = alloc.flat_number;
      if (!flatNum || flatNum === 'SOCIETY') continue;
      const amt = Number(alloc.amount || 0);
      const row = getRow(flatNum);
      row.maintenance_paid += amt;
      row.maintenance_count += 1;
      row.details.push({
        type: 'maintenance',
        title: e.title || 'Ledger receipt',
        amount: amt,
        date: ledgerDate.slice(0, 10),
        method: e.payment_method || 'other',
        status: 'verified',
      });
    }
  }

  for (const split of flatReportSplits) {
    const exp = flatReportExpenses.find((e) => e.id === split.expense_id);
    if (!exp) continue;
    const expDate = String(exp.expense_date || '');
    if (!isInRange(expDate)) continue;
    const flatNum = String(split.flat_number || '');
    if (!flatNum || flatNum === 'SOCIETY') continue;
    const amt = Number(split.amount || 0);
    const row = getRow(flatNum);
    row.expense_share += amt;
    row.expense_count += 1;
    if (split.is_settled) {
      row.settled_amount += amt;
    } else {
      row.unsettled_amount += amt;
    }
    row.details.push({
      type: 'expense',
      title: String(exp.title || 'Expense'),
      amount: amt,
      date: expDate.slice(0, 10),
      method: String(exp.payment_method || 'cash'),
      status: split.is_settled ? 'settled' : 'pending',
      group_name: exp.group_name,
    });
  }

  for (const row of flatMap.values()) {
    row.net_position = row.maintenance_paid - row.expense_share;
    row.details.sort((a, b) => b.date.localeCompare(a.date));
  }

  let rows = [...flatMap.values()].sort((a, b) => compareFlatNumbers(a.flat_number, b.flat_number));
  if (selectedFlat !== 'all') {
    rows = rows.filter((r) => r.flat_number === selectedFlat);
  }
  return rows;
}
