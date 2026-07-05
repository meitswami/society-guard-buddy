import { normalizePaymentChannel, type ChannelTotals } from '@/lib/cashBankChannel';
import { dateInInclusiveRange, isDateBefore, ledgerTransactionDate, paymentBillingDate } from '@/lib/financeDates';
import { financeExpenseHeadFromLedgerEntry, isEventFoodLedgerEntry } from '@/lib/financeExpenseHead';

/** Verified maintenance payment row — same fields Finance → Period report uses. */
export type FinancePeriodPayment = {
  id?: string;
  payment_status?: string;
  amount?: number;
  payment_method?: string;
  due_date?: string | null;
  finance_entry_id?: string | null;
  flat_number?: string;
  created_at?: string;
  notes?: string | null;
  transaction_id?: string | null;
  resident_name?: string;
  charge_id?: string;
};

/** Society finance ledger row (event food excluded upstream). */
export type FinancePeriodLedgerEntry = {
  id: string;
  record_mode?: string;
  destination: string;
  total_amount: number;
  payment_method: string;
  payment_status?: string;
  title?: string | null;
  notes?: string | null;
  transaction_id?: string | null;
  transaction_date?: string | null;
  entry_month?: string | null;
  created_at?: string;
  expense_id?: string | null;
  aggregate_flat_count?: number;
};

export type ExpenseByHeadRow = { cash: number; bank: number; other: number; total: number };

export type FinancePeriodReserveTransfer = {
  id: string;
  entry_month: string;
  amount: number;
  direction: string;
  payment_method: string;
  notes?: string | null;
  created_at: string;
};

export type FinancePeriodReportResult = {
  verifiedPaymentCount: number;
  maintenanceReceipts: number;
  corpusReceipts: number;
  receiptByMethod: ChannelTotals;
  totalReceipts: number;
  expenseByMethod: ChannelTotals;
  expenseByHead: [string, ExpenseByHeadRow][];
  totalExpenses: number;
  cashInHand: number;
  cashInBank: number;
  otherNet: number;
  totalBalance: number;
  extraLedgerReceipt: number;
  openingCash: number;
  openingBank: number;
  openingOther: number;
  openingBalance: number;
  closingCash: number;
  closingBank: number;
  closingOther: number;
  closingBalance: number;
};

export function collectLinkedFinanceEntryIds(payments: FinancePeriodPayment[]): Set<string> {
  const ids = new Set<string>();
  for (const p of payments) {
    if (String(p.payment_status) !== 'verified') continue;
    const feId = p.finance_entry_id;
    if (typeof feId === 'string' && feId.length > 0) ids.add(feId);
  }
  return ids;
}

/** Exclude event food ledger rows — same rule as Finance module. */
export function filterSocietyLedgerEntries<T extends { expense_id?: string | null; title?: string | null }>(
  entries: T[],
  expenseCategoryById: Map<string, string>,
): T[] {
  return entries.filter((e) => !isEventFoodLedgerEntry(e, expenseCategoryById));
}

/**
 * Core period report math — single source of truth for Finance → Period report,
 * Reports → net summary, and Cash Flow Statement opening/closing/receipts/expenses.
 */
export function computeFinancePeriodReport(input: {
  periodFrom: string;
  periodTo: string;
  payments: FinancePeriodPayment[];
  ledgerEntries: FinancePeriodLedgerEntry[];
  expenseCategoryById?: Map<string, string>;
}): FinancePeriodReportResult {
  const { periodFrom, periodTo, payments, ledgerEntries } = input;
  const expenseCategoryById = input.expenseCategoryById ?? new Map<string, string>();
  const allLinkedFeIds = collectLinkedFinanceEntryIds(payments);

  const openingReceipt = { cash: 0, bank: 0, other: 0 };
  const openingExpense = { cash: 0, bank: 0, other: 0 };

  for (const p of payments) {
    if (String(p.payment_status) !== 'verified') continue;
    const d = paymentBillingDate(p);
    if (!d || !isDateBefore(d, periodFrom)) continue;
    const amt = Number(p.amount || 0);
    const ch = normalizePaymentChannel(p.payment_method);
    openingReceipt[ch] += amt;
  }

  for (const e of ledgerEntries) {
    if (String(e.payment_status ?? 'verified') !== 'verified') continue;
    const ledgerDate = ledgerTransactionDate(e);
    if (!ledgerDate || !isDateBefore(ledgerDate, periodFrom)) continue;
    const amt = Number(e.total_amount || 0);
    const ch = normalizePaymentChannel(e.payment_method);
    if (e.destination === 'separate_entry') {
      openingExpense[ch] += amt;
    } else if (e.destination === 'current_month_maintenance' || e.destination === 'corpus') {
      if (!allLinkedFeIds.has(e.id)) openingReceipt[ch] += amt;
    }
  }

  const openingCash = openingReceipt.cash - openingExpense.cash;
  const openingBank = openingReceipt.bank - openingExpense.bank;
  const openingOther = openingReceipt.other - openingExpense.other;
  const openingBalance = openingCash + openingBank + openingOther;

  const receiptByMethod = { cash: 0, bank: 0, other: 0 };
  let verifiedPaymentCount = 0;
  let maintenanceReceipts = 0;

  for (const p of payments) {
    if (String(p.payment_status) !== 'verified') continue;
    const d = paymentBillingDate(p);
    if (!d || !dateInInclusiveRange(d, periodFrom, periodTo)) continue;
    const amt = Number(p.amount || 0);
    const ch = normalizePaymentChannel(p.payment_method);
    receiptByMethod[ch] += amt;
    maintenanceReceipts += amt;
    verifiedPaymentCount += 1;
  }

  const expenseByMethod = { cash: 0, bank: 0, other: 0 };
  const expenseByHead = new Map<string, ExpenseByHeadRow>();
  let extraLedgerReceipt = 0;
  let corpusReceipts = 0;

  for (const e of ledgerEntries) {
    if (String(e.payment_status ?? 'verified') !== 'verified') continue;
    const ledgerDate = ledgerTransactionDate(e);
    if (!ledgerDate || !dateInInclusiveRange(ledgerDate, periodFrom, periodTo)) continue;
    const amt = Number(e.total_amount || 0);
    const ch = normalizePaymentChannel(e.payment_method);
    if (e.destination === 'separate_entry') {
      expenseByMethod[ch] += amt;
      const head = financeExpenseHeadFromLedgerEntry(
        e.title,
        e.expense_id ? expenseCategoryById.get(e.expense_id) : null,
      );
      const cur = expenseByHead.get(head) ?? { cash: 0, bank: 0, other: 0, total: 0 };
      cur[ch] += amt;
      cur.total += amt;
      expenseByHead.set(head, cur);
    } else if (e.destination === 'current_month_maintenance' || e.destination === 'corpus') {
      if (!allLinkedFeIds.has(e.id)) {
        extraLedgerReceipt += amt;
        receiptByMethod[ch] += amt;
        if (e.destination === 'corpus') corpusReceipts += amt;
      }
    }
  }

  const totalReceipts = receiptByMethod.cash + receiptByMethod.bank + receiptByMethod.other;
  const totalExpenses = expenseByMethod.cash + expenseByMethod.bank + expenseByMethod.other;
  const cashInHand = receiptByMethod.cash - expenseByMethod.cash;
  const cashInBank = receiptByMethod.bank - expenseByMethod.bank;
  const otherNet = receiptByMethod.other - expenseByMethod.other;
  const totalBalance = cashInHand + cashInBank + otherNet;

  return {
    verifiedPaymentCount,
    maintenanceReceipts,
    corpusReceipts,
    receiptByMethod,
    totalReceipts,
    expenseByMethod,
    expenseByHead: [...expenseByHead.entries()].sort((a, b) => a[0].localeCompare(b[0])),
    totalExpenses,
    cashInHand,
    cashInBank,
    otherNet,
    totalBalance,
    extraLedgerReceipt,
    openingCash,
    openingBank,
    openingOther,
    openingBalance,
    closingCash: openingCash + cashInHand,
    closingBank: openingBank + cashInBank,
    closingOther: openingOther + otherNet,
    closingBalance: openingBalance + totalBalance,
  };
}
