import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { AlertTriangle, BookOpen, RefreshCw, Trash2, Calendar } from 'lucide-react';
import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import {
  analyzeLedgerOvercountByMonth,
  type AuditLedgerRow,
  type AuditPaymentRow,
  type LedgerOvercountMonth,
} from '@/lib/financeAuditDetection';
import {
  alignLedgerEntryMonth,
  alignPaymentDueToMonth,
  deleteOrphanLedgerEntry,
} from '@/lib/financeAuditRemediation';

type Props = {
  /** When set, only show issues for this month (manual tracer). */
  focusMonth?: string;
  onResolved?: () => void;
};

const FinanceLedgerOvercountPanel = ({ focusMonth, onResolved }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [issues, setIssues] = useState<LedgerOvercountMonth[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedMonth, setExpandedMonth] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const detect = useCallback(async () => {
    if (!societyId) {
      setIssues([]);
      setLoading(false);
      return;
    }
    setLoading(true);

    const { data: charges } = await supabase
      .from('maintenance_charges')
      .select('id')
      .eq('society_id', societyId);
    const chargeIds = (charges ?? []).map((c) => c.id);

    const { data: payments } =
      chargeIds.length > 0
        ? await supabase
            .from('maintenance_payments')
            .select(
              'id, charge_id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, finance_entry_id',
            )
            .in('charge_id', chargeIds)
            .eq('payment_status', 'verified')
        : { data: [] as AuditPaymentRow[] };

    const { data: ledgerEntries } = await supabase
      .from('finance_entries')
      .select(
        'id, record_mode, destination, total_amount, payment_method, payment_status, entry_month, created_at, title',
      )
      .eq('society_id', societyId);

    let found = analyzeLedgerOvercountByMonth(
      (payments ?? []) as AuditPaymentRow[],
      (ledgerEntries ?? []) as AuditLedgerRow[],
    );
    if (focusMonth) found = found.filter((x) => x.month === focusMonth);
    setIssues(found);
    setLoading(false);
  }, [societyId, focusMonth]);

  useEffect(() => {
    void detect();
  }, [detect]);

  const afterFix = () => {
    void detect();
    onResolved?.();
  };

  const handleDeleteLedger = async (entryId: string, amount: number, month: string) => {
    const ok = await confirmAction(
      'Remove extra ledger receipt?',
      `This deletes the orphan ledger entry of ₹${amount.toLocaleString('en-IN')} for ${fmtIsoMonthToDisplay(month)}. Period reports will stop double-counting it. Linked payments are not affected.`,
      'Delete ledger entry',
      'Cancel',
    );
    if (!ok) return;
    setBusyId(entryId);
    const res = await deleteOrphanLedgerEntry(entryId);
    setBusyId(null);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success('Ledger entry removed');
    afterFix();
  };

  const handleAlignPayment = async (paymentId: string, entryMonth: string) => {
    setBusyId(paymentId);
    const res = await alignPaymentDueToMonth(paymentId, entryMonth);
    setBusyId(null);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success(`Payment due date set to ${entryMonth}`);
    afterFix();
  };

  const handleAlignLedger = async (entryId: string, paymentMonth: string) => {
    setBusyId(entryId);
    const res = await alignLedgerEntryMonth(entryId, paymentMonth);
    setBusyId(null);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }
    toast.success(`Ledger month set to ${paymentMonth}`);
    afterFix();
  };

  if (loading) {
    return (
      <div className="card-section p-4">
        <p className="text-sm text-muted-foreground">Scanning for ledger double-count in period reports…</p>
      </div>
    );
  }

  if (issues.length === 0) {
    return (
      <div className="card-section p-4 border-green-500/30 bg-green-500/5">
        <div className="flex items-center gap-2">
          <BookOpen className="w-4 h-4 text-green-600" />
          <p className="text-sm font-medium text-green-700 dark:text-green-400">
            No ledger double-count in period reports
          </p>
        </div>
        <p className="text-xs text-muted-foreground mt-1">
          Receipt totals match verified payments — no extra unlinked finance ledger rows are inflating monthly reports.
        </p>
      </div>
    );
  }

  const totalExcess = issues.reduce((s, i) => s + i.excess, 0);

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-amber-500/10 flex items-center justify-center">
            <BookOpen className="w-4 h-4 text-amber-600" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-amber-800 dark:text-amber-300">
              Ledger double-count (period reports)
            </h3>
            <p className="text-[10px] text-muted-foreground">
              ₹{totalExcess.toLocaleString('en-IN')} extra across {issues.length} month
              {issues.length > 1 ? 's' : ''} — not the same as duplicate payment rows
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => void detect()}
          className="p-2 rounded-lg bg-secondary text-secondary-foreground hover:bg-secondary/80"
          aria-label="Refresh"
        >
          <RefreshCw className="w-4 h-4" />
        </button>
      </div>

      {issues.map((issue) => (
        <div key={issue.month} className="card-section p-3 border-amber-500/40 bg-amber-500/5">
          <button
            type="button"
            className="w-full text-left"
            onClick={() => setExpandedMonth(expandedMonth === issue.month ? null : issue.month)}
          >
            <div className="flex items-start gap-2">
              <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold">
                  {fmtIsoMonthToDisplay(issue.month)} — ₹{issue.excess.toLocaleString('en-IN')} over-counted
                </p>
                <p className="text-[10px] text-muted-foreground mt-0.5">
                  Report shows ₹{issue.reportTotal.toLocaleString('en-IN')} vs ₹
                  {issue.paymentTotal.toLocaleString('en-IN')} from payments
                </p>
                <p className="text-[10px] text-muted-foreground mt-1">
                  Tap to fix — remove orphan ledger rows or align payment / ledger months
                </p>
              </div>
            </div>
          </button>

          {expandedMonth === issue.month && (
            <div className="mt-3 pt-3 border-t border-amber-500/20 space-y-3">
              {issue.unlinkedLedger.length > 0 && (
                <div>
                  <p className="text-[10px] font-semibold uppercase text-muted-foreground mb-2">
                    Extra ledger receipts (no linked payments)
                  </p>
                  {issue.unlinkedLedger.map((e) => (
                    <div
                      key={e.id}
                      className="bg-background border border-border rounded-lg p-3 flex items-center justify-between gap-2 mb-2"
                    >
                      <div className="min-w-0">
                        <p className="text-sm font-medium truncate">{e.title || 'Ledger entry'}</p>
                        <p className="text-xs font-mono">₹{e.total_amount.toLocaleString('en-IN')}</p>
                        <p className="text-[10px] text-muted-foreground">
                          {e.record_mode.replace(/_/g, ' ')} · {e.destination.replace(/_/g, ' ')} ·{' '}
                          {fmtIsoMonthToDisplay(e.entry_month || issue.month)}
                        </p>
                      </div>
                      <button
                        type="button"
                        disabled={busyId === e.id}
                        onClick={() => void handleDeleteLedger(e.id, e.total_amount, issue.month)}
                        className="p-2 rounded-lg bg-destructive/10 text-destructive hover:bg-destructive/20 shrink-0"
                        title="Delete this orphan ledger entry"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ))}
                </div>
              )}

              {issue.dateBoundary.length > 0 && (
                <div>
                  <p className="text-[10px] font-semibold uppercase text-muted-foreground mb-2">
                    Payment month ≠ ledger month
                  </p>
                  {issue.dateBoundary.map((row) => (
                    <div
                      key={row.payment.id}
                      className="bg-background border border-border rounded-lg p-3 mb-2 space-y-2"
                    >
                      <p className="text-sm">
                        Flat {row.payment.flat_number} · ₹{Number(row.payment.amount).toLocaleString('en-IN')}
                      </p>
                      <p className="text-[10px] text-muted-foreground">
                        Payment month: {fmtIsoMonthToDisplay(row.paymentMonth)} · Ledger month:{' '}
                        {fmtIsoMonthToDisplay(row.entryMonth)}
                        {row.entryTitle ? ` · ${row.entryTitle}` : ''}
                      </p>
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          disabled={busyId === row.payment.id}
                          onClick={() => void handleAlignPayment(row.payment.id, row.entryMonth)}
                          className="text-[10px] px-2 py-1.5 rounded-lg border border-border flex items-center gap-1"
                        >
                          <Calendar className="w-3 h-3" />
                          Set payment to {fmtIsoMonthToDisplay(row.entryMonth)}
                        </button>
                        <button
                          type="button"
                          disabled={busyId === row.entryId}
                          onClick={() => void handleAlignLedger(row.entryId, row.paymentMonth)}
                          className="text-[10px] px-2 py-1.5 rounded-lg border border-border flex items-center gap-1"
                        >
                          <Calendar className="w-3 h-3" />
                          Set ledger to {fmtIsoMonthToDisplay(row.paymentMonth)}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {issue.unlinkedLedger.length === 0 && issue.dateBoundary.length === 0 && (
                <p className="text-xs text-muted-foreground">
                  Over-count detected but no automatic culprit listed. Use Manual Discrepancy Tracer for this month or
                  review Finance → Receipts for duplicate bulk entries.
                </p>
              )}
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

export default FinanceLedgerOvercountPanel;
