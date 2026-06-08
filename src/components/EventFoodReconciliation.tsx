import { useEffect, useMemo, useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Receipt, TrendingDown, TrendingUp, Paperclip, Scale } from 'lucide-react';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { DescriptiveStatSummary } from '@/components/DescriptiveStatCard';

type EventRow = { id: string; title: string; event_date: string; contribution_amount: number };
type ContribRow = {
  id: string;
  event_id: string;
  flat_number: string;
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
}

const EventFoodReconciliation = ({ adminName: _adminName = 'Admin', refreshKey = 0 }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [events, setEvents] = useState<EventRow[]>([]);
  const [contributions, setContributions] = useState<ContribRow[]>([]);
  const [foodExpenses, setFoodExpenses] = useState<FoodExpenseRow[]>([]);
  const [loading, setLoading] = useState(false);

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
    return { contribIn, foodOut, net: contribIn - foodOut };
  }, [contributions, foodExpenses]);

  const eventRows = useMemo(() => {
    const byEvent = new Map<
      string,
      { event: EventRow; contribIn: number; foodOut: number; contribs: ContribRow[]; expenses: FoodExpenseRow[] }
    >();

    for (const ev of events) {
      byEvent.set(ev.id, { event: ev, contribIn: 0, foodOut: 0, contribs: [], expenses: [] });
    }

    const unlinkedKey = '__unlinked__';
    const unlinked = {
      event: { id: unlinkedKey, title: 'Food not linked to an event', event_date: '', contribution_amount: 0 },
      contribIn: 0,
      foodOut: 0,
      contribs: [] as ContribRow[],
      expenses: [] as FoodExpenseRow[],
    };

    for (const c of contributions) {
      const row = byEvent.get(c.event_id);
      if (!row) continue;
      row.contribIn += Number(c.amount || 0);
      row.contribs.push(c);
    }

    for (const ex of foodExpenses) {
      if (ex.event_id && byEvent.has(ex.event_id)) {
        const row = byEvent.get(ex.event_id)!;
        row.foodOut += Number(ex.total_amount || 0);
        row.expenses.push(ex);
      } else {
        unlinked.foodOut += Number(ex.total_amount || 0);
        unlinked.expenses.push(ex);
      }
    }

    const rows = [...byEvent.values()].filter(
      (r) => r.contribIn > 0 || r.foodOut > 0 || r.contribs.length > 0 || r.expenses.length > 0,
    );
    if (unlinked.foodOut > 0 || unlinked.expenses.length) rows.push(unlinked);
    rows.sort((a, b) => (b.event.event_date || '').localeCompare(a.event.event_date || ''));
    return rows;
  }, [events, contributions, foodExpenses]);

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
            Net ₹{totals.net.toLocaleString('en-IN')}
          </>
        }
        description="Event contribution receipts (in) vs food/catering bills (out). Reconcile here — not under Finance → Transactions."
        howCalculated="Sums event_contributions and active food expenses (expense_category = food) for this society."
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
        eventRows.map(({ event, contribIn, foodOut, contribs, expenses }) => {
          const net = contribIn - foodOut;
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
                  <p className={`font-semibold ${net >= 0 ? 'text-foreground' : 'text-destructive'}`}>
                    Net ₹{net.toLocaleString('en-IN')}
                  </p>
                </div>
              </div>

              {contribs.length > 0 && (
                <div>
                  <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1 flex items-center gap-1">
                    <Receipt className="w-3 h-3" /> Contribution receipts
                  </p>
                  <div className="space-y-1">
                    {contribs.map((c) => (
                      <div key={c.id} className="flex flex-col gap-0.5 text-xs bg-muted/40 rounded p-2">
                        <div className="flex justify-between gap-2">
                          <span>
                            {contribReceiptLabel(c)} · {c.payment_method}
                          </span>
                          <span className="font-semibold shrink-0">₹{Number(c.amount).toLocaleString('en-IN')}</span>
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
                          <div className="flex justify-between gap-2">
                            <span className="font-medium">{ex.title}</span>
                            <span className="font-semibold shrink-0">₹{Number(ex.total_amount).toLocaleString('en-IN')}</span>
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
    </div>
  );
};

export default EventFoodReconciliation;
