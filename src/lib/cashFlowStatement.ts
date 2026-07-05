import { normalizePaymentChannel, type PaymentChannel } from '@/lib/cashBankChannel';
import { financeExpenseHeadFromLedgerEntry } from '@/lib/financeExpenseHead';
import { dateInInclusiveRange, isDateBefore, ledgerTransactionDate } from '@/lib/financeDates';

export interface FinanceEntryForCfs {
  id: string;
  record_mode: string;
  destination: string;
  total_amount: number;
  entry_month: string | null;
  created_at: string;
  payment_status: string;
  payment_method: string;
  title?: string | null;
  notes?: string | null;
  transaction_id?: string | null;
  transaction_date?: string | null;
  expense_id?: string | null;
  aggregate_flat_count?: number;
}

export interface ReserveTransferForCfs {
  id: string;
  entry_month: string;
  amount: number;
  direction: string;
  payment_method: string;
  notes?: string | null;
  created_at: string;
}

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
  opening: { cash: number; bank: number; other: number; total: number };
  closing: { cash: number; bank: number; other: number; total: number };
  netChange: { cash: number; bank: number; other: number; total: number };
  periodReceipts: number;
  periodExpenses: number;
  expenseByHead: [string, number][];
  statementEntries: StatementEntry[];
}

function isVerified(e: FinanceEntryForCfs): boolean {
  return String(e.payment_status) === 'verified';
}

function entryDate(e: FinanceEntryForCfs): string {
  return ledgerTransactionDate(e);
}

function reserveTransferDate(r: ReserveTransferForCfs): string {
  return `${r.entry_month}-01`;
}

function entryToStatement(e: FinanceEntryForCfs, expenseHead?: string): StatementEntry {
  const ch = normalizePaymentChannel(e.payment_method);
  const isExpense = e.destination === 'separate_entry';
  const isCorpus = e.destination === 'corpus';
  return {
    id: e.id,
    date: entryDate(e),
    label: e.title || `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
    sublabel: expenseHead || `Method: ${e.payment_method || 'N/A'}`,
    amount: isExpense ? -Number(e.total_amount || 0) : Number(e.total_amount || 0),
    type: isExpense ? 'expense' : isCorpus ? 'corpus' : 'receipt',
    channel: ch,
    record_mode: e.record_mode,
    destination: e.destination,
    payment_method: e.payment_method,
    notes: e.notes ?? undefined,
    transaction_id: e.transaction_id ?? undefined,
    aggregate_flat_count: e.aggregate_flat_count,
  };
}

function reserveToStatement(r: ReserveTransferForCfs): StatementEntry {
  const ch = normalizePaymentChannel(r.payment_method);
  const outflow = r.direction === 'operating_to_reserve' || r.direction === 'reserve_to_fixed' || r.direction === 'reserve_to_emergency';
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
  };
}

export function computeCashFlowStatement(
  period: StatementPeriod,
  entries: FinanceEntryForCfs[],
  reserveTransfers: ReserveTransferForCfs[],
  expenseCategoryById: Map<string, string> = new Map(),
): CashFlowResult {
  const verified = entries.filter(isVerified);
  const beforePeriod = verified.filter((e) => isDateBefore(entryDate(e), period.from));
  const inPeriod = verified.filter((e) => dateInInclusiveRange(entryDate(e), period.from, period.to));

  const openingReceipt = { cash: 0, bank: 0, other: 0 };
  const openingExpense = { cash: 0, bank: 0, other: 0 };
  for (const e of beforePeriod) {
    const amt = Number(e.total_amount || 0);
    const ch = normalizePaymentChannel(e.payment_method);
    if (e.destination === 'separate_entry') openingExpense[ch] += amt;
    else if (e.destination === 'current_month_maintenance' || e.destination === 'corpus') openingReceipt[ch] += amt;
  }

  const opening = {
    cash: openingReceipt.cash - openingExpense.cash,
    bank: openingReceipt.bank - openingExpense.bank,
    other: openingReceipt.other - openingExpense.other,
    total: 0,
  };
  opening.total = opening.cash + opening.bank + opening.other;

  const receiptByChannel = { cash: 0, bank: 0, other: 0 };
  const expenseByChannel = { cash: 0, bank: 0, other: 0 };
  const expenseByHead = new Map<string, number>();
  let corpusReceipts = 0;
  let maintenanceReceipts = 0;

  for (const e of inPeriod) {
    const amt = Number(e.total_amount || 0);
    const ch = normalizePaymentChannel(e.payment_method);
    if (e.destination === 'separate_entry') {
      expenseByChannel[ch] += amt;
      const head = financeExpenseHeadFromLedgerEntry(
        e.title,
        e.expense_id ? expenseCategoryById.get(e.expense_id) : null,
      );
      expenseByHead.set(head, (expenseByHead.get(head) ?? 0) + amt);
    } else if (e.destination === 'corpus') {
      corpusReceipts += amt;
      receiptByChannel[ch] += amt;
    } else if (e.destination === 'current_month_maintenance') {
      maintenanceReceipts += amt;
      receiptByChannel[ch] += amt;
    }
  }

  const periodReserve = reserveTransfers.filter((r) =>
    dateInInclusiveRange(reserveTransferDate(r), period.from, period.to),
  );
  let investingOut = 0;
  let investingIn = 0;
  let financingIn = 0;
  let financingOut = 0;

  for (const r of periodReserve) {
    const amt = Number(r.amount || 0);
    if (r.direction === 'operating_to_reserve' || r.direction === 'reserve_to_fixed' || r.direction === 'reserve_to_emergency') {
      investingOut += amt;
    } else if (r.direction === 'reserve_to_operating') {
      financingIn += amt;
    }
  }

  const periodReceipts = receiptByChannel.cash + receiptByChannel.bank + receiptByChannel.other;
  const periodExpenses = expenseByChannel.cash + expenseByChannel.bank + expenseByChannel.other;
  const netOperating = periodReceipts - periodExpenses;
  const netInvesting = investingIn - investingOut;
  const netFinancing = financingIn - financingOut;
  const netChangeTotal = netOperating + netInvesting + netFinancing;

  const netChange = {
    cash: receiptByChannel.cash - expenseByChannel.cash,
    bank: receiptByChannel.bank - expenseByChannel.bank,
    other: receiptByChannel.other - expenseByChannel.other,
    total: netChangeTotal,
  };

  const closing = {
    cash: opening.cash + netChange.cash,
    bank: opening.bank + netChange.bank,
    other: opening.other + netChange.other,
    total: opening.total + netChange.total,
  };

  const lines: CashFlowLine[] = [
    { id: 'sec-op', label: 'Operating Activities', amount: 0, section: 'operating', bold: true },
    {
      id: 'op-receipts',
      label: 'Collections from members & outsiders',
      amount: maintenanceReceipts,
      section: 'operating',
      indent: true,
      drillable: true,
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
    ...[...expenseByHead.entries()]
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([head, total]) => ({
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
      drillable: true,
      drillKind: 'receipts',
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
      drillKey: 'opening',
    },
    {
      id: 'open-bank',
      label: 'Opening — Balance in bank',
      amount: opening.bank,
      section: 'summary',
      indent: true,
      drillable: true,
      drillKind: 'bank_statement',
      drillKey: 'opening',
    },
    {
      id: 'close-cash',
      label: 'Closing — Cash in hand',
      amount: closing.cash,
      section: 'summary',
      indent: true,
      drillable: true,
      drillKind: 'cash_statement',
      drillKey: 'closing',
    },
    {
      id: 'close-bank',
      label: 'Closing — Balance in bank',
      amount: closing.bank,
      section: 'summary',
      indent: true,
      drillable: true,
      drillKind: 'bank_statement',
      drillKey: 'closing',
    },
  ];

  const statementEntries: StatementEntry[] = [
    ...inPeriod.map((e) =>
      entryToStatement(
        e,
        e.destination === 'separate_entry'
          ? financeExpenseHeadFromLedgerEntry(e.title, e.expense_id ? expenseCategoryById.get(e.expense_id) : null)
          : undefined,
      ),
    ),
    ...periodReserve.map(reserveToStatement),
  ].sort((a, b) => a.date.localeCompare(b.date) || a.label.localeCompare(b.label));

  return {
    lines,
    opening,
    closing,
    netChange,
    periodReceipts,
    periodExpenses,
    expenseByHead: [...expenseByHead.entries()].sort((a, b) => a[0].localeCompare(b[0])),
    statementEntries,
  };
}

export function filterStatementByChannel(entries: StatementEntry[], channel: PaymentChannel): StatementEntry[] {
  return entries.filter((e) => e.channel === channel);
}

export function addRunningBalance(entries: StatementEntry[], openingBalance: number): (StatementEntry & { runningBalance: number })[] {
  let bal = openingBalance;
  return entries.map((e) => {
    bal += e.amount;
    return { ...e, runningBalance: bal };
  });
}
