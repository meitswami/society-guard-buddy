import { normalizePaymentChannel, type PaymentChannel } from '@/lib/cashBankChannel';
import { dateInInclusiveRange, ledgerTransactionDate, paymentBillingDate } from '@/lib/financeDates';
import { financeExpenseHeadFromLedgerEntry } from '@/lib/financeExpenseHead';
import { formatLedgerFieldLabel } from '@/lib/financeLedgerDisplay';
import { compareByFlatThenDate, compareFlatNumbers } from '@/lib/flatMultiSelectOptions';
import {
  collectLinkedFinanceEntryIds,
  computeFinancePeriodReport,
  type FinancePeriodLedgerEntry,
  type FinancePeriodPayment,
  type FinancePeriodReserveTransfer,
  type FinanceOpeningBalanceAnchor,
} from '@/lib/financePeriodReport';

export type { FinancePeriodPayment, FinancePeriodLedgerEntry, FinancePeriodReserveTransfer };

export type ReserveTransferForCfs = FinancePeriodReserveTransfer;

export interface StatementPeriod {
  from: string;
  to: string;
}

export interface StatementEntry {
  id: string;
  date: string;
  label: string;
  sublabel?: string;
  amount: number;
  type: 'receipt' | 'expense' | 'reserve' | 'corpus';
  channel: PaymentChannel;
  record_mode?: string;
  destination?: string;
  payment_method?: string;
  notes?: string;
  transaction_id?: string;
  aggregate_flat_count?: number;
  source?: 'payment' | 'ledger' | 'reserve';
  expenseHead?: string;
}

export interface CashFlowLine {
  id: string;
  label: string;
  amount: number;
  section: 'operating' | 'investing' | 'financing' | 'summary';
  indent?: boolean;
  bold?: boolean;
  drillable?: boolean;
  drillKind?: 'receipts' | 'expenses' | 'expense_head' | 'corpus' | 'reserve' | 'cash_statement' | 'bank_statement';
  drillKey?: string;
}

export interface CashFlowResult {
  lines: CashFlowLine[];
  periodReport: ReturnType<typeof computeFinancePeriodReport>;
  opening: { cash: number; bank: number; other: number; total: number };
  closing: { cash: number; bank: number; other: number; total: number };
  netChange: { cash: number; bank: number; other: number; total: number };
  periodReceipts: number;
  periodExpenses: number;
  expenseByHead: [string, number][];
  statementEntries: StatementEntry[];
  maintenanceReceipts: number;
  corpusReceipts: number;
}

function reserveTransferDate(r: ReserveTransferForCfs): string {
  return `${r.entry_month}-01`;
}

function reserveToStatement(r: ReserveTransferForCfs): StatementEntry {
  const ch = normalizePaymentChannel(r.payment_method);
  const outflow =
    r.direction === 'operating_to_reserve' ||
    r.direction === 'reserve_to_fixed' ||
    r.direction === 'reserve_to_emergency';
  return {
    id: r.id,
    date: reserveTransferDate(r),
    label: r.direction.replace(/_/g, ' '),
    sublabel: r.notes || 'Reserve fund transfer',
    amount: outflow ? -Number(r.amount) : Number(r.amount),
    type: 'reserve',
    channel: ch,
    payment_method: r.payment_method,
    notes: r.notes ?? undefined,
    source: 'reserve',
  };
}

/** Build chronological statement rows — same sources as Finance → Transactions. */
export function buildPeriodStatementEntries(input: {
  periodFrom: string;
  periodTo: string;
  payments: FinancePeriodPayment[];
  ledgerEntries: FinancePeriodLedgerEntry[];
  reserveTransfers?: ReserveTransferForCfs[];
  expenseCategoryById?: Map<string, string>;
}): StatementEntry[] {
  const { periodFrom, periodTo, payments, ledgerEntries } = input;
  const expenseCategoryById = input.expenseCategoryById ?? new Map<string, string>();
  const allLinkedFeIds = collectLinkedFinanceEntryIds(payments);
  const entries: StatementEntry[] = [];

  for (const p of payments) {
    if (String(p.payment_status) !== 'verified') continue;
    const d = paymentBillingDate(p);
    if (!d || !dateInInclusiveRange(d, periodFrom, periodTo)) continue;
    entries.push({
      id: p.id ?? `mp-${d}-${p.flat_number}`,
      date: d,
      label: `Maintenance receipt · Flat ${p.flat_number ?? '—'}`,
      sublabel: p.resident_name || undefined,
      amount: Number(p.amount || 0),
      type: 'receipt',
      channel: normalizePaymentChannel(p.payment_method),
      payment_method: p.payment_method,
      notes: p.notes ?? undefined,
      transaction_id: p.transaction_id ?? undefined,
      destination: 'current_month_maintenance',
      source: 'payment',
    });
  }

  for (const e of ledgerEntries) {
    if (String(e.payment_status ?? 'verified') !== 'verified') continue;
    const ledgerDate = ledgerTransactionDate(e);
    if (!ledgerDate || !dateInInclusiveRange(ledgerDate, periodFrom, periodTo)) continue;

    const ch = normalizePaymentChannel(e.payment_method);
    const isExpense = e.destination === 'separate_entry';
    const isCorpus = e.destination === 'corpus';

    if (isExpense) {
      const head = financeExpenseHeadFromLedgerEntry(
        e.title,
        e.expense_id ? expenseCategoryById.get(e.expense_id) : null,
      );
      entries.push({
        id: e.id,
        date: ledgerDate,
        label: e.title || `Society payment — ${head}`,
        sublabel: `Head: ${head} · ${e.payment_method || 'N/A'}`,
        amount: -Number(e.total_amount || 0),
        type: 'expense',
        channel: ch,
        record_mode: e.record_mode,
        destination: e.destination,
        payment_method: e.payment_method,
        notes: e.notes ?? undefined,
        transaction_id: e.transaction_id ?? undefined,
        aggregate_flat_count: e.aggregate_flat_count,
        source: 'ledger',
        expenseHead: head,
      });
    } else if (e.destination === 'current_month_maintenance' || e.destination === 'corpus') {
      if (allLinkedFeIds.has(e.id)) continue;
      entries.push({
        id: e.id,
        date: ledgerDate,
        label: e.title || `${formatLedgerFieldLabel(e.record_mode, 'Ledger')} → ${formatLedgerFieldLabel(e.destination)}`,
        sublabel: `Method: ${e.payment_method || 'N/A'}`,
        amount: Number(e.total_amount || 0),
        type: isCorpus ? 'corpus' : 'receipt',
        channel: ch,
        record_mode: e.record_mode,
        destination: e.destination,
        payment_method: e.payment_method,
        notes: e.notes ?? undefined,
        transaction_id: e.transaction_id ?? undefined,
        aggregate_flat_count: e.aggregate_flat_count,
        source: 'ledger',
      });
    }
  }

  for (const r of input.reserveTransfers ?? []) {
    if (!dateInInclusiveRange(reserveTransferDate(r), periodFrom, periodTo)) continue;
    entries.push(reserveToStatement(r));
  }

  return entries.sort((a, b) => a.date.localeCompare(b.date) || a.label.localeCompare(b.label));
}

export function computeCashFlowStatement(
  period: StatementPeriod,
  payments: FinancePeriodPayment[],
  ledgerEntries: FinancePeriodLedgerEntry[],
  reserveTransfers: ReserveTransferForCfs[],
  expenseCategoryById: Map<string, string> = new Map(),
  openingBalanceAnchors: FinanceOpeningBalanceAnchor[] = [],
): CashFlowResult {
  const periodReport = computeFinancePeriodReport({
    periodFrom: period.from,
    periodTo: period.to,
    payments,
    ledgerEntries,
    expenseCategoryById,
    openingBalanceAnchors,
  });

  const periodReserve = reserveTransfers.filter((r) =>
    dateInInclusiveRange(reserveTransferDate(r), period.from, period.to),
  );

  let investingOut = 0;
  let investingIn = 0;
  let financingIn = 0;

  for (const r of periodReserve) {
    const amt = Number(r.amount || 0);
    if (['operating_to_reserve', 'reserve_to_fixed', 'reserve_to_emergency'].includes(r.direction)) {
      investingOut += amt;
    } else if (r.direction === 'reserve_to_operating') {
      financingIn += amt;
    }
  }

  const netOperating = periodReport.totalBalance;
  const netInvesting = investingIn - investingOut;
  const netFinancing = financingIn;
  const netChangeTotal = netOperating + netInvesting + netFinancing;

  const opening = {
    cash: periodReport.openingCash,
    bank: periodReport.openingBank,
    other: periodReport.openingOther,
    total: periodReport.openingBalance,
  };

  const closing = {
    cash: periodReport.closingCash,
    bank: periodReport.closingBank,
    other: periodReport.closingOther,
    total: periodReport.closingBalance,
  };

  const netChange = {
    cash: periodReport.cashInHand,
    bank: periodReport.cashInBank,
    other: periodReport.otherNet,
    total: netChangeTotal,
  };

  const { maintenanceReceipts, corpusReceipts } = periodReport;
  const expenseByHeadFlat: [string, number][] = periodReport.expenseByHead.map(([head, v]) => [head, v.total]);

  const lines: CashFlowLine[] = [
    { id: 'sec-op', label: 'Operating Activities', amount: 0, section: 'operating', bold: true },
    {
      id: 'op-receipts',
      label: 'Collections from members (verified receipts)',
      amount: maintenanceReceipts,
      section: 'operating',
      indent: true,
      drillable: maintenanceReceipts > 0,
      drillKind: 'receipts',
    },
    {
      id: 'op-ledger-extra',
      label: 'Ledger-only inflows (not linked to receipts)',
      amount: periodReport.extraLedgerReceipt,
      section: 'operating',
      indent: true,
      drillable: periodReport.extraLedgerReceipt > 0,
      drillKind: 'receipts',
    },
    {
      id: 'op-corpus',
      label: 'Corpus fund receipts',
      amount: corpusReceipts,
      section: 'operating',
      indent: true,
      drillable: corpusReceipts > 0,
      drillKind: 'corpus',
    },
    ...expenseByHeadFlat.map(([head, total]) => ({
      id: `op-exp-${head}`,
      label: `Payment — ${head}`,
      amount: -total,
      section: 'operating' as const,
      indent: true,
      drillable: true,
      drillKind: 'expense_head' as const,
      drillKey: head,
    })),
    {
      id: 'op-net',
      label: 'Net cash from operating activities',
      amount: netOperating,
      section: 'operating',
      bold: true,
    },
    { id: 'sec-inv', label: 'Investing Activities', amount: 0, section: 'investing', bold: true },
    {
      id: 'inv-reserve',
      label: 'Reserve fund transfers (out)',
      amount: -investingOut,
      section: 'investing',
      indent: true,
      drillable: investingOut > 0,
      drillKind: 'reserve',
      drillKey: 'out',
    },
    {
      id: 'inv-net',
      label: 'Net cash from investing activities',
      amount: netInvesting,
      section: 'investing',
      bold: true,
    },
    { id: 'sec-fin', label: 'Financing Activities', amount: 0, section: 'financing', bold: true },
    {
      id: 'fin-reserve',
      label: 'Reserve draw to operating',
      amount: financingIn,
      section: 'financing',
      indent: true,
      drillable: financingIn > 0,
      drillKind: 'reserve',
      drillKey: 'in',
    },
    {
      id: 'fin-net',
      label: 'Net cash from financing activities',
      amount: netFinancing,
      section: 'financing',
      bold: true,
    },
    { id: 'sep1', label: '', amount: 0, section: 'summary' },
    {
      id: 'net-change',
      label: 'Net increase / (decrease) in cash & bank',
      amount: netChangeTotal,
      section: 'summary',
      bold: true,
    },
    {
      id: 'open-cash',
      label: 'Opening — Cash in hand',
      amount: opening.cash,
      section: 'summary',
      indent: true,
      drillable: true,
      drillKind: 'cash_statement',
    },
    {
      id: 'open-bank',
      label: 'Opening — Balance in bank',
      amount: opening.bank,
      section: 'summary',
      indent: true,
      drillable: true,
      drillKind: 'bank_statement',
    },
    {
      id: 'close-cash',
      label: 'Closing — Cash in hand',
      amount: closing.cash,
      section: 'summary',
      indent: true,
      drillable: true,
      drillKind: 'cash_statement',
    },
    {
      id: 'close-bank',
      label: 'Closing — Balance in bank',
      amount: closing.bank,
      section: 'summary',
      indent: true,
      drillable: true,
      drillKind: 'bank_statement',
    },
  ];

  const statementEntries = buildPeriodStatementEntries({
    periodFrom: period.from,
    periodTo: period.to,
    payments,
    ledgerEntries,
    reserveTransfers,
    expenseCategoryById,
  });

  return {
    lines,
    periodReport,
    opening,
    closing,
    netChange,
    periodReceipts: periodReport.totalReceipts,
    periodExpenses: periodReport.totalExpenses,
    expenseByHead: expenseByHeadFlat,
    statementEntries,
    maintenanceReceipts,
    corpusReceipts,
  };
}

export function filterStatementByChannel(entries: StatementEntry[], channel: PaymentChannel): StatementEntry[] {
  return entries.filter((e) => e.channel === channel);
}

export function addRunningBalance(
  entries: StatementEntry[],
  openingBalance: number,
): (StatementEntry & { runningBalance: number })[] {
  let bal = openingBalance;
  return entries.map((e) => {
    bal += e.amount;
    return { ...e, runningBalance: bal };
  });
}

export function filterStatementEntriesForDrill(
  entries: StatementEntry[],
  kind: NonNullable<CashFlowLine['drillKind']>,
  drillKey?: string,
): StatementEntry[] {
  if (kind === 'receipts') {
    const filtered = entries.filter((e) => e.type === 'receipt' || e.type === 'corpus');
    return sortFlatMaintenanceReceiptEntries(filtered);
  }
  if (kind === 'corpus') return entries.filter((e) => e.type === 'corpus');
  if (kind === 'expense_head' && drillKey) {
    return entries.filter((e) => e.type === 'expense' && e.expenseHead === drillKey);
  }
  if (kind === 'reserve') {
    return entries.filter((e) => e.type === 'reserve');
  }
  return entries;
}

function flatNumberFromStatementLabel(label: string): string | null {
  const m = label.match(/Flat\s+(\S+)/i);
  return m?.[1] ?? null;
}

/** Flat maintenance receipts in numeric flat order (101 → 605); others interleaved by date. */
export function sortFlatMaintenanceReceiptEntries(entries: StatementEntry[]): StatementEntry[] {
  return [...entries].sort((a, b) => {
    const flatA = flatNumberFromStatementLabel(a.label);
    const flatB = flatNumberFromStatementLabel(b.label);
    const byFlatOrDate = compareByFlatThenDate(flatA, flatB, a.date, b.date);
    if (byFlatOrDate !== 0) return byFlatOrDate;
    return a.label.localeCompare(b.label);
  });
}
