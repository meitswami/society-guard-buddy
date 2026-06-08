import { useEffect, useMemo, useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Receipt, TrendingDown, TrendingUp, Paperclip, Scale, Pencil, AlertTriangle, Plus, ArrowRightLeft } from 'lucide-react';
import { toast } from 'sonner';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { DescriptiveStatSummary } from '@/components/DescriptiveStatCard';
import CashBankBreakdown, { ChannelBadge } from '@/components/CashBankBreakdown';
import EventContributionEditModal from '@/components/EventContributionEditModal';
import FoodExpenseEditModal from '@/components/FoodExpenseEditModal';
import { sumByChannel, netChannels, addToChannel, type ChannelTotals } from '@/lib/cashBankChannel';
import {
  eventFoodBalance,
  EVENT_FOOD_ADJUST_KIND_LABELS,
  EVENT_FOOD_SHORTFALL_SOURCE_LABELS,
  type EventFoodAdjustmentRow,
  type EventFoodAdjustKind,
  type EventFoodAdjustSource,
} from '@/lib/eventFoodFundAdjustments';

const UNLINKED_EVENT_KEY = '__unlinked__';

type EventRow = { id: string; title: string; event_date: string; contribution_amount: number };
type ContribRow = {
  id: string;
  event_id: string;
  flat_number: string | null;
  resident_name: string | null;
  amount: number;
  payment_method: string;
  screenshot_url: string | null;
  verified_at: string | null;
  contributor_type?: string | null;
  outsider_name?: string | null;
  adult_count?: number | null;
  kid_count?: number | null;
  split_mode?: string | null;
  receipt_basis?: string | null;
  batch_label?: string | null;
};

function contribReceiptLabel(c: ContribRow): string {
  if (c.receipt_basis === 'non_flat' || !c.flat_number) {
    return `No flat · ${c.batch_label || c.outsider_name || c.resident_name || 'Receipt'}`;
  }
  const parts = [`Flat ${c.flat_number}`];
  if (c.resident_name) parts.push(c.resident_name);
  if (c.adult_count != null || c.kid_count != null) {
    parts.push(`${c.adult_count ?? 0}A/${c.kid_count ?? 0}K`);
  }
  if (c.split_mode === 'headcount') parts.push('headcount');
  if (c.split_mode === 'lump_equal') parts.push('lump ÷');
  if (c.split_mode === 'individual') parts.push('individual');
  return parts.join(' · ');
}
type FoodExpenseRow = {
  id: string;
  title: string;
  total_amount: number;
  expense_date: string;
  payment_method: string;
  bill_screenshot_url: string | null;
  attachment_urls: string[] | null;
  group_id: string;
  group_name: string;
  event_id: string | null;
};

interface Props {
  adminName?: string;
  /** Increment to reload after new receipts are recorded below. */
  refreshKey?: number;
  /** Called after edit/delete so parent sections can refresh. */
  onRecordsChanged?: () => void;
}

const EventFoodReconciliation = ({ adminName = 'Admin', refreshKey = 0, onRecordsChanged }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [events, setEvents] = useState<EventRow[]>([]);
  const [contributions, setContributions] = useState<ContribRow[]>([]);
  const [foodExpenses, setFoodExpenses] = useState<FoodExpenseRow[]>([]);
  const [adjustments, setAdjustments] = useState<EventFoodAdjustmentRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [editingContribId, setEditingContribId] = useState<string | null>(null);
  const [editingExpenseId, setEditingExpenseId] = useState<string | null>(null);
  const [adjustTarget, setAdjustTarget] = useState<{ eventKey: string; kind: EventFoodAdjustKind } | null>(null);
  const [adjForm, setAdjForm] = useState({
    amount: '',
    source_type: 'maintenance_pool' as EventFoodAdjustSource,
    flat_number: '',
    payment_method: 'cash',
    notes: '',
  });
  const [savingAdj, setSavingAdj] = useState(false);

  const loadAll = useCallback(async () => {
    if (!societyId) {
      setEvents([]);
      setContributions([]);
      setFoodExpenses([]);
      return;
    }
    setLoading(true);
    try {
      const { data: evRows } = await supabase
        .from('events')
        .select('id, title, event_date, contribution_amount')
        .eq('society_id', societyId)
        .order('event_date', { ascending: false })
        .limit(120);
      setEvents((evRows ?? []) as EventRow[]);
      const eventIds = (evRows ?? []).map((e) => e.id);

      const { data: allGroups } = await supabase
        .from('expense_groups')
        .select('id, name, event_id, group_kind')
        .eq('society_id', societyId);

      const groups = (allGroups ?? []) as { id: string; name: string; event_id: string | null; group_kind: string | null }[];
      const groupById = new Map(groups.map((g) => [g.id, g]));
      const groupIds = groups.map((g) => g.id);

      const [contribRes, expRes] = await Promise.all([
        eventIds.length
          ? supabase.from('event_contributions').select('*').in('event_id', eventIds).order('verified_at', { ascending: false })
          : Promise.resolve({ data: [] as ContribRow[] }),
        groupIds.length
          ? supabase
              .from('expenses')
              .select(
                'id, title, total_amount, expense_date, payment_method, bill_screenshot_url, attachment_urls, group_id',
              )
              .in('group_id', groupIds)
              .eq('expense_category', 'food')
              .eq('record_status', 'active')
              .order('expense_date', { ascending: false })
          : Promise.resolve({ data: [] as Omit<FoodExpenseRow, 'group_name' | 'event_id'>[] }),
      ]);

      setContributions((contribRes.data ?? []) as ContribRow[]);

      const { data: adjRows } = await supabase
        .from('event_food_fund_adjustments')
        .select('*')
        .eq('society_id', societyId)
        .order('created_at', { ascending: false });
      setAdjustments((adjRows ?? []) as EventFoodAdjustmentRow[]);

      setFoodExpenses(
        (expRes.data ?? []).map((ex) => {
          const g = groupById.get(ex.group_id as string);
          const attachment_urls = Array.isArray(ex.attachment_urls)
            ? (ex.attachment_urls as unknown[]).filter((u): u is string => typeof u === 'string')
            : null;
          return {
            ...(ex as Omit<FoodExpenseRow, 'group_name' | 'event_id'>),
            group_name: g?.name ?? 'Food group',
            event_id: g?.event_id ?? null,
            bill_screenshot_url: ex.bill_screenshot_url || null,
            attachment_urls,
          };
        }),
      );
    } finally {
      setLoading(false);
    }
  }, [societyId]);

  useEffect(() => {
    void loadAll();
  }, [loadAll, refreshKey]);

  const totals = useMemo(() => {
    const contribIn = contributions.reduce((s, c) => s + Number(c.amount || 0), 0);
    const foodOut = foodExpenses.reduce((s, e) => s + Number(e.total_amount || 0), 0);
    const shortfallCovers = adjustments
      .filter((a) => a.adjustment_kind === 'shortfall_cover')
      .reduce((s, a) => s + Number(a.amount || 0), 0);
    const surplusTransfers = adjustments
      .filter((a) => a.adjustment_kind === 'surplus_to_pool')
      .reduce((s, a) => s + Number(a.amount || 0), 0);
    const receiptChannels = sumByChannel(contributions, (c) => Number(c.amount || 0), (c) => c.payment_method);
    const paymentChannels = sumByChannel(foodExpenses, (e) => Number(e.total_amount || 0), (e) => e.payment_method);
    const balance = eventFoodBalance({ contribIn, foodOut, shortfallCovers, surplusTransfers });
    return {
      contribIn,
      foodOut,
      net: balance.rawNet,
      ...balance,
      receiptChannels,
      paymentChannels,
      netChannels: netChannels(receiptChannels, paymentChannels),
    };
  }, [contributions, foodExpenses, adjustments]);

  const eventRows = useMemo(() => {
    const adjForKey = (eventKey: string) => {
      const eventId = eventKey === UNLINKED_EVENT_KEY ? null : eventKey;
      return adjustments.filter((a) => (a.event_id ?? null) === eventId);
    };
    const byEvent = new Map<
      string,
      {
        event: EventRow;
        contribIn: number;
        foodOut: number;
        contribs: ContribRow[];
        expenses: FoodExpenseRow[];
        receiptChannels: ChannelTotals;
        paymentChannels: ChannelTotals;
        eventAdjustments: EventFoodAdjustmentRow[];
        shortfallCovers: number;
        surplusTransfers: number;
        remainingShortfall: number;
        remainingSurplus: number;
        adjustedNet: number;
      }
    >();

    for (const ev of events) {
      byEvent.set(ev.id, {
        event: ev,
        contribIn: 0,
        foodOut: 0,
        contribs: [],
        expenses: [],
        receiptChannels: { cash: 0, bank: 0, other: 0 },
        paymentChannels: { cash: 0, bank: 0, other: 0 },
        eventAdjustments: [],
        shortfallCovers: 0,
        surplusTransfers: 0,
        remainingShortfall: 0,
        remainingSurplus: 0,
        adjustedNet: 0,
      });
    }

    const unlinkedKey = UNLINKED_EVENT_KEY;
    const unlinked = {
      event: { id: unlinkedKey, title: 'Food not linked to an event', event_date: '', contribution_amount: 0 },
      contribIn: 0,
      foodOut: 0,
      contribs: [] as ContribRow[],
      expenses: [] as FoodExpenseRow[],
      receiptChannels: { cash: 0, bank: 0, other: 0 } as ChannelTotals,
      paymentChannels: { cash: 0, bank: 0, other: 0 } as ChannelTotals,
      eventAdjustments: [] as EventFoodAdjustmentRow[],
      shortfallCovers: 0,
      surplusTransfers: 0,
      remainingShortfall: 0,
      remainingSurplus: 0,
      adjustedNet: 0,
    };

    for (const c of contributions) {
      const row = byEvent.get(c.event_id);
      if (!row) continue;
      row.contribIn += Number(c.amount || 0);
      row.contribs.push(c);
      addToChannel(row.receiptChannels, c.payment_method, Number(c.amount || 0));
    }

    for (const ex of foodExpenses) {
      if (ex.event_id && byEvent.has(ex.event_id)) {
        const row = byEvent.get(ex.event_id)!;
        row.foodOut += Number(ex.total_amount || 0);
        row.expenses.push(ex);
        addToChannel(row.paymentChannels, ex.payment_method, Number(ex.total_amount || 0));
      } else {
        unlinked.foodOut += Number(ex.total_amount || 0);
        unlinked.expenses.push(ex);
        addToChannel(unlinked.paymentChannels, ex.payment_method, Number(ex.total_amount || 0));
      }
    }

    for (const row of [...byEvent.values(), unlinked]) {
      const key = row.event.id;
      const eventAdjustments = adjForKey(key);
      const shortfallCovers = eventAdjustments
        .filter((a) => a.adjustment_kind === 'shortfall_cover')
        .reduce((s, a) => s + Number(a.amount || 0), 0);
      const surplusTransfers = eventAdjustments
        .filter((a) => a.adjustment_kind === 'surplus_to_pool')
        .reduce((s, a) => s + Number(a.amount || 0), 0);
      const bal = eventFoodBalance({
        contribIn: row.contribIn,
        foodOut: row.foodOut,
        shortfallCovers,
        surplusTransfers,
      });
      row.eventAdjustments = eventAdjustments;
      row.shortfallCovers = shortfallCovers;
      row.surplusTransfers = surplusTransfers;
      row.remainingShortfall = bal.remainingShortfall;
      row.remainingSurplus = bal.remainingSurplus;
      row.adjustedNet = bal.adjustedNet;
    }

    const rows = [...byEvent.values()].filter(
      (r) =>
        r.contribIn > 0 ||
        r.foodOut > 0 ||
        r.contribs.length > 0 ||
        r.expenses.length > 0 ||
        r.eventAdjustments.length > 0,
    );
    if (unlinked.foodOut > 0 || unlinked.expenses.length) rows.push(unlinked);
    rows.sort((a, b) => (b.event.event_date || '').localeCompare(a.event.event_date || ''));
    return rows;
  }, [events, contributions, foodExpenses, adjustments]);

  const recordAdjustment = async (eventKey: string, kind: EventFoodAdjustKind) => {
    if (!societyId) return;
    const amount = Number(adjForm.amount);
    if (!amount || amount <= 0) {
      toast.error('Enter adjustment amount');
      return;
    }
    if (kind === 'shortfall_cover' && adjForm.source_type === 'member_advance' && !adjForm.flat_number.trim()) {
      toast.error('Enter flat number for member advance');
      return;
    }
    setSavingAdj(true);
    try {
      const flat =
        adjForm.source_type === 'member_advance' && adjForm.flat_number.trim()
          ? await supabase
              .from('flats')
              .select('id')
              .eq('society_id', societyId)
              .eq('flat_number', adjForm.flat_number.trim())
              .maybeSingle()
          : { data: null };

      const eventId = eventKey === UNLINKED_EVENT_KEY ? null : eventKey;
      const { error } = await supabase.from('event_food_fund_adjustments').insert({
        society_id: societyId,
        event_id: eventId,
        adjustment_kind: kind,
        amount,
        source_type: kind === 'surplus_to_pool' ? 'society_pool' : adjForm.source_type,
        flat_number: adjForm.flat_number.trim() || null,
        flat_id: flat.data?.id ?? null,
        payment_method: adjForm.payment_method,
        notes: adjForm.notes.trim() || null,
        created_by: adminName,
      });
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success(
        kind === 'surplus_to_pool'
          ? 'Surplus recorded — transferred to society pool'
          : 'Shortfall adjustment recorded',
      );
      setAdjustTarget(null);
      setAdjForm({ amount: '', source_type: 'maintenance_pool', flat_number: '', payment_method: 'cash', notes: '' });
      handleSaved();
    } finally {
      setSavingAdj(false);
    }
  };

  const openAdjust = (eventKey: string, kind: EventFoodAdjustKind, suggested: number) => {
    setAdjustTarget({ eventKey, kind });
    setAdjForm({
      amount: suggested > 0 ? String(suggested) : '',
      source_type: kind === 'surplus_to_pool' ? 'society_pool' : 'maintenance_pool',
      flat_number: '',
      payment_method: 'cash',
      notes: '',
    });
  };

  const handleSaved = () => {
    void loadAll();
    onRecordsChanged?.();
  };

  const receiptLinks = (ex: FoodExpenseRow) => {
    const urls: { label: string; url: string }[] = [];
    if (ex.bill_screenshot_url) urls.push({ label: 'Bill / receipt', url: ex.bill_screenshot_url });
    for (const u of ex.attachment_urls ?? []) {
      if (u && !urls.some((x) => x.url === u)) {
        const name = decodeURIComponent(u.split('/').pop() || 'Attachment').replace(/^[a-f0-9-]+_/, '');
        urls.push({ label: name, url: u });
      }
    }
    return urls;
  };

  if (loading) {
    return <p className="text-xs text-muted-foreground text-center py-4">Loading event receipts…</p>;
  }

  return (
    <div className="space-y-4">
      <DescriptiveStatSummary
        label={
          <>
            Contributions ₹{totals.contribIn.toLocaleString('en-IN')} · Food bills ₹{totals.foodOut.toLocaleString('en-IN')} ·
            Raw net ₹{totals.net.toLocaleString('en-IN')}
            {(totals.shortfallCovers > 0 || totals.surplusTransfers > 0) && (
              <> · Adjusted net ₹{totals.adjustedNet.toLocaleString('en-IN')}</>
            )}
          </>
        }
        description="Cover a shortfall from maintenance pool, corpus, or member advance. Transfer excess contributions to the society pool account."
        howCalculated="Raw net = contributions − food bills. Adjusted net includes shortfall covers (+) and surplus pool transfers (−)."
      />

      {(totals.remainingShortfall > 0 || totals.remainingSurplus > 0) && (
        <div className="card-section p-3 space-y-2 border-primary/20">
          <p className="text-xs font-medium">Society-wide balance (all events)</p>
          {totals.remainingShortfall > 0 && (
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-destructive/30 bg-destructive/5 p-2">
              <p className="text-xs text-destructive font-medium">
                Shortfall ₹{totals.remainingShortfall.toLocaleString('en-IN')} — food bills exceed contributions (after adjustments)
              </p>
            </div>
          )}
          {totals.remainingSurplus > 0 && (
            <div className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-emerald-500/30 bg-emerald-500/5 p-2">
              <p className="text-xs text-emerald-800 dark:text-emerald-300 font-medium flex items-center gap-1">
                <ArrowRightLeft className="w-3.5 h-3.5" />
                Excess ₹{totals.remainingSurplus.toLocaleString('en-IN')} — available to transfer to society pool
              </p>
            </div>
          )}
          {totals.shortfallCovers > 0 && (
            <p className="text-[10px] text-blue-600">Shortfall covered so far: ₹{totals.shortfallCovers.toLocaleString('en-IN')}</p>
          )}
          {totals.surplusTransfers > 0 && (
            <p className="text-[10px] text-muted-foreground">
              Transferred to pool so far: ₹{totals.surplusTransfers.toLocaleString('en-IN')}
            </p>
          )}
        </div>
      )}

      <CashBankBreakdown
        className="mb-2"
        receipts={totals.receiptChannels}
        payments={totals.paymentChannels}
        receiptLabel="Contribution receipts"
        paymentLabel="Food bills"
      />

      {eventRows.length === 0 ? (
        <div className="card-section p-6 text-center">
          <Scale className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
          <p className="text-sm text-muted-foreground">No event receipts recorded yet.</p>
          <p className="text-xs text-muted-foreground mt-1">
            Use <span className="font-medium text-foreground">Record contribution receipt</span> on an event above, or add a food bill with attachment in Food expenses above.
          </p>
        </div>
      ) : (
        eventRows.map(
          ({
            event,
            contribIn,
            foodOut,
            contribs,
            expenses,
            receiptChannels,
            paymentChannels,
            eventAdjustments,
            shortfallCovers,
            surplusTransfers,
            remainingShortfall,
            remainingSurplus,
            adjustedNet,
          }) => {
          const rawNet = contribIn - foodOut;
          return (
            <div key={event.id} className="card-section p-4 space-y-3">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="font-semibold text-sm">{event.title}</p>
                  {event.event_date && (
                    <p className="text-[10px] text-muted-foreground">{fmtIsoDateToDisplay(event.event_date)}</p>
                  )}
                </div>
                <div className="text-right text-xs space-y-0.5">
                  <p className="text-green-600 flex items-center justify-end gap-1">
                    <TrendingUp className="w-3 h-3" /> ₹{contribIn.toLocaleString('en-IN')} in
                  </p>
                  <p className="text-orange-600 flex items-center justify-end gap-1">
                    <TrendingDown className="w-3 h-3" /> ₹{foodOut.toLocaleString('en-IN')} out
                  </p>
                  {shortfallCovers > 0 && (
                    <p className="text-blue-600 flex items-center justify-end gap-1">
                      <Plus className="w-3 h-3" /> ₹{shortfallCovers.toLocaleString('en-IN')} covered
                    </p>
                  )}
                  {surplusTransfers > 0 && (
                    <p className="text-muted-foreground flex items-center justify-end gap-1">
                      <ArrowRightLeft className="w-3 h-3" /> ₹{surplusTransfers.toLocaleString('en-IN')} to pool
                    </p>
                  )}
                  <p className={`font-semibold ${rawNet >= 0 ? 'text-foreground' : 'text-destructive'}`}>
                    Raw net ₹{rawNet.toLocaleString('en-IN')}
                  </p>
                  {(shortfallCovers > 0 || surplusTransfers > 0) && (
                    <p className={`text-[10px] font-semibold ${adjustedNet >= 0 ? 'text-primary' : 'text-destructive'}`}>
                      Adjusted net ₹{adjustedNet.toLocaleString('en-IN')}
                    </p>
                  )}
                </div>
              </div>

              {remainingShortfall > 0 && (
                <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-2.5 flex gap-2 items-start">
                  <AlertTriangle className="w-4 h-4 text-destructive shrink-0 mt-0.5" />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium text-destructive">
                      Short of funds: ₹{remainingShortfall.toLocaleString('en-IN')}
                    </p>
                    <p className="text-[10px] text-muted-foreground mt-0.5">
                      Draw from society pool, maintenance collections, corpus, or record a member advance.
                    </p>
                  </div>
                  <button
                    type="button"
                    className="text-xs px-2 py-1 rounded-lg bg-primary/10 text-primary shrink-0"
                    onClick={() => openAdjust(event.id, 'shortfall_cover', remainingShortfall)}
                  >
                    Cover
                  </button>
                </div>
              )}

              {remainingSurplus > 0 && (
                <div className="rounded-lg border border-emerald-500/30 bg-emerald-500/5 p-2.5 flex gap-2 items-start">
                  <ArrowRightLeft className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium text-emerald-800 dark:text-emerald-300">
                      Excess: ₹{remainingSurplus.toLocaleString('en-IN')}
                    </p>
                    <p className="text-[10px] text-muted-foreground mt-0.5">
                      Transfer unspent contribution surplus to the society pool account (Finance → society pool).
                    </p>
                  </div>
                  <button
                    type="button"
                    className="text-xs px-2 py-1 rounded-lg bg-primary/10 text-primary shrink-0"
                    onClick={() => openAdjust(event.id, 'surplus_to_pool', remainingSurplus)}
                  >
                    To pool
                  </button>
                </div>
              )}

              {adjustTarget?.eventKey === event.id && (
                <div className="rounded-lg border border-border bg-muted/20 p-3 space-y-2">
                  <p className="text-xs font-medium">
                    {EVENT_FOOD_ADJUST_KIND_LABELS[adjustTarget.kind]}
                  </p>
                  <input
                    className="input-field text-sm"
                    type="number"
                    placeholder="Amount (₹)"
                    value={adjForm.amount}
                    onChange={(e) => setAdjForm({ ...adjForm, amount: e.target.value })}
                  />
                  {adjustTarget.kind === 'shortfall_cover' ? (
                    <>
                      <select
                        className="input-field text-sm"
                        value={adjForm.source_type}
                        onChange={(e) =>
                          setAdjForm({ ...adjForm, source_type: e.target.value as EventFoodAdjustSource })
                        }
                      >
                        {(Object.keys(EVENT_FOOD_SHORTFALL_SOURCE_LABELS) as EventFoodAdjustSource[]).map((k) => (
                          <option key={k} value={k}>
                            {EVENT_FOOD_SHORTFALL_SOURCE_LABELS[k]}
                          </option>
                        ))}
                      </select>
                      {adjForm.source_type === 'member_advance' && (
                        <input
                          className="input-field text-sm"
                          placeholder="Flat number"
                          value={adjForm.flat_number}
                          onChange={(e) => setAdjForm({ ...adjForm, flat_number: e.target.value })}
                        />
                      )}
                    </>
                  ) : (
                    <p className="text-[10px] text-muted-foreground">
                      Destination: {EVENT_FOOD_SHORTFALL_SOURCE_LABELS.society_pool}
                    </p>
                  )}
                  <select
                    className="input-field text-sm"
                    value={adjForm.payment_method}
                    onChange={(e) => setAdjForm({ ...adjForm, payment_method: e.target.value })}
                  >
                    <option value="cash">Cash</option>
                    <option value="upi">UPI / Bank</option>
                    <option value="bank_transfer">Bank transfer</option>
                  </select>
                  <input
                    className="input-field text-sm"
                    placeholder="Notes (optional)"
                    value={adjForm.notes}
                    onChange={(e) => setAdjForm({ ...adjForm, notes: e.target.value })}
                  />
                  <div className="flex gap-2">
                    <button
                      type="button"
                      className="btn-primary text-sm flex-1"
                      disabled={savingAdj}
                      onClick={() => void recordAdjustment(event.id, adjustTarget.kind)}
                    >
                      {savingAdj ? 'Saving…' : 'Save'}
                    </button>
                    <button type="button" className="btn-secondary text-sm flex-1" onClick={() => setAdjustTarget(null)}>
                      Cancel
                    </button>
                  </div>
                </div>
              )}

              {eventAdjustments.length > 0 && (
                <div>
                  <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1">Pool / adjustments</p>
                  <div className="space-y-1">
                    {eventAdjustments.map((a) => (
                      <div key={a.id} className="text-xs bg-blue-500/5 rounded p-2">
                        {a.adjustment_kind === 'surplus_to_pool' ? '→ Pool' : '← Cover'} ₹
                        {Number(a.amount).toLocaleString('en-IN')} — {EVENT_FOOD_SHORTFALL_SOURCE_LABELS[a.source_type]}
                        {a.flat_number ? ` (Flat ${a.flat_number})` : ''}
                        {a.notes ? ` · ${a.notes}` : ''}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {(contribIn > 0 || foodOut > 0) && (
                <CashBankBreakdown
                  variant="compact"
                  receipts={receiptChannels}
                  payments={paymentChannels}
                  receiptLabel="Contributions"
                  paymentLabel="Food bills"
                />
              )}

              {contribs.length > 0 && (
                <div>
                  <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1 flex items-center gap-1">
                    <Receipt className="w-3 h-3" /> Contribution receipts
                  </p>
                  <div className="space-y-1">
                    {contribs.map((c) => (
                      <div key={c.id} className="flex flex-col gap-0.5 text-xs bg-muted/40 rounded p-2">
                        <div className="flex justify-between gap-2 items-start">
                          <span className="flex items-center gap-1.5 flex-wrap">
                            {contribReceiptLabel(c)}
                            <ChannelBadge method={c.payment_method} />
                          </span>
                          <div className="flex items-center gap-1.5 shrink-0">
                            <span className="font-semibold">₹{Number(c.amount).toLocaleString('en-IN')}</span>
                            <button
                              type="button"
                              className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary inline-flex items-center gap-0.5"
                              onClick={() => setEditingContribId(c.id)}
                            >
                              <Pencil className="w-3 h-3" /> Edit
                            </button>
                          </div>
                        </div>
                        {c.screenshot_url ? (
                          <a href={c.screenshot_url} target="_blank" rel="noreferrer" className="text-[10px] text-primary underline">
                            View payment proof
                          </a>
                        ) : (
                          <span className="text-[10px] text-muted-foreground">No attachment</span>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {expenses.length > 0 && (
                <div>
                  <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1 flex items-center gap-1">
                    <Paperclip className="w-3 h-3" /> Food bill receipts
                  </p>
                  <div className="space-y-1">
                    {expenses.map((ex) => {
                      const links = receiptLinks(ex);
                      return (
                        <div key={ex.id} className="text-xs bg-muted/40 rounded p-2">
                          <div className="flex justify-between gap-2 items-start">
                            <span className="font-medium flex items-center gap-1.5 flex-wrap">
                              {ex.title}
                              <ChannelBadge method={ex.payment_method} />
                            </span>
                            <div className="flex items-center gap-1.5 shrink-0">
                              <span className="font-semibold">₹{Number(ex.total_amount).toLocaleString('en-IN')}</span>
                              <button
                                type="button"
                                className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary inline-flex items-center gap-0.5"
                                onClick={() => setEditingExpenseId(ex.id)}
                              >
                                <Pencil className="w-3 h-3" /> Edit
                              </button>
                            </div>
                          </div>
                          <p className="text-[10px] text-muted-foreground">
                            {ex.group_name} · {ex.payment_method} · {fmtIsoDateToDisplay(String(ex.expense_date))}
                          </p>
                          {links.length > 0 ? (
                            <div className="flex flex-wrap gap-2 mt-1">
                              {links.map((link) => (
                                <a
                                  key={link.url}
                                  href={link.url}
                                  target="_blank"
                                  rel="noreferrer"
                                  className="text-[10px] text-primary underline"
                                >
                                  {link.label}
                                </a>
                              ))}
                            </div>
                          ) : (
                            <span className="text-[10px] text-muted-foreground">No bill attached</span>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          );
        })
      )}

      <EventContributionEditModal
        contributionId={editingContribId}
        adminName={adminName}
        onClose={() => setEditingContribId(null)}
        onSaved={handleSaved}
      />
      <FoodExpenseEditModal
        expenseId={editingExpenseId}
        onClose={() => setEditingExpenseId(null)}
        onSaved={handleSaved}
      />
    </div>
  );
};

export default EventFoodReconciliation;
