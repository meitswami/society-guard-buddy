import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { AlertTriangle, IndianRupee, RefreshCw, Trash2, Pencil, X, Check, Search } from 'lucide-react';
import { fmtIsoMonthToDisplay, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import {
  findDuplicatePaymentGroups,
  findReceiptHeadLookupGroups,
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

type ChargeOption = { id: string; title: string };

const PaymentEntryRow = ({
  p,
  editState,
  onStartEdit,
  onCancelEdit,
  onSaveEdit,
  onEditChange,
  onDelete,
}: {
  p: PaymentRow;
  editState: EditState | null;
  onStartEdit: (p: PaymentRow) => void;
  onCancelEdit: () => void;
  onSaveEdit: () => void;
  onEditChange: (next: EditState) => void;
  onDelete: (p: PaymentRow) => void;
}) => (
  <div className="bg-background border border-border rounded-lg p-3">
    {editState?.id === p.id ? (
      <div className="space-y-2">
        <div className="grid grid-cols-2 gap-2">
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase">Amount (₹)</label>
            <input
              type="number"
              className="input-field mt-0.5 text-sm"
              value={editState.amount}
              onChange={(e) => onEditChange({ ...editState, amount: e.target.value })}
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase">Method</label>
            <select
              className="input-field mt-0.5 text-sm"
              value={editState.payment_method}
              onChange={(e) => onEditChange({ ...editState, payment_method: e.target.value })}
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
            onChange={(e) => onEditChange({ ...editState, payment_status: e.target.value })}
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
            onChange={(e) => onEditChange({ ...editState, notes: e.target.value })}
          />
        </div>
        <div className="flex gap-2 justify-end pt-1">
          <button
            type="button"
            onClick={onCancelEdit}
            className="px-3 py-1.5 text-xs rounded-lg bg-secondary text-secondary-foreground flex items-center gap-1"
          >
            <X className="w-3 h-3" /> Cancel
          </button>
          <button
            type="button"
            onClick={() => void onSaveEdit()}
            className="px-3 py-1.5 text-xs rounded-lg bg-primary text-primary-foreground flex items-center gap-1"
          >
            <Check className="w-3 h-3" /> Save
          </button>
        </div>
      </div>
    ) : (
      <div className="flex items-center justify-between">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold font-mono">
              ₹{Number(p.amount).toLocaleString('en-IN')}
            </span>
            <span
              className={`text-[10px] px-1.5 py-0.5 rounded-full font-medium ${
                p.payment_status === 'verified'
                  ? 'bg-green-500/10 text-green-600'
                  : p.payment_status === 'rejected'
                    ? 'bg-destructive/10 text-destructive'
                    : 'bg-amber-500/10 text-amber-600'
              }`}
            >
              {p.payment_status}
            </span>
            <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-muted text-muted-foreground">
              {p.payment_method}
            </span>
          </div>
          <p className="text-[10px] text-muted-foreground mt-0.5">
            Due: {p.due_date ? fmtIsoDateToDisplay(p.due_date) : '—'} · Created:{' '}
            {fmtIsoDateToDisplay(p.created_at)}
          </p>
          {p.transaction_id && (
            <p className="text-[10px] text-muted-foreground font-mono">Txn: {p.transaction_id}</p>
          )}
          {p.notes && <p className="text-[10px] text-muted-foreground italic mt-0.5">{p.notes}</p>}
          <p className="text-[9px] text-muted-foreground/60 font-mono mt-0.5">ID: {p.id.slice(0, 8)}</p>
        </div>
        <div className="flex gap-1.5 flex-shrink-0 ml-2">
          <button
            type="button"
            onClick={() => onStartEdit(p)}
            className="p-2 rounded-lg bg-secondary text-secondary-foreground hover:bg-secondary/80"
            aria-label="Edit payment"
            title="Edit this entry"
          >
            <Pencil className="w-3.5 h-3.5" />
          </button>
          <button
            type="button"
            onClick={() => void onDelete(p)}
            className="p-2 rounded-lg bg-destructive/10 text-destructive hover:bg-destructive/20"
            aria-label="Delete payment"
            title="Delete this entry"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    )}
  </div>
);

const ReceiptHeadGroupCard = ({
  alarm,
  expanded,
  onToggle,
  editState,
  onStartEdit,
  onCancelEdit,
  onSaveEdit,
  onEditChange,
  onDelete,
}: {
  alarm: DuplicatePaymentGroup;
  expanded: boolean;
  onToggle: () => void;
  editState: EditState | null;
  onStartEdit: (p: PaymentRow) => void;
  onCancelEdit: () => void;
  onSaveEdit: () => void;
  onEditChange: (next: EditState) => void;
  onDelete: (p: PaymentRow) => void;
}) => (
  <div className="card-section p-3 border-destructive/40 bg-destructive/5">
    <div className="flex items-start gap-3 cursor-pointer" onClick={onToggle}>
      <div className="w-9 h-9 rounded-full bg-destructive/10 flex items-center justify-center flex-shrink-0">
        <AlertTriangle className="w-4 h-4 text-destructive" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-foreground">
          Flat {alarm.flat_number} — {alarm.count > 1 ? `credited ${alarm.count}×` : 'already recorded'} via{' '}
          <span className="uppercase font-bold text-destructive">{alarm.payment_method}</span>
        </p>
        <p className="text-xs text-muted-foreground mt-0.5">
          {alarm.charge_title} · {fmtIsoMonthToDisplay(alarm.month)}
        </p>
        <div className="flex items-center gap-3 mt-2">
          <span className="text-xs font-mono bg-destructive/10 text-destructive px-2 py-0.5 rounded">
            ₹{alarm.total_amount.toLocaleString('en-IN')} total ({alarm.count} entr{alarm.count > 1 ? 'ies' : 'y'})
          </span>
        </div>
        <p className="text-[10px] text-muted-foreground mt-1">Tap to expand — edit or delete individual entries</p>
      </div>
    </div>

    {expanded && (
      <div className="mt-3 pt-3 border-t border-destructive/20 space-y-2">
        {alarm.payments.map((p) => (
          <PaymentEntryRow
            key={p.id}
            p={p as PaymentRow}
            editState={editState}
            onStartEdit={onStartEdit}
            onCancelEdit={onCancelEdit}
            onSaveEdit={onSaveEdit}
            onEditChange={onEditChange}
            onDelete={onDelete}
          />
        ))}
      </div>
    )}
  </div>
);

const FinanceAuditAlarms = () => {
  const [refreshKey, setRefreshKey] = useState(0);
  const societyId = useStore((s) => s.societyId);
  const [alarms, setAlarms] = useState<DuplicatePaymentGroup[]>([]);
  const [allPayments, setAllPayments] = useState<PaymentRow[]>([]);
  const [chargeOptions, setChargeOptions] = useState<ChargeOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedIdx, setExpandedIdx] = useState<number | null>(null);
  const [lookupExpandedIdx, setLookupExpandedIdx] = useState<number | null>(null);
  const [editState, setEditState] = useState<EditState | null>(null);
  const [lookupFlat, setLookupFlat] = useState('');
  const [lookupChargeId, setLookupChargeId] = useState('');
  const [lookupMonth, setLookupMonth] = useState('');
  const [lookupResults, setLookupResults] = useState<DuplicatePaymentGroup[]>([]);
  const [lookupSearched, setLookupSearched] = useState(false);

  const chargeTitleById = useMemo(
    () => new Map(chargeOptions.map((c) => [c.id, c.title])),
    [chargeOptions],
  );

  const detect = useCallback(async () => {
    if (!societyId) {
      setAlarms([]);
      setAllPayments([]);
      setChargeOptions([]);
      setLoading(false);
      return;
    }
    setLoading(true);

    const { data: charges } = await supabase
      .from('maintenance_charges')
      .select('id, title')
      .eq('society_id', societyId)
      .order('title');

    if (!charges || charges.length === 0) {
      setAlarms([]);
      setAllPayments([]);
      setChargeOptions([]);
      setLoading(false);
      return;
    }

    setChargeOptions(charges as ChargeOption[]);
    const chargeIds = charges.map((c) => c.id);

    const { data: payments } = await supabase
      .from('maintenance_payments')
      .select(
        'id, charge_id, flat_number, amount, payment_method, due_date, payment_date, created_at, payment_status, transaction_id, notes, finance_entry_id',
      )
      .in('charge_id', chargeIds)
      .in('payment_status', ['verified', 'pending']);

    const rows = (payments ?? []) as PaymentRow[];
    setAllPayments(rows);

    const titleMap = new Map(charges.map((c) => [c.id, c.title]));
    const duplicates = findDuplicatePaymentGroups(rows, titleMap, { chargeIds });
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
    setLookupExpandedIdx(null);
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

  const runLookup = () => {
    if (!lookupFlat.trim() && !lookupChargeId && !lookupMonth.trim()) {
      toast.error('Enter at least one filter — flat, receipt head, or month (YYYY-MM)');
      return;
    }
    const results = findReceiptHeadLookupGroups(allPayments, chargeTitleById, {
      flat_number: lookupFlat.trim() || undefined,
      charge_id: lookupChargeId || undefined,
      month: lookupMonth.trim() || undefined,
    });
    setLookupResults(results);
    setLookupSearched(true);
    setLookupExpandedIdx(null);
    setEditState(null);
  };

  const bumpRefresh = () => setRefreshKey((k) => k + 1);

  const rowHandlers = {
    editState,
    onStartEdit: startEdit,
    onCancelEdit: cancelEdit,
    onSaveEdit: saveEdit,
    onEditChange: setEditState,
    onDelete: handleDelete,
  };

  return (
    <div className="space-y-4">
      <FinanceLedgerOvercountPanel onResolved={bumpRefresh} />

      <div className="card-section p-4 space-y-3">
        <div className="flex items-center gap-2">
          <Search className="w-4 h-4 text-primary" />
          <div>
            <h3 className="text-sm font-semibold">Find recorded receipt head</h3>
            <p className="text-[10px] text-muted-foreground">
              When Finance blocks a duplicate, look up the existing entry here to edit or delete it.
            </p>
          </div>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
          <input
            className="input-field text-sm"
            placeholder="Flat (e.g. A-101)"
            value={lookupFlat}
            onChange={(e) => setLookupFlat(e.target.value)}
          />
          <select
            className="input-field text-sm"
            value={lookupChargeId}
            onChange={(e) => setLookupChargeId(e.target.value)}
          >
            <option value="">All receipt heads</option>
            {chargeOptions.map((c) => (
              <option key={c.id} value={c.id}>
                {c.title}
              </option>
            ))}
          </select>
          <input
            className="input-field text-sm font-mono"
            placeholder="Month (YYYY-MM)"
            value={lookupMonth}
            onChange={(e) => setLookupMonth(e.target.value)}
          />
        </div>
        <button type="button" onClick={runLookup} className="btn-primary text-sm w-full sm:w-auto">
          Search recorded entries
        </button>

        {lookupSearched && lookupResults.length === 0 && (
          <p className="text-xs text-muted-foreground">No matching receipt-head entries found.</p>
        )}

        {lookupResults.length > 0 && (
          <div className="space-y-2 pt-1">
            {lookupResults.map((group, idx) => (
              <ReceiptHeadGroupCard
                key={`lookup-${group.flat_number}-${group.charge_id}-${group.month}-${group.payment_method}`}
                alarm={group}
                expanded={lookupExpandedIdx === idx}
                onToggle={() => setLookupExpandedIdx(lookupExpandedIdx === idx ? null : idx)}
                {...rowHandlers}
              />
            ))}
          </div>
        )}
      </div>

      {loading ? (
        <div className="card-section p-4">
          <p className="text-sm text-muted-foreground">Scanning for duplicate receipt-head entries…</p>
        </div>
      ) : alarms.length === 0 ? (
        <div className="card-section p-4 border-green-500/30 bg-green-500/5">
          <div className="flex items-center gap-2">
            <IndianRupee className="w-4 h-4 text-green-600" />
            <p className="text-sm font-medium text-green-700 dark:text-green-400">
              No duplicate receipt-head entries
            </p>
          </div>
          <p className="text-xs text-muted-foreground mt-1">
            No flat has two verified/pending payments for the same receipt head, month, and channel. Finance → Record
            receipt blocks a second entry automatically. Use the search above to edit or delete an existing entry.
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
                <h3 className="text-sm font-semibold text-destructive">Duplicate receipt heads detected</h3>
                <p className="text-[10px] text-muted-foreground">
                  {alarms.length} group{alarms.length > 1 ? 's' : ''} — same flat + receipt head + month + channel twice
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
            <ReceiptHeadGroupCard
              key={`dupe-${alarm.flat_number}-${alarm.charge_id}-${alarm.month}-${alarm.payment_method}`}
              alarm={alarm}
              expanded={expandedIdx === idx}
              onToggle={() => setExpandedIdx(expandedIdx === idx ? null : idx)}
              {...rowHandlers}
            />
          ))}
        </div>
      )}
    </div>
  );
};

export default FinanceAuditAlarms;
