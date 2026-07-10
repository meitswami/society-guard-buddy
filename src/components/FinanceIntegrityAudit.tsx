import { useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import {
  AlertTriangle,
  ShieldCheck,
  Play,
  Loader2,
  TrendingDown,
  Bug,
  CheckCircle2,
  XCircle,
  IndianRupee,
  ArrowRight,
  MapPin,
  ListOrdered,
  Trash2,
  Calendar,
  Pencil,
} from 'lucide-react';
import { format } from 'date-fns';
import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import {
  analyzeLedgerOvercountByMonth,
  analyzeRecordingMismatchByMonth,
  buildAuditFixQueue,
  buildChannelTransactions,
  findDuplicatePaymentGroups,
  formatChannelBalanceFaultTrace,
  formatRecordingMismatchFaultTrace,
  normalizePaymentChannel,
  traceChannelBalanceDeficit,
  type AuditFixQueueItem,
  type AuditLedgerRow,
  type AuditPaymentRow,
  type ChannelBalanceTrace,
  type LedgerOvercountMonth,
  type RecordingMismatchMonth,
} from '@/lib/financeAuditDetection';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { ledgerTransactionDate } from '@/lib/financeDates';
import {
  alignLedgerEntryMonth,
  alignPaymentDueToMonth,
  deleteMaintenancePayment,
  deleteOrphanLedgerEntry,
} from '@/lib/financeAuditRemediation';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';

/* ─── Types ─── */

type Severity = 'critical' | 'warning' | 'info' | 'pass';

type FindingKind =
  | 'duplicate_payments'
  | 'ledger_overcount'
  | 'recording_mismatch'
  | 'orphaned_payments'
  | 'generic';

interface AuditFinding {
  id: string;
  severity: Severity;
  title: string;
  description: string;
  reason: string;
  rectification: string;
  faultTrace?: string;
  kind?: FindingKind;
  data?: Record<string, unknown>;
  ledgerIssues?: LedgerOvercountMonth[];
  channelTrace?: ChannelBalanceTrace;
  recordingMismatchMonths?: RecordingMismatchMonth[];
}

interface AuditResult {
  ranAt: string;
  findings: AuditFinding[];
  fixQueue: AuditFixQueueItem[];
  summary: { critical: number; warning: number; info: number; pass: number };
}

const scrollToAuditAlarms = () => {
  document.getElementById('finance-audit-alarms')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
};

const sevIcon = (s: Severity) => {
  switch (s) {
    case 'critical': return <XCircle className="w-4 h-4 text-destructive" />;
    case 'warning': return <AlertTriangle className="w-4 h-4 text-amber-500" />;
    case 'info': return <Bug className="w-4 h-4 text-blue-500" />;
    case 'pass': return <CheckCircle2 className="w-4 h-4 text-green-500" />;
  }
};

const sevBg = (s: Severity) => {
  switch (s) {
    case 'critical': return 'border-destructive/40 bg-destructive/5';
    case 'warning': return 'border-amber-500/40 bg-amber-500/5';
    case 'info': return 'border-blue-500/30 bg-blue-500/5';
    case 'pass': return 'border-green-500/30 bg-green-500/5';
  }
};

/* ─── Component ─── */

const FinanceIntegrityAudit = () => {
  const societyId = useStore((s) => s.societyId);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<AuditResult | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [busyQueueKey, setBusyQueueKey] = useState<string | null>(null);
  const [resolvedQueueKeys, setResolvedQueueKeys] = useState<Set<string>>(new Set());

  const runAudit = useCallback(async () => {
    if (!societyId) return;
    setRunning(true);
    setResult(null);
    setResolvedQueueKeys(new Set());

    const findings: AuditFinding[] = [];
    let findingIdx = 0;
    const addFinding = (f: Omit<AuditFinding, 'id'>) => {
      findings.push({ ...f, id: `f-${findingIdx++}` });
    };

    let duplicateGroups: ReturnType<typeof findDuplicatePaymentGroups> = [];
    let ledgerOvercountIssues: LedgerOvercountMonth[] = [];
    let recordingMismatchMonths: RecordingMismatchMonth[] = [];
    let orphanedPayments: AuditPaymentRow[] = [];
    let cashTrace: ChannelBalanceTrace | null = null;
    let bankTrace: ChannelBalanceTrace | null = null;

    try {
      /* ─── 1. Load all data ─── */
      const { data: charges } = await supabase
        .from('maintenance_charges')
        .select('id, title, amount, frequency')
        .eq('society_id', societyId);

      const chargeIds = (charges ?? []).map((c) => c.id);
      const chargeMap = new Map((charges ?? []).map((c) => [c.id, c]));

      const { data: payments } = chargeIds.length > 0
        ? await supabase
            .from('maintenance_payments')
            .select('id, charge_id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, finance_entry_id, transaction_id')
            .in('charge_id', chargeIds)
        : { data: [] as any[] };

      const { data: ledgerEntries } = await supabase
        .from('finance_entries')
        .select('id, record_mode, destination, total_amount, payment_method, payment_status, entry_month, created_at, title, charge_id, aggregate_flat_count')
        .eq('society_id', societyId);

      const { data: flats } = await supabase
        .from('flats')
        .select('id, flat_number, is_occupied')
        .eq('society_id', societyId);

      const allPayments = (payments ?? []) as AuditPaymentRow[];
      const allLedger = (ledgerEntries ?? []) as AuditLedgerRow[];
      const monthlyChargeIds = (charges ?? [])
        .filter((c) => (c.frequency ?? '').toLowerCase() === 'monthly')
        .map((c) => c.id);
      const chargeTitleById = new Map((charges ?? []).map((c) => [c.id, c.title]));
      const allFlats = (flats ?? []) as any[];
      const verifiedPayments = allPayments.filter((p) => p.payment_status === 'verified');

      /* ─── 2. NEGATIVE CASH / BANK BALANCE CHECK ─── */
      const receiptByChannel = { cash: 0, bank: 0, other: 0 };
      const expenseByChannel = { cash: 0, bank: 0, other: 0 };
      const linkedFeIds = new Set<string>();

      for (const p of verifiedPayments) {
        const ch = normalizePaymentChannel(p.payment_method);
        receiptByChannel[ch] += Number(p.amount || 0);
        if (p.finance_entry_id) linkedFeIds.add(p.finance_entry_id);
      }

      for (const e of allLedger) {
        const ch = normalizePaymentChannel(e.payment_method);
        const amt = Number(e.total_amount || 0);
        if (e.destination === 'separate_entry') {
          expenseByChannel[ch] += amt;
        } else if (!linkedFeIds.has(e.id)) {
          receiptByChannel[ch] += amt;
        }
      }

      const cashBalance = receiptByChannel.cash - expenseByChannel.cash;
      const bankBalance = receiptByChannel.bank - expenseByChannel.bank;

      const channelTransactions = buildChannelTransactions(verifiedPayments, allLedger, linkedFeIds);
      cashTrace = traceChannelBalanceDeficit(channelTransactions, 'cash');
      bankTrace = traceChannelBalanceDeficit(channelTransactions, 'bank');

      if (cashBalance < 0) {
        const faultDate = cashTrace?.firstNegativeDate;
        const faultMonth = cashTrace?.firstNegativeMonth;
        const faultDesc = faultDate
          ? `Negative cash first appears on ${fmtIsoDateToDisplay(faultDate)}${faultMonth ? ` (${fmtIsoMonthToDisplay(faultMonth)})` : ''}.`
          : 'Cash outflow exceeds cash inflow across all recorded dates.';
        addFinding({
          severity: 'critical',
          title: `Negative Cash Balance: ₹${Math.abs(cashBalance).toLocaleString('en-IN')}`,
          description: `${faultDesc} Cash outflow (₹${expenseByChannel.cash.toLocaleString('en-IN')}) exceeds cash inflow (₹${receiptByChannel.cash.toLocaleString('en-IN')}).`,
          reason:
            'Usually caused by a cash expense on the fault date without a matching cash receipt, or a receipt tagged as bank/UPI instead of cash.',
          faultTrace: cashTrace ? formatChannelBalanceFaultTrace(cashTrace) : undefined,
          rectification: faultDate
            ? `1. Open Reports → Financial, set statement period to ${faultMonth ? fmtIsoMonthToDisplay(faultMonth) : faultDate.slice(0, 7)} and review cash-channel entries.\n2. Review the entries listed under "Trace to fault" — correct payment_method or delete duplicate expenses.\n3. If a receipt exists under bank/UPI for the same payment, retag it as cash or change the expense to bank.\n4. Re-run this audit after fixing.`
            : '1. Go to Reports → Financial and review cash-channel entries to identify mismatched items.\n2. Check if any expense marked "cash" should actually be "bank/UPI".\n3. Verify all cash receipts are in "verified" status.\n4. Look for duplicate expense entries under cash channel.\n5. Correct the payment_method on the wrongly tagged entry from Finance → Transactions.',
          data: {
            cashReceipts: receiptByChannel.cash,
            cashExpenses: expenseByChannel.cash,
            deficit: cashBalance,
            faultDate: faultDate ?? null,
            faultMonth: faultMonth ?? null,
          },
          channelTrace: cashTrace ?? undefined,
        });
      } else {
        addFinding({
          severity: 'pass',
          title: `Cash Balance OK: ₹${cashBalance.toLocaleString('en-IN')}`,
          description: 'Cash inflow covers all cash outflow.',
          reason: '',
          rectification: '',
        });
      }

      if (bankBalance < 0) {
        const faultDate = bankTrace?.firstNegativeDate;
        const faultMonth = bankTrace?.firstNegativeMonth;
        const faultDesc = faultDate
          ? `Negative bank balance first appears on ${fmtIsoDateToDisplay(faultDate)}${faultMonth ? ` (${fmtIsoMonthToDisplay(faultMonth)})` : ''}.`
          : 'Bank outflow exceeds bank inflow across all recorded dates.';
        addFinding({
          severity: 'critical',
          title: `Negative Bank Balance: ₹${Math.abs(bankBalance).toLocaleString('en-IN')}`,
          description: `${faultDesc} Bank outflow (₹${expenseByChannel.bank.toLocaleString('en-IN')}) exceeds bank inflow (₹${receiptByChannel.bank.toLocaleString('en-IN')}).`,
          reason:
            'Usually caused by a bank/UPI expense on the fault date without a matching bank receipt, or a receipt incorrectly tagged as cash.',
          faultTrace: bankTrace ? formatChannelBalanceFaultTrace(bankTrace) : undefined,
          rectification: faultDate
            ? `1. Open Reports → Financial, set statement period to ${faultMonth ? fmtIsoMonthToDisplay(faultMonth) : faultDate.slice(0, 7)} and review bank-channel entries.\n2. Review entries under "Trace to fault" — correct payment_method or remove duplicate bank expenses.\n3. If the receipt was recorded as cash, retag it as UPI/bank or change the expense channel.\n4. Re-run this audit after fixing.`
            : '1. Go to Reports → Financial and review bank-channel entries.\n2. Check if any receipt marked "cash" should be "UPI/bank".\n3. Verify no bank receipts are stuck in "pending" or "rejected" status.\n4. Look for duplicate expense entries under bank channel.\n5. Correct the payment_method on mismatched entries in Finance → Transactions.',
          data: {
            bankReceipts: receiptByChannel.bank,
            bankExpenses: expenseByChannel.bank,
            deficit: bankBalance,
            faultDate: faultDate ?? null,
            faultMonth: faultMonth ?? null,
          },
          channelTrace: bankTrace ?? undefined,
        });
      } else {
        addFinding({
          severity: 'pass',
          title: `Bank Balance OK: ₹${bankBalance.toLocaleString('en-IN')}`,
          description: 'Bank inflow covers all bank outflow.',
          reason: '',
          rectification: '',
        });
      }

      /* ─── 3. DUPLICATE PAYMENT DETECTION (monthly charges — same as alarm panel) ─── */
      duplicateGroups = findDuplicatePaymentGroups(allPayments, chargeTitleById, {
        chargeIds: monthlyChargeIds,
      });

      if (duplicateGroups.length > 0) {
        const monthSummary = [...new Set(duplicateGroups.map((g) => g.month))]
          .sort()
          .reverse()
          .slice(0, 5)
          .map((m) => fmtIsoMonthToDisplay(m))
          .join(', ');
        const sampleGroups = duplicateGroups
          .slice(0, 4)
          .map(
            (g) =>
              `  • ${fmtIsoMonthToDisplay(g.month)}: Flat ${g.flat_number}, ${g.charge_title} (${g.payment_method}) — ${g.count} rows, ₹${g.total_amount.toLocaleString('en-IN')}`,
          )
          .join('\n');
        addFinding({
          severity: 'critical',
          kind: 'duplicate_payments',
          title: `${duplicateGroups.length} Duplicate Payment Group${duplicateGroups.length > 1 ? 's' : ''} Found`,
          description: `Duplicate rows in month(s): ${monthSummary}. Same flat + monthly charge + month + channel has multiple maintenance_payments rows.`,
          reason:
            'Two or more payment rows exist for the same flat and month. This is different from ledger double-count (an extra finance_entries receipt without duplicate payments).',
          faultTrace: `Affected months: ${monthSummary}\nDuplicate groups:\n${sampleGroups}`,
          rectification:
            'Scroll to "Duplicate maintenance payment rows" above, expand the group for the month listed, and delete or edit the extra payment. Keep one verified row per flat per month.',
          data: {
            duplicateGroups: duplicateGroups.length,
            months: [...new Set(duplicateGroups.map((g) => g.month))],
          },
        });
      } else {
        addFinding({
          severity: 'pass',
          title: 'No Duplicate Payment Rows',
          description: 'Each flat has at most one monthly maintenance payment per month per channel.',
          reason: '',
          rectification: '',
        });
      }

      /* ─── 4. RECORDING vs REPORTING DISCREPANCY ─── */
      // Compare: sum of maintenance_payments (verified) vs sum of finance_entries (flats_only, verified)
      const mpTotal = verifiedPayments.reduce((s, p) => s + Number(p.amount || 0), 0);

      const feFlatsOnlyTotal = allLedger
        .filter((e) => e.record_mode === 'flats_only' && e.payment_status === 'verified')
        .reduce((s, e) => s + Number(e.total_amount || 0), 0);

      const discrepancy = Math.abs(mpTotal - feFlatsOnlyTotal);
      recordingMismatchMonths = analyzeRecordingMismatchByMonth(verifiedPayments, allLedger);
      if (discrepancy > 1) {
        const earliestMonth = recordingMismatchMonths.length > 0
          ? [...recordingMismatchMonths].sort((a, b) => a.month.localeCompare(b.month))[0].month
          : null;
        const monthHint = earliestMonth
          ? `Mismatch traceable from ${fmtIsoMonthToDisplay(earliestMonth)} onward.`
          : '';
        addFinding({
          severity: 'warning',
          kind: 'recording_mismatch',
          title: `Recording vs Ledger Discrepancy: ₹${discrepancy.toLocaleString('en-IN')}`,
          description: `Sum of verified maintenance_payments (₹${mpTotal.toLocaleString('en-IN')}) does not match sum of finance_entries[flats_only] (₹${feFlatsOnlyTotal.toLocaleString('en-IN')}). ${monthHint}`,
          reason:
            'Lifetime totals differ — often orphaned payments (no finance_entry_id), deleted ledger rows, or amount edits in only one table. Expand "Trace to fault" to see which month and entries caused the gap.',
          faultTrace: formatRecordingMismatchFaultTrace(recordingMismatchMonths),
          rectification:
            '1. Start with the earliest month in "Trace to fault" — open Reports → Financial for that statement period.\n2. Fix orphan payments or orphan ledger rows listed for that month.\n3. If amounts differ on linked pairs, align in Finance → Record receipt or Transactions.\n4. Re-run audit; repeat for the next affected month if needed.',
          data: {
            maintenancePaymentsTotal: mpTotal,
            financeEntriesTotal: feFlatsOnlyTotal,
            difference: discrepancy,
            affectedMonths: recordingMismatchMonths.map((m) => m.month),
          },
          recordingMismatchMonths,
        });
      } else {
        addFinding({
          severity: 'pass',
          title: 'Recording & Reporting Figures Match',
          description: 'Maintenance payments total matches finance ledger entries total.',
          reason: '',
          rectification: '',
        });
      }

      /* ─── 5. PERIOD REPORT LEDGER DOUBLE-COUNT (matches FinanceManager period report) ─── */
      ledgerOvercountIssues = analyzeLedgerOvercountByMonth(verifiedPayments, allLedger);

      if (ledgerOvercountIssues.length > 0) {
        const totalExcess = ledgerOvercountIssues.reduce((s, m) => s + m.excess, 0);
        const orphanCount = ledgerOvercountIssues.reduce((s, m) => s + m.unlinkedLedger.length, 0);
        const earliestMonth = [...ledgerOvercountIssues].sort((a, b) => a.month.localeCompare(b.month))[0]?.month;
        const faultTraceLines = ledgerOvercountIssues.slice(0, 6).map((issue) => {
          const orphanLines = issue.unlinkedLedger
            .slice(0, 2)
            .map((e) => `${ledgerTransactionDate(e)} orphan "${e.title || 'Entry'}" ₹${e.total_amount.toLocaleString('en-IN')}`)
            .join('; ');
          const boundaryLines = issue.dateBoundary
            .slice(0, 2)
            .map(
              (b) =>
                `Flat ${b.payment.flat_number}: payment month ${fmtIsoMonthToDisplay(b.paymentMonth)} vs ledger ${fmtIsoMonthToDisplay(b.entryMonth)}`,
            )
            .join('; ');
          const parts = [orphanLines, boundaryLines].filter(Boolean).join(' | ');
          return `  • ${fmtIsoMonthToDisplay(issue.month)} (+₹${issue.excess.toLocaleString('en-IN')})${parts ? `: ${parts}` : ''}`;
        });
        addFinding({
          severity: 'critical',
          kind: 'ledger_overcount',
          title: `Ledger Double-Count in Reports: ₹${totalExcess.toLocaleString('en-IN')} across ${ledgerOvercountIssues.length} month(s)`,
          description: `Period reports count extra receipt(s) beyond verified payments — usually ${orphanCount} unlinked finance_entries row(s).${earliestMonth ? ` Earliest anomaly: ${fmtIsoMonthToDisplay(earliestMonth)}.` : ''} Months: ${ledgerOvercountIssues.map((m) => `${fmtIsoMonthToDisplay(m.month)} (+₹${m.excess.toLocaleString('en-IN')})`).join(', ')}.`,
          reason:
            'An extra finance ledger receipt exists without linked maintenance_payments (or payment/ledger months disagree). This inflates period reports but does NOT appear in "duplicate payment rows" — there may still be only one payment per flat.',
          faultTrace: [
            earliestMonth ? `Earliest affected month: ${fmtIsoMonthToDisplay(earliestMonth)}` : '',
            faultTraceLines.length > 0 ? `Month → entry trail:\n${faultTraceLines.join('\n')}` : '',
          ]
            .filter(Boolean)
            .join('\n\n'),
          rectification:
            'Use the "Ledger double-count (period reports)" panel above: start with the earliest month in the trace, delete orphan ledger entries, or align payment due_date with ledger entry_month. Then re-run this audit.',
          data: {
            months: ledgerOvercountIssues.map((m) => ({
              month: m.month,
              excess: m.excess,
              unlinkedCount: m.unlinkedLedger.length,
              boundaryCount: m.dateBoundary.length,
            })),
          },
          ledgerIssues: ledgerOvercountIssues,
        });
      } else {
        addFinding({
          severity: 'pass',
          title: 'Period Report Totals Verified',
          description: 'No ledger double-count in monthly period reports.',
          reason: '',
          rectification: '',
        });
      }

      /* ─── 6. ORPHANED PAYMENTS (no finance_entry_id) ─── */
      orphanedPayments = verifiedPayments.filter((p) => !p.finance_entry_id);
      if (orphanedPayments.length > 0) {
        const orphanTotal = orphanedPayments.reduce((s, p) => s + Number(p.amount || 0), 0);
        const orphansByMonth = new Map<string, AuditPaymentRow[]>();
        for (const p of orphanedPayments) {
          const d = p.due_date || p.payment_date || p.created_at || '';
          const m = d ? format(new Date(d), 'yyyy-MM') : 'unknown';
          if (!orphansByMonth.has(m)) orphansByMonth.set(m, []);
          orphansByMonth.get(m)!.push(p);
        }
        const monthLines = [...orphansByMonth.entries()]
          .sort((a, b) => a[0].localeCompare(b[0]))
          .slice(0, 6)
          .map(([m, rows]) => {
            const total = rows.reduce((s, p) => s + Number(p.amount || 0), 0);
            const samples = rows
              .slice(0, 2)
              .map((p) => `${p.due_date || p.payment_date || 'no date'} Flat ${p.flat_number} ₹${Number(p.amount || 0).toLocaleString('en-IN')}`)
              .join('; ');
            return `  • ${m === 'unknown' ? 'Unknown month' : fmtIsoMonthToDisplay(m)}: ${rows.length} orphan(s), ₹${total.toLocaleString('en-IN')} — ${samples}`;
          })
          .join('\n');
        const earliestOrphanMonth = [...orphansByMonth.keys()].filter((m) => m !== 'unknown').sort()[0];
        addFinding({
          severity: 'warning',
          kind: 'orphaned_payments',
          title: `${orphanedPayments.length} Orphaned Payment${orphanedPayments.length > 1 ? 's' : ''} (₹${orphanTotal.toLocaleString('en-IN')})`,
          description: `These verified payments have no linked finance_entry record.${earliestOrphanMonth ? ` Earliest: ${fmtIsoMonthToDisplay(earliestOrphanMonth)}.` : ''}`,
          reason: 'Likely recorded before the ledger system was introduced, or the finance_entry was deleted while the payment remained.',
          faultTrace: monthLines ? `Orphans by month:\n${monthLines}` : undefined,
          rectification:
            'Start with the earliest month in the trace. Finance → Payments: re-record with ledger, or delete orphan payment rows if they are mistakes.',
          data: {
            count: orphanedPayments.length,
            total: orphanTotal,
            samples: orphanedPayments.slice(0, 8).map((p) => ({
              id: p.id.slice(0, 8),
              flat: p.flat_number,
              amount: p.amount,
              due: p.due_date,
            })),
          },
        });
      } else {
        addFinding({
          severity: 'pass',
          title: 'All Payments Linked to Ledger',
          description: 'Every verified payment has a corresponding finance_entry.',
          reason: '',
          rectification: '',
        });
      }

      /* ─── 7. FINANCE ENTRIES WITH WRONG FLAT COUNT ─── */
      const feWithAllocMismatch: string[] = [];
      for (const e of allLedger) {
        if (e.record_mode === 'flats_only' && e.aggregate_flat_count > 0) {
          // Check if linked payments count matches
          const linkedPayments = allPayments.filter((p) => p.finance_entry_id === e.id);
          if (linkedPayments.length > 0 && linkedPayments.length !== e.aggregate_flat_count) {
            feWithAllocMismatch.push(e.id);
          }
        }
      }
      if (feWithAllocMismatch.length > 0) {
        addFinding({
          severity: 'warning',
          title: `${feWithAllocMismatch.length} Ledger Entries with Flat Count Mismatch`,
          description: 'The aggregate_flat_count on these finance_entries does not match the actual number of linked payments.',
          reason: 'A payment was deleted or added after the finance_entry was created without updating the entry metadata.',
          rectification: 'Review these entries in Finance → Receipts tab. The totals may be incorrect. Delete and re-record if needed.',
          data: { entryIds: feWithAllocMismatch.slice(0, 5) },
        });
      }

      /* ─── 8. AMOUNT MISMATCH: charge amount vs recorded payment ─── */
      const monthlyCharges = (charges ?? []).filter((c) => (c.frequency ?? '').toLowerCase() === 'monthly');
      let amountMismatchCount = 0;
      for (const p of verifiedPayments) {
        const charge = chargeMap.get(p.charge_id);
        if (!charge || (charge.frequency ?? '').toLowerCase() !== 'monthly') continue;
        const expected = Number(charge.amount || 0);
        const actual = Number(p.amount || 0);
        if (expected > 0 && actual !== expected) {
          amountMismatchCount++;
        }
      }
      if (amountMismatchCount > 0) {
        addFinding({
          severity: 'info',
          title: `${amountMismatchCount} Payment${amountMismatchCount > 1 ? 's' : ''} with Non-Standard Amount`,
          description: 'Some payments have a different amount than the charge definition.',
          reason: 'Could be partial payments, penalty additions, discounts, or data entry errors.',
          rectification: 'Review in Finance → Payments tab. Filter by charge type and compare amounts. Correct any that are clearly wrong.',
          data: { count: amountMismatchCount },
        });
      }

      /* ─── 9. PENDING PAYMENTS STUCK ─── */
      const pendingPayments = allPayments.filter((p) => p.payment_status === 'pending');
      const oldPending = pendingPayments.filter((p) => {
        const d = new Date(p.created_at || '');
        return !Number.isNaN(d.getTime()) && Date.now() - d.getTime() > 7 * 24 * 60 * 60 * 1000;
      });
      if (oldPending.length > 0) {
        addFinding({
          severity: 'warning',
          title: `${oldPending.length} Payment${oldPending.length > 1 ? 's' : ''} Pending > 7 Days`,
          description: 'These payments have been in "pending" status for over a week without verification.',
          reason: 'Admin may have missed verifying them, or they were submitted by residents and never reviewed.',
          rectification: 'Go to Finance → Payments tab, filter by "Pending" status, and verify or reject each one.',
          data: { count: oldPending.length },
        });
      }

      /* ─── 10. FLATS WITH NO PAYMENTS THIS MONTH ─── */
      const currentMonth = format(new Date(), 'yyyy-MM');
      const flatsWithPaymentThisMonth = new Set<string>();
      for (const p of verifiedPayments) {
        const d = p.due_date || p.payment_date || p.created_at || '';
        if (d && format(new Date(d), 'yyyy-MM') === currentMonth) {
          flatsWithPaymentThisMonth.add(p.flat_number);
        }
      }
      const occupiedFlats = allFlats.filter((f) => f.is_occupied !== false);
      const unpaidFlats = occupiedFlats.filter((f) => !flatsWithPaymentThisMonth.has(f.flat_number));
      if (unpaidFlats.length > 0 && monthlyCharges.length > 0) {
        addFinding({
          severity: 'info',
          title: `${unpaidFlats.length} Flat${unpaidFlats.length > 1 ? 's' : ''} Unpaid This Month (${fmtIsoMonthToDisplay(currentMonth)})`,
          description: `Occupied flats without a verified payment for ${fmtIsoMonthToDisplay(currentMonth)}: ${unpaidFlats.slice(0, 10).map((f) => f.flat_number).join(', ')}${unpaidFlats.length > 10 ? '…' : ''}`,
          reason: 'Either payment not yet recorded, or resident has not paid.',
          rectification: 'Send reminders from Finance → Reminders tab, or record payments if already received.',
          data: { count: unpaidFlats.length, flats: unpaidFlats.slice(0, 20).map((f) => f.flat_number) },
        });
      }

    } catch (err: any) {
      addFinding({
        severity: 'critical',
        title: 'Audit Engine Error',
        description: err?.message || 'An unexpected error occurred while running the audit.',
        reason: 'Database connectivity issue or missing table.',
        rectification: 'Check your internet connection and try again. If the issue persists, contact support.',
      });
    }

    const fixQueue = buildAuditFixQueue({
      duplicateGroups,
      ledgerOvercountIssues,
      recordingMismatchMonths,
      orphanedPayments,
      cashTrace,
      bankTrace,
    });

    const summary = {
      critical: findings.filter((f) => f.severity === 'critical').length,
      warning: findings.filter((f) => f.severity === 'warning').length,
      info: findings.filter((f) => f.severity === 'info').length,
      pass: findings.filter((f) => f.severity === 'pass').length,
    };

    setResult({ ranAt: new Date().toISOString(), findings, fixQueue, summary });
    setRunning(false);
  }, [societyId]);

  const handleQueueDelete = async (item: AuditFixQueueItem) => {
    const ok = await confirmAction(
      'Delete this entry?',
      `${item.title} — ₹${item.amount.toLocaleString('en-IN')} on ${fmtIsoDateToDisplay(item.sortDate)}. ${item.actionHint}`,
      'Delete',
      'Cancel',
    );
    if (!ok) return;

    setBusyQueueKey(item.queueKey);
    const res =
      item.entryKind === 'payment'
        ? await deleteMaintenancePayment(item.entryId, item.financeEntryId ?? null)
        : await deleteOrphanLedgerEntry(item.entryId);
    setBusyQueueKey(null);

    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success('Entry deleted — re-run audit when done with this batch');
    setResolvedQueueKeys((prev) => new Set(prev).add(item.queueKey));
  };

  const handleQueueAlignPayment = async (item: AuditFixQueueItem) => {
    if (!item.alignTargetMonth) return;
    setBusyQueueKey(item.queueKey);
    const res = await alignPaymentDueToMonth(item.entryId, item.alignTargetMonth);
    setBusyQueueKey(null);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success(`Payment aligned to ${fmtIsoMonthToDisplay(item.alignTargetMonth)}`);
    setResolvedQueueKeys((prev) => new Set(prev).add(item.queueKey));
  };

  const handleQueueAlignLedger = async (item: AuditFixQueueItem, paymentMonth: string) => {
    if (!item.relatedEntryId) return;
    setBusyQueueKey(item.queueKey);
    const res = await alignLedgerEntryMonth(item.relatedEntryId, paymentMonth);
    setBusyQueueKey(null);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success(`Ledger aligned to ${fmtIsoMonthToDisplay(paymentMonth)}`);
    setResolvedQueueKeys((prev) => new Set(prev).add(item.queueKey));
  };

  return (
    <div className="space-y-3">
      {/* Header + Run button */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
            <ShieldCheck className="w-4 h-4 text-primary" />
          </div>
          <div>
            <h3 className="text-sm font-semibold">Internal Finance Audit</h3>
            <p className="text-[10px] text-muted-foreground">
              Checks for negative balances, discrepancies, duplicates & data bugs
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => void runAudit()}
          disabled={running || !societyId}
          className="px-3 py-2 rounded-lg bg-primary text-primary-foreground text-xs font-medium flex items-center gap-1.5 disabled:opacity-50"
        >
          {running ? (
            <>
              <Loader2 className="w-3.5 h-3.5 animate-spin" /> Running…
            </>
          ) : (
            <>
              <Play className="w-3.5 h-3.5" /> Run Self-Audit
            </>
          )}
        </button>
      </div>

      {/* Results */}
      {result && (
        <div className="space-y-3">
          {/* Summary bar */}
          <div className="grid grid-cols-4 gap-2">
            <DescriptiveStatCard
              title="Critical"
              caption="Critical"
              description="Checks that indicate data integrity risk or broken links between payments and ledger."
              howCalculated="Count of self-audit findings with severity critical."
              variant="stat"
              contentAlign="center"
              value={result.summary.critical}
              valueClassName="text-lg text-destructive"
              className="p-2 border-destructive/30"
            />
            <DescriptiveStatCard
              title="Warnings"
              caption="Warnings"
              description="Possible duplicates or mismatches that should be reviewed by the treasurer."
              howCalculated="Count of findings with severity warning."
              variant="stat"
              contentAlign="center"
              value={result.summary.warning}
              valueClassName="text-lg text-amber-500"
              className="p-2 border-amber-500/30"
            />
            <DescriptiveStatCard
              title="Info"
              caption="Info"
              description="Informational notices that do not block reporting but help reconciliation."
              howCalculated="Count of findings with severity info."
              variant="stat"
              contentAlign="center"
              value={result.summary.info}
              valueClassName="text-lg text-blue-500"
              className="p-2 border-blue-500/30"
            />
            <DescriptiveStatCard
              title="Passed"
              caption="Passed"
              description="Rules that completed with no issues detected."
              howCalculated="Count of findings with severity pass."
              variant="stat"
              contentAlign="center"
              value={result.summary.pass}
              valueClassName="text-lg text-green-500"
              className="p-2 border-green-500/30"
            />
          </div>

          <p className="text-[10px] text-muted-foreground">
            Audit ran at {format(new Date(result.ranAt), 'dd MMM yyyy, hh:mm a')}
          </p>

          {/* Chronological fix queue — exact entries from earliest discrepancy */}
          {result.fixQueue.length > 0 && (
            <div className="card-section p-3 border-primary/40 bg-primary/5 space-y-3">
              <div className="flex items-start gap-2">
                <ListOrdered className="w-4 h-4 text-primary shrink-0 mt-0.5" />
                <div>
                  <p className="text-sm font-semibold">Entries to inspect (earliest first)</p>
                  <p className="text-[10px] text-muted-foreground mt-0.5">
                    Fix one entry at a time from the oldest discrepancy through today, then re-run the audit.
                  </p>
                </div>
              </div>
              <div className="space-y-2">
                {result.fixQueue.map((item, idx) => {
                  const done = resolvedQueueKeys.has(item.queueKey);
                  return (
                    <div
                      key={item.queueKey}
                      className={`rounded-lg border p-3 ${
                        done
                          ? 'border-green-500/30 bg-green-500/5 opacity-60'
                          : item.severity === 'critical'
                            ? 'border-destructive/30 bg-background'
                            : 'border-amber-500/30 bg-background'
                      }`}
                    >
                      <div className="flex items-start gap-2">
                        <span
                          className={`text-[10px] font-bold px-1.5 py-0.5 rounded shrink-0 ${
                            done ? 'bg-green-500/20 text-green-700' : 'bg-primary/10 text-primary'
                          }`}
                        >
                          {done ? '✓' : idx + 1}
                        </span>
                        <div className="flex-1 min-w-0">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="text-xs font-semibold">{item.issueLabel}</span>
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                              {fmtIsoDateToDisplay(item.sortDate)}
                            </span>
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                              {fmtIsoMonthToDisplay(item.month)}
                            </span>
                          </div>
                          <p className="text-sm font-medium mt-1">{item.title}</p>
                          <p className="text-xs font-mono mt-0.5">₹{item.amount.toLocaleString('en-IN')}</p>
                          <p className="text-[10px] text-muted-foreground mt-1">{item.detail}</p>
                          <p className="text-[10px] text-foreground mt-1">
                            <span className="font-semibold">Action:</span> {item.actionHint}
                          </p>
                          <p className="text-[9px] text-muted-foreground/70 font-mono mt-0.5">
                            {item.entryKind === 'payment' ? 'Payment' : 'Ledger'} ID: {item.entryId.slice(0, 8)}…
                          </p>
                          {!done && (
                            <div className="flex flex-wrap gap-2 mt-2">
                              {item.action === 'delete' && (
                                <button
                                  type="button"
                                  disabled={busyQueueKey === item.queueKey}
                                  onClick={() => void handleQueueDelete(item)}
                                  className="text-[10px] px-2 py-1.5 rounded-lg bg-destructive/10 text-destructive flex items-center gap-1"
                                >
                                  <Trash2 className="w-3 h-3" /> Delete
                                </button>
                              )}
                              {item.action === 'align_payment_month' && item.alignTargetMonth && (
                                <>
                                  <button
                                    type="button"
                                    disabled={busyQueueKey === item.queueKey}
                                    onClick={() => void handleQueueAlignPayment(item)}
                                    className="text-[10px] px-2 py-1.5 rounded-lg border border-border flex items-center gap-1"
                                  >
                                    <Calendar className="w-3 h-3" />
                                    Set payment to {fmtIsoMonthToDisplay(item.alignTargetMonth)}
                                  </button>
                                  <button
                                    type="button"
                                    disabled={busyQueueKey === item.queueKey}
                                    onClick={() => void handleQueueAlignLedger(item, item.month)}
                                    className="text-[10px] px-2 py-1.5 rounded-lg border border-border flex items-center gap-1"
                                  >
                                    <Calendar className="w-3 h-3" />
                                    Set ledger to {fmtIsoMonthToDisplay(item.month)}
                                  </button>
                                </>
                              )}
                              {item.action === 'review' && (
                                <button
                                  type="button"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    scrollToAuditAlarms();
                                  }}
                                  className="text-[10px] px-2 py-1.5 rounded-lg border border-border flex items-center gap-1"
                                >
                                  <Pencil className="w-3 h-3" /> Review in Finance
                                </button>
                              )}
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
              {resolvedQueueKeys.size > 0 && (
                <button
                  type="button"
                  onClick={() => void runAudit()}
                  className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground w-full"
                >
                  Re-run audit after fixes ({resolvedQueueKeys.size} marked done)
                </button>
              )}
            </div>
          )}

          {/* Findings */}
          {result.findings
            .filter((f) => f.severity !== 'pass')
            .map((f) => (
              <div
                key={f.id}
                className={`card-section p-3 ${sevBg(f.severity)} cursor-pointer`}
                onClick={() => setExpandedId(expandedId === f.id ? null : f.id)}
              >
                <div className="flex items-start gap-2">
                  {sevIcon(f.severity)}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold">{f.title}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">{f.description}</p>
                  </div>
                </div>

                {expandedId === f.id && (
                  <div className="mt-3 pt-3 border-t border-border space-y-2">
                    {f.reason && (
                      <div>
                        <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1">
                          <TrendingDown className="w-3 h-3" /> Why This Happens
                        </p>
                        <p className="text-xs text-foreground mt-1 whitespace-pre-line">{f.reason}</p>
                      </div>
                    )}
                    {f.faultTrace && (
                      <div className="rounded-lg border border-primary/30 bg-primary/5 p-2">
                        <p className="text-[10px] font-semibold text-primary uppercase tracking-wider flex items-center gap-1">
                          <MapPin className="w-3 h-3" /> Trace to Fault
                        </p>
                        <p className="text-xs text-foreground mt-1 whitespace-pre-line font-mono">{f.faultTrace}</p>
                      </div>
                    )}
                    {f.rectification && (
                      <div>
                        <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1">
                          <ArrowRight className="w-3 h-3" /> How to Rectify
                        </p>
                        <p className="text-xs text-foreground mt-1 whitespace-pre-line">{f.rectification}</p>
                        {(f.kind === 'ledger_overcount' || f.kind === 'duplicate_payments') && (
                          <button
                            type="button"
                            className="mt-2 text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground"
                            onClick={(e) => {
                              e.stopPropagation();
                              scrollToAuditAlarms();
                            }}
                          >
                            Open fix panel above
                          </button>
                        )}
                      </div>
                    )}
                    {f.kind === 'ledger_overcount' && f.ledgerIssues && f.ledgerIssues.length > 0 && (
                      <div className="rounded-lg border border-amber-500/30 bg-amber-500/5 p-2 space-y-2">
                        <p className="text-[10px] font-semibold uppercase text-muted-foreground">Affected months (oldest first)</p>
                        {[...f.ledgerIssues]
                          .sort((a, b) => a.month.localeCompare(b.month))
                          .map((issue) => (
                          <div key={issue.month} className="text-xs">
                            <p className="font-medium">
                              {fmtIsoMonthToDisplay(issue.month)} — ₹{issue.excess.toLocaleString('en-IN')} extra
                            </p>
                            {issue.unlinkedLedger.length > 0 && (
                              <ul className="mt-1 space-y-0.5 text-[10px] text-muted-foreground list-disc pl-4">
                                {issue.unlinkedLedger.slice(0, 4).map((e) => (
                                  <li key={e.id}>
                                    Orphan ledger: {e.title || 'Entry'} · ₹{e.total_amount.toLocaleString('en-IN')}
                                  </li>
                                ))}
                              </ul>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                    {f.data && (
                      <div>
                        <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider">Raw Data</p>
                        <div className="bg-muted/50 rounded-lg p-2 mt-1 text-[10px] font-mono break-all">
                          {Object.entries(f.data).map(([k, v]) => (
                            <p key={k}>
                              <span className="text-muted-foreground">{k}:</span>{' '}
                              {typeof v === 'object' ? JSON.stringify(v) : String(v)}
                            </p>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            ))}

          {/* Passed checks (collapsed) */}
          {result.summary.pass > 0 && (
            <div className="card-section p-3 border-green-500/20 bg-green-500/5">
              <div className="flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 text-green-500" />
                <p className="text-xs font-medium text-green-700 dark:text-green-400">
                  {result.summary.pass} check{result.summary.pass > 1 ? 's' : ''} passed
                </p>
              </div>
              <div className="mt-2 space-y-1">
                {result.findings
                  .filter((f) => f.severity === 'pass')
                  .map((f) => (
                    <p key={f.id} className="text-[10px] text-muted-foreground flex items-center gap-1">
                      <CheckCircle2 className="w-2.5 h-2.5 text-green-500" /> {f.title}
                    </p>
                  ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* No result yet prompt */}
      {!result && !running && (
        <div className="card-section p-4 text-center">
          <ShieldCheck className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-40" />
          <p className="text-xs text-muted-foreground">
            Click "Run Self-Audit" to scan for discrepancies. Results list exact entries to inspect from the earliest date through today.
          </p>
        </div>
      )}
    </div>
  );
};

export default FinanceIntegrityAudit;
