import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { AlertTriangle, IndianRupee, RefreshCw, Trash2, Pencil, X, Check } from 'lucide-react';
import { fmtIsoMonthToDisplay, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import {
  findDuplicatePaymentGroups,
  type AuditPaymentRow,
  type DuplicatePaymentGroup,
} from '@/lib/financeAuditDetection';
import { deleteMaintenancePayment } from '@/lib/financeAuditRemediation';
import FinanceLedgerOvercountPanel from '@/components/FinanceLedgerOvercountPanel';

type PaymentRow = AuditPaymentRow & {
  transaction_id: string | null;
  notes: string | null;
};

interface EditState {
  id: string;
  amount: string;
  payment_method: string;
  payment_status: string;
  notes: string;
}

const FinanceAuditAlarms = () => {
  const [refreshKey, setRefreshKey] = useState(0);
  const societyId = useStore((s) => s.societyId);
  const [alarms, setAlarms] = useState<DuplicatePaymentGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedIdx, setExpandedIdx] = useState<number | null>(null);
  const [editState, setEditState] = useState<EditState | null>(null);

  const detect = useCallback(async () => {
    if (!societyId) {
      setAlarms([]);
      setLoading(false);
      return;
    }
    setLoading(true);

    const { data: charges } = await supabase
      .from('maintenance_charges')
      .select('id, title, frequency')
      .eq('society_id', societyId);

    if (!charges || charges.length === 0) {
      setAlarms([]);
      setLoading(false);
      return;
    }

    const monthlyCharges = charges.filter(
      (c) => (c.frequency ?? '').toLowerCase() === 'monthly',
    );
    if (monthlyCharges.length === 0) {
      setAlarms([]);
      setLoading(false);
      return;
    }

    const chargeIds = monthlyCharges.map((c) => c.id);

    const { data: payments } = await supabase
      .from('maintenance_payments')
      .select('id, charge_id, flat_number, amount, payment_method, due_date, payment_date, created_at, payment_status, transaction_id, notes, finance_entry_id')
      .in('charge_id', chargeIds)
      .in('payment_status', ['verified', 'pending']);

    if (!payments || payments.length === 0) {
      setAlarms([]);
      setLoading(false);
      return;
    }

    const chargeTitleById = new Map(monthlyCharges.map((c) => [c.id, c.title]));
    const duplicates = findDuplicatePaymentGroups(payments as PaymentRow[], chargeTitleById, {
      chargeIds,
    });

    setAlarms(duplicates);
    setLoading(false);
  }, [societyId, refreshKey]);

  useEffect(() => {
    void detect();
  }, [detect]);

  const handleDelete = async (payment: PaymentRow) => {
    const ok = await confirmAction(
      'Delete this payment entry?',
      `₹${Number(payment.amount).toLocaleString('en-IN')} for Flat ${payment.flat_number} via ${payment.payment_method}. This cannot be undone.`,
      'Delete',
      'Cancel',
    );
    if (!ok) return;

    const res = await deleteMaintenancePayment(payment.id, payment.finance_entry_id);
    if (!res.ok) {
      toast.error(res.error);
      return;
    }

    toast.success('Payment entry deleted');
    setEditState(null);
    setExpandedIdx(null);
    void detect();
  };

  const startEdit = (payment: PaymentRow) => {
    setEditState({
      id: payment.id,
      amount: String(payment.amount),
      payment_method: payment.payment_method ?? 'cash',
      payment_status: payment.payment_status,
      notes: payment.notes ?? '',
    });
  };

  const cancelEdit = () => setEditState(null);

  const saveEdit = async () => {
    if (!editState) return;
    const payload: Record<string, unknown> = {
      amount: Number(editState.amount),
      payment_method: editState.payment_method,
      payment_status: editState.payment_status,
      notes: editState.notes.trim() || null,
    };

    const { error } = await (supabase as any)
      .from('maintenance_payments')
      .update(payload)
      .eq('id', editState.id);

    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Payment entry updated');
    setEditState(null);
    void detect();
  };

  const bumpRefresh = () => setRefreshKey((k) => k + 1);

  return (
    <div className="space-y-4">
      <FinanceLedgerOvercountPanel onResolved={bumpRefresh} />

      {loading ? (
        <div className="card-section p-4">
          <p className="text-sm text-muted-foreground">Scanning for duplicate maintenance payment rows…</p>
        </div>
      ) : alarms.length === 0 ? (
        <div className="card-section p-4 border-green-500/30 bg-green-500/5">
          <div className="flex items-center gap-2">
            <IndianRupee className="w-4 h-4 text-green-600" />
            <p className="text-sm font-medium text-green-700 dark:text-green-400">
              No duplicate maintenance payment rows
            </p>
          </div>
          <p className="text-xs text-muted-foreground mt-1">
            No flat has two verified/pending payments for the same monthly charge, month, and channel. If Internal Audit
            still flags an issue, check Ledger double-count above — that is a different problem (extra finance
            ledger receipt).
          </p>
        </div>
      ) : (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-destructive/10 flex items-center justify-center">
            <AlertTriangle className="w-4 h-4 text-destructive animate-pulse" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-destructive">
              ⚠️ Duplicate Maintenance Credits Detected
            </h3>
            <p className="text-[10px] text-muted-foreground">
              {alarms.length} group{alarms.length > 1 ? 's' : ''} — same flat + charge + month + channel twice
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

      {alarms.map((alarm, idx) => (
        <div
          key={idx}
          className="card-section p-3 border-destructive/40 bg-destructive/5"
        >
          <div
            className="flex items-start gap-3 cursor-pointer"
            onClick={() => setExpandedIdx(expandedIdx === idx ? null : idx)}
          >
            <div className="w-9 h-9 rounded-full bg-destructive/10 flex items-center justify-center flex-shrink-0">
              <AlertTriangle className="w-4 h-4 text-destructive" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-foreground">
                Flat {alarm.flat_number} — credited {alarm.count}× via{' '}
                <span className="uppercase font-bold text-destructive">{alarm.payment_method}</span>
              </p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {alarm.charge_title} · {fmtIsoMonthToDisplay(alarm.month)}
              </p>
              <div className="flex items-center gap-3 mt-2">
                <span className="text-xs font-mono bg-destructive/10 text-destructive px-2 py-0.5 rounded">
                  ₹{alarm.total_amount.toLocaleString('en-IN')} total ({alarm.count} entries)
                </span>
              </div>
              <p className="text-[10px] text-muted-foreground mt-1">
                Tap to expand and edit/remove individual entries
              </p>
            </div>
          </div>

          {/* Expanded: show individual payment rows with edit/delete */}
          {expandedIdx === idx && (
            <div className="mt-3 pt-3 border-t border-destructive/20 space-y-2">
              {alarm.payments.map((p) => (
                <div
                  key={p.id}
                  className="bg-background border border-border rounded-lg p-3"
                >
                  {editState?.id === p.id ? (
                    /* Edit mode */
                    <div className="space-y-2">
                      <div className="grid grid-cols-2 gap-2">
                        <div>
                          <label className="text-[10px] font-medium text-muted-foreground uppercase">Amount (₹)</label>
                          <input
                            type="number"
                            className="input-field mt-0.5 text-sm"
                            value={editState.amount}
                            onChange={(e) => setEditState({ ...editState, amount: e.target.value })}
                          />
                        </div>
                        <div>
                          <label className="text-[10px] font-medium text-muted-foreground uppercase">Method</label>
                          <select
                            className="input-field mt-0.5 text-sm"
                            value={editState.payment_method}
                            onChange={(e) => setEditState({ ...editState, payment_method: e.target.value })}
                          >
                            <option value="cash">Cash</option>
                            <option value="upi">UPI</option>
                            <option value="bank_transfer">Bank Transfer</option>
                            <option value="cheque">Cheque</option>
                            <option value="neft">NEFT</option>
                            <option value="rtgs">RTGS</option>
                            <option value="online">Online</option>
                          </select>
                        </div>
                      </div>
                      <div>
                        <label className="text-[10px] font-medium text-muted-foreground uppercase">Status</label>
                        <select
                          className="input-field mt-0.5 text-sm"
                          value={editState.payment_status}
                          onChange={(e) => setEditState({ ...editState, payment_status: e.target.value })}
                        >
                          <option value="verified">Verified</option>
                          <option value="pending">Pending</option>
                          <option value="rejected">Rejected</option>
                        </select>
                      </div>
                      <div>
                        <label className="text-[10px] font-medium text-muted-foreground uppercase">Notes</label>
                        <input
                          className="input-field mt-0.5 text-sm"
                          value={editState.notes}
                          placeholder="Optional note"
                          onChange={(e) => setEditState({ ...editState, notes: e.target.value })}
                        />
                      </div>
                      <div className="flex gap-2 justify-end pt-1">
                        <button
                          type="button"
                          onClick={cancelEdit}
                          className="px-3 py-1.5 text-xs rounded-lg bg-secondary text-secondary-foreground flex items-center gap-1"
                        >
                          <X className="w-3 h-3" /> Cancel
                        </button>
                        <button
                          type="button"
                          onClick={() => void saveEdit()}
                          className="px-3 py-1.5 text-xs rounded-lg bg-primary text-primary-foreground flex items-center gap-1"
                        >
                          <Check className="w-3 h-3" /> Save
                        </button>
                      </div>
                    </div>
                  ) : (
                    /* View mode */
                    <div className="flex items-center justify-between">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-semibold font-mono">
                            ₹{Number(p.amount).toLocaleString('en-IN')}
                          </span>
                          <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${
                            p.payment_status === 'verified'
                              ? 'bg-green-500/10 text-green-600'
                              : p.payment_status === 'rejected'
                                ? 'bg-destructive/10 text-destructive'
                                : 'bg-amber-500/10 text-amber-600'
                          }`}>
                            {p.payment_status}
                          </span>
                          <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-muted text-muted-foreground">
                            {p.payment_method}
                          </span>
                        </div>
                        <p className="text-[10px] text-muted-foreground mt-0.5">
                          Due: {p.due_date ? fmtIsoDateToDisplay(p.due_date) : '—'} · Created: {fmtIsoDateToDisplay(p.created_at)}
                        </p>
                        {p.transaction_id && (
                          <p className="text-[10px] text-muted-foreground font-mono">
                            Txn: {p.transaction_id}
                          </p>
                        )}
                        {p.notes && (
                          <p className="text-[10px] text-muted-foreground italic mt-0.5">
                            {p.notes}
                          </p>
                        )}
                        <p className="text-[9px] text-muted-foreground/60 font-mono mt-0.5">
                          ID: {p.id.slice(0, 8)}
                        </p>
                      </div>
                      <div className="flex gap-1.5 flex-shrink-0 ml-2">
                        <button
                          type="button"
                          onClick={() => startEdit(p)}
                          className="p-2 rounded-lg bg-secondary text-secondary-foreground hover:bg-secondary/80"
                          aria-label="Edit payment"
                          title="Edit this entry"
                        >
                          <Pencil className="w-3.5 h-3.5" />
                        </button>
                        <button
                          type="button"
                          onClick={() => void handleDelete(p)}
                          className="p-2 rounded-lg bg-destructive/10 text-destructive hover:bg-destructive/20"
                          aria-label="Delete payment"
                          title="Remove this duplicate entry"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
      )}
    </div>
  );
};

export default FinanceAuditAlarms;
