import { useState, useMemo, useEffect } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { BarChart3, Calendar, CalendarRange, Users, Car, Truck, Shield, IndianRupee, Heart, Split, ClipboardList, DoorOpen, ParkingSquare, Vote, Wrench } from 'lucide-react';
import { format, parse, endOfMonth } from 'date-fns';
import { fmtDate, fmtDateTime, fmtIsoDateToDisplay, fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import { useLanguage } from '@/i18n/LanguageContext';
import ReportDetailModal, { type ReportDetailRow } from '@/components/ReportDetailModal';
import CashFlowStatement from '@/components/CashFlowStatement';
import { DateInput } from '@/components/DateInput';
import { DescriptiveStatCard, DescriptiveValueButton } from '@/components/DescriptiveStatCard';
import { REPORT_MAINTENANCE_METRICS, REPORT_PAGE_METRICS } from '@/lib/descriptiveMetricCopy';
import ExportFormatMenu from '@/components/ExportFormatMenu';
import { downloadMonthlyReport } from '@/lib/monthlyReportExport';
import type { ExportFormat } from '@/lib/reportExportUtils';
import { toast } from 'sonner';

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

type ReportTab = 'financial' | 'visitor' | 'vehicle' | 'all_modules';
type StatementPeriodMode = 'monthly' | 'custom';

const defaultCustomPeriodFrom = () => {
  const y = new Date().getFullYear();
  return `${y}-04-01`;
};

const defaultCustomPeriodTo = () => format(new Date(), 'yyyy-MM-dd');

const REPORT_TABS: { id: ReportTab; labelKey: string; icon: React.ElementType }[] = [
  { id: 'financial', labelKey: 'Financial Reports', icon: IndianRupee },
  { id: 'visitor', labelKey: 'Visitor Reports', icon: Users },
  { id: 'vehicle', labelKey: 'Vehicle Reports', icon: Car },
  { id: 'all_modules', labelKey: 'All Modules', icon: ClipboardList },
];

const ReportPage = () => {
  const { visitors, societyId } = useStore();
  const { t } = useLanguage();
  const [activeTab, setActiveTab] = useState<ReportTab>('financial');
  const [reportMonth, setReportMonth] = useState(format(new Date(), 'yyyy-MM'));
  const [statementPeriodMode, setStatementPeriodMode] = useState<StatementPeriodMode>('monthly');
  const [customPeriodFrom, setCustomPeriodFrom] = useState(defaultCustomPeriodFrom);
  const [customPeriodTo, setCustomPeriodTo] = useState(defaultCustomPeriodTo);
  const [shifts, setShifts] = useState<ShiftRow[]>([]);
  const [financeEntries, setFinanceEntries] = useState<FinanceEntrySummaryRow[]>([]);
  const [ledgerStatuses, setLedgerStatuses] = useState<{ payment_status: string; count: number; total: number }[]>([]);
  const [maintenanceStatuses, setMaintenanceStatuses] = useState<{ payment_status: string; count: number; total: number }[]>([]);
  const [maintenanceLinkSummary, setMaintenanceLinkSummary] = useState<{
    linked: { count: number; total: number };
    unlinked: { count: number; total: number };
  } | null>(null);
  const [donationStatuses, setDonationStatuses] = useState<{ status: string; count: number; total: number }[]>([]);
  const [splitStatuses, setSplitStatuses] = useState<{ status: string; count: number; total: number }[]>([]);
  const [societyName, setSocietyName] = useState('Society');

  // Modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [modalTitle, setModalTitle] = useState('');
  const [modalSubtitle, setModalSubtitle] = useState('');
  const [modalTotal, setModalTotal] = useState<number | undefined>(undefined);
  const [modalRows, setModalRows] = useState<ReportDetailRow[]>([]);

  // Derived date range from month
  const monthDate = useMemo(() => parse(`${reportMonth}-01`, 'yyyy-MM-dd', new Date()), [reportMonth]);
  const monthFrom = useMemo(() => format(monthDate, 'yyyy-MM-dd'), [monthDate]);
  const monthTo = useMemo(() => format(endOfMonth(monthDate), 'yyyy-MM-dd'), [monthDate]);

  const statementPeriodFrom = statementPeriodMode === 'monthly' ? monthFrom : customPeriodFrom;
  const statementPeriodTo = statementPeriodMode === 'monthly' ? monthTo : customPeriodTo;
  const statementPeriodLabel =
    statementPeriodMode === 'monthly'
      ? fmtIsoMonthToDisplay(reportMonth)
      : `${fmtIsoDateToDisplay(statementPeriodFrom)} – ${fmtIsoDateToDisplay(statementPeriodTo)}`;

  useEffect(() => {
    const loadShifts = async () => {
      if (!societyId) { setShifts([]); return; }
      const { data } = await supabase.from('guard_shifts').select('*')
        .eq('society_id', societyId)
        .gte('login_time', `${monthFrom}T00:00:00`)
        .lte('login_time', `${monthTo}T23:59:59`)
        .order('login_time', { ascending: true });
      if (data) setShifts(data);
    };
    loadShifts();
  }, [monthFrom, monthTo, societyId]);

  useEffect(() => {
    const loadSocietyName = async () => {
      if (!societyId) {
        setSocietyName('Society');
        return;
      }
      const { data } = await supabase.from('societies').select('name').eq('id', societyId).maybeSingle();
      setSocietyName(data?.name?.trim() || 'Society');
    };
    void loadSocietyName();
  }, [societyId]);

  useEffect(() => {
    const loadFinance = async () => {
      if (!societyId) {
        setFinanceEntries([]); setLedgerStatuses([]); setMaintenanceStatuses([]);
        setMaintenanceLinkSummary(null); setDonationStatuses([]); setSplitStatuses([]);
        return;
      }
      const { data } = await supabase
        .from('finance_entries')
        .select('id, record_mode, destination, total_amount, aggregate_flat_count, entry_month, created_at, payment_status, payment_method')
        .eq('society_id', societyId)
        .eq('entry_month', reportMonth)
        .order('created_at', { ascending: false })
        .limit(800);
      const rows = (data as FinanceEntrySummaryRow[]) ?? [];
      setFinanceEntries(rows);

      const from = format(monthDate, "yyyy-MM-dd'T'00:00:00");
      const to = format(endOfMonth(monthDate), "yyyy-MM-dd'T'23:59:59");

      // Ledger statuses
      const map = new Map<string, { count: number; total: number }>();
      for (const e of rows) {
        const st = String(e.payment_status ?? 'verified');
        const cur = map.get(st) ?? { count: 0, total: 0 };
        cur.count += 1;
        cur.total += Number(e.total_amount || 0);
        map.set(st, cur);
      }
      setLedgerStatuses([...map.entries()].map(([payment_status, v]) => ({ payment_status, ...v })));

      // Maintenance
      const dueFrom = format(monthDate, 'yyyy-MM-dd');
      const dueTo = format(endOfMonth(monthDate), 'yyyy-MM-dd');
      const { data: chargeRows } = await supabase.from('maintenance_charges').select('id').eq('society_id', societyId);
      const chargeIds = (chargeRows as { id: string }[] | null)?.map((c) => c.id) ?? [];
      if (!chargeIds.length) {
        setMaintenanceStatuses([]); setMaintenanceLinkSummary(null);
      } else {
        const { data: mpRows } = await supabase
          .from('maintenance_payments')
          .select('payment_status, amount, finance_entry_id')
          .in('charge_id', chargeIds)
          .gte('due_date', dueFrom)
          .lte('due_date', dueTo);
        const maintMap = new Map<string, { count: number; total: number }>();
        let linkedCount = 0, linkedTotal = 0, unlinkedCount = 0, unlinkedTotal = 0;
        for (const p of (mpRows as { payment_status?: string; amount: number; finance_entry_id: string | null }[] | null) ?? []) {
          const st = String(p.payment_status ?? 'pending');
          const amt = Number(p.amount || 0);
          const cur = maintMap.get(st) ?? { count: 0, total: 0 };
          cur.count += 1; cur.total += amt; maintMap.set(st, cur);
          if (p.finance_entry_id) { linkedCount += 1; linkedTotal += amt; }
          else { unlinkedCount += 1; unlinkedTotal += amt; }
        }
        setMaintenanceStatuses([...maintMap.entries()].map(([payment_status, v]) => ({ payment_status, ...v })));
        const n = (mpRows ?? []).length;
        setMaintenanceLinkSummary(n > 0 ? { linked: { count: linkedCount, total: linkedTotal }, unlinked: { count: unlinkedCount, total: unlinkedTotal } } : null);
      }

      // Donations
      const { data: campRows } = await supabase.from('donation_campaigns').select('id').eq('society_id', societyId);
      const campIds = (campRows as { id: string }[] | null)?.map((c) => c.id) ?? [];
      if (!campIds.length) { setDonationStatuses([]); }
      else {
        const { data: dp } = await supabase
          .from('donation_payments')
          .select('amount, verified_at, created_at')
          .in('campaign_id', campIds)
          .gte('created_at', from).lte('created_at', to);
        const dMap = new Map<string, { count: number; total: number }>();
        for (const p of (dp as { amount: number; verified_at: string | null }[] | null) ?? []) {
          const st = p.verified_at ? 'verified' : 'pending';
          const cur = dMap.get(st) ?? { count: 0, total: 0 };
          cur.count += 1; cur.total += Number(p.amount || 0); dMap.set(st, cur);
        }
        setDonationStatuses([...dMap.entries()].map(([status, v]) => ({ status, ...v })));
      }

      // Society payments (Record payment) — not event food
      const { data: groups } = await supabase
        .from('expense_groups')
        .select('id')
        .eq('society_id', societyId)
        .eq('group_kind', 'general');
      const groupIds = (groups as { id: string }[] | null)?.map((g) => g.id) ?? [];
      if (!groupIds.length) { setSplitStatuses([]); }
      else {
        const { data: ex } = await supabase
          .from('expenses').select('id, expense_date, record_status, group_id')
          .in('group_id', groupIds).eq('record_status', 'active').eq('expense_category', 'payment')
          .gte('expense_date', dueFrom).lte('expense_date', dueTo);
        const expIds = (ex as { id: string }[] | null)?.map((x) => x.id) ?? [];
        if (!expIds.length) { setSplitStatuses([]); }
        else {
          const { data: splits } = await supabase
            .from('expense_splits').select('amount, is_settled').in('expense_id', expIds);
          const sMap = new Map<string, { count: number; total: number }>();
          for (const s of (splits as { amount: number; is_settled: boolean }[] | null) ?? []) {
            const st = s.is_settled ? 'settled' : 'pending';
            const cur = sMap.get(st) ?? { count: 0, total: 0 };
            cur.count += 1; cur.total += Number(s.amount || 0); sMap.set(st, cur);
          }
          setSplitStatuses([...sMap.entries()].map(([status, v]) => ({ status, ...v })));
        }
      }
    };
    void loadFinance();
  }, [reportMonth, societyId, monthDate]);

  // Visitors for the selected month
  const monthVisitors = useMemo(() => visitors.filter(v => v.entryTime.startsWith(reportMonth)), [visitors, reportMonth]);

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
    return { cashInHand, cashInBank, otherNet, totalBalance: cashInHand + cashInBank + otherNet };
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

  const financeMonthTotal = useMemo(() => financeGroups.reduce((s, g) => s + g.total, 0), [financeGroups]);

  // Visitor stats for the month
  const visitorStats = useMemo(() => ({
    totalVisitors: monthVisitors.filter(v => v.category === 'visitor').length,
    totalVehicles: monthVisitors.filter(v => v.vehicleNumber).length,
    totalDeliveries: monthVisitors.filter(v => v.category === 'delivery' || v.category === 'service').length,
    currentlyInside: monthVisitors.filter(v => !v.exitTime).length,
    uniqueFlats: new Set(monthVisitors.map(v => v.flatNumber)).size,
  }), [monthVisitors]);

  // Modal openers for clickable amount boxes
  const openCashInHandModal = () => {
    const rows: ReportDetailRow[] = financeEntries
      .filter(e => String(e.payment_status) === 'verified' && normalizePaymentChannel(e.payment_method) === 'cash')
      .map(e => ({
        id: e.id,
        label: `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
        sublabel: `Method: Cash`,
        amount: Number(e.total_amount || 0),
        date: fmtDate(e.created_at),
        status: e.destination === 'separate_entry' ? 'expense' : 'receipt',
      }));
    setModalTitle('Cash In Hand — Breakdown');
    setModalSubtitle(`Verified cash transactions for ${reportMonth}`);
    setModalTotal(reportMonthNet.cashInHand);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openBankBalanceModal = () => {
    const rows: ReportDetailRow[] = financeEntries
      .filter(e => String(e.payment_status) === 'verified' && normalizePaymentChannel(e.payment_method) === 'bank')
      .map(e => ({
        id: e.id,
        label: `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
        sublabel: `Method: ${e.payment_method}`,
        amount: Number(e.total_amount || 0),
        date: fmtDate(e.created_at),
        status: e.destination === 'separate_entry' ? 'expense' : 'receipt',
      }));
    setModalTitle('Balance In Bank — Breakdown');
    setModalSubtitle(`Verified bank transactions for ${reportMonth}`);
    setModalTotal(reportMonthNet.cashInBank);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openOtherNetModal = () => {
    const rows: ReportDetailRow[] = financeEntries
      .filter(e => String(e.payment_status) === 'verified' && normalizePaymentChannel(e.payment_method) === 'other')
      .map(e => ({
        id: e.id,
        label: `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
        sublabel: `Method: ${e.payment_method || 'Other'}`,
        amount: Number(e.total_amount || 0),
        date: fmtDate(e.created_at),
        status: e.destination === 'separate_entry' ? 'expense' : 'receipt',
      }));
    setModalTitle('Other Net — Breakdown');
    setModalSubtitle(`Other payment channel transactions for ${reportMonth}`);
    setModalTotal(reportMonthNet.otherNet);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openTotalBalanceModal = () => {
    const rows: ReportDetailRow[] = financeEntries
      .filter(e => String(e.payment_status) === 'verified')
      .map(e => ({
        id: e.id,
        label: `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
        sublabel: `Method: ${e.payment_method || 'N/A'} | Channel: ${normalizePaymentChannel(e.payment_method)}`,
        amount: Number(e.total_amount || 0),
        date: fmtDate(e.created_at),
        status: e.destination === 'separate_entry' ? 'expense' : 'receipt',
      }));
    setModalTitle('Total Balance — All Verified');
    setModalSubtitle(`All verified entries for ${reportMonth}`);
    setModalTotal(reportMonthNet.totalBalance);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openGrossAmountModal = () => {
    const rows: ReportDetailRow[] = financeEntries.map(e => ({
      id: e.id,
      label: `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
      sublabel: `Flats: ${e.aggregate_flat_count} | Method: ${e.payment_method || 'N/A'}`,
      amount: Number(e.total_amount || 0),
      date: fmtDate(e.created_at),
      status: e.payment_status,
    }));
    setModalTitle('Gross Amount — All Entries');
    setModalSubtitle(`All finance entries for ${reportMonth}`);
    setModalTotal(financeMonthTotal);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openLedgerStatusModal = (status: string, count: number, total: number) => {
    const rows: ReportDetailRow[] = financeEntries
      .filter(e => String(e.payment_status ?? 'verified') === status)
      .map(e => ({
        id: e.id,
        label: `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
        sublabel: `Method: ${e.payment_method || 'N/A'}`,
        amount: Number(e.total_amount || 0),
        date: fmtDate(e.created_at),
        status: e.payment_status,
      }));
    setModalTitle(`Ledger — ${status}`);
    setModalSubtitle(`${count} entries with status "${status}"`);
    setModalTotal(total);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openVisitorModal = () => {
    const rows: ReportDetailRow[] = monthVisitors
      .filter(v => v.category === 'visitor')
      .map(v => ({
        id: v.id,
        label: v.name,
        sublabel: `Flat ${v.flatNumber} · ${v.purpose}`,
        date: fmtDateTime(v.entryTime),
        extra: v.exitTime ? `Out: ${fmtDateTime(v.exitTime)}` : 'Still inside',
        status: v.exitTime ? 'exited' : 'inside',
      }));
    setModalTitle('Visitors — Detail');
    setModalSubtitle(`All visitors for ${reportMonth}`);
    setModalTotal(undefined);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openVehicleModal = () => {
    const rows: ReportDetailRow[] = monthVisitors
      .filter(v => v.vehicleNumber)
      .map(v => ({
        id: v.id,
        label: v.vehicleNumber || 'N/A',
        sublabel: `${v.name} · Flat ${v.flatNumber}`,
        date: fmtDateTime(v.entryTime),
        extra: v.category,
        status: v.exitTime ? 'exited' : 'inside',
      }));
    setModalTitle('Vehicles — Detail');
    setModalSubtitle(`All vehicle entries for ${reportMonth}`);
    setModalTotal(undefined);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openDeliveryModal = () => {
    const rows: ReportDetailRow[] = monthVisitors
      .filter(v => v.category === 'delivery' || v.category === 'service')
      .map(v => ({
        id: v.id,
        label: v.name,
        sublabel: `Flat ${v.flatNumber} · ${v.purpose}`,
        date: fmtDateTime(v.entryTime),
        extra: v.vehicleNumber || undefined,
        status: v.exitTime ? 'exited' : 'inside',
      }));
    setModalTitle('Deliveries & Services — Detail');
    setModalSubtitle(`All delivery/service entries for ${reportMonth}`);
    setModalTotal(undefined);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openShiftModal = () => {
    const rows: ReportDetailRow[] = shifts.map(s => ({
      id: s.id,
      label: s.guard_name,
      sublabel: `Guard ID: ${s.guard_id}`,
      date: `${fmtDate(s.login_time)}, ${format(new Date(s.login_time), 'hh:mm a')}`,
      extra: s.logout_time ? `Out: ${format(new Date(s.logout_time), 'hh:mm a')}` : 'Active',
      status: s.logout_time ? 'completed' : 'active',
    }));
    setModalTitle('Guard Shifts — Detail');
    setModalSubtitle(`All guard shifts for ${reportMonth}`);
    setModalTotal(undefined);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openDonationModal = () => {
    const total = donationStatuses.reduce((s, d) => s + d.total, 0);
    const rows: ReportDetailRow[] = donationStatuses.map((s, i) => ({
      id: `don-${i}`,
      label: `Donations — ${s.status}`,
      sublabel: `${s.count} payment(s)`,
      amount: s.total,
      status: s.status,
    }));
    setModalTitle('Donations — Summary');
    setModalSubtitle(`Donation payments for ${reportMonth}`);
    setModalTotal(total);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openSplitModal = () => {
    const total = splitStatuses.reduce((s, d) => s + d.total, 0);
    const rows: ReportDetailRow[] = splitStatuses.map((s, i) => ({
      id: `split-${i}`,
      label: `Splits — ${s.status}`,
      sublabel: `${s.count} split(s)`,
      amount: s.total,
      status: s.status,
    }));
    setModalTitle('Society payment splits — Summary');
    setModalSubtitle(`Record payment entries for ${reportMonth}`);
    setModalTotal(total);
    setModalRows(rows);
    setModalOpen(true);
  };

  const exportReport = (format: ExportFormat) => {
    downloadMonthlyReport(format, {
      societyName,
      reportMonth,
      tab: activeTab,
      financeEntries,
      financeGroups,
      financeMonthTotal,
      reportMonthNet,
      visitors: monthVisitors,
      visitorStats,
    });
    toast.success(`${format.toUpperCase()} downloaded`);
  };

  // ─── RENDER ───────────────────────────────────────────────────────────────────
  return (
    <div className="page-container">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <BarChart3 className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('report.title')}</h1>
            <p className="text-xs text-muted-foreground">{t('report.subtitle')}</p>
          </div>
        </div>
        <ExportFormatMenu label="Export" onExport={exportReport} />
      </div>

      {/* Month Selector */}
      <div className="flex items-center gap-2 mb-4">
        <Calendar className="w-4 h-4 text-muted-foreground" />
        <input
          type="month"
          className="input-field text-sm flex-1"
          value={reportMonth}
          onChange={(e) => setReportMonth(e.target.value)}
        />
      </div>

      {/* Report Type Tabs */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 mb-5 scrollbar-hide">
        {REPORT_TABS.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium whitespace-nowrap transition-all ${
              activeTab === tab.id
                ? 'bg-primary text-primary-foreground shadow-sm'
                : 'bg-secondary text-secondary-foreground hover:bg-muted'
            }`}
          >
            <tab.icon className="w-3.5 h-3.5" />
            {tab.labelKey}
          </button>
        ))}
      </div>

      {/* ═══ FINANCIAL REPORTS TAB ═══ */}
      {activeTab === 'financial' && (
        <div>
          {/* Net Summary - Clickable Boxes */}
          <div className="mb-4 rounded-lg border border-border bg-card/40 p-3">
            <p className="text-[11px] font-medium text-foreground mb-2">{t('report.financeNetTitle')}</p>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
              <DescriptiveStatCard
                {...REPORT_PAGE_METRICS.reportCashInHand}
                caption={t('report.cashInHand')}
                value={`₹${reportMonthNet.cashInHand.toLocaleString('en-IN')}`}
                valueClassName="text-sm font-mono"
                onNavigate={openCashInHandModal}
                navigateLabel="View entries"
                className="!p-2.5 rounded-md border border-border/80 bg-background/60 shadow-none"
              />
              <DescriptiveStatCard
                {...REPORT_PAGE_METRICS.reportCashInBank}
                caption={t('report.balanceInBank')}
                value={`₹${reportMonthNet.cashInBank.toLocaleString('en-IN')}`}
                valueClassName="text-sm font-mono"
                onNavigate={openBankBalanceModal}
                navigateLabel="View entries"
                className="!p-2.5 rounded-md border border-border/80 bg-background/60 shadow-none"
              />
              <DescriptiveStatCard
                {...REPORT_PAGE_METRICS.reportOtherNet}
                caption={t('report.otherNet')}
                value={`₹${reportMonthNet.otherNet.toLocaleString('en-IN')}`}
                valueClassName="text-sm font-mono"
                onNavigate={openOtherNetModal}
                navigateLabel="View entries"
                className="!p-2.5 rounded-md border border-border/80 bg-background/60 shadow-none"
              />
              <DescriptiveStatCard
                {...REPORT_PAGE_METRICS.reportTotalBalance}
                caption={t('report.totalBalance')}
                value={`₹${reportMonthNet.totalBalance.toLocaleString('en-IN')}`}
                valueClassName="text-sm font-mono text-primary"
                onNavigate={openTotalBalanceModal}
                navigateLabel="View entries"
                className="!p-2.5 rounded-md border border-primary/30 bg-primary/5 shadow-none"
              />
            </div>
          </div>

          {/* Cash Flow Statement with drill-down to cash/bank statements */}
          <div className="mb-4 rounded-lg border border-border bg-card/40 p-3">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between mb-3">
              <div>
                <p className="text-[11px] font-medium text-foreground">Statement period</p>
                <p className="text-[10px] text-muted-foreground">Cash flow, cash & bank statements use this range</p>
              </div>
              <div className="flex gap-1.5">
                <button
                  type="button"
                  onClick={() => setStatementPeriodMode('monthly')}
                  className={`flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium transition-all ${
                    statementPeriodMode === 'monthly'
                      ? 'bg-primary text-primary-foreground'
                      : 'bg-secondary text-secondary-foreground hover:bg-muted'
                  }`}
                >
                  <Calendar className="w-3 h-3" />
                  Monthly
                </button>
                <button
                  type="button"
                  onClick={() => setStatementPeriodMode('custom')}
                  className={`flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium transition-all ${
                    statementPeriodMode === 'custom'
                      ? 'bg-primary text-primary-foreground'
                      : 'bg-secondary text-secondary-foreground hover:bg-muted'
                  }`}
                >
                  <CalendarRange className="w-3 h-3" />
                  Date range
                </button>
              </div>
            </div>
            {statementPeriodMode === 'monthly' ? (
              <div className="flex items-center gap-2">
                <Calendar className="w-4 h-4 text-muted-foreground shrink-0" />
                <input
                  type="month"
                  className="input-field text-sm flex-1"
                  value={reportMonth}
                  onChange={(e) => setReportMonth(e.target.value)}
                />
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground mb-1 block">From</label>
                  <DateInput className="input-field text-sm w-full" value={customPeriodFrom} onChange={(e) => setCustomPeriodFrom(e.target.value)} />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground mb-1 block">To</label>
                  <DateInput className="input-field text-sm w-full" value={customPeriodTo} onChange={(e) => setCustomPeriodTo(e.target.value)} />
                </div>
              </div>
            )}
            {statementPeriodFrom > statementPeriodTo && (
              <p className="text-[10px] text-destructive mt-2">End date must be on or after start date.</p>
            )}
          </div>
          <CashFlowStatement
            periodFrom={statementPeriodFrom}
            periodTo={statementPeriodTo}
            periodLabel={statementPeriodLabel}
          />

          {/* Gross clickable */}
          <DescriptiveStatCard
            {...REPORT_PAGE_METRICS.financeGross}
            caption={t('report.financeGross')}
            className="w-full mb-4 rounded-lg border border-border bg-muted/20 !p-3 shadow-none"
            value={
              <span className="text-sm font-mono font-semibold">
                ₹{financeMonthTotal.toLocaleString('en-IN')} · {financeEntries.length} {t('report.entryCountLabel')}
              </span>
            }
            valueClassName="text-sm"
            onNavigate={openGrossAmountModal}
            navigateLabel="View ledger entries"
          />

          {/* Ledger Table */}
          {financeGroups.length === 0 ? (
            <p className="text-xs text-muted-foreground text-center py-4">{t('report.noLedgerRows')}</p>
          ) : (
            <div className="overflow-x-auto mb-5 border border-border rounded-xl p-3">
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

          {/* Ledger & Maintenance Status Cards - Clickable */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-5">
            <div className="border border-border rounded-xl p-4 bg-card/50">
              <div className="flex items-center gap-2 mb-2">
                <IndianRupee className="w-4 h-4 text-green-600" />
                <h2 className="text-sm font-semibold">{t('report.receiptsLedgerStatus')}</h2>
              </div>
              {ledgerStatuses.length === 0 ? (
                <p className="text-xs text-muted-foreground">{t('report.noLedgerRows')}</p>
              ) : (
                <div className="space-y-2">
                  {ledgerStatuses.map((s) => (
                    <button key={s.payment_status} onClick={() => openLedgerStatusModal(s.payment_status, s.count, s.total)} className="w-full flex items-center justify-between text-xs p-2 rounded-lg hover:bg-muted/50 transition-colors cursor-pointer">
                      <span className="capitalize">{s.payment_status}</span>
                      <span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            <div className="border border-border rounded-xl p-4 bg-card/50">
              <div className="flex items-center gap-2 mb-1">
                <IndianRupee className="w-4 h-4 text-purple-600" />
                <h2 className="text-sm font-semibold">{t('report.maintenanceFromLedger')}</h2>
              </div>
              <p className="text-[10px] text-muted-foreground mb-2">{t('report.maintenanceFromLedgerHint')}</p>
              {maintenanceStatuses.length === 0 ? (
                <p className="text-xs text-muted-foreground">{t('report.noMaintenanceLedgerRows')}</p>
              ) : (
                <>
                  <div className="space-y-2">
                    {maintenanceStatuses.map((s) => (
                      <div key={s.payment_status} className="flex items-center justify-between text-xs gap-2">
                        <span className="capitalize">{s.payment_status}</span>
                        <DescriptiveValueButton
                          {...REPORT_MAINTENANCE_METRICS.maintenanceStatus}
                          title={`Maintenance — ${s.payment_status}`}
                          description={`${REPORT_MAINTENANCE_METRICS.maintenanceStatus.description} Status: ${s.payment_status}.`}
                          howCalculated={`${REPORT_MAINTENANCE_METRICS.maintenanceStatus.howCalculated} This row: ${s.count} payment(s).`}
                          value={<span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>}
                          valueClassName="font-mono text-xs font-semibold"
                        />
                      </div>
                    ))}
                  </div>
                  {maintenanceLinkSummary && (
                    <div className="mt-3 pt-2 border-t border-border/60 text-[10px] text-muted-foreground space-y-1 font-mono">
                      <div className="flex justify-between gap-2 items-center">
                        <span>{t('report.maintenanceLinkedToLedger')}</span>
                        <DescriptiveValueButton
                          {...REPORT_MAINTENANCE_METRICS.maintenanceLinked}
                          value={
                            <span>
                              {maintenanceLinkSummary.linked.count} · ₹{maintenanceLinkSummary.linked.total.toLocaleString('en-IN')}
                            </span>
                          }
                          valueClassName="font-mono text-[10px] font-semibold"
                        />
                      </div>
                      <div className="flex justify-between gap-2 items-center">
                        <span>{t('report.maintenanceNotLinkedToLedger')}</span>
                        <DescriptiveValueButton
                          {...REPORT_MAINTENANCE_METRICS.maintenanceUnlinked}
                          value={
                            <span>
                              {maintenanceLinkSummary.unlinked.count} · ₹{maintenanceLinkSummary.unlinked.total.toLocaleString('en-IN')}
                            </span>
                          }
                          valueClassName="font-mono text-[10px] font-semibold"
                        />
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>

          {/* Donations & Splits - Clickable */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.moduleDonations}
              title={t('report.donationsStatuses')}
              caption={t('report.donationsStatuses')}
              icon={
                <div className="flex items-center gap-2">
                  <Heart className="w-4 h-4 text-rose-500" />
                  <h2 className="text-sm font-semibold">{t('report.donationsStatuses')}</h2>
                </div>
              }
              value={donationStatuses.reduce((s, d) => s + d.count, 0)}
              onNavigate={openDonationModal}
              navigateLabel="View donation detail"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              {donationStatuses.length === 0 ? (
                <p className="text-xs text-muted-foreground mt-2">No donations for this month.</p>
              ) : (
                <div className="space-y-2 mt-2 w-full">
                  {donationStatuses.map((s) => (
                    <div key={s.status} className="flex items-center justify-between text-xs">
                      <span className="capitalize">{s.status}</span>
                      <span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>
                    </div>
                  ))}
                </div>
              )}
            </DescriptiveStatCard>

            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.moduleExpenseSplits}
              title={t('report.splitwiseFromGroups')}
              caption={t('report.splitwiseFromGroups')}
              icon={
                <div className="flex items-center gap-2">
                  <Split className="w-4 h-4 text-amber-600" />
                  <h2 className="text-sm font-semibold">{t('report.splitwiseFromGroups')}</h2>
                </div>
              }
              value={splitStatuses.reduce((s, d) => s + d.count, 0)}
              onNavigate={openSplitModal}
              navigateLabel="View split detail"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">{t('report.splitwiseFromGroupsHint')}</p>
              {splitStatuses.length === 0 ? (
                <p className="text-xs text-muted-foreground mt-2">{t('report.noSplitwiseSplits')}</p>
              ) : (
                <div className="space-y-2 mt-2 w-full">
                  {splitStatuses.map((s) => (
                    <div key={s.status} className="flex items-center justify-between text-xs">
                      <span className="capitalize">{s.status}</span>
                      <span className="font-mono">{s.count} · ₹{s.total.toLocaleString('en-IN')}</span>
                    </div>
                  ))}
                </div>
              )}
            </DescriptiveStatCard>
          </div>
        </div>
      )}

      {/* ═══ VISITOR REPORTS TAB ═══ */}
      {activeTab === 'visitor' && (
        <div>
          {/* Stat boxes - clickable */}
          <div className="grid grid-cols-3 gap-2 mb-5">
            <DescriptiveStatCard
              title={t('dashboard.visitors')}
              caption={t('dashboard.visitors')}
              description="Visitor log entries in the selected report month."
              howCalculated="Count of visitor records in the month filter."
              contentAlign="center"
              icon={<Users className="w-4 h-4 text-muted-foreground" />}
              value={visitorStats.totalVisitors}
              onNavigate={openVisitorModal}
              navigateLabel="View visitor list"
              className="p-3"
            />
            <DescriptiveStatCard
              title={t('dashboard.deliveries')}
              caption={t('dashboard.deliveries')}
              description="Delivery personnel entries in the selected month."
              howCalculated="Visitors categorised as deliveries in the month."
              contentAlign="center"
              icon={<Truck className="w-4 h-4 text-muted-foreground" />}
              value={visitorStats.totalDeliveries}
              onNavigate={openDeliveryModal}
              navigateLabel="View delivery list"
              className="p-3"
            />
            <DescriptiveStatCard
              title={t('dashboard.insideNow')}
              caption={t('dashboard.insideNow')}
              description="Visitors who entered but have no exit time recorded yet."
              howCalculated="Entries in month with exit_time null."
              contentAlign="center"
              icon={<DoorOpen className="w-4 h-4 text-muted-foreground" />}
              value={visitorStats.currentlyInside}
              className="p-3"
            />
          </div>

          {/* Visitor entries list */}
          <h2 className="text-sm font-semibold mb-3">Entries ({monthVisitors.length})</h2>
          {monthVisitors.length === 0 ? (
            <p className="text-xs text-muted-foreground text-center py-4">{t('report.noEntries')}</p>
          ) : (
            <div className="flex flex-col gap-1.5">
              {monthVisitors.slice(0, 30).map(v => (
                <div key={v.id} className="card-section py-2.5 flex items-center gap-2">
                  <div className={`w-1.5 h-1.5 rounded-full ${v.exitTime ? 'bg-muted-foreground' : 'bg-success'}`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium truncate">{v.name} <span className="text-muted-foreground">· {v.flatNumber}</span></p>
                    <p className="text-[10px] text-muted-foreground">{v.category} · {fmtDateTime(v.entryTime)}</p>
                  </div>
                  {v.vehicleNumber && <span className="text-[10px] font-mono bg-muted px-1.5 py-0.5 rounded">{v.vehicleNumber}</span>}
                </div>
              ))}
              {monthVisitors.length > 30 && (
                <p className="text-[10px] text-muted-foreground text-center py-2">+ {monthVisitors.length - 30} more entries</p>
              )}
            </div>
          )}
        </div>
      )}

      {/* ═══ VEHICLE REPORTS TAB ═══ */}
      {activeTab === 'vehicle' && (
        <div>
          <div className="grid grid-cols-2 gap-2 mb-5">
            <DescriptiveStatCard
              title="Vehicle entries"
              caption="Vehicle entries"
              description="Visitor log rows that include a vehicle number in the period."
              howCalculated="Count of month visitors with vehicle_number set."
              contentAlign="center"
              icon={<Car className="w-4 h-4 text-muted-foreground" />}
              value={visitorStats.totalVehicles}
              onNavigate={openVehicleModal}
              navigateLabel="View vehicles"
              className="p-3"
            />
            <DescriptiveStatCard
              title="Unique flats"
              caption="Unique flats"
              description="Distinct flat numbers that had vehicle entries in the period."
              howCalculated="Distinct flat_number on vehicle visitor rows."
              contentAlign="center"
              icon={<Users className="w-4 h-4 text-muted-foreground" />}
              value={visitorStats.uniqueFlats}
              className="p-3"
            />
          </div>

          {/* Vehicle entries list */}
          <h2 className="text-sm font-semibold mb-3">Vehicle Entries</h2>
          {(() => {
            const vehicleEntries = monthVisitors.filter(v => v.vehicleNumber);
            return vehicleEntries.length === 0 ? (
              <p className="text-xs text-muted-foreground text-center py-4">No vehicle entries this month</p>
            ) : (
              <div className="flex flex-col gap-1.5">
                {vehicleEntries.slice(0, 30).map(v => (
                  <div key={v.id} className="card-section py-2.5 flex items-center gap-2">
                    <Car className="w-4 h-4 text-muted-foreground shrink-0" />
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-mono font-semibold">{v.vehicleNumber}</p>
                      <p className="text-[10px] text-muted-foreground">{v.name} · Flat {v.flatNumber} · {fmtDateTime(v.entryTime)}</p>
                    </div>
                    <span className={`text-[10px] px-1.5 py-0.5 rounded-full ${v.exitTime ? 'bg-muted text-muted-foreground' : 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'}`}>
                      {v.exitTime ? 'Exited' : 'Inside'}
                    </span>
                  </div>
                ))}
                {vehicleEntries.length > 30 && (
                  <p className="text-[10px] text-muted-foreground text-center py-2">+ {vehicleEntries.length - 30} more</p>
                )}
              </div>
            );
          })()}
        </div>
      )}

      {/* ═══ ALL MODULES TAB ═══ */}
      {activeTab === 'all_modules' && (
        <div>
          <p className="text-xs text-muted-foreground mb-4">Summary across all modules for {reportMonth}</p>

          <div className="grid grid-cols-2 gap-3">
            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.financeGross}
              title="Finance"
              caption="Finance"
              icon={
                <div className="flex items-center gap-2">
                  <IndianRupee className="w-4 h-4 text-green-600" />
                  <span className="text-xs font-semibold">Finance</span>
                </div>
              }
              value={`₹${financeMonthTotal.toLocaleString('en-IN')}`}
              onNavigate={openGrossAmountModal}
              navigateLabel="View finance detail"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">{financeEntries.length} entries</p>
            </DescriptiveStatCard>

            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.guardShifts}
              title="Guard Shifts"
              caption="Guard Shifts"
              icon={
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-blue-600" />
                  <span className="text-xs font-semibold">Guard Shifts</span>
                </div>
              }
              value={shifts.length}
              onNavigate={openShiftModal}
              navigateLabel="View shift list"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">Login/Logout records</p>
            </DescriptiveStatCard>

            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.moduleVisitors}
              title="Visitors"
              caption="Visitors"
              icon={
                <div className="flex items-center gap-2">
                  <Users className="w-4 h-4 text-indigo-600" />
                  <span className="text-xs font-semibold">Visitors</span>
                </div>
              }
              value={visitorStats.totalVisitors}
              onNavigate={openVisitorModal}
              navigateLabel="View visitors"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">Guest entries</p>
            </DescriptiveStatCard>

            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.moduleVehicles}
              title="Vehicles"
              caption="Vehicles"
              icon={
                <div className="flex items-center gap-2">
                  <Car className="w-4 h-4 text-orange-600" />
                  <span className="text-xs font-semibold">Vehicles</span>
                </div>
              }
              value={visitorStats.totalVehicles}
              onNavigate={openVehicleModal}
              navigateLabel="View vehicles"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">Vehicle entries</p>
            </DescriptiveStatCard>

            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.moduleDeliveries}
              title="Deliveries"
              caption="Deliveries"
              icon={
                <div className="flex items-center gap-2">
                  <Truck className="w-4 h-4 text-teal-600" />
                  <span className="text-xs font-semibold">Deliveries</span>
                </div>
              }
              value={visitorStats.totalDeliveries}
              onNavigate={openDeliveryModal}
              navigateLabel="View deliveries"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">Delivery/Service entries</p>
            </DescriptiveStatCard>

            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.moduleDonations}
              title="Donations"
              caption="Donations"
              icon={
                <div className="flex items-center gap-2">
                  <Heart className="w-4 h-4 text-rose-500" />
                  <span className="text-xs font-semibold">Donations</span>
                </div>
              }
              value={donationStatuses.reduce((s, d) => s + d.count, 0)}
              onNavigate={openDonationModal}
              navigateLabel="View donations"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">
                ₹{donationStatuses.reduce((s, d) => s + d.total, 0).toLocaleString('en-IN')}
              </p>
            </DescriptiveStatCard>

            <DescriptiveStatCard
              {...REPORT_PAGE_METRICS.moduleExpenseSplits}
              title="Expense Splits"
              caption="Expense Splits"
              icon={
                <div className="flex items-center gap-2">
                  <Split className="w-4 h-4 text-amber-600" />
                  <span className="text-xs font-semibold">Expense Splits</span>
                </div>
              }
              value={splitStatuses.reduce((s, d) => s + d.count, 0)}
              onNavigate={openSplitModal}
              navigateLabel="View splits"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">
                ₹{splitStatuses.reduce((s, d) => s + d.total, 0).toLocaleString('en-IN')}
              </p>
            </DescriptiveStatCard>

            {/* Parking - placeholder */}
            <div className="border border-border rounded-xl p-4 bg-card/50 opacity-60">
              <div className="flex items-center gap-2 mb-2">
                <ParkingSquare className="w-4 h-4 text-cyan-600" />
                <h3 className="text-xs font-semibold">Parking</h3>
              </div>
              <p className="text-[10px] text-muted-foreground">Coming soon</p>
            </div>

            {/* Polls - placeholder */}
            <div className="border border-border rounded-xl p-4 bg-card/50 opacity-60">
              <div className="flex items-center gap-2 mb-2">
                <Vote className="w-4 h-4 text-violet-600" />
                <h3 className="text-xs font-semibold">Polls & Elections</h3>
              </div>
              <p className="text-[10px] text-muted-foreground">Coming soon</p>
            </div>

            {/* Maintenance - placeholder */}
            <div className="border border-border rounded-xl p-4 bg-card/50 opacity-60">
              <div className="flex items-center gap-2 mb-2">
                <Wrench className="w-4 h-4 text-gray-600" />
                <h3 className="text-xs font-semibold">Maintenance Requests</h3>
              </div>
              <p className="text-[10px] text-muted-foreground">Coming soon</p>
            </div>
          </div>
        </div>
      )}

      {/* Detail Modal */}
      <ReportDetailModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={modalTitle}
        subtitle={modalSubtitle}
        totalAmount={modalTotal}
        rows={modalRows}
      />
    </div>
  );
};

export default ReportPage;
