import { useMemo } from 'react';
import { addToChannel, type ChannelTotals } from '@/lib/cashBankChannel';
import { financeExpenseHeadFromLedgerEntry } from '@/lib/financeExpenseHead';
import { ledgerMonthValue } from '@/lib/financeLedgerDisplay';
import type { FinanceLedgerRow } from '@/lib/financeManagerTypes';

export type TotalsInflowRow = {
  mode: string;
  destination: string;
  total: number;
  flatUnits: number;
  entries: number;
  byChannel: ChannelTotals;
};

export type TotalsOutflowRow = {
  head: string;
  total: number;
  flatUnits: number;
  entries: number;
  byChannel: ChannelTotals;
};

export function computeTotalsInflowBreakdown(
  ledgerEntries: FinanceLedgerRow[],
  totalsMonth: string,
): TotalsInflowRow[] {
  const map = new Map<string, { total: number; flatUnits: number; entries: number; byChannel: ChannelTotals }>();
  for (const e of ledgerEntries) {
    const m = ledgerMonthValue(e);
    if (m !== totalsMonth) continue;
    if (e.destination === 'separate_entry') continue;
    const k = `${e.record_mode}||${e.destination}`;
    const cur = map.get(k) ?? { total: 0, flatUnits: 0, entries: 0, byChannel: { cash: 0, bank: 0, other: 0 } };
    const amt = Number(e.total_amount || 0);
    cur.total += amt;
    cur.flatUnits += Number(e.aggregate_flat_count || 0);
    cur.entries += 1;
    addToChannel(cur.byChannel, e.payment_method, amt);
    map.set(k, cur);
  }
  return [...map.entries()]
    .map(([k, v]) => {
      const [mode, destination] = k.split('||');
      return { mode, destination, ...v };
    })
    .sort((a, b) => `${a.mode}${a.destination}`.localeCompare(`${b.mode}${b.destination}`));
}

export function computeTotalsOutflowBreakdown(
  societyLedgerEntries: FinanceLedgerRow[],
  totalsMonth: string,
  expenseCategoryById: Map<string, string>,
): TotalsOutflowRow[] {
  const map = new Map<string, { total: number; flatUnits: number; entries: number; byChannel: ChannelTotals }>();
  for (const e of societyLedgerEntries) {
    const m = ledgerMonthValue(e);
    if (m !== totalsMonth) continue;
    if (e.destination !== 'separate_entry') continue;
    const head = financeExpenseHeadFromLedgerEntry(e.title, e.expense_id ? expenseCategoryById.get(e.expense_id) : null);
    const cur = map.get(head) ?? { total: 0, flatUnits: 0, entries: 0, byChannel: { cash: 0, bank: 0, other: 0 } };
    const amt = Number(e.total_amount || 0);
    cur.total += amt;
    cur.flatUnits += Number(e.aggregate_flat_count || 0);
    cur.entries += 1;
    addToChannel(cur.byChannel, e.payment_method, amt);
    map.set(head, cur);
  }
  return [...map.entries()]
    .map(([head, v]) => ({ head, ...v }))
    .sort((a, b) => a.head.localeCompare(b.head));
}

function sumChannels(rows: { byChannel: ChannelTotals }[]): ChannelTotals {
  return rows.reduce(
    (acc, r) => {
      acc.cash += r.byChannel.cash;
      acc.bank += r.byChannel.bank;
      acc.other += r.byChannel.other;
      return acc;
    },
    { cash: 0, bank: 0, other: 0 } as ChannelTotals,
  );
}

export function useFinanceTotalsBreakdown(
  ledgerEntries: FinanceLedgerRow[],
  societyLedgerEntries: FinanceLedgerRow[],
  totalsMonth: string,
  expenseCategoryById: Map<string, string>,
) {
  const totalsBreakdown = useMemo(
    () => computeTotalsInflowBreakdown(ledgerEntries, totalsMonth),
    [ledgerEntries, totalsMonth],
  );

  const totalsMonthReceiptChannels = useMemo(() => sumChannels(totalsBreakdown), [totalsBreakdown]);

  const totalsMonthNet = useMemo(
    () => totalsBreakdown.reduce((s, r) => s + r.total, 0),
    [totalsBreakdown],
  );

  const totalsOutflowBreakdown = useMemo(
    () => computeTotalsOutflowBreakdown(societyLedgerEntries, totalsMonth, expenseCategoryById),
    [societyLedgerEntries, totalsMonth, expenseCategoryById],
  );

  const totalsMonthPaymentChannels = useMemo(
    () => sumChannels(totalsOutflowBreakdown),
    [totalsOutflowBreakdown],
  );

  const totalsMonthOutflow = useMemo(
    () => totalsOutflowBreakdown.reduce((s, r) => s + r.total, 0),
    [totalsOutflowBreakdown],
  );

  return {
    totalsBreakdown,
    totalsMonthReceiptChannels,
    totalsMonthNet,
    totalsOutflowBreakdown,
    totalsMonthPaymentChannels,
    totalsMonthOutflow,
  };
}
