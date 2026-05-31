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
} from 'lucide-react';
import { format } from 'date-fns';
import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';

/* ─── Types ─── */

type Severity = 'critical' | 'warning' | 'info' | 'pass';

interface AuditFinding {
  id: string;
  severity: Severity;
  title: string;
  description: string;
  reason: string;
  rectification: string;
  data?: Record<string, unknown>;
}

interface AuditResult {
  ranAt: string;
  findings: AuditFinding[];
  summary: { critical: number; warning: number; info: number; pass: number };
}

/* ─── Helpers ─── */

const normalizePaymentChannel = (method: unknown): 'cash' | 'bank' | 'other' => {
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

  const runAudit = useCallback(async () => {
    if (!societyId) return;
    setRunning(true);
    setResult(null);

    const findings: AuditFinding[] = [];
    let findingIdx = 0;
    const addFinding = (f: Omit<AuditFinding, 'id'>) => {
      findings.push({ ...f, id: `f-${findingIdx++}` });
    };

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

      const allPayments = (payments ?? []) as any[];
      const allLedger = (ledgerEntries ?? []) as any[];
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

      if (cashBalance < 0) {
        addFinding({
          severity: 'critical',
          title: `Negative Cash Balance: ₹${Math.abs(cashBalance).toLocaleString('en-IN')}`,
          description: `Cash outflow (₹${expenseByChannel.cash.toLocaleString('en-IN')}) exceeds cash inflow (₹${receiptByChannel.cash.toLocaleString('en-IN')}).`,
          reason: 'This typically happens when: (1) An expense was recorded as "cash" but the corresponding receipt was recorded as "bank/UPI", (2) A cash receipt was accidentally deleted or rejected, (3) Expenses were double-recorded under cash, or (4) A payment method was incorrectly tagged.',
          rectification: '1. Go to Finance → Period Report and filter by cash method to identify mismatched entries.\n2. Check if any expense marked "cash" should actually be "bank/UPI".\n3. Verify all cash receipts are in "verified" status.\n4. Look for duplicate expense entries under cash channel.\n5. Correct the payment_method on the wrongly tagged entry from the Payments or Receipts tab.',
          data: { cashReceipts: receiptByChannel.cash, cashExpenses: expenseByChannel.cash, deficit: cashBalance },
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
        addFinding({
          severity: 'critical',
          title: `Negative Bank Balance: ₹${Math.abs(bankBalance).toLocaleString('en-IN')}`,
          description: `Bank outflow (₹${expenseByChannel.bank.toLocaleString('en-IN')}) exceeds bank inflow (₹${receiptByChannel.bank.toLocaleString('en-IN')}).`,
          reason: 'This typically happens when: (1) A bank expense was recorded but the receipt was tagged as "cash", (2) A UPI/bank receipt was rejected or deleted, (3) Duplicate bank expenses exist, or (4) An outsider payment allocated to bank was not linked correctly.',
          rectification: '1. Go to Finance → Period Report and review bank-channel entries.\n2. Check if any receipt marked "cash" should be "UPI/bank".\n3. Verify no bank receipts are stuck in "pending" or "rejected" status.\n4. Look for duplicate expense entries under bank channel.\n5. Correct the payment_method on mismatched entries.',
          data: { bankReceipts: receiptByChannel.bank, bankExpenses: expenseByChannel.bank, deficit: bankBalance },
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

      /* ─── 3. DUPLICATE PAYMENT DETECTION ─── */
      const dupeKey = (p: any) => {
        const dateStr = p.due_date || p.payment_date || p.created_at || '';
        const month = dateStr ? format(new Date(dateStr), 'yyyy-MM') : 'unknown';
        const ch = normalizePaymentChannel(p.payment_method);
        return `${p.flat_number}||${p.charge_id}||${month}||${ch}`;
      };

      const dupeGroups = new Map<string, any[]>();
      for (const p of allPayments.filter((x) => x.payment_status === 'verified' || x.payment_status === 'pending')) {
        const key = dupeKey(p);
        if (!dupeGroups.has(key)) dupeGroups.set(key, []);
        dupeGroups.get(key)!.push(p);
      }

      let dupeCount = 0;
      for (const [, group] of dupeGroups) {
        if (group.length > 1) dupeCount++;
      }

      if (dupeCount > 0) {
        addFinding({
          severity: 'critical',
          title: `${dupeCount} Duplicate Payment Group${dupeCount > 1 ? 's' : ''} Found`,
          description: `Same flat + same charge + same month + same channel has multiple entries.`,
          reason: 'Payments were recorded more than once — either by admin double-click, network retry, or manual re-entry without checking existing records.',
          rectification: 'Use the "Duplicate Maintenance Credits" alarm panel above to expand and delete the extra entries directly.',
          data: { duplicateGroups: dupeCount },
        });
      } else {
        addFinding({
          severity: 'pass',
          title: 'No Duplicate Payments',
          description: 'Each flat has at most one payment per charge per month per channel.',
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
      if (discrepancy > 1) {
        addFinding({
          severity: 'warning',
          title: `Recording vs Ledger Discrepancy: ₹${discrepancy.toLocaleString('en-IN')}`,
          description: `Sum of verified maintenance_payments (₹${mpTotal.toLocaleString('en-IN')}) does not match sum of finance_entries[flats_only] (₹${feFlatsOnlyTotal.toLocaleString('en-IN')}).`,
          reason: 'This happens when: (1) A payment was recorded without creating a finance_entry (older data or bug), (2) A finance_entry was deleted but the payment remains, (3) Amount was edited in one table but not the other.',
          rectification: '1. Identify payments without a finance_entry_id — these are orphaned records.\n2. Check if any finance_entry has a different total_amount than the sum of its linked payments.\n3. Re-record missing entries or delete orphaned ones from the Payments tab.',
          data: { maintenancePaymentsTotal: mpTotal, financeEntriesTotal: feFlatsOnlyTotal, difference: discrepancy },
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

      /* ─── 5. PERIOD REPORT CROSS-VERIFICATION (date-boundary double-count detection) ─── */
      // Simulate the period report logic per month and compare against raw payment sums
      // This catches the exact bug where payment dates and entry_month fall in different periods
      const monthlyPaymentTotals = new Map<string, number>(); // yyyy-MM → sum from payments
      const monthlyReportTotals = new Map<string, number>(); // yyyy-MM → what period report would show

      // Raw payment totals per month (ground truth)
      for (const p of verifiedPayments) {
        const d = p.due_date || p.payment_date || p.created_at || '';
        if (!d) continue;
        const month = format(new Date(d), 'yyyy-MM');
        monthlyPaymentTotals.set(month, (monthlyPaymentTotals.get(month) || 0) + Number(p.amount || 0));
      }

      // Simulate period report per month: payments in range + unlinked ledger entries in range
      for (const [month] of monthlyPaymentTotals) {
        const fromYmd = `${month}-01`;
        const lastDay = new Date(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0).getDate();
        const toYmd = `${month}-${String(lastDay).padStart(2, '0')}`;

        let reportTotal = 0;
        // Payments in this month's range
        for (const p of verifiedPayments) {
          const d = p.due_date || p.payment_date || p.created_at || '';
          if (!d) continue;
          const t = new Date(d).getTime();
          if (t >= new Date(`${fromYmd}T00:00:00`).getTime() && t <= new Date(`${toYmd}T23:59:59.999`).getTime()) {
            reportTotal += Number(p.amount || 0);
          }
        }
        // Unlinked ledger entries in this month's range (what period report adds on top)
        for (const e of allLedger) {
          if (e.destination === 'separate_entry') continue;
          const ledgerDate = e.entry_month ? `${e.entry_month}-01` : e.created_at;
          const t = new Date(ledgerDate).getTime();
          if (t < new Date(`${fromYmd}T00:00:00`).getTime() || t > new Date(`${toYmd}T23:59:59.999`).getTime()) continue;
          if (!linkedFeIds.has(e.id)) {
            reportTotal += Number(e.total_amount || 0);
          }
        }
        monthlyReportTotals.set(month, reportTotal);
      }

      // Check for months where report total exceeds payment total (over-counting)
      const overCountedMonths: { month: string; paymentTotal: number; reportTotal: number; excess: number }[] = [];
      for (const [month, payTotal] of monthlyPaymentTotals) {
        const repTotal = monthlyReportTotals.get(month) || 0;
        if (repTotal > payTotal + 1) { // tolerance of ₹1 for rounding
          overCountedMonths.push({ month, paymentTotal: payTotal, reportTotal: repTotal, excess: repTotal - payTotal });
        }
      }

      if (overCountedMonths.length > 0) {
        const totalExcess = overCountedMonths.reduce((s, m) => s + m.excess, 0);
        addFinding({
          severity: 'critical',
          title: `Period Report Over-Counting: ₹${totalExcess.toLocaleString('en-IN')} excess across ${overCountedMonths.length} month(s)`,
          description: `The period report shows more receipts than actual payments for: ${overCountedMonths.map((m) => `${fmtIsoMonthToDisplay(m.month)} (₹${m.excess.toLocaleString('en-IN')} extra)`).join(', ')}.`,
          reason: 'This happens when a finance_entry has entry_month in one period but its linked payments have due_date in a different period. The deduplication fails at the date boundary — payments are not counted (wrong month) but the unlinked ledger entry IS counted (right month), causing double-counting.',
          rectification: '1. Go to Finance → Payments tab and check entries near month boundaries (last/first few days).\n2. Ensure payment due_date matches the finance_entry entry_month.\n3. Or update the payment due_date to fall within the correct month.\n4. The system fix has been applied — this check verifies historical data integrity.',
          data: { months: overCountedMonths },
        });
      } else {
        addFinding({
          severity: 'pass',
          title: 'Period Report Totals Verified',
          description: 'No date-boundary over-counting detected. Period report figures match raw payment sums.',
          reason: '',
          rectification: '',
        });
      }

      /* ─── 6. ORPHANED PAYMENTS (no finance_entry_id) ─── */
      const orphanedPayments = verifiedPayments.filter((p) => !p.finance_entry_id);
      if (orphanedPayments.length > 0) {
        const orphanTotal = orphanedPayments.reduce((s, p) => s + Number(p.amount || 0), 0);
        addFinding({
          severity: 'warning',
          title: `${orphanedPayments.length} Orphaned Payment${orphanedPayments.length > 1 ? 's' : ''} (₹${orphanTotal.toLocaleString('en-IN')})`,
          description: 'These verified payments have no linked finance_entry record.',
          reason: 'Likely recorded before the ledger system was introduced, or the finance_entry was deleted while the payment remained.',
          rectification: '1. These payments are counted in totals but lack a ledger trail.\n2. Re-record them via Finance → Record Payment to create proper ledger entries, then delete the orphaned ones.\n3. Or accept them as legacy data if the amounts are correct.',
          data: { count: orphanedPayments.length, total: orphanTotal },
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

    const summary = {
      critical: findings.filter((f) => f.severity === 'critical').length,
      warning: findings.filter((f) => f.severity === 'warning').length,
      info: findings.filter((f) => f.severity === 'info').length,
      pass: findings.filter((f) => f.severity === 'pass').length,
    };

    setResult({ ranAt: new Date().toISOString(), findings, summary });
    setRunning(false);
  }, [societyId]);

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
            <div className="card-section p-2 text-center border-destructive/30">
              <p className="text-lg font-bold text-destructive">{result.summary.critical}</p>
              <p className="text-[9px] text-muted-foreground">Critical</p>
            </div>
            <div className="card-section p-2 text-center border-amber-500/30">
              <p className="text-lg font-bold text-amber-500">{result.summary.warning}</p>
              <p className="text-[9px] text-muted-foreground">Warnings</p>
            </div>
            <div className="card-section p-2 text-center border-blue-500/30">
              <p className="text-lg font-bold text-blue-500">{result.summary.info}</p>
              <p className="text-[9px] text-muted-foreground">Info</p>
            </div>
            <div className="card-section p-2 text-center border-green-500/30">
              <p className="text-lg font-bold text-green-500">{result.summary.pass}</p>
              <p className="text-[9px] text-muted-foreground">Passed</p>
            </div>
          </div>

          <p className="text-[10px] text-muted-foreground">
            Audit ran at {format(new Date(result.ranAt), 'dd MMM yyyy, hh:mm a')}
          </p>

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
                    {f.rectification && (
                      <div>
                        <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1">
                          <ArrowRight className="w-3 h-3" /> How to Rectify
                        </p>
                        <p className="text-xs text-foreground mt-1 whitespace-pre-line">{f.rectification}</p>
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
            Click "Run Self-Audit" to scan for negative balances, recording discrepancies, orphaned entries, and data integrity issues.
          </p>
        </div>
      )}
    </div>
  );
};

export default FinanceIntegrityAudit;
