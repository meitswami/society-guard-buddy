import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { AlertTriangle, IndianRupee, RefreshCw } from 'lucide-react';
import { format } from 'date-fns';
import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';

interface DuplicateAlarm {
  flat_number: string;
  charge_title: string;
  month: string; // yyyy-MM
  payment_method: string;
  count: number;
  total_amount: number;
  payment_ids: string[];
}

const normalizeChannel = (method: unknown): string => {
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

const FinanceAuditAlarms = () => {
  const societyId = useStore((s) => s.societyId);
  const [alarms, setAlarms] = useState<DuplicateAlarm[]>([]);
  const [loading, setLoading] = useState(true);

  const detect = useCallback(async () => {
    if (!societyId) {
      setAlarms([]);
      setLoading(false);
      return;
    }
    setLoading(true);

    // Load maintenance charges for this society
    const { data: charges } = await supabase
      .from('maintenance_charges')
      .select('id, title, frequency')
      .eq('society_id', societyId);

    if (!charges || charges.length === 0) {
      setAlarms([]);
      setLoading(false);
      return;
    }

    // Only look at monthly charges
    const monthlyCharges = charges.filter(
      (c) => (c.frequency ?? '').toLowerCase() === 'monthly',
    );
    if (monthlyCharges.length === 0) {
      setAlarms([]);
      setLoading(false);
      return;
    }

    const chargeIds = monthlyCharges.map((c) => c.id);
    const chargeMap = new Map(monthlyCharges.map((c) => [c.id, c.title]));

    // Load all verified/pending payments for these charges
    const { data: payments } = await supabase
      .from('maintenance_payments')
      .select('id, charge_id, flat_number, amount, payment_method, due_date, payment_date, created_at, payment_status')
      .in('charge_id', chargeIds)
      .in('payment_status', ['verified', 'pending']);

    if (!payments || payments.length === 0) {
      setAlarms([]);
      setLoading(false);
      return;
    }

    // Group by flat_number + charge_id + month + channel
    // A duplicate = same flat, same charge, same month, same channel, more than 1 entry
    const groupKey = (p: typeof payments[0]) => {
      const dateStr = p.due_date || p.payment_date || p.created_at || '';
      const month = dateStr ? format(new Date(dateStr), 'yyyy-MM') : 'unknown';
      const channel = normalizeChannel(p.payment_method);
      return `${p.flat_number}||${p.charge_id}||${month}||${channel}`;
    };

    const groups = new Map<string, typeof payments>();
    for (const p of payments) {
      const key = groupKey(p);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(p);
    }

    // Find duplicates (count > 1)
    const duplicates: DuplicateAlarm[] = [];
    for (const [key, group] of groups) {
      if (group.length <= 1) continue;
      const [flat_number, charge_id, month, channel] = key.split('||');
      const chargeTitle = chargeMap.get(charge_id) ?? 'Unknown charge';
      duplicates.push({
        flat_number,
        charge_title: chargeTitle,
        month,
        payment_method: channel,
        count: group.length,
        total_amount: group.reduce((sum, p) => sum + Number(p.amount || 0), 0),
        payment_ids: group.map((p) => p.id),
      });
    }

    // Sort by month descending, then flat number
    duplicates.sort((a, b) => {
      if (a.month !== b.month) return b.month.localeCompare(a.month);
      return a.flat_number.localeCompare(b.flat_number);
    });

    setAlarms(duplicates);
    setLoading(false);
  }, [societyId]);

  useEffect(() => {
    void detect();
  }, [detect]);

  if (loading) {
    return (
      <div className="card-section p-4">
        <p className="text-sm text-muted-foreground">Scanning for duplicate maintenance entries…</p>
      </div>
    );
  }

  if (alarms.length === 0) {
    return (
      <div className="card-section p-4 border-green-500/30 bg-green-500/5">
        <div className="flex items-center gap-2">
          <IndianRupee className="w-4 h-4 text-green-600" />
          <p className="text-sm font-medium text-green-700 dark:text-green-400">
            No duplicate maintenance credits detected
          </p>
        </div>
        <p className="text-xs text-muted-foreground mt-1">
          All monthly maintenance entries appear correctly recorded (no flat credited twice in the same month via the same channel).
        </p>
      </div>
    );
  }

  return (
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
              {alarms.length} alarm{alarms.length > 1 ? 's' : ''} — same flat credited twice in the same month
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
          className="card-section p-3 border-destructive/40 bg-destructive/5 animate-in fade-in"
        >
          <div className="flex items-start gap-3">
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
                <span className="text-[10px] text-muted-foreground">
                  IDs: {alarm.payment_ids.map((id) => id.slice(0, 6)).join(', ')}
                </span>
              </div>
              <p className="text-[10px] text-destructive/80 mt-1.5 font-medium">
                ⚡ Action needed: Verify in Finance → Payments tab and remove the duplicate entry.
              </p>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default FinanceAuditAlarms;
