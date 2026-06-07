import { useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import {
  Search,
  AlertTriangle,
  ArrowRight,
  ExternalLink,
  IndianRupee,
  Loader2,
  MapPin,
  FileText,
  CheckCircle2,
  XCircle,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';
import { format } from 'date-fns';
import { fmtIsoMonthToDisplay, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import type { AdminTab } from '@/lib/adminPermissions';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import { MANUAL_AUDIT_METRICS } from '@/lib/descriptiveMetricCopy';

interface Props {
  onNavigate?: (tab: AdminTab) => void;
}

type TraceSource = 'period_report' | 'flat_report' | 'payments_tab' | 'receipts_tab';

interface TraceResult {
  source: string;
  computedTotal: number;
  expectedTotal: number;
  difference: number;
  findings: TraceFinding[];
}

interface TraceFinding {
  id: string;
  severity: 'error' | 'warning' | 'info';
  title: string;
  description: string;
  origin: string;
  navigateTo: AdminTab;
  navigateLabel: string;
  data?: Record<string, unknown>;
}

const normalizePaymentChannel = (method: unknown): 'cash' | 'bank' | 'other' => {
  const x = String(method ?? 'cash').toLowerCase().replace(/\s/g, '');
  if (x === 'cash') return 'cash';
  if (['upi', 'bank_transfer', 'razorpay', 'online', 'card', 'neft', 'rtgs', 'imps', 'netbanking', 'cheque', 'dd'].some((k) => x === k || x.includes(k)))
    return 'bank';
  return 'other';
};

const ManualAuditTracer = ({ onNavigate }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [month, setMonth] = useState(format(new Date(), 'yyyy-MM'));
  const [expectedAmount, setExpectedAmount] = useState('');
  const [source, setSource] = useState<TraceSource>('period_report');
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState<TraceResult | null>(null);
  const [expandedFinding, setExpandedFinding] = useState<string | null>(null);

  const trace = useCallback(async () => {
    if (!societyId || !expectedAmount || !month) return;
    setRunning(true);
    setResult(null);

    const expected = Number(expectedAmount);
    const findings: TraceFinding[] = [];
    let findingIdx = 0;
    const addFinding = (f: Omit<TraceFinding, 'id'>) => {
      findings.push({ ...f, id: `tf-${findingIdx++}` });
    };

    try {
      // Load data for the selected month
      const fromYmd = `${month}-01`;
      const lastDay = new Date(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0).getDate();
      const toYmd = `${month}-${String(lastDay).padStart(2, '0')}`;
      const fromMs = new Date(`${fromYmd}T00:00:00`).getTime();
      const toMs = new Date(`${toYmd}T23:59:59.999`).getTime();

      const { data: charges } = await supabase
        .from('maintenance_charges')
        .select('id, title, amount, frequency')
        .eq('society_id', societyId);

      const chargeIds = (charges ?? []).map((c) => c.id);
      const chargeMap = new Map((charges ?? []).map((c) => [c.id, c]));

      const { data: payments } = chargeIds.length > 0
        ? await supabase
            .from('maintenance_payments')
            .select('id, charge_id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, finance_entry_id')
            .in('charge_id', chargeIds)
        : { data: [] as any[] };

      const { data: ledgerEntries } = await supabase
        .from('finance_entries')
        .select('id, record_mode, destination, total_amount, payment_method, payment_status, entry_month, created_at, title, aggregate_flat_count')
        .eq('society_id', societyId);

      const allPayments = (payments ?? []) as any[];
      const allLedger = (ledgerEntries ?? []) as any[];
      const verifiedPayments = allPayments.filter((p) => p.payment_status === 'verified');

      // Collect all linked finance_entry_ids
      const allLinkedFeIds = new Set<string>();
      for (const p of verifiedPayments) {
        if (p.finance_entry_id) allLinkedFeIds.add(p.finance_entry_id);
      }

      // ─── Compute what the period report shows for this month ───
      let periodReportTotal = 0;
      const periodPayments: any[] = [];
      for (const p of verifiedPayments) {
        const d = p.due_date || p.payment_date || p.created_at || '';
        const t = new Date(d).getTime();
        if (!Number.isNaN(t) && t >= fromMs && t <= toMs) {
          periodReportTotal += Number(p.amount || 0);
          periodPayments.push(p);
        }
      }

      // Unlinked ledger entries in this month
      const unlinkedLedgerInMonth: any[] = [];
      for (const e of allLedger) {
        if (e.destination === 'separate_entry') continue;
        const ledgerDate = e.entry_month ? `${e.entry_month}-01` : e.created_at;
        const t = new Date(ledgerDate).getTime();
        if (Number.isNaN(t) || t < fromMs || t > toMs) continue;
        if (!allLinkedFeIds.has(e.id)) {
          periodReportTotal += Number(e.total_amount || 0);
          unlinkedLedgerInMonth.push(e);
        }
      }

      // ─── Compute flat report total for this month ───
      let flatReportTotal = 0;
      const countedFeIds = new Set<string>();
      for (const p of verifiedPayments) {
        const d = p.due_date || p.payment_date || p.created_at || '';
        const t = new Date(d).getTime();
        if (!Number.isNaN(t) && t >= fromMs && t <= toMs) {
          flatReportTotal += Number(p.amount || 0);
          if (p.finance_entry_id) countedFeIds.add(p.finance_entry_id);
        }
      }
      // Add allocations from non-flats_only or orphaned flats_only entries
      for (const e of allLedger) {
        if (e.destination === 'separate_entry') continue;
        const ledgerDate = e.entry_month ? `${e.entry_month}-01` : e.created_at;
        const t = new Date(ledgerDate).getTime();
        if (Number.isNaN(t) || t < fromMs || t > toMs) continue;
        if (e.record_mode === 'flats_only' && countedFeIds.has(e.id)) continue;
        flatReportTotal += Number(e.total_amount || 0);
      }

      // ─── Determine which computed total to use based on source ───
      const computedTotal = source === 'period_report' || source === 'receipts_tab'
        ? periodReportTotal
        : flatReportTotal;

      const difference = computedTotal - expected;

      // ─── TRACE THE DISCREPANCY ───

      if (Math.abs(difference) < 1) {
        addFinding({
          severity: 'info',
          title: 'No discrepancy detected',
          description: `The ${source.replace('_', ' ')} shows ₹${computedTotal.toLocaleString('en-IN')} which matches your expected ₹${expected.toLocaleString('en-IN')}.`,
          origin: 'System computation matches expected value.',
          navigateTo: 'finance',
          navigateLabel: 'Open Finance',
        });
      } else {
        // 1. Check for date-boundary payments (payment date in different month than entry_month)
        const dateBoundaryPayments: any[] = [];
        for (const p of verifiedPayments) {
          if (!p.finance_entry_id) continue;
          const pDate = p.due_date || p.payment_date || p.created_at || '';
          const pMonth = pDate ? format(new Date(pDate), 'yyyy-MM') : '';
          const entry = allLedger.find((e) => e.id === p.finance_entry_id);
          if (!entry) continue;
          const eMonth = entry.entry_month || '';
          if (pMonth && eMonth && pMonth !== eMonth) {
            // Check if either month is our target month
            if (pMonth === month || eMonth === month) {
              dateBoundaryPayments.push({ ...p, paymentMonth: pMonth, entryMonth: eMonth, entryTitle: entry.title });
            }
          }
        }

        if (dateBoundaryPayments.length > 0) {
          const boundaryTotal = dateBoundaryPayments.reduce((s, p) => s + Number(p.amount || 0), 0);
          addFinding({
            severity: 'error',
            title: `${dateBoundaryPayments.length} Date-Boundary Payment(s) — ₹${boundaryTotal.toLocaleString('en-IN')}`,
            description: `These payments have due_date in one month but their finance_entry has entry_month in a different month. This causes the payment to appear in one report but the ledger entry in another.`,
            origin: 'Finance → Payments tab. The payment due_date does not match the finance_entry entry_month.',
            navigateTo: 'finance',
            navigateLabel: 'Go to Payments',
            data: {
              payments: dateBoundaryPayments.slice(0, 10).map((p) => ({
                id: p.id.slice(0, 8),
                flat: p.flat_number,
                amount: p.amount,
                paymentMonth: p.paymentMonth,
                entryMonth: p.entryMonth,
                method: p.payment_method,
              })),
            },
          });
        }

        // 2. Check for unlinked ledger entries adding extra receipts
        if (unlinkedLedgerInMonth.length > 0) {
          const unlinkedTotal = unlinkedLedgerInMonth.reduce((s, e) => s + Number(e.total_amount || 0), 0);
          addFinding({
            severity: 'error',
            title: `${unlinkedLedgerInMonth.length} Unlinked Ledger Entry/Entries — ₹${unlinkedTotal.toLocaleString('en-IN')}`,
            description: `These finance_entries have no linked maintenance_payments. The period report counts their total_amount as additional receipts, inflating the total.`,
            origin: 'Finance → Receipts tab. These entries exist in the ledger but have no corresponding payment records.',
            navigateTo: 'finance',
            navigateLabel: 'Go to Receipts',
            data: {
              entries: unlinkedLedgerInMonth.slice(0, 10).map((e) => ({
                id: e.id.slice(0, 8),
                title: e.title,
                amount: e.total_amount,
                mode: e.record_mode,
                destination: e.destination,
                entryMonth: e.entry_month,
              })),
            },
          });
        }

        // 3. Check for duplicate payments in this month
        const dupeKey = (p: any) => {
          const d = p.due_date || p.payment_date || p.created_at || '';
          const month = d ? format(new Date(d), 'yyyy-MM') : 'unknown';
          const ch = normalizePaymentChannel(p.payment_method);
          return `${p.flat_number}||${p.charge_id}||${month}||${ch}`;
        };
        const dupeGroups = new Map<string, any[]>();
        for (const p of periodPayments) {
          const key = dupeKey(p);
          if (!dupeGroups.has(key)) dupeGroups.set(key, []);
          dupeGroups.get(key)!.push(p);
        }
        const dupes = [...dupeGroups.entries()].filter(([, g]) => g.length > 1);
        if (dupes.length > 0) {
          const dupeTotal = dupes.reduce((s, [, g]) => s + g.slice(1).reduce((ss, p) => ss + Number(p.amount || 0), 0), 0);
          addFinding({
            severity: 'error',
            title: `${dupes.length} Duplicate Payment Group(s) — ₹${dupeTotal.toLocaleString('en-IN')} extra`,
            description: `Same flat + same charge + same channel recorded multiple times in ${fmtIsoMonthToDisplay(month)}.`,
            origin: 'Finance → Payments tab. Delete the duplicate entries.',
            navigateTo: 'audit',
            navigateLabel: 'Go to Duplicate Alarms',
            data: {
              duplicates: dupes.slice(0, 5).map(([key, g]) => ({
                flat: key.split('||')[0],
                count: g.length,
                totalAmount: g.reduce((s, p) => s + Number(p.amount || 0), 0),
              })),
            },
          });
        }

        // 4. Check for payments with wrong amount vs charge definition
        const wrongAmountPayments: any[] = [];
        for (const p of periodPayments) {
          const charge = chargeMap.get(p.charge_id);
          if (!charge || (charge.frequency ?? '').toLowerCase() !== 'monthly') continue;
          const expected = Number(charge.amount || 0);
          const actual = Number(p.amount || 0);
          if (expected > 0 && Math.abs(actual - expected) > 1) {
            wrongAmountPayments.push({ ...p, expectedAmount: expected, chargeTitle: charge.title });
          }
        }
        if (wrongAmountPayments.length > 0) {
          const amtDiff = wrongAmountPayments.reduce((s, p) => s + (Number(p.amount) - p.expectedAmount), 0);
          addFinding({
            severity: 'warning',
            title: `${wrongAmountPayments.length} Payment(s) with Non-Standard Amount — ₹${Math.abs(amtDiff).toLocaleString('en-IN')} ${amtDiff > 0 ? 'over' : 'under'}`,
            description: `These payments have a different amount than the charge definition. Could be partial payments, penalties, or data entry errors.`,
            origin: 'Finance → Payments tab. Compare each payment amount against the charge definition.',
            navigateTo: 'finance',
            navigateLabel: 'Go to Payments',
            data: {
              payments: wrongAmountPayments.slice(0, 10).map((p) => ({
                flat: p.flat_number,
                recorded: p.amount,
                expected: p.expectedAmount,
                charge: p.chargeTitle,
                diff: Number(p.amount) - p.expectedAmount,
              })),
            },
          });
        }

        // 5. Check for orphaned payments (no finance_entry_id) in this month
        const orphansInMonth = periodPayments.filter((p) => !p.finance_entry_id);
        if (orphansInMonth.length > 0) {
          const orphanTotal = orphansInMonth.reduce((s, p) => s + Number(p.amount || 0), 0);
          addFinding({
            severity: 'warning',
            title: `${orphansInMonth.length} Orphaned Payment(s) — ₹${orphanTotal.toLocaleString('en-IN')}`,
            description: `These payments have no linked finance_entry. They are counted in totals but lack a ledger trail, which can cause flat report vs period report mismatch.`,
            origin: 'Finance → Payments tab. These need to be re-recorded properly or linked to a ledger entry.',
            navigateTo: 'finance',
            navigateLabel: 'Go to Payments',
            data: {
              count: orphansInMonth.length,
              total: orphanTotal,
              flats: [...new Set(orphansInMonth.map((p) => p.flat_number))].slice(0, 10),
            },
          });
        }

        // 6. Check period report vs flat report discrepancy
        const reportDiff = Math.abs(periodReportTotal - flatReportTotal);
        if (reportDiff > 1) {
          addFinding({
            severity: 'warning',
            title: `Period Report vs Flat Report Mismatch — ₹${reportDiff.toLocaleString('en-IN')}`,
            description: `Period report shows ₹${periodReportTotal.toLocaleString('en-IN')} but flat report shows ₹${flatReportTotal.toLocaleString('en-IN')} for ${fmtIsoMonthToDisplay(month)}.`,
            origin: 'Finance → Period tab and Flat Report tab. Compare the two views for this month.',
            navigateTo: 'finance',
            navigateLabel: 'Go to Finance',
            data: { periodReport: periodReportTotal, flatReport: flatReportTotal, difference: reportDiff },
          });
        }

        // 7. Summary: breakdown of where the excess/deficit comes from
        if (Math.abs(difference) > 1) {
          const breakdown: string[] = [];
          if (dateBoundaryPayments.length > 0) breakdown.push(`Date-boundary: ₹${dateBoundaryPayments.reduce((s, p) => s + Number(p.amount || 0), 0).toLocaleString('en-IN')}`);
          if (unlinkedLedgerInMonth.length > 0) breakdown.push(`Unlinked ledger: ₹${unlinkedLedgerInMonth.reduce((s, e) => s + Number(e.total_amount || 0), 0).toLocaleString('en-IN')}`);
          if (dupes.length > 0) breakdown.push(`Duplicates: ₹${dupes.reduce((s, [, g]) => s + g.slice(1).reduce((ss, p) => ss + Number(p.amount || 0), 0), 0).toLocaleString('en-IN')}`);

          addFinding({
            severity: 'info',
            title: `Discrepancy Breakdown: ${difference > 0 ? '+' : ''}₹${difference.toLocaleString('en-IN')}`,
            description: `System shows ₹${computedTotal.toLocaleString('en-IN')}, you expected ₹${expected.toLocaleString('en-IN')}. Possible sources: ${breakdown.length > 0 ? breakdown.join(' + ') : 'Could not pinpoint — check individual payments manually.'}`,
            origin: 'Multiple sources may contribute. Expand findings above for details.',
            navigateTo: 'finance',
            navigateLabel: 'Open Finance Module',
          });
        }
      }

      setResult({
        source: source.replace(/_/g, ' '),
        computedTotal,
        expectedTotal: expected,
        difference,
        findings,
      });
    } catch (err: any) {
      setResult({
        source: source.replace(/_/g, ' '),
        computedTotal: 0,
        expectedTotal: expected,
        difference: 0,
        findings: [{
          id: 'err',
          severity: 'error',
          title: 'Trace Failed',
          description: err?.message || 'Unexpected error',
          origin: 'System error',
          navigateTo: 'audit',
          navigateLabel: 'Stay here',
        }],
      });
    }

    setRunning(false);
  }, [societyId, month, expectedAmount, source]);

  return (
    <div className="space-y-3">
      {/* Header */}
      <div className="flex items-center gap-2">
        <div className="w-8 h-8 rounded-lg bg-amber-500/10 flex items-center justify-center">
          <MapPin className="w-4 h-4 text-amber-600" />
        </div>
        <div>
          <h3 className="text-sm font-semibold">Manual Discrepancy Tracer</h3>
          <p className="text-[10px] text-muted-foreground">
            Enter the expected amount and let the system trace where the mistake originates
          </p>
        </div>
      </div>

      {/* Input form */}
      <div className="card-section p-3 space-y-3">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Month</label>
            <input
              type="month"
              className="input-field mt-0.5 text-sm"
              value={month}
              onChange={(e) => setMonth(e.target.value)}
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Report Source</label>
            <select
              className="input-field mt-0.5 text-sm"
              value={source}
              onChange={(e) => setSource(e.target.value as TraceSource)}
            >
              <option value="period_report">Period Report</option>
              <option value="flat_report">Flat Report</option>
              <option value="payments_tab">Payments Tab</option>
              <option value="receipts_tab">Receipts Tab</option>
            </select>
          </div>
        </div>
        <div>
          <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">
            Actual / Expected Collection (₹)
          </label>
          <input
            type="number"
            className="input-field mt-0.5 text-sm font-mono"
            placeholder="e.g. 72500"
            value={expectedAmount}
            onChange={(e) => setExpectedAmount(e.target.value)}
          />
          <p className="text-[9px] text-muted-foreground mt-0.5">
            Enter the amount you believe is correct (from bank statement, manual count, etc.)
          </p>
        </div>
        <button
          type="button"
          onClick={() => void trace()}
          disabled={running || !expectedAmount || !month || !societyId}
          className="w-full px-4 py-2.5 rounded-lg bg-amber-500 text-white text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-50 hover:bg-amber-600 transition-colors"
        >
          {running ? (
            <><Loader2 className="w-4 h-4 animate-spin" /> Tracing…</>
          ) : (
            <><Search className="w-4 h-4" /> Trace Discrepancy</>
          )}
        </button>
      </div>

      {/* Results */}
      {result && (
        <div className="space-y-3">
          {/* Summary card */}
          <div className={`grid grid-cols-3 gap-2 ${Math.abs(result.difference) < 1 ? '' : ''}`}>
            <DescriptiveStatCard
              {...MANUAL_AUDIT_METRICS.computedTotal}
              caption={`System (${result.source})`}
              value={`₹${result.computedTotal.toLocaleString('en-IN')}`}
              valueClassName="text-base font-mono"
              className={`!p-2.5 ${Math.abs(result.difference) < 1 ? 'border-green-500/30 bg-green-500/5' : 'border-amber-500/30 bg-amber-500/5'}`}
            />
            {Math.abs(result.difference) < 1 ? (
              <DescriptiveStatCard
                {...MANUAL_AUDIT_METRICS.match}
                caption="Match"
                value={<CheckCircle2 className="w-6 h-6 text-green-500 mx-auto" />}
                className="!p-2.5 border-green-500/30 bg-green-500/5 items-center text-center"
                contentAlign="center"
              />
            ) : (
              <DescriptiveStatCard
                {...MANUAL_AUDIT_METRICS.difference}
                caption={result.difference > 0 ? 'Over-reported' : 'Under-reported'}
                value={`${result.difference > 0 ? '+' : ''}₹${result.difference.toLocaleString('en-IN')}`}
                valueClassName={`text-base font-mono ${result.difference > 0 ? 'text-destructive' : 'text-amber-600'}`}
                className="!p-2.5 border-amber-500/30 bg-amber-500/5"
              />
            )}
            <DescriptiveStatCard
              {...MANUAL_AUDIT_METRICS.expectedTotal}
              caption="Expected (yours)"
              value={`₹${result.expectedTotal.toLocaleString('en-IN')}`}
              valueClassName="text-base font-mono"
              className={`!p-2.5 ${Math.abs(result.difference) < 1 ? 'border-green-500/30 bg-green-500/5' : 'border-amber-500/30 bg-amber-500/5'}`}
            />
          </div>

          {/* Findings with navigation */}
          {result.findings.map((f) => (
            <div
              key={f.id}
              className={`card-section p-3 ${
                f.severity === 'error' ? 'border-destructive/30 bg-destructive/5' :
                f.severity === 'warning' ? 'border-amber-500/30 bg-amber-500/5' :
                'border-blue-500/20 bg-blue-500/5'
              }`}
            >
              <div
                className="flex items-start gap-2 cursor-pointer"
                onClick={() => setExpandedFinding(expandedFinding === f.id ? null : f.id)}
              >
                {f.severity === 'error' ? <XCircle className="w-4 h-4 text-destructive flex-shrink-0 mt-0.5" /> :
                 f.severity === 'warning' ? <AlertTriangle className="w-4 h-4 text-amber-500 flex-shrink-0 mt-0.5" /> :
                 <FileText className="w-4 h-4 text-blue-500 flex-shrink-0 mt-0.5" />}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold">{f.title}</p>
                  <p className="text-xs text-muted-foreground mt-0.5">{f.description}</p>
                </div>
                {expandedFinding === f.id ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
              </div>

              {expandedFinding === f.id && (
                <div className="mt-3 pt-3 border-t border-border space-y-3">
                  {/* Origin explanation */}
                  <div>
                    <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1">
                      <MapPin className="w-3 h-3" /> Mistake Origin
                    </p>
                    <p className="text-xs text-foreground mt-1">{f.origin}</p>
                  </div>

                  {/* Raw data */}
                  {f.data && (
                    <div>
                      <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider">Details</p>
                      <div className="bg-muted/50 rounded-lg p-2 mt-1 text-[10px] font-mono break-all max-h-40 overflow-y-auto">
                        {Object.entries(f.data).map(([k, v]) => (
                          <p key={k}>
                            <span className="text-muted-foreground">{k}:</span>{' '}
                            {typeof v === 'object' ? JSON.stringify(v, null, 1) : String(v)}
                          </p>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Navigate button */}
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onNavigate?.(f.navigateTo);
                    }}
                    className="w-full px-3 py-2 rounded-lg bg-primary text-primary-foreground text-xs font-medium flex items-center justify-center gap-2 hover:bg-primary/90 transition-colors"
                  >
                    <ExternalLink className="w-3.5 h-3.5" />
                    {f.navigateLabel}
                    <ArrowRight className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default ManualAuditTracer;
