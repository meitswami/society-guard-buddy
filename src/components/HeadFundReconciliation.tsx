import { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Scale, TrendingDown, TrendingUp, Receipt, AlertTriangle, Plus } from 'lucide-react';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { DescriptiveStatSummary } from '@/components/DescriptiveStatCard';
import CashBankBreakdown, { ChannelBadge } from '@/components/CashBankBreakdown';
import { sumByChannel, type ChannelTotals } from '@/lib/cashBankChannel';
import {
  expenseMatchesHead,
  HEAD_ADJUSTMENT_SOURCE_LABELS,
} from '@/lib/headFundMatch';
import { toast } from 'sonner';

type GroupRow = {
  id: string;
  name: string;
  major_head: string | null;
  description: string | null;
};

type ContribRow = {
  id: string;
  group_id: string;
  flat_number: string;
  resident_name: string | null;
  amount: number;
  payment_method: string;
  screenshot_url: string | null;
  due_date: string;
  charge_title: string;
};

type ExpenseRow = {
  id: string;
  group_id: string;
  title: string;
  total_amount: number;
  expense_date: string;
  payment_method: string;
  bill_screenshot_url: string | null;
  vendor_or_service: string | null;
  group_name: string;
  correlated: boolean;
};

type AdjustmentRow = {
  id: string;
  expense_group_id: string;
  amount: number;
  source_type: 'member_advance' | 'maintenance_pool' | 'corpus';
  flat_number: string | null;
  notes: string | null;
  created_at: string;
};

interface Props {
  adminName?: string;
  refreshKey?: number;
  onOpenRecordReceipt?: () => void;
}

const HeadFundReconciliation = ({
  adminName = 'Admin',
  refreshKey = 0,
  onOpenRecordReceipt,
}: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [groups, setGroups] = useState<GroupRow[]>([]);
  const [contributions, setContributions] = useState<ContribRow[]>([]);
  const [expenses, setExpenses] = useState<ExpenseRow[]>([]);
  const [adjustments, setAdjustments] = useState<AdjustmentRow[]>([]);
  const [charges, setCharges] = useState<{ id: string; title: string; expense_group_id: string | null }[]>([]);
  const [loading, setLoading] = useState(false);
  const [adjustGroupId, setAdjustGroupId] = useState<string | null>(null);
  const [adjForm, setAdjForm] = useState({
    amount: '',
    source_type: 'maintenance_pool' as 'member_advance' | 'maintenance_pool' | 'corpus',
    flat_number: '',
    notes: '',
  });
  const [saving, setSaving] = useState(false);

  const loadAll = useCallback(async () => {
    if (!societyId) {
      setGroups([]);
      setContributions([]);
      setExpenses([]);
      setAdjustments([]);
      setCharges([]);
      return;
    }
    setLoading(true);
    try {
      const { data: gRows } = await supabase
        .from('expense_groups')
        .select('id, name, major_head, description')
        .eq('society_id', societyId)
        .eq('group_kind', 'general')
        .order('name');

      const { data: chRows } = await supabase
        .from('maintenance_charges')
        .select('id, title, expense_group_id')
        .eq('society_id', societyId);

      const chargeList = (chRows ?? []) as { id: string; title: string; expense_group_id: string | null }[];
      const groupList = (gRows ?? []) as GroupRow[];
      setGroups(groupList);
      setCharges(chargeList);

      const linkedCharges = chargeList.filter((c) => c.expense_group_id);
      const chargeIdToGroup = new Map(linkedCharges.map((c) => [c.id, c.expense_group_id!]));
      const chargeTitleById = new Map(chargeList.map((c) => [c.id, c.title]));
      const activeGroupIds = groupList.map((g) => g.id);

      const mpRes =
        linkedCharges.length > 0
          ? await supabase
              .from('maintenance_payments')
              .select(
                'id, flat_number, resident_name, amount, payment_method, screenshot_url, due_date, charge_id',
              )
              .in('charge_id', linkedCharges.map((c) => c.id))
              .in('payment_status', ['verified', 'pending'])
          : { data: [] };

      setContributions(
        (mpRes.data ?? [])
          .map((row) => {
            const groupId = chargeIdToGroup.get(String(row.charge_id));
            if (!groupId) return null;
            return {
              id: String(row.id),
              group_id: groupId,
              flat_number: String(row.flat_number),
              resident_name: (row.resident_name as string | null) ?? null,
              amount: Number(row.amount),
              payment_method: String(row.payment_method),
              screenshot_url: (row.screenshot_url as string | null) ?? null,
              due_date: String(row.due_date),
              charge_title: chargeTitleById.get(String(row.charge_id)) ?? '',
            };
          })
          .filter(Boolean) as ContribRow[],
      );

      const exRes =
        activeGroupIds.length > 0
          ? await supabase
              .from('expenses')
              .select(
                'id, title, total_amount, expense_date, payment_method, bill_screenshot_url, vendor_or_service, group_id, expense_groups!inner(name, society_id)',
              )
              .eq('expense_groups.society_id', societyId)
              .eq('expense_category', 'payment')
              .eq('record_status', 'active')
          : { data: [] };

      setExpenses(
        (exRes.data ?? []).map((row: Record<string, unknown>) => {
          const g = row.expense_groups as { name: string };
          return {
            id: String(row.id),
            group_id: String(row.group_id),
            title: String(row.title),
            total_amount: Number(row.total_amount),
            expense_date: String(row.expense_date),
            payment_method: String(row.payment_method),
            bill_screenshot_url: (row.bill_screenshot_url as string | null) ?? null,
            vendor_or_service: (row.vendor_or_service as string | null) ?? null,
            group_name: g.name,
            correlated: false,
          };
        }),
      );

      const adjRes =
        activeGroupIds.length > 0
          ? await supabase
              .from('head_fund_adjustments')
              .select('id, expense_group_id, amount, source_type, flat_number, notes, created_at')
              .eq('society_id', societyId)
              .order('created_at', { ascending: false })
          : { data: [] };

      setAdjustments((adjRes.data ?? []) as AdjustmentRow[]);
    } finally {
      setLoading(false);
    }
  }, [societyId]);

  useEffect(() => {
    void loadAll();
  }, [loadAll, refreshKey]);

  const headRows = useMemo(() => {
    const chargeByGroup = new Map<string, string[]>();
    for (const ch of charges) {
      if (!ch.expense_group_id) continue;
      const list = chargeByGroup.get(ch.expense_group_id) ?? [];
      list.push(ch.title);
      chargeByGroup.set(ch.expense_group_id, list);
    }

    const contribByGroup = new Map<string, ContribRow[]>();
    for (const c of contributions) {
      const list = contribByGroup.get(c.group_id) ?? [];
      list.push(c);
      contribByGroup.set(c.group_id, list);
    }

    const rows: {
      group: GroupRow;
      chargeTitles: string[];
      contribs: ContribRow[];
      expenses: ExpenseRow[];
      adjustments: AdjustmentRow[];
      contribIn: number;
      adjustIn: number;
      expenseOut: number;
      net: number;
      shortfall: number;
      receiptChannels: ChannelTotals;
      paymentChannels: ChannelTotals;
    }[] = [];

    const candidateGroups = groups.filter(
      (g) =>
        chargeByGroup.has(g.id) ||
        (contribByGroup.get(g.id)?.length ?? 0) > 0 ||
        expenses.some((e) => e.group_id === g.id || expenseMatchesHead(g.name, e)) ||
        adjustments.some((a) => a.expense_group_id === g.id),
    );

    for (const group of candidateGroups) {
      const contribs = contribByGroup.get(group.id) ?? [];
      const matchedExpenses: ExpenseRow[] = [];
      for (const ex of expenses) {
        const inGroup = ex.group_id === group.id;
        const correlated = !inGroup && expenseMatchesHead(group.name, ex);
        if (inGroup || correlated) {
          matchedExpenses.push({ ...ex, correlated });
        }
      }
      const groupAdj = adjustments.filter((a) => a.expense_group_id === group.id);
      const contribIn = contribs.reduce((s, c) => s + Number(c.amount || 0), 0);
      const adjustIn = groupAdj.reduce((s, a) => s + Number(a.amount || 0), 0);
      const expenseOut = matchedExpenses.reduce((s, e) => s + Number(e.total_amount || 0), 0);
      const net = contribIn + adjustIn - expenseOut;
      const shortfall = Math.max(0, expenseOut - contribIn - adjustIn);
      const receiptChannels = sumByChannel(contribs, (c) => Number(c.amount || 0), (c) => c.payment_method);
      const paymentChannels = sumByChannel(matchedExpenses, (e) => Number(e.total_amount || 0), (e) => e.payment_method);

      if (contribIn > 0 || adjustIn > 0 || expenseOut > 0 || chargeByGroup.has(group.id)) {
        rows.push({
          group,
          chargeTitles: chargeByGroup.get(group.id) ?? [],
          contribs,
          expenses: matchedExpenses,
          adjustments: groupAdj,
          contribIn,
          adjustIn,
          expenseOut,
          net,
          shortfall,
          receiptChannels,
          paymentChannels,
        });
      }
    }

    rows.sort((a, b) => a.group.name.localeCompare(b.group.name));
    return rows;
  }, [groups, charges, contributions, expenses, adjustments]);

  const societyChannelTotals = useMemo(() => {
    const receiptChannels = sumByChannel(contributions, (c) => Number(c.amount || 0), (c) => c.payment_method);
    const paymentChannels = sumByChannel(expenses, (e) => Number(e.total_amount || 0), (e) => e.payment_method);
    return { receiptChannels, paymentChannels };
  }, [contributions, expenses]);

  const recordAdjustment = async (groupId: string, shortfall: number) => {
    if (!societyId) return;
    const amount = Number(adjForm.amount);
    if (!amount || amount <= 0) {
      toast.error('Enter adjustment amount');
      return;
    }
    if (adjForm.source_type === 'member_advance' && !adjForm.flat_number.trim()) {
      toast.error('Enter flat number for member advance');
      return;
    }
    setSaving(true);
    try {
      const flat = adjForm.flat_number.trim()
        ? await supabase
            .from('flats')
            .select('id')
            .eq('society_id', societyId)
            .eq('flat_number', adjForm.flat_number.trim())
            .maybeSingle()
        : { data: null };

      const { error } = await supabase.from('head_fund_adjustments').insert({
        society_id: societyId,
        expense_group_id: groupId,
        amount,
        source_type: adjForm.source_type,
        flat_number: adjForm.flat_number.trim() || null,
        flat_id: flat.data?.id ?? null,
        notes: adjForm.notes.trim() || null,
        created_by: adminName,
      });
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success(
        shortfall > 0 && amount >= shortfall
          ? 'Shortfall covered — head balanced'
          : 'Adjustment recorded',
      );
      setAdjustGroupId(null);
      setAdjForm({ amount: '', source_type: 'maintenance_pool', flat_number: '', notes: '' });
      await loadAll();
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <p className="text-xs text-muted-foreground text-center py-4">Loading head reconciliation…</p>;
  }

  if (headRows.length === 0) {
    return (
      <div className="card-section p-4 mb-4 text-center">
        <Scale className="w-7 h-7 text-muted-foreground mx-auto mb-2 opacity-50" />
        <p className="text-sm text-muted-foreground">No linked expense heads yet.</p>
        <p className="text-xs text-muted-foreground mt-1">
          Create a receipt type under Create Receipts and link it to a payment head, or add expenses under Record payment.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4 mb-6">
      <DescriptiveStatSummary
        label="Head fund reconciliation"
        description="Contributions collected (receipt type linked to head) vs expenses incurred under the same head. Cash and bank shown separately."
        howCalculated="Contributions = maintenance_payments on linked charges. Expenses = payment expenses in the head group + correlated items. Channel from payment_method."
      />

      <CashBankBreakdown
        className="mb-2"
        receipts={societyChannelTotals.receiptChannels}
        payments={societyChannelTotals.paymentChannels}
        receiptLabel="Head contributions (receipts)"
        paymentLabel="Head expenses (payments)"
      />

      {headRows.map(
        ({
          group,
          chargeTitles,
          contribs,
          expenses: headExpenses,
          adjustments: headAdj,
          contribIn,
          adjustIn,
          expenseOut,
          net,
          shortfall,
          receiptChannels,
          paymentChannels,
        }) => (
          <div key={group.id} className="card-section p-4 space-y-3">
            <div className="flex flex-wrap items-start justify-between gap-2">
              <div>
                <p className="font-semibold text-sm">{group.name}</p>
                {group.major_head && (
                  <p className="text-[10px] text-muted-foreground">{group.major_head}</p>
                )}
                {chargeTitles.length > 0 && (
                  <p className="text-[10px] text-muted-foreground mt-0.5">
                    Receipt type: {chargeTitles.join(', ')}
                  </p>
                )}
              </div>
              <div className="text-right text-xs space-y-0.5">
                <p className="text-green-600 flex items-center justify-end gap-1">
                  <TrendingUp className="w-3 h-3" /> ₹{contribIn.toLocaleString('en-IN')} collected
                </p>
                {adjustIn > 0 && (
                  <p className="text-blue-600 flex items-center justify-end gap-1">
                    <Plus className="w-3 h-3" /> ₹{adjustIn.toLocaleString('en-IN')} adjusted
                  </p>
                )}
                <p className="text-orange-600 flex items-center justify-end gap-1">
                  <TrendingDown className="w-3 h-3" /> ₹{expenseOut.toLocaleString('en-IN')} spent
                </p>
                <p className={`font-semibold ${net >= 0 ? 'text-foreground' : 'text-destructive'}`}>
                  Net ₹{net.toLocaleString('en-IN')}
                </p>
              </div>
            </div>

            {(contribIn > 0 || expenseOut > 0) && (
              <CashBankBreakdown
                variant="compact"
                receipts={receiptChannels}
                payments={paymentChannels}
                receiptLabel="Contributions"
                paymentLabel="Expenses"
              />
            )}

            {shortfall > 0 && (
              <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-2.5 flex gap-2 items-start">
                <AlertTriangle className="w-4 h-4 text-destructive shrink-0 mt-0.5" />
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-medium text-destructive">
                    Short of funds: ₹{shortfall.toLocaleString('en-IN')}
                  </p>
                  <p className="text-[10px] text-muted-foreground mt-0.5">
                    Contributions + adjustments are less than expenses. Record member top-up, draw from maintenance collections, or corpus.
                  </p>
                  {onOpenRecordReceipt && contribs.length === 0 && (
                    <button
                      type="button"
                      className="text-[10px] text-primary underline mt-1"
                      onClick={onOpenRecordReceipt}
                    >
                      Record flat contributions (Create Receipts / Record receipt)
                    </button>
                  )}
                </div>
                <button
                  type="button"
                  className="text-xs px-2 py-1 rounded-lg bg-primary/10 text-primary shrink-0"
                  onClick={() => {
                    setAdjustGroupId(group.id);
                    setAdjForm((f) => ({ ...f, amount: String(shortfall) }));
                  }}
                >
                  Adjust
                </button>
              </div>
            )}

            {adjustGroupId === group.id && (
              <div className="rounded-lg border border-border bg-muted/20 p-3 space-y-2">
                <p className="text-xs font-medium">Record shortfall adjustment</p>
                <input
                  className="input-field text-sm"
                  type="number"
                  placeholder="Amount (₹)"
                  value={adjForm.amount}
                  onChange={(e) => setAdjForm({ ...adjForm, amount: e.target.value })}
                />
                <select
                  className="input-field text-sm"
                  value={adjForm.source_type}
                  onChange={(e) =>
                    setAdjForm({
                      ...adjForm,
                      source_type: e.target.value as typeof adjForm.source_type,
                    })
                  }
                >
                  {(Object.keys(HEAD_ADJUSTMENT_SOURCE_LABELS) as (keyof typeof HEAD_ADJUSTMENT_SOURCE_LABELS)[]).map(
                    (k) => (
                      <option key={k} value={k}>
                        {HEAD_ADJUSTMENT_SOURCE_LABELS[k]}
                      </option>
                    ),
                  )}
                </select>
                {adjForm.source_type === 'member_advance' && (
                  <input
                    className="input-field text-sm"
                    placeholder="Flat number"
                    value={adjForm.flat_number}
                    onChange={(e) => setAdjForm({ ...adjForm, flat_number: e.target.value })}
                  />
                )}
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
                    disabled={saving}
                    onClick={() => void recordAdjustment(group.id, shortfall)}
                  >
                    {saving ? 'Saving…' : 'Save adjustment'}
                  </button>
                  <button
                    type="button"
                    className="btn-secondary text-sm flex-1"
                    onClick={() => setAdjustGroupId(null)}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}

            {contribs.length > 0 && (
              <div>
                <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1 flex items-center gap-1">
                  <Receipt className="w-3 h-3" /> Contribution receipts
                </p>
                <div className="space-y-1 max-h-40 overflow-y-auto">
                  {contribs.map((c) => (
                    <div key={c.id} className="flex justify-between gap-2 text-xs bg-muted/40 rounded p-2">
                      <span className="flex items-center gap-1.5 flex-wrap">
                        Flat {c.flat_number}
                        {c.resident_name ? ` · ${c.resident_name}` : ''}
                        <ChannelBadge method={c.payment_method} />
                      </span>
                      <span className="font-semibold shrink-0">₹{Number(c.amount).toLocaleString('en-IN')}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {headExpenses.length > 0 && (
              <div>
                <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1">Expenses incurred</p>
                <div className="space-y-1 max-h-48 overflow-y-auto">
                  {headExpenses.map((ex) => (
                    <div key={ex.id} className="text-xs bg-muted/40 rounded p-2">
                      <div className="flex justify-between gap-2">
                        <span className="font-medium flex items-center gap-1.5 flex-wrap">
                          {ex.title}
                          <ChannelBadge method={ex.payment_method} />
                          {ex.correlated && (
                            <span className="text-[10px] text-muted-foreground font-normal">(linked)</span>
                          )}
                        </span>
                        <span className="font-semibold shrink-0">₹{Number(ex.total_amount).toLocaleString('en-IN')}</span>
                      </div>
                      <p className="text-[10px] text-muted-foreground">
                        {ex.group_name}
                        {ex.vendor_or_service ? ` · ${ex.vendor_or_service}` : ''} ·{' '}
                        {fmtIsoDateToDisplay(ex.expense_date)}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {headAdj.length > 0 && (
              <div>
                <p className="text-[10px] font-semibold text-muted-foreground uppercase mb-1">Adjustments</p>
                {headAdj.map((a) => (
                  <div key={a.id} className="text-xs bg-blue-500/5 rounded p-2 mb-1">
                    ₹{Number(a.amount).toLocaleString('en-IN')} — {HEAD_ADJUSTMENT_SOURCE_LABELS[a.source_type]}
                    {a.flat_number ? ` (Flat ${a.flat_number})` : ''}
                    {a.notes ? ` · ${a.notes}` : ''}
                  </div>
                ))}
              </div>
            )}
          </div>
        ),
      )}
    </div>
  );
};

export default HeadFundReconciliation;
