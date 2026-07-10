import { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Wallet, ArrowRightLeft, AlertTriangle, PiggyBank } from 'lucide-react';
import { toast } from 'sonner';
import { DescriptiveStatSummary } from '@/components/DescriptiveStatCard';
import { HoverInfoTip } from '@/components/HoverInfoTip';
import {
  monthlyOperatingInflow,
  monthlyOperatingOutflow,
  netTransferEffectForMonth,
  reserveFundBalance,
  RESERVE_TRANSFER_LABELS,
  type ReserveTransferDirection,
  transfersForMonth,
} from '@/lib/operatingReserveFund';
import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';

type LedgerRow = {
  id: string;
  entry_month?: string | null;
  transaction_date?: string | null;
  destination?: string | null;
  total_amount?: number | null;
  title?: string | null;
  expense_id?: string | null;
};

type Props = {
  societyId: string | null;
  totalsMonth: string;
  ledgerEntries: LedgerRow[];
  societyLedgerEntries: LedgerRow[];
  payments: { amount?: number; due_date?: string; payment_status?: string; charge_id?: string }[];
  charges: { id: string; title: string; frequency?: string | null; expense_group_id?: string | null }[];
  expenseCategoryById: Map<string, string>;
  adminName?: string;
  onRefresh?: () => void;
};

const MonthlyOperatingFundPanel = ({
  societyId,
  totalsMonth,
  ledgerEntries,
  societyLedgerEntries,
  payments,
  charges,
  expenseCategoryById,
  adminName = 'Admin',
  onRefresh,
}: Props) => {
  const [transfers, setTransfers] = useState<
    { id: string; entry_month: string; amount: number; direction: ReserveTransferDirection; notes: string | null; created_at: string }[]
  >([]);
  const [loading, setLoading] = useState(false);
  const [showTransfer, setShowTransfer] = useState<'surplus' | 'draw' | null>(null);
  const [form, setForm] = useState({ amount: '', direction: 'operating_to_reserve' as ReserveTransferDirection, notes: '' });
  const [saving, setSaving] = useState(false);

  const chargeTitleById = useMemo(() => new Map(charges.map((c) => [c.id, c.title])), [charges]);

  const isOutflowEntry = useCallback(
    (e: LedgerRow) => {
      if (e.destination !== 'separate_entry') return false;
      const cat = e.expense_id ? expenseCategoryById.get(e.expense_id) : null;
      return cat !== 'food';
    },
    [expenseCategoryById],
  );

  const loadTransfers = useCallback(async () => {
    if (!societyId) {
      setTransfers([]);
      return;
    }
    setLoading(true);
    try {
      const { data } = await supabase
        .from('reserve_fund_transfers')
        .select('id, entry_month, amount, direction, notes, created_at')
        .eq('society_id', societyId)
        .order('created_at', { ascending: false })
        .limit(200);
      setTransfers((data ?? []) as typeof transfers);
    } finally {
      setLoading(false);
    }
  }, [societyId]);

  useEffect(() => {
    void loadTransfers();
  }, [loadTransfers, totalsMonth]);

  const operatingIn = useMemo(
    () => monthlyOperatingInflow(totalsMonth, payments, charges, chargeTitleById),
    [totalsMonth, payments, charges, chargeTitleById],
  );

  const operatingOut = useMemo(
    () => monthlyOperatingOutflow(totalsMonth, societyLedgerEntries, isOutflowEntry),
    [totalsMonth, societyLedgerEntries, isOutflowEntry],
  );

  const monthTransfers = useMemo(() => transfersForMonth(transfers, totalsMonth), [transfers, totalsMonth]);
  const transferNet = useMemo(() => netTransferEffectForMonth(transfers, totalsMonth), [transfers, totalsMonth]);

  const rawSurplus = operatingIn - operatingOut;
  const closingOperating = rawSurplus + transferNet;
  const reserveBalance = useMemo(
    () => reserveFundBalance(ledgerEntries, transfers),
    [ledgerEntries, transfers],
  );

  const saveTransfer = async () => {
    if (!societyId) return;
    const amount = Number(form.amount);
    if (!amount || amount <= 0) {
      toast.error('Enter a valid amount');
      return;
    }
    if (form.direction !== 'operating_to_reserve' && amount > reserveBalance) {
      toast.error('Amount exceeds reserve fund balance');
      return;
    }
    if (form.direction === 'operating_to_reserve' && amount > Math.max(0, rawSurplus)) {
      toast.error('Amount exceeds this month’s unallocated surplus');
      return;
    }
    setSaving(true);
    try {
      const { error } = await supabase.from('reserve_fund_transfers').insert({
        society_id: societyId,
        entry_month: totalsMonth,
        amount,
        direction: form.direction,
        payment_method: 'bank_transfer',
        notes: form.notes.trim() || null,
        created_by: adminName,
      });
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success(RESERVE_TRANSFER_LABELS[form.direction]);
      setShowTransfer(null);
      setForm({ amount: '', direction: 'operating_to_reserve', notes: '' });
      await loadTransfers();
      onRefresh?.();
    } finally {
      setSaving(false);
    }
  };

  if (!societyId) return null;

  return (
    <div className="card-section p-4 mb-6 space-y-4 border-primary/20 bg-primary/5">
      <div className="flex items-start gap-3">
        <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
          <Wallet className="w-4 h-4 text-primary" />
        </div>
        <div className="min-w-0">
          <HoverInfoTip
            title="Monthly operating fund & reserve"
            description="Monthly maintenance from members is a temporary fund for that month's operational expenses (unless a receipt type is linked to a specific head). Surplus can move to the reserve fund for emergencies, fixed investments, or to cover a future month's shortfall."
          >
            <p className="text-sm font-semibold">Monthly operating fund &amp; reserve</p>
          </HoverInfoTip>
        </div>
      </div>

      <DescriptiveStatSummary
        label={<>Operating month: {fmtIsoMonthToDisplay(totalsMonth)}</>}
        description={`Collections ₹${operatingIn.toLocaleString('en-IN')} · Operational expenses ₹${operatingOut.toLocaleString('en-IN')} · Reserve balance ₹${reserveBalance.toLocaleString('en-IN')}`}
        howCalculated="Operating inflow = verified monthly maintenance receipts (excludes one-time / head-linked charges). Outflow = society payment expenses for the month. Reserve = corpus receipts + surplus transfers − reserve draws."
      />

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-center">
        <div className="rounded-lg bg-background/80 p-2">
          <p className="text-[10px] text-muted-foreground uppercase">Collected</p>
          <p className="text-sm font-semibold text-green-600">₹{operatingIn.toLocaleString('en-IN')}</p>
        </div>
        <div className="rounded-lg bg-background/80 p-2">
          <p className="text-[10px] text-muted-foreground uppercase">Operational spent</p>
          <p className="text-sm font-semibold text-orange-600">₹{operatingOut.toLocaleString('en-IN')}</p>
        </div>
        <div className="rounded-lg bg-background/80 p-2">
          <p className="text-[10px] text-muted-foreground uppercase">Month balance</p>
          <p className={`text-sm font-semibold ${closingOperating >= 0 ? 'text-foreground' : 'text-destructive'}`}>
            ₹{closingOperating.toLocaleString('en-IN')}
          </p>
        </div>
        <div className="rounded-lg bg-background/80 p-2">
          <p className="text-[10px] text-muted-foreground uppercase flex items-center justify-center gap-1">
            <PiggyBank className="w-3 h-3" /> Reserve
          </p>
          <p className="text-sm font-semibold text-blue-600">₹{reserveBalance.toLocaleString('en-IN')}</p>
        </div>
      </div>

      {rawSurplus > 0 && (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className="text-xs px-3 py-1.5 rounded-lg bg-primary/10 text-primary flex items-center gap-1"
            onClick={() => {
              setShowTransfer('surplus');
              setForm({ amount: String(Math.max(0, rawSurplus + transferNet)), direction: 'operating_to_reserve', notes: '' });
            }}
          >
            <ArrowRightLeft className="w-3 h-3" /> Transfer surplus to reserve
          </button>
        </div>
      )}

      {rawSurplus + transferNet < 0 && (
        <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-2.5 flex gap-2 items-start">
          <AlertTriangle className="w-4 h-4 text-destructive shrink-0" />
          <div className="flex-1">
            <p className="text-xs font-medium text-destructive">
              Shortfall ₹{Math.abs(rawSurplus + transferNet).toLocaleString('en-IN')} — collections did not cover operational expenses
            </p>
            <p className="text-[10px] text-muted-foreground mt-0.5">
              Draw from reserve, member advance (head reconciliation), or use next month’s collections.
            </p>
          </div>
          {reserveBalance > 0 && (
            <button
              type="button"
              className="text-xs px-2 py-1 rounded-lg bg-primary/10 text-primary shrink-0"
              onClick={() => {
                setShowTransfer('draw');
                setForm({
                  amount: String(Math.min(reserveBalance, Math.abs(rawSurplus + transferNet))),
                  direction: 'reserve_to_operating',
                  notes: '',
                });
              }}
            >
              Draw reserve
            </button>
          )}
        </div>
      )}

      {showTransfer && (
        <div className="rounded-lg border border-border bg-background p-3 space-y-2">
          <p className="text-xs font-medium">
            {showTransfer === 'surplus' ? 'Transfer surplus to reserve fund' : 'Draw from reserve fund'}
          </p>
          <input
            className="input-field text-sm"
            type="number"
            placeholder="Amount (₹)"
            value={form.amount}
            onChange={(e) => setForm({ ...form, amount: e.target.value })}
          />
          {showTransfer === 'draw' && (
            <select
              className="input-field text-sm"
              value={form.direction}
              onChange={(e) => setForm({ ...form, direction: e.target.value as ReserveTransferDirection })}
            >
              <option value="reserve_to_operating">{RESERVE_TRANSFER_LABELS.reserve_to_operating}</option>
              <option value="reserve_to_fixed">{RESERVE_TRANSFER_LABELS.reserve_to_fixed}</option>
              <option value="reserve_to_emergency">{RESERVE_TRANSFER_LABELS.reserve_to_emergency}</option>
            </select>
          )}
          <input
            className="input-field text-sm"
            placeholder="Notes (optional)"
            value={form.notes}
            onChange={(e) => setForm({ ...form, notes: e.target.value })}
          />
          <div className="flex gap-2">
            <button type="button" className="btn-primary text-sm flex-1" disabled={saving} onClick={() => void saveTransfer()}>
              {saving ? 'Saving…' : 'Confirm'}
            </button>
            <button type="button" className="btn-secondary text-sm flex-1" onClick={() => setShowTransfer(null)}>
              Cancel
            </button>
          </div>
        </div>
      )}

      {monthTransfers.length > 0 && (
        <div>
          <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1">Movements this month</p>
          <div className="space-y-1">
            {monthTransfers.map((t) => (
              <div key={t.id} className="text-xs bg-background/60 rounded p-2 flex justify-between gap-2">
                <span>{RESERVE_TRANSFER_LABELS[t.direction]}</span>
                <span className="font-semibold shrink-0">₹{Number(t.amount).toLocaleString('en-IN')}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {loading && <p className="text-[10px] text-muted-foreground text-center">Updating…</p>}
    </div>
  );
};

export default MonthlyOperatingFundPanel;
