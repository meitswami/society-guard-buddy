import { format } from 'date-fns';
import { ledgerTransactionDate, paymentBillingDate } from '@/lib/financeDates';

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
  const dateStr = paymentBillingDate(p) || '';
  const month = dateStr ? format(new Date(dateStr), 'yyyy-MM') : 'unknown';
  const channel = normalizePaymentChannel(p.payment_method);
  return `${p.flat_number}||${p.charge_id}||${month}||${channel}`;
}

export type ReceiptHeadRecordingTarget = {
  flatNumber: string;
  dueDate: string;
  chargeId: string;
  paymentMethod: string;
};

/** Key used to block a new payment when the receipt head is already recorded. */
export function receiptHeadKeyFromRecording(
  flatNumber: string,
  chargeId: string,
  dueDate: string,
  paymentMethod: string,
): string {
  const month = dueDate.slice(0, 7);
  return `${flatNumber}||${chargeId}||${month}||${normalizePaymentChannel(paymentMethod)}`;
}

/** Find verified/pending payments that already occupy the same receipt head slot. */
export function findReceiptHeadConflicts(
  existingPayments: AuditPaymentRow[],
  targets: ReceiptHeadRecordingTarget[],
): AuditPaymentRow[] {
  const targetKeys = new Set(
    targets.map((t) => receiptHeadKeyFromRecording(t.flatNumber, t.chargeId, t.dueDate, t.paymentMethod)),
  );
  const seen = new Set<string>();
  const conflicts: AuditPaymentRow[] = [];

  for (const p of existingPayments) {
    if (p.payment_status !== 'verified' && p.payment_status !== 'pending') continue;
    const key = paymentDuplicateGroupKey(p);
    if (!targetKeys.has(key) || seen.has(p.id)) continue;
    seen.add(p.id);
    conflicts.push(p);
  }

  return conflicts;
}

export type ReceiptHeadLookupFilter = {
  flat_number?: string;
  charge_id?: string;
  month?: string;
};

/** Lookup recorded receipt-head payments (including single entries) for audit edit/delete. */
export function findReceiptHeadLookupGroups(
  payments: AuditPaymentRow[],
  chargeTitleById: Map<string, string>,
  filter: ReceiptHeadLookupFilter,
): DuplicatePaymentGroup[] {
  const flat = filter.flat_number?.trim().toUpperCase();
  const chargeId = filter.charge_id?.trim();
  const month = filter.month?.trim();

  const groups = new Map<string, AuditPaymentRow[]>();
  for (const p of payments) {
    if (p.payment_status !== 'verified' && p.payment_status !== 'pending') continue;
    if (flat && p.flat_number.toUpperCase() !== flat) continue;
    if (chargeId && p.charge_id !== chargeId) continue;
    const key = paymentDuplicateGroupKey(p);
    const pMonth = key.split('||')[2];
    if (month && pMonth !== month) continue;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(p);
  }

  const results: DuplicatePaymentGroup[] = [];
  for (const [key, group] of groups) {
    const [flat_number, charge_id, groupMonth, payment_method] = key.split('||') as [
      string,
      string,
      string,
      PaymentChannel,
    ];
    results.push({
      flat_number,
      charge_id,
      charge_title: chargeTitleById.get(charge_id) ?? 'Unknown receipt head',
      month: groupMonth,
      payment_method,
      count: group.length,
      total_amount: group.reduce((sum, row) => sum + Number(row.amount || 0), 0),
      payments: group,
    });
  }

  results.sort((a, b) => {
    if (a.month !== b.month) return b.month.localeCompare(a.month);
    return a.flat_number.localeCompare(b.flat_number);
  });

  return results;
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
    const d = paymentBillingDate(p);
    if (!d) continue;
    const month = format(new Date(d), 'yyyy-MM');
    monthlyPaymentTotals.set(month, (monthlyPaymentTotals.get(month) || 0) + Number(p.amount || 0));
  }

  const months = new Set<string>([...monthlyPaymentTotals.keys()]);
  for (const e of allLedger) {
    if (!isReceiptDestination(e.destination)) continue;
    const m = format(new Date(ledgerTransactionDate(e)), 'yyyy-MM');
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
      const d = paymentBillingDate(p);
      if (!d) continue;
      const t = new Date(d).getTime();
      if (t >= fromMs && t <= toMs) reportTotal += Number(p.amount || 0);
    }

    const unlinkedLedger: LedgerOvercountEntry[] = [];
    for (const e of allLedger) {
      if (!isReceiptDestination(e.destination)) continue;
      const ledgerDate = ledgerTransactionDate(e);
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
      const pDate = paymentBillingDate(p);
      const pMonth = pDate ? format(new Date(pDate), 'yyyy-MM') : '';
      const eMonth = entry.entry_month || (entry.transaction_date ? format(new Date(entry.transaction_date), 'yyyy-MM') : '');
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

/* ─── Channel balance tracing (negative cash / bank) ─── */

export type BalanceTransaction = {
  date: string;
  type: 'receipt' | 'expense';
  amount: number;
  channel: PaymentChannel;
  source: 'payment' | 'ledger';
  id: string;
  label: string;
};

export type ChannelBalanceCulprit = {
  date: string;
  label: string;
  amount: number;
  type: 'receipt' | 'expense';
  balanceAfter: number;
};

export type ChannelMonthlyBalance = {
  month: string;
  receipts: number;
  expenses: number;
  netChange: number;
  closingBalance: number;
};

export type ChannelBalanceTrace = {
  channel: PaymentChannel;
  finalBalance: number;
  firstNegativeDate: string | null;
  firstNegativeMonth: string | null;
  balanceBeforeFault: number;
  culprits: ChannelBalanceCulprit[];
  monthlyBreakdown: ChannelMonthlyBalance[];
};

const paymentTransactionDate = (p: AuditPaymentRow): string =>
  paymentBillingDate(p) || (p.payment_date || '').slice(0, 10) || (p.created_at || '').slice(0, 10);

const ledgerMonthKey = (e: AuditLedgerRow): string => {
  if (e.entry_month) return e.entry_month.slice(0, 7);
  const d = ledgerTransactionDate(e);
  return d ? format(new Date(d), 'yyyy-MM') : '';
};

export function buildChannelTransactions(
  verifiedPayments: AuditPaymentRow[],
  allLedger: AuditLedgerRow[],
  linkedFeIds: Set<string>,
): BalanceTransaction[] {
  const txns: BalanceTransaction[] = [];

  for (const p of verifiedPayments) {
    const date = paymentTransactionDate(p);
    if (!date) continue;
    txns.push({
      date,
      type: 'receipt',
      amount: Number(p.amount || 0),
      channel: normalizePaymentChannel(p.payment_method),
      source: 'payment',
      id: p.id,
      label: `Flat ${p.flat_number} maintenance receipt`,
    });
  }

  for (const e of allLedger) {
    const date = ledgerTransactionDate(e);
    if (!date) continue;
    const ch = normalizePaymentChannel(e.payment_method);
    const amt = Number(e.total_amount || 0);
    if (e.destination === 'separate_entry') {
      txns.push({
        date,
        type: 'expense',
        amount: amt,
        channel: ch,
        source: 'ledger',
        id: e.id,
        label: e.title || 'Expense entry',
      });
    } else if (!linkedFeIds.has(e.id)) {
      txns.push({
        date,
        type: 'receipt',
        amount: amt,
        channel: ch,
        source: 'ledger',
        id: e.id,
        label: e.title || 'Ledger receipt (no linked payments)',
      });
    }
  }

  return txns;
}

export function traceChannelBalanceDeficit(
  transactions: BalanceTransaction[],
  channel: PaymentChannel,
): ChannelBalanceTrace | null {
  const channelTxns = transactions
    .filter((t) => t.channel === channel)
    .sort((a, b) => {
      const cmp = a.date.localeCompare(b.date);
      if (cmp !== 0) return cmp;
      return a.type === 'receipt' ? -1 : 1;
    });

  if (channelTxns.length === 0) return null;

  let balance = 0;
  let firstNegativeDate: string | null = null;
  let firstNegativeMonth: string | null = null;
  let balanceBeforeFault = 0;
  const culprits: ChannelBalanceCulprit[] = [];

  const monthlyMap = new Map<string, { receipts: number; expenses: number }>();

  for (const t of channelTxns) {
    const month = t.date.slice(0, 7);
    if (!monthlyMap.has(month)) monthlyMap.set(month, { receipts: 0, expenses: 0 });
    const m = monthlyMap.get(month)!;
    if (t.type === 'receipt') m.receipts += t.amount;
    else m.expenses += t.amount;

    const prevBalance = balance;
    balance += t.type === 'receipt' ? t.amount : -t.amount;

    if (firstNegativeDate === null && prevBalance >= 0 && balance < 0) {
      firstNegativeDate = t.date;
      firstNegativeMonth = month;
      balanceBeforeFault = prevBalance;
      culprits.push({
        date: t.date,
        label: t.label,
        amount: t.amount,
        type: t.type,
        balanceAfter: balance,
      });
    } else if (firstNegativeDate === t.date) {
      culprits.push({
        date: t.date,
        label: t.label,
        amount: t.amount,
        type: t.type,
        balanceAfter: balance,
      });
    }
  }

  const monthlyBreakdown: ChannelMonthlyBalance[] = [];
  let runningBalance = 0;
  const sortedMonths = [...monthlyMap.keys()].sort();
  for (const month of sortedMonths) {
    const { receipts, expenses } = monthlyMap.get(month)!;
    const netChange = receipts - expenses;
    runningBalance += netChange;
    monthlyBreakdown.push({ month, receipts, expenses, netChange, closingBalance: runningBalance });
  }

  return {
    channel,
    finalBalance: balance,
    firstNegativeDate,
    firstNegativeMonth,
    balanceBeforeFault,
    culprits,
    monthlyBreakdown,
  };
}

/* ─── Recording vs reporting mismatch by month ─── */

export type RecordingMismatchSource = {
  kind: 'orphan_payment' | 'orphan_ledger' | 'amount_diff';
  id: string;
  date: string;
  label: string;
  amount: number;
};

export type RecordingMismatchMonth = {
  month: string;
  paymentsTotal: number;
  ledgerTotal: number;
  difference: number;
  sources: RecordingMismatchSource[];
};

export function analyzeRecordingMismatchByMonth(
  verifiedPayments: AuditPaymentRow[],
  allLedger: AuditLedgerRow[],
): RecordingMismatchMonth[] {
  const linkedFeIds = new Set<string>();
  for (const p of verifiedPayments) {
    if (p.finance_entry_id) linkedFeIds.add(p.finance_entry_id);
  }

  const months = new Set<string>();
  for (const p of verifiedPayments) {
    const d = paymentTransactionDate(p);
    if (d) months.add(d.slice(0, 7));
  }
  for (const e of allLedger) {
    if (e.record_mode !== 'flats_only' || e.payment_status !== 'verified') continue;
    const m = ledgerMonthKey(e);
    if (m) months.add(m);
  }

  const issues: RecordingMismatchMonth[] = [];

  for (const month of months) {
    let paymentsTotal = 0;
    const monthPayments: AuditPaymentRow[] = [];
    for (const p of verifiedPayments) {
      const d = paymentTransactionDate(p);
      if (!d || d.slice(0, 7) !== month) continue;
      paymentsTotal += Number(p.amount || 0);
      monthPayments.push(p);
    }

    let ledgerTotal = 0;
    const monthLedger: AuditLedgerRow[] = [];
    for (const e of allLedger) {
      if (e.record_mode !== 'flats_only' || e.payment_status !== 'verified') continue;
      if (ledgerMonthKey(e) !== month) continue;
      ledgerTotal += Number(e.total_amount || 0);
      monthLedger.push(e);
    }

    const difference = paymentsTotal - ledgerTotal;
    if (Math.abs(difference) <= 1) continue;

    const sources: RecordingMismatchSource[] = [];

    for (const p of monthPayments) {
      if (!p.finance_entry_id) {
        sources.push({
          kind: 'orphan_payment',
          id: p.id,
          date: paymentTransactionDate(p),
          label: `Flat ${p.flat_number} — no ledger link`,
          amount: Number(p.amount || 0),
        });
      }
    }

    for (const e of monthLedger) {
      const linked = monthPayments.some((p) => p.finance_entry_id === e.id);
      if (!linked) {
        sources.push({
          kind: 'orphan_ledger',
          id: e.id,
          date: ledgerTransactionDate(e),
          label: e.title || 'Ledger entry — no linked payments',
          amount: Number(e.total_amount || 0),
        });
      }
    }

    issues.push({ month, paymentsTotal, ledgerTotal, difference, sources });
  }

  issues.sort((a, b) => Math.abs(b.difference) - Math.abs(a.difference));
  return issues;
}

export function formatChannelBalanceFaultTrace(trace: ChannelBalanceTrace): string {
  if (!trace.firstNegativeDate) {
    return 'Could not pinpoint the exact date — review channel entries in Finance → Period Report.';
  }

  const monthLabel = trace.firstNegativeMonth ?? trace.firstNegativeDate.slice(0, 7);
  const culpritLines = trace.culprits
    .slice(0, 4)
    .map(
      (c) =>
        `  • ${c.date}: ${c.type === 'expense' ? 'Expense' : 'Receipt'} "${c.label}" ₹${c.amount.toLocaleString('en-IN')} → balance ₹${c.balanceAfter.toLocaleString('en-IN')}`,
    )
    .join('\n');

  const monthLines = trace.monthlyBreakdown
    .filter((m) => m.closingBalance < 0 || m.month >= (trace.firstNegativeMonth ?? ''))
    .slice(0, 6)
    .map(
      (m) =>
        `  • ${m.month}: receipts ₹${m.receipts.toLocaleString('en-IN')} − expenses ₹${m.expenses.toLocaleString('en-IN')} → closing ₹${m.closingBalance.toLocaleString('en-IN')}`,
    )
    .join('\n');

  return [
    `Fault origin: ${trace.firstNegativeDate} (${monthLabel}) — balance was ₹${trace.balanceBeforeFault.toLocaleString('en-IN')} before this date.`,
    culpritLines ? `Entries on fault date:\n${culpritLines}` : '',
    monthLines ? `Month-wise trail from fault:\n${monthLines}` : '',
  ]
    .filter(Boolean)
    .join('\n\n');
}

export function formatRecordingMismatchFaultTrace(issues: RecordingMismatchMonth[]): string {
  if (issues.length === 0) return '';

  const lines = issues.slice(0, 6).map((m) => {
    const dir = m.difference > 0 ? 'payments exceed ledger' : 'ledger exceeds payments';
    const sourceHint =
      m.sources.length > 0
        ? ` — likely from: ${m.sources
            .slice(0, 3)
            .map((s) => `${s.date} ${s.label} (₹${s.amount.toLocaleString('en-IN')})`)
            .join('; ')}`
        : '';
    return `  • ${m.month}: ₹${Math.abs(m.difference).toLocaleString('en-IN')} (${dir})${sourceHint}`;
  });

  const earliest = [...issues].sort((a, b) => a.month.localeCompare(b.month))[0];
  return [
    `Earliest affected month: ${earliest.month}`,
    `Months with mismatch (largest first):\n${lines.join('\n')}`,
  ].join('\n\n');
}
