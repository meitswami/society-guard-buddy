import { useState, useMemo, useEffect } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { BarChart3, Download, Printer, Calendar, Users, Car, Truck, Shield, DollarSign, Heart, Split } from 'lucide-react';
import { format, parse, endOfMonth } from 'date-fns';
import { useLanguage } from '@/i18n/LanguageContext';

interface ShiftRow { id: string; guard_id: string; guard_name: string; login_time: string; logout_time: string | null; }

interface FinanceEntrySummaryRow {
  id: string;
  record_mode: string;
  destination: string;
  total_amount: number;
  aggregate_flat_count: number;
  entry_month: string | null;
  created_at: string;
  payment_status: string;
  payment_method: string;
}

function normalizePaymentChannel(method: unknown): 'cash' | 'bank' | 'other' {
  const x = String(method ?? 'cash')
    .toLowerCase()
    .replace(/\s/g, '');
  if (x === 'cash') return 'cash';
  if (
    ['upi', 'bank_transfer', 'razorpay', 'online', 'card', 'neft', 'rtgs', 'imps', 'netbanking', 'cheque', 'dd'].some(
      (k) => x === k || x.includes(k),
    )
  )
    return 'bank';
  return 'other';
}

const ReportPage = () => {
  const { visitors, societyId } = useStore();
  const { t } = useLanguage();
  const [date, setDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [shifts, setShifts] = useState<ShiftRow[]>([]);
  const [financeMonth, setFinanceMonth] = useState(format(new Date(), 'yyyy-MM'));
  const [financeEntries, setFinanceEntries] = useState<FinanceEntrySummaryRow[]>([]);
  const [ledgerStatuses, setLedgerStatuses] = useState<{ payment_status: string; count: number; total: number }[]>([]);
  const [maintenanceStatuses, setMaintenanceStatuses] = useState<{ payment_status: string; count: number; total: number }[]>([]);
  const [maintenanceLinkSummary, setMaintenanceLinkSummary] = useState<{
    linked: { count: number; total: number };
    unlinked: { count: number; total: number };
  } | null>(null);
  const [donationStatuses, setDonationStatuses] = useState<{ status: string; count: number; total: number }[]>([]);
  const [splitStatuses, setSplitStatuses] = useState<{ status: string; count: number; total: number }[]>([]);

  useEffect(() => {
    const loadShifts = async () => {
      if (!societyId) {
        setShifts([]);
        return;
      }
      const { data } = await supabase.from('guard_shifts').select('*')
        .eq('society_id', societyId)
        .gte('login_time', `${date}T00:00:00`).lte('login_time', `${date}T23:59:59`)
        .order('login_time', { ascending: true });
      if (data) setShifts(data);
    };
    loadShifts();
  }, [date, societyId]);

  useEffect(() => {
    const loadFinance = async () => {
      if (!societyId) {
        setFinanceEntries([]);
        setLedgerStatuses([]);
        setMaintenanceStatuses([]);
        setMaintenanceLinkSummary(null);
        setDonationStatuses([]);
        setSplitStatuses([]);
        return;
      }
      const { data } = await supabase
        .from('finance_entries')
        .select(
          'id, record_mode, destination, total_amount, aggregate_flat_count, entry_month, created_at, payment_status, payment_method',
        )
        .eq('society_id', societyId)
        .eq('entry_month', financeMonth)
        .order('created_at', { ascending: false })
        .limit(800);
      const rows = (data as FinanceEntrySummaryRow[]) ?? [];
      setFinanceEntries(rows);

      const monthDate = parse(`${financeMonth}-01`, 'yyyy-MM-dd', new Date());
      const from = format(monthDate, "yyyy-MM-dd'T'00:00:00");
      const to = format(endOfMonth(monthDate), "yyyy-MM-dd'T'23:59:59");

      // Receipts — ledger verification (all ledger rows this month)
      const map = new Map<string, { count: number; total: number }>();
      for (const e of rows) {
        const st = String(e.payment_status ?? 'verified');
        const cur = map.get(st) ?? { count: 0, total: 0 };
        cur.count += 1;
        cur.total += Number(e.total_amount || 0);
        map.set(st, cur);
      }
      setLedgerStatuses([...map.entries()].map(([payment_status, v]) => ({ payment_status, ...v })));

      // Maintenance — all maintenance_payments for society charges (Finance → Payments scope), due date in selected month
      const dueFrom = format(monthDate, 'yyyy-MM-dd');
      const dueTo = format(endOfMonth(monthDate), 'yyyy-MM-dd');
      const { data: chargeRows } = await supabase.from('maintenance_charges').select('id').eq('society_id', societyId);
      const chargeIds = (chargeRows as { id: string }[] | null)?.map((c) => c.id) ?? [];
      if (!chargeIds.length) {
        setMaintenanceStatuses([]);
        setMaintenanceLinkSummary(null);
      } else {
        const { data: mpRows } = await supabase
          .from('maintenance_payments')
          .select('payment_status, amount, finance_entry_id')
          .in('charge_id', chargeIds)
          .gte('due_date', dueFrom)
          .lte('due_date', dueTo);
        const maintMap = new Map<string, { count: number; total: number }>();
        let linkedCount = 0;
        let linkedTotal = 0;
        let unlinkedCount = 0;
        let unlinkedTotal = 0;
        for (const p of (mpRows as { payment_status?: string; amount: number; finance_entry_id: string | null }[] | null) ?? []) {
          const st = String(p.payment_status ?? 'pending');
          const amt = Number(p.amount || 0);
          const cur = maintMap.get(st) ?? { count: 0, total: 0 };
          cur.count += 1;
          cur.total += amt;
          maintMap.set(st, cur);
          if (p.finance_entry_id) {
            linkedCount += 1;
            linkedTotal += amt;
          } else {
            unlinkedCount += 1;
            unlinkedTotal += amt;
          }
        }
        setMaintenanceStatuses([...maintMap.entries()].map(([payment_status, v]) => ({ payment_status, ...v })));
        const n = (mpRows ?? []).length;
        setMaintenanceLinkSummary(
          n > 0
            ? {
                linked: { count: linkedCount, total: linkedTotal },
                unlinked: { count: unlinkedCount, total: unlinkedTotal },
              }
            : null,
        );
      }

      // Donation payments status summary (by created_at month; scoped via society campaigns)
      const { data: campRows } = await supabase.from('donation_campaigns').select('id').eq('society_id', societyId);
      const campIds = (campRows as { id: string }[] | null)?.map((c) => c.id) ?? [];
      if (!campIds.length) {
        setDonationStatuses([]);
      } else {
        const { data: dp } = await supabase
          .from('donation_payments')
          .select('amount, verified_at, created_at')
          .in('campaign_id', campIds)
          .gte('created_at', from)
          .lte('created_at', to);
        const dMap = new Map<string, { count: number; total: number }>();
        for (const p of (dp as { amount: number; verified_at: string | null }[] | null) ?? []) {
          const st = p.verified_at ? 'verified' : 'pending';
          const cur = dMap.get(st) ?? { count: 0, total: 0 };
          cur.count += 1;
          cur.total += Number(p.amount || 0);
          dMap.set(st, cur);
        }
        setDonationStatuses([...dMap.entries()].map(([status, v]) => ({ status, ...v })));
      }

      // Splitwise — only expenses under society expense_groups, active in month
      const { data: groups } = await supabase.from('expense_groups').select('id').eq('society_id', societyId);
      const groupIds = (groups as { id: string }[] | null)?.map((g) => g.id) ?? [];
      if (!groupIds.length) {
        setSplitStatuses([]);
      } else {
        const { data: ex } = await supabase
          .from('expenses')
          .select('id, created_at, record_status, group_id')
          .in('group_id', groupIds)
          .eq('record_status', 'active')
          .gte('created_at', from)
          .lte('created_at', to);
        const expIds = (ex as { id: string }[] | null)?.map((x) => x.id) ?? [];
        if (!expIds.length) {
          setSplitStatuses([]);
        } else {
          const { data: splits } = await supabase
            .from('expense_splits')
            .select('amount, is_settled')
            .in('expense_id', expIds);
          const sMap = new Map<string, { count: number; total: number }>();
          for (const s of (splits as { amount: number; is_settled: boolean }[] | null) ?? []) {
            const st = s.is_settled ? 'settled' : 'pending';
            const cur = sMap.get(st) ?? { count: 0, total: 0 };
            cur.count += 1;
            cur.total += Number(s.amount || 0);
            sMap.set(st, cur);
          }
          setSplitStatuses([...sMap.entries()].map(([status, v]) => ({ status, ...v })));
        }
      }
    };
    void loadFinance();
  }, [financeMonth, societyId]);

  const dayVisitors = useMemo(() => visitors.filter(v => v.entryTime.startsWith(date)), [visitors, date]);

  /** Verified ledger: inflows (maintenance + corpus) minus separate-entry expenses, by payment channel. */
  const reportMonthNet = useMemo(() => {
    const receipt = { cash: 0, bank: 0, other: 0 };
    const expense = { cash: 0, bank: 0, other: 0 };
    for (const e of financeEntries) {
      if (String(e.payment_status) !== 'verified') continue;
      const amt = Number(e.total_amount || 0);
      const ch = normalizePaymentChannel(e.payment_method);
      if (e.destination === 'separate_entry') expense[ch] += amt;
      else if (e.destination === 'current_month_maintenance' || e.destination === 'corpus') receipt[ch] += amt;
    }
    const cashInHand = receipt.cash - expense.cash;
    const cashInBank = receipt.bank - expense.bank;
    const otherNet = receipt.other - expense.other;
    return {
      cashInHand,
      cashInBank,
      otherNet,
      totalBalance: cashInHand + cashInBank + otherNet,
    };
  }, [financeEntries]);

  const financeGroups = useMemo(() => {
    const map = new Map<string, { total: number; flatUnits: number; count: number }>();
    for (const e of financeEntries) {
      const key = `${e.record_mode}||${e.destination}`;
      const cur = map.get(key) ?? { total: 0, flatUnits: 0, count: 0 };
      cur.total += Number(e.total_amount || 0);
      cur.flatUnits += Number(e.aggregate_flat_count || 0);
      cur.count += 1;
      map.set(key, cur);
    }
    return [...map.entries()].map(([k, v]) => {
      const [record_mode, destination] = k.split('||');
      return { record_mode, destination, ...v };
    });
  }, [financeEntries]);

  const financeMonthTotal = useMemo(
    () => financeGroups.reduce((s, g) => s + g.total, 0),
    [financeGroups],
  );

  const exportFinanceCSV = () => {
    const headers = ['record_mode', 'destination', 'entries', 'total_amount', 'flat_units'];
    const rows = financeGroups.map((g) => [g.record_mode, g.destination, g.count, g.total, g.flatUnits]);
    const csv = [headers, ...rows].map((r) => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `finance-totals-${financeMonth}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const stats = useMemo(() => ({
    totalVisitors: dayVisitors.filter(v => v.category === 'visitor').length,
    totalVehicles: dayVisitors.filter(v => v.vehicleNumber).length,
    totalDeliveries: dayVisitors.filter(v => v.category === 'delivery' || v.category === 'service').length,
    currentlyInside: dayVisitors.filter(v => !v.exitTime).length,
    uniqueFlats: new Set(dayVisitors.map(v => v.flatNumber)).size,
  }), [dayVisitors]);

  const printReport = () => {
    const visitorRows = dayVisitors.map(v => `<tr>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.name}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;font-family:monospace;">${v.phone}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.flatNumber}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.category}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.purpose}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${format(new Date(v.entryTime), 'hh:mm a')}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.exitTime ? format(new Date(v.exitTime), 'hh:mm a') : t('common.inside')}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.vehicleNumber || '-'}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.guardName}</td></tr>`).join('');

    const shiftRows = shifts.map(s => `<tr>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;font-family:monospace;">${s.guard_id}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${s.guard_name}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${format(new Date(s.login_time), 'hh:mm a')}</td>
      <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${s.logout_time ? format(new Date(s.logout_time), 'hh:mm a') : t('common.active')}</td></tr>`).join('');

    const html = `<!DOCTYPE html><html><head><title>${t('report.title')} - ${date}</title><style>
      body{font-family:Arial,sans-serif;padding:20px;color:#333}table{width:100%;border-collapse:collapse;margin-bottom:24px}
      th{text-align:left;padding:8px;background:#f5f5f5;border-bottom:2px solid #ddd;font-size:12px}
      h1{font-size:20px}h2{font-size:16px;margin-top:24px;border-bottom:1px solid #ddd;padding-bottom:4px}
      .stats{display:flex;gap:16px;margin:16px 0;flex-wrap:wrap}.stat{background:#f8f8f8;padding:12px 16px;border-radius:8px;min-width:100px}
      .stat-val{font-size:24px;font-weight:bold}.stat-label{font-size:11px;color:#888}
    </style></head><body>
      <h1>🏢 ${t('app.name')} — ${t('report.title')}</h1>
      <p style="color:#888">${format(new Date(date), 'EEEE, dd MMMM yyyy')}</p>
      <div class="stats">
        <div class="stat"><div class="stat-val">${stats.totalVisitors}</div><div class="stat-label">${t('dashboard.visitors')}</div></div>
        <div class="stat"><div class="stat-val">${stats.totalVehicles}</div><div class="stat-label">${t('dashboard.vehicles')}</div></div>
        <div class="stat"><div class="stat-val">${stats.totalDeliveries}</div><div class="stat-label">${t('dashboard.deliveries')}</div></div>
        <div class="stat"><div class="stat-val">${stats.currentlyInside}</div><div class="stat-label">${t('dashboard.insideNow')}</div></div>
        <div class="stat"><div class="stat-val">${stats.uniqueFlats}</div><div class="stat-label">${t('report.flatsVisited')}</div></div>
      </div>
      <h2>${t('report.entries')} (${dayVisitors.length})</h2>
      <table><thead><tr><th>Name</th><th>Phone</th><th>Flat</th><th>Category</th><th>Purpose</th><th>In</th><th>Out</th><th>Vehicle</th><th>Guard</th></tr></thead>
      <tbody>${visitorRows || '<tr><td colspan="9" style="text-align:center;padding:20px;color:#999">No entries</td></tr>'}</tbody></table>
      <h2>${t('report.guardShifts')} (${shifts.length})</h2>
      <table><thead><tr><th>Guard ID</th><th>Name</th><th>Login</th><th>Logout</th></tr></thead>
      <tbody>${shiftRows || '<tr><td colspan="4" style="text-align:center;padding:20px;color:#999">No shifts</td></tr>'}</tbody></table>
      <p style="color:#aaa;font-size:10px;margin-top:32px">${t('app.footer')}</p>
    </body></html>`;
    const win = window.open('', '_blank');
    if (win) { win.document.write(html); win.document.close(); setTimeout(() => win.print(), 500); }
  };

  const exportCSV = () => {
    const headers = ['Name', 'Phone', 'Flat', 'Category', 'Purpose', 'Entry', 'Exit', 'Vehicle', 'Guard'];
    const rows = dayVisitors.map(v => [
      v.name, v.phone, v.flatNumber, v.category, v.purpose,
      format(new Date(v.entryTime), 'dd/MM/yyyy HH:mm'),
      v.exitTime ? format(new Date(v.exitTime), 'dd/MM/yyyy HH:mm') : 'Inside',
      v.vehicleNumber || '-', v.guardName,
    ]);
    const csv = [headers, ...rows].map(r => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `report-${date}.csv`; a.click();
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <BarChart3 className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('report.title')}</h1>
            <p className="text-xs text-muted-foreground">{t('report.subtitle')}</p>
          </div>
        </div>
        <div className="flex gap-1.5">
          <button onClick={exportCSV} className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1"><Download className="w-3.5 h-3.5" /> CSV</button>
          <button onClick={printReport} className="btn-primary text-xs px-2.5 py-2 flex items-center gap-1"><Printer className="w-3.5 h-3.5" /> {t('report.print')}</button>
        </div>
      </div>

      <div className="flex items-center gap-2 mb-5">
        <Calendar className="w-4 h-4 text-muted-foreground" />
        <input type="date" className="input-field text-sm flex-1" value={date} onChange={e => setDate(e.target.value)} />
      </div>

      <div className="mb-8 border border-border rounded-xl p-4 bg-muted/20">
        <div className="flex items-center justify-between gap-3 mb-4 flex-wrap">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 rounded-lg bg-green-500/10 flex items-center justify-center">
              <DollarSign className="w-4 h-4 text-green-600" />
            </div>
            <div>
              <h2 className="text-sm font-semibold">{t('report.financeSummaryReceipts')}</h2>
              <p className="text-[10px] text-muted-foreground">{t('report.financeLedgerSubtitle')}</p>
            </div>
          </div>
          <button type="button" onClick={exportFinanceCSV} className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1">
            <Download className="w-3.5 h-3.5" /> {t('report.exportFinanceCsv')}
          </button>
        </div>
        <div className="flex flex-wrap items-center gap-3 mb-4">
          <label className="text-xs text-muted-foreground flex items-center gap-2">
            {t('report.financeMonth')}
            <input
              type="month"
              className="input-field text-sm"
              value={financeMonth}
              onChange={(e) => setFinanceMonth(e.target.value)}
            />
          </label>
          <span className="text-xs font-mono">
            {t('report.financeGross')} ₹{financeMonthTotal.toLocaleString('en-IN')} · {financeEntries.length}{' '}
            {t('report.entryCountLabel')}
          </span>
        </div>
        <div className="mb-4 rounded-lg border border-border bg-card/40 p-3">
          <p className="text-[11px] font-medium text-foreground mb-2">{t('report.financeNetTitle')}</p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
            <div className="rounded-md border border-border/80 bg-background/60 px-2.5 py-2">
              <p className="text-[10px] text-muted-foreground">{t('report.cashInHand')}</p>
              <p className="text-sm font-mono font-semibold">₹{reportMonthNet.cashInHand.toLocaleString('en-IN')}</p>
            </div>
            <div className="rounded-md border border-border/80 bg-background/60 px-2.5 py-2">
              <p className="text-[10px] text-muted-foreground">{t('report.balanceInBank')}</p>
              <p className="text-sm font-mono font-semibold">₹{reportMonthNet.cashInBank.toLocaleString('en-IN')}</p>
            </div>
            <div className="rounded-md border border-border/80 bg-background/60 px-2.5 py-2">
              <p className="text-[10px] text-muted-foreground">{t('report.otherNet')}</p>
              <p className="text-sm font-mono font-semibold">₹{reportMonthNet.otherNet.toLocaleString('en-IN')}</p>
            </div>
            <div className="rounded-md border border-primary/30 bg-primary/5 px-2.5 py-2">
              <p className="text-[10px] text-muted-foreground">{t('report.totalBalance')}</p>
              <p className="text-sm font-mono font-semibold text-primary">₹{reportMonthNet.totalBalance.toLocaleString('en-IN')}</p>
            </div>
          </div>
        </div>
        {financeGroups.length === 0 ? (
          <p className="text-xs text-muted-foreground text-center py-4">{t('report.noLedgerRows')}</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-left text-muted-foreground border-b border-border">
                  <th className="py-2 pr-2">{t('report.colMode')}</th>
                  <th className="py-2 pr-2">{t('report.colDestination')}</th>
                  <th className="py-2 pr-2">{t('report.colEntries')}</th>
                  <th className="py-2 pr-2">{t('report.colAmount')}</th>
                  <th className="py-2">{t('report.colFlatUnits')}</th>
                </tr>
              </thead>
              <tbody>
                {financeGroups.map((g) => (
                  <tr key={`${g.record_mode}-${g.destination}`} className="border-b border-border/60">
                    <td className="py-2 pr-2 capitalize">{g.record_mode.replace(/_/g, ' ')}</td>
                    <td className="py-2 pr-2 capitalize">{g.destination.replace(/_/g, ' ')}</td>
                    <td className="py-2 pr-2 font-mono">{g.count}</td>
                    <td className="py-2 pr-2 font-mono">₹{g.total.toLocaleString('en-IN')}</td>
                    <td className="py-2 font-mono">{g.flatUnits}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-8">
        <div className="border border-border rounded-xl p-4 bg-card/50">
          <div className="flex items-center gap-2 mb-1">
            <DollarSign className="w-4 h-4 text-green-600" />
            <h2 className="text-sm font-semibold">{t('report.receiptsLedgerStatus')}</h2>
          </div>
          {ledgerStatuses.length === 0 ? (
            <p className="text-xs text-muted-foreground">{t('report.noLedgerRows')}</p>
          ) : (
            <div className="space-y-2">
              {ledgerStatuses.map((s) => (
                <div key={s.payment_status} className="flex items-center justify-between text-xs">
                  <span className="capitalize">{s.payment_status}</span>
                  <span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="border border-border rounded-xl p-4 bg-card/50">
          <div className="flex items-center gap-2 mb-1">
            <DollarSign className="w-4 h-4 text-purple-600" />
            <h2 className="text-sm font-semibold">{t('report.maintenanceFromLedger')}</h2>
          </div>
          <p className="text-[10px] text-muted-foreground mb-2">{t('report.maintenanceFromLedgerHint')}</p>
          {maintenanceStatuses.length === 0 ? (
            <p className="text-xs text-muted-foreground">{t('report.noMaintenanceLedgerRows')}</p>
          ) : (
            <>
              <div className="space-y-2">
                {maintenanceStatuses.map((s) => (
                  <div key={s.payment_status} className="flex items-center justify-between text-xs">
                    <span className="capitalize">{s.payment_status}</span>
                    <span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>
                  </div>
                ))}
              </div>
              {maintenanceLinkSummary && (
                <div className="mt-3 pt-2 border-t border-border/60 text-[10px] text-muted-foreground space-y-1 font-mono">
                  <div className="flex justify-between gap-2">
                    <span>{t('report.maintenanceLinkedToLedger')}</span>
                    <span>
                      {maintenanceLinkSummary.linked.count} · ₹{maintenanceLinkSummary.linked.total.toLocaleString('en-IN')}
                    </span>
                  </div>
                  <div className="flex justify-between gap-2">
                    <span>{t('report.maintenanceNotLinkedToLedger')}</span>
                    <span>
                      {maintenanceLinkSummary.unlinked.count} · ₹{maintenanceLinkSummary.unlinked.total.toLocaleString('en-IN')}
                    </span>
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        <div className="border border-border rounded-xl p-4 bg-card/50">
          <div className="flex items-center gap-2 mb-3">
            <Heart className="w-4 h-4 text-rose-500" />
            <h2 className="text-sm font-semibold">{t('report.donationsStatuses')}</h2>
          </div>
          {donationStatuses.length === 0 ? (
            <p className="text-xs text-muted-foreground">No donations for this month.</p>
          ) : (
            <div className="space-y-2">
              {donationStatuses.map((s) => (
                <div key={s.status} className="flex items-center justify-between text-xs">
                  <span className="capitalize">{s.status}</span>
                  <span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="border border-border rounded-xl p-4 bg-card/50">
          <div className="flex items-center gap-2 mb-1">
            <Split className="w-4 h-4 text-amber-600" />
            <h2 className="text-sm font-semibold">{t('report.splitwiseFromGroups')}</h2>
          </div>
          <p className="text-[10px] text-muted-foreground mb-2">{t('report.splitwiseFromGroupsHint')}</p>
          {splitStatuses.length === 0 ? (
            <p className="text-xs text-muted-foreground">{t('report.noSplitwiseSplits')}</p>
          ) : (
            <div className="space-y-2">
              {splitStatuses.map((s) => (
                <div key={s.status} className="flex items-center justify-between text-xs">
                  <span className="capitalize">{s.status}</span>
                  <span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 mb-6">
        <div className="stat-card items-center text-center"><Users className="w-4 h-4 text-muted-foreground" /><span className="text-xl font-bold font-mono">{stats.totalVisitors}</span><span className="text-[10px] text-muted-foreground">{t('dashboard.visitors')}</span></div>
        <div className="stat-card items-center text-center"><Car className="w-4 h-4 text-muted-foreground" /><span className="text-xl font-bold font-mono">{stats.totalVehicles}</span><span className="text-[10px] text-muted-foreground">{t('dashboard.vehicles')}</span></div>
        <div className="stat-card items-center text-center"><Truck className="w-4 h-4 text-muted-foreground" /><span className="text-xl font-bold font-mono">{stats.totalDeliveries}</span><span className="text-[10px] text-muted-foreground">{t('dashboard.deliveries')}</span></div>
      </div>

      <div className="mb-6">
        <h2 className="text-sm font-semibold mb-3 flex items-center gap-1.5"><Shield className="w-4 h-4 text-primary" /> {t('report.guardShifts')}</h2>
        {shifts.length === 0 ? (
          <p className="text-xs text-muted-foreground text-center py-4">{t('report.noShifts')}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {shifts.map(s => (
              <div key={s.id} className="card-section flex items-center gap-3">
                <div className={`w-2 h-2 rounded-full ${s.logout_time ? 'bg-muted-foreground' : 'bg-success animate-pulse'}`} />
                <div className="flex-1">
                  <p className="text-sm font-medium">{s.guard_name} <span className="font-mono text-xs text-muted-foreground">({s.guard_id})</span></p>
                  <p className="text-xs text-muted-foreground">
                    {format(new Date(s.login_time), 'hh:mm a')}{s.logout_time && ` — ${format(new Date(s.logout_time), 'hh:mm a')}`}{!s.logout_time && ` — ${t('common.active')}`}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div>
        <h2 className="text-sm font-semibold mb-3">{t('report.entries')} ({dayVisitors.length})</h2>
        {dayVisitors.length === 0 ? (
          <p className="text-xs text-muted-foreground text-center py-4">{t('report.noEntries')}</p>
        ) : (
          <div className="flex flex-col gap-1.5">
            {dayVisitors.slice(0, 20).map(v => (
              <div key={v.id} className="card-section py-2.5 flex items-center gap-2">
                <div className={`w-1.5 h-1.5 rounded-full ${v.exitTime ? 'bg-muted-foreground' : 'bg-success'}`} />
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-medium truncate">{v.name} · {t('common.flat')} {v.flatNumber}</p>
                  <p className="text-[10px] text-muted-foreground">{v.category} · {format(new Date(v.entryTime), 'hh:mm a')}</p>
                </div>
              </div>
            ))}
            {dayVisitors.length > 20 && (
              <p className="text-xs text-muted-foreground text-center py-2">+{dayVisitors.length - 20} {t('report.more')}</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ReportPage;
