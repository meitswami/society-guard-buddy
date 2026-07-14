import { useState, useMemo, useEffect, useCallback, useRef } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { BarChart3, Calendar, CalendarRange, ChevronDown, Users, Car, Truck, Shield, IndianRupee, Heart, ClipboardList, DoorOpen, ParkingSquare, Vote, Wrench, Search, Table2 } from 'lucide-react';
import MetadataReportEngine from '@/components/reporting/MetadataReportEngine';
import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import { FULL_ADMIN_PERMISSIONS } from '@/lib/adminPermissions';
import { format, parse, endOfMonth } from 'date-fns';
import { fmtDate, fmtDateTime, fmtIsoDateToDisplay, fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import { useLanguage } from '@/i18n/LanguageContext';
import ReportDetailModal, { type ReportDetailRow } from '@/components/ReportDetailModal';
import CashFlowStatement from '@/components/CashFlowStatement';
import FinancePeriodHeadTables from '@/components/FinancePeriodHeadTables';
import { FinanceFlatReportTab } from '@/components/finance/FinanceFlatReportTab';
import { DateInput } from '@/components/DateInput';
import { useSocietyFinanceData } from '@/hooks/useSocietyFinanceData';
import { useReportModuleAggregations } from '@/hooks/useReportModuleAggregations';
import { useSocietyOpeningBalanceAnchors } from '@/hooks/useSocietyOpeningBalanceAnchors';
import { useFinanceFlatReport } from '@/hooks/finance/useFinanceFlatReport';
import { buildFlatReportRows } from '@/lib/financeFlatReport';
import {
  computeFinancePeriodReport,
  defaultFinancePeriodFrom,
  defaultFinancePeriodTo,
  FINANCE_REPORTING_EARLIEST_MONTH,
} from '@/lib/financePeriodReport';
import { dateInInclusiveRange, ledgerTransactionDate } from '@/lib/financeDates';
import { formatLedgerFieldLabel } from '@/lib/financeLedgerDisplay';
import {
  computeLedgerInflowGroups,
  filterLedgerByTransactionDateRange,
} from '@/lib/reportAggregations';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import { REPORT_PAGE_METRICS } from '@/lib/descriptiveMetricCopy';
import FinancePeriodReportSendPanel from '@/components/FinancePeriodReportSendPanel';
import ExportFormatMenu from '@/components/ExportFormatMenu';
import SharePdfWhatsAppButton from '@/components/SharePdfWhatsAppButton';
import { buildMonthlyReportPdfBlob, downloadMonthlyReport, type ReportExportContext } from '@/lib/monthlyReportExport';
import type { ExportFormat } from '@/lib/reportExportUtils';
import { filterLedgerEntries, filterShiftRows, filterVisitorRows } from '@/lib/reportQueryFilter';
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { openBlobInNewTab } from '@/lib/reportExportUtils';
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

type ReportTab = 'financial' | 'visitor' | 'vehicle' | 'all_modules' | 'engine';
type StatementPeriodMode = 'monthly' | 'custom';
type FinancialReportKind =
  | 'collection_receipts'
  | 'expenses'
  | 'flat_wise'
  | 'cash_flow'
  | 'donation_statuses';

const FINANCIAL_REPORT_OPTIONS: { id: FinancialReportKind; label: string }[] = [
  { id: 'collection_receipts', label: 'Collection receipts (Head wise)' },
  { id: 'expenses', label: 'Expenses (Head wise)' },
  { id: 'flat_wise', label: 'Flat wise Financial Report' },
  { id: 'cash_flow', label: 'Cash Flow Statement' },
  { id: 'donation_statuses', label: 'Donation statuses' },
];

const REPORT_TABS: { id: Exclude<ReportTab, 'financial'>; labelKey: string; icon: React.ElementType }[] = [
  { id: 'visitor', labelKey: 'Visitor Reports', icon: Users },
  { id: 'vehicle', labelKey: 'Vehicle Reports', icon: Car },
  { id: 'all_modules', labelKey: 'All Modules', icon: ClipboardList },
  { id: 'engine', labelKey: 'Custom Reports', icon: Table2 },
];

const ReportPage = ({
  adminName = 'Admin',
  permissions = FULL_ADMIN_PERMISSIONS,
  initialSearchQuery,
  onInitialSearchConsumed,
}: {
  adminName?: string;
  permissions?: AdminPanelPermissions;
  initialSearchQuery?: string;
  onInitialSearchConsumed?: () => void;
} = {}) => {
  const { visitors, societyId } = useStore();
  const { t } = useLanguage();
  const [activeTab, setActiveTab] = useState<ReportTab>('financial');
  const [selectedFinancialReports, setSelectedFinancialReports] = useState<FinancialReportKind[]>([
    'collection_receipts',
  ]);
  const [searchQuery, setSearchQuery] = useState('');

  const toggleFinancialReport = (id: FinancialReportKind) => {
    setSelectedFinancialReports((prev) => {
      if (prev.includes(id)) {
        if (prev.length === 1) return prev;
        return prev.filter((k) => k !== id);
      }
      return FINANCIAL_REPORT_OPTIONS.map((o) => o.id).filter((k) => k === id || prev.includes(k));
    });
  };

  const selectedFinancialLabels = FINANCIAL_REPORT_OPTIONS.filter((o) =>
    selectedFinancialReports.includes(o.id),
  ).map((o) => o.label);

  useEffect(() => {
    if (!initialSearchQuery) return;
    setSearchQuery(initialSearchQuery);
    onInitialSearchConsumed?.();
  }, [initialSearchQuery, onInitialSearchConsumed]);
  const [reportMonth, setReportMonth] = useState(format(new Date(), 'yyyy-MM'));
  const [statementPeriodMode, setStatementPeriodMode] = useState<StatementPeriodMode>('monthly');
  const [customPeriodFrom, setCustomPeriodFrom] = useState(defaultFinancePeriodFrom);
  const [customPeriodTo, setCustomPeriodTo] = useState(defaultFinancePeriodTo);
  const [shifts, setShifts] = useState<ShiftRow[]>([]);
  const [flatReportFrom, setFlatReportFrom] = useState(defaultFinancePeriodFrom);
  const [flatReportTo, setFlatReportTo] = useState(defaultFinancePeriodTo);
  const [flatReportSelectedFlat, setFlatReportSelectedFlat] = useState('all');

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

  const {
    payments,
    societyLedgerEntries,
    expenseCategoryById,
    reserveTransfers,
    loading: financeLoading,
    societyName,
    flats,
    charges,
    ledgerEntries,
    primaryByFlatId,
    isLoading: financeCoreLoading,
  } = useSocietyFinanceData(societyId, 'Report');
  const { anchors: openingBalanceAnchors } = useSocietyOpeningBalanceAnchors(societyId);
  const {
    donationStatuses,
  } = useReportModuleAggregations(
    societyId,
    statementPeriodFrom,
    statementPeriodTo,
    activeTab === 'financial' || activeTab === 'all_modules',
  );
  const {
    expenses: flatReportExpenses,
    splits: flatReportSplits,
    isLoading: flatReportLoading,
  } = useFinanceFlatReport(
    societyId,
    activeTab === 'financial' && selectedFinancialReports.includes('flat_wise'),
  );

  useEffect(() => {
    setFlatReportFrom(statementPeriodFrom);
    setFlatReportTo(statementPeriodTo);
  }, [statementPeriodFrom, statementPeriodTo]);

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

  // Visitors for the selected month
  const monthVisitors = useMemo(() => visitors.filter(v => v.entryTime.startsWith(reportMonth)), [visitors, reportMonth]);
  const searchedMonthVisitors = useMemo(
    () => filterVisitorRows(monthVisitors, searchQuery),
    [monthVisitors, searchQuery],
  );
  const searchedShifts = useMemo(() => filterShiftRows(shifts, searchQuery), [shifts, searchQuery]);

  const periodReport = useMemo(
    () =>
      statementPeriodFrom > statementPeriodTo
        ? null
        : computeFinancePeriodReport({
            periodFrom: statementPeriodFrom,
            periodTo: statementPeriodTo,
            payments,
            ledgerEntries: societyLedgerEntries,
            expenseCategoryById,
            openingBalanceAnchors,
          }),
    [statementPeriodFrom, statementPeriodTo, payments, societyLedgerEntries, expenseCategoryById, openingBalanceAnchors],
  );

  const flatReportRows = useMemo(
    () =>
      activeTab === 'financial' && flats.length > 0
        ? buildFlatReportRows({
            from: flatReportFrom,
            to: flatReportTo,
            selectedFlat: flatReportSelectedFlat,
            payments,
            ledgerEntries,
            flatReportExpenses,
            flatReportSplits,
            flats,
            primaryByFlatId,
            charges,
          })
        : [],
    [
      activeTab,
      flats,
      charges,
      ledgerEntries,
      flatReportFrom,
      flatReportTo,
      flatReportSelectedFlat,
      payments,
      flatReportExpenses,
      flatReportSplits,
      primaryByFlatId,
    ],
  );

  const periodFinanceEntries = useMemo(
    () =>
      statementPeriodFrom > statementPeriodTo
        ? []
        : filterLedgerByTransactionDateRange(societyLedgerEntries, statementPeriodFrom, statementPeriodTo),
    [societyLedgerEntries, statementPeriodFrom, statementPeriodTo],
  );

  const searchedPeriodFinanceEntries = useMemo(
    () => filterLedgerEntries(periodFinanceEntries, searchQuery),
    [periodFinanceEntries, searchQuery],
  );

  const financeGroups = useMemo(
    () => computeLedgerInflowGroups(searchedPeriodFinanceEntries),
    [searchedPeriodFinanceEntries],
  );

  const financePeriodTotal = useMemo(() => financeGroups.reduce((s, g) => s + g.total, 0), [financeGroups]);

  const monthFinanceEntries = useMemo(
    () =>
      societyLedgerEntries.filter((e) =>
        dateInInclusiveRange(ledgerTransactionDate(e), monthFrom, monthTo),
      ),
    [societyLedgerEntries, monthFrom, monthTo],
  );

  const searchedMonthFinanceEntries = useMemo(
    () => filterLedgerEntries(monthFinanceEntries, searchQuery),
    [monthFinanceEntries, searchQuery],
  );

  const monthFinanceTotal = useMemo(
    () => searchedMonthFinanceEntries.reduce((s, e) => s + Number(e.total_amount || 0), 0),
    [searchedMonthFinanceEntries],
  );

  const displayVisitors = searchedMonthVisitors;
  const displayVehicleEntries = useMemo(
    () => searchedMonthVisitors.filter((v) => v.vehicleNumber),
    [searchedMonthVisitors],
  );

  // Visitor stats for the month (respects search when active)
  const visitorStats = useMemo(() => ({
    totalVisitors: displayVisitors.filter(v => v.category === 'visitor').length,
    totalVehicles: displayVisitors.filter(v => v.vehicleNumber).length,
    totalDeliveries: displayVisitors.filter(v => v.category === 'delivery' || v.category === 'service').length,
    currentlyInside: displayVisitors.filter(v => !v.exitTime).length,
    uniqueFlats: new Set(displayVisitors.map(v => v.flatNumber)).size,
  }), [displayVisitors]);

  const reportSearchPlaceholder = useMemo(() => {
    switch (activeTab) {
      case 'financial':
        return t('report.searchPlaceholderFinancial');
      case 'visitor':
        return t('report.searchPlaceholderVisitor');
      case 'vehicle':
        return t('report.searchPlaceholderVehicle');
      case 'engine':
        return 'Search custom report columns…';
      default:
        return t('report.searchPlaceholderAll');
    }
  }, [activeTab, t]);

  const engineExportRef = useRef<((format: ExportFormat) => Promise<void>) | null>(null);
  const onEngineExportReady = useCallback((exporter: ((format: ExportFormat) => Promise<void>) | null) => {
    engineExportRef.current = exporter;
  }, []);

  const openMonthFinanceModal = () => {
    const rows: ReportDetailRow[] = searchedMonthFinanceEntries.map((e) => ({
      id: e.id,
      label: `${formatLedgerFieldLabel(e.record_mode)} → ${formatLedgerFieldLabel(e.destination)}`,
      sublabel: `Flats: ${e.aggregate_flat_count ?? 0} | Method: ${e.payment_method || 'N/A'}`,
      amount: Number(e.total_amount || 0),
      date: fmtDate(ledgerTransactionDate(e)),
      dateIso: ledgerTransactionDate(e),
      status: e.payment_status,
    }));
    setModalTitle('Finance — All Entries');
    setModalSubtitle(`All finance entries for ${fmtIsoMonthToDisplay(reportMonth)}`);
    setModalTotal(monthFinanceTotal);
    setModalRows(rows);
    setModalOpen(true);
  };

  const openVisitorModal = () => {
    const rows: ReportDetailRow[] = displayVisitors
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
    const rows: ReportDetailRow[] = displayVehicleEntries
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
    const rows: ReportDetailRow[] = displayVisitors
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
    const rows: ReportDetailRow[] = searchedShifts.map(s => ({
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
    setModalSubtitle(`Donation payments for ${statementPeriodLabel}`);
    setModalTotal(total);
    setModalRows(rows);
    setModalOpen(true);
  };

  const reportExportContext = useMemo((): ReportExportContext => ({
    societyName,
    reportMonth: statementPeriodLabel,
    tab: activeTab === 'engine' ? 'all_modules' : activeTab,
    financeEntries: searchedPeriodFinanceEntries.map((e) => ({
      record_mode: String(e.record_mode ?? ''),
      destination: e.destination,
      total_amount: Number(e.total_amount || 0),
      aggregate_flat_count: Number(e.aggregate_flat_count || 0),
      payment_status: String(e.payment_status ?? 'verified'),
      payment_method: e.payment_method,
      created_at: ledgerTransactionDate(e),
    })),
    financeGroups,
    financeMonthTotal: financePeriodTotal,
    reportMonthNet: periodReport
      ? {
          cashInHand: periodReport.cashInHand,
          cashInBank: periodReport.cashInBank,
          otherNet: periodReport.otherNet,
          totalBalance: periodReport.totalBalance,
        }
      : undefined,
    periodHeadWise: periodReport
      ? {
          receiptByHead: periodReport.receiptByHead,
          expenseByHead: periodReport.expenseByHead,
          receiptByMethod: periodReport.receiptByMethod,
          expenseByMethod: periodReport.expenseByMethod,
          totalReceipts: periodReport.totalReceipts,
          totalExpenses: periodReport.totalExpenses,
        }
      : undefined,
    visitors: displayVisitors,
    visitorStats,
  }), [
    societyName,
    statementPeriodLabel,
    activeTab,
    searchedPeriodFinanceEntries,
    financeGroups,
    financePeriodTotal,
    periodReport,
    displayVisitors,
    visitorStats,
  ]);

  const exportReport = (format: ExportFormat) => {
    if (activeTab === 'engine') {
      void (async () => {
        try {
          await engineExportRef.current?.(format);
          toast.success(`${format.toUpperCase()} downloaded`);
        } catch (e) {
          toast.error(e instanceof Error ? e.message : 'Export failed');
        }
      })();
      return;
    }
    // Financial PDFs open in a new tab for viewing; other formats download.
    if (format === 'pdf' && activeTab === 'financial') {
      const filename = `financial-report-${statementPeriodLabel.replace(/\s+/g, '-')}.pdf`;
      openBlobInNewTab(buildMonthlyReportPdfBlob(reportExportContext), filename);
      toast.success('PDF opened to view');
      return;
    }
    downloadMonthlyReport(format, reportExportContext);
    toast.success(`${format.toUpperCase()} downloaded`);
  };

  // ─── RENDER ───────────────────────────────────────────────────────────────────
  return (
    <div className="page-container">
      {/* Header */}
      <div className="flex items-start justify-between mb-4 gap-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <BarChart3 className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('report.title')}</h1>
            <p className="text-xs text-muted-foreground">{t('report.subtitle')}</p>
          </div>
        </div>
        <div className="flex flex-col items-end gap-2 shrink-0">
          {activeTab !== 'financial' && (
            <>
              <div className="flex flex-wrap gap-2 justify-end">
                <ExportFormatMenu
                  label="Export"
                  onExport={exportReport}
                  formats={activeTab === 'engine' ? ['excel', 'csv', 'pdf'] : undefined}
                />
                {activeTab !== 'engine' && (
                  <SharePdfWhatsAppButton
                    label="Share on WhatsApp"
                    filename={`${activeTab}-report-${statementPeriodLabel.replace(/\s+/g, '-')}.pdf`}
                    message={`${societyName} — ${statementPeriodLabel} report`}
                    getBlob={() => buildMonthlyReportPdfBlob(reportExportContext)}
                  />
                )}
              </div>
              <label className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1.5 cursor-pointer">
                <Calendar className="w-3.5 h-3.5" />
                <span>{fmtIsoMonthToDisplay(reportMonth)}</span>
                <input
                  type="month"
                  className="sr-only"
                  min={FINANCE_REPORTING_EARLIEST_MONTH}
                  value={reportMonth}
                  onChange={(e) => setReportMonth(e.target.value)}
                />
              </label>
            </>
          )}
        </div>
      </div>

      {/* On-demand search — shared across all tabs including Custom Reports */}
      <div className="mb-4 rounded-lg border border-border bg-card/40 p-3">
        <p className="text-[11px] font-medium text-foreground mb-2">{t('report.searchTitle')}</p>
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            className="input-field pl-9 text-sm"
            placeholder={reportSearchPlaceholder}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        {searchQuery.trim() && (
          <p className="text-[10px] text-muted-foreground mt-2">
            {activeTab === 'financial' && (
              <>
                {searchedPeriodFinanceEntries.length} of {periodFinanceEntries.length} ledger entries match
              </>
            )}
            {activeTab === 'visitor' && (
              <>
                {displayVisitors.length} of {monthVisitors.length} entries match
              </>
            )}
            {activeTab === 'vehicle' && (
              <>
                {displayVehicleEntries.length} of {monthVisitors.filter((v) => v.vehicleNumber).length} vehicle entries match
              </>
            )}
            {activeTab === 'all_modules' && (
              <>
                {searchedMonthFinanceEntries.length} finance · {displayVisitors.length} visitors · {searchedShifts.length} shifts match
              </>
            )}
            {activeTab === 'engine' && <>Filtering custom report rows…</>}
          </p>
        )}
      </div>

      {/* Report Type Tabs */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 mb-5 scrollbar-hide">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              type="button"
              onClick={() => setActiveTab('financial')}
              className={`flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium whitespace-nowrap transition-all ${
                activeTab === 'financial'
                  ? 'bg-primary text-primary-foreground shadow-sm'
                  : 'bg-secondary text-secondary-foreground hover:bg-muted'
              }`}
            >
              <IndianRupee className="w-3.5 h-3.5" />
              {activeTab === 'financial'
                ? selectedFinancialLabels.length === 1
                  ? `Financial Reports: ${selectedFinancialLabels[0]}`
                  : `Financial Reports (${selectedFinancialLabels.length})`
                : 'Financial Reports'}
              <ChevronDown className="w-3 h-3 opacity-70" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start" className="min-w-[16rem]" onCloseAutoFocus={(e) => e.preventDefault()}>
            {FINANCIAL_REPORT_OPTIONS.map((opt) => (
              <DropdownMenuCheckboxItem
                key={opt.id}
                className="text-xs cursor-pointer"
                checked={selectedFinancialReports.includes(opt.id)}
                onSelect={(e) => {
                  e.preventDefault();
                  setActiveTab('financial');
                  toggleFinancialReport(opt.id);
                }}
              >
                {opt.label}
              </DropdownMenuCheckboxItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
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
          {/* Export, share, and period controls above the selected report */}
          <div className="mb-4 rounded-lg border border-border bg-card/40 p-3 space-y-3">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <p className="text-[11px] font-medium text-foreground">
                  {selectedFinancialLabels.length === 1
                    ? selectedFinancialLabels[0]
                    : `${selectedFinancialLabels.length} reports selected`}
                </p>
                <p className="text-[10px] text-muted-foreground">
                  {selectedFinancialLabels.length > 1
                    ? `${selectedFinancialLabels.join(' · ')} · ${statementPeriodLabel}`
                    : statementPeriodLabel}
                  {' — '}
                  PDF opens to view; Share opens WhatsApp
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <ExportFormatMenu label="Download / View" onExport={exportReport} />
                <SharePdfWhatsAppButton
                  label="Share on WhatsApp"
                  filename={`financial-report-${statementPeriodLabel.replace(/\s+/g, '-')}.pdf`}
                  message={`${societyName} — ${statementPeriodLabel} financial report (${selectedFinancialLabels.join(', ')})`}
                  getBlob={() => buildMonthlyReportPdfBlob(reportExportContext)}
                />
              </div>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
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
              {statementPeriodMode === 'monthly' ? (
                <label className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1.5 cursor-pointer w-fit">
                  <Calendar className="w-3.5 h-3.5" />
                  <span>{fmtIsoMonthToDisplay(reportMonth)}</span>
                  <input
                    type="month"
                    className="sr-only"
                    min={FINANCE_REPORTING_EARLIEST_MONTH}
                    value={reportMonth}
                    onChange={(e) => setReportMonth(e.target.value)}
                  />
                </label>
              ) : (
                <div className="grid grid-cols-2 gap-2 sm:max-w-xs">
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
            </div>
            {statementPeriodFrom > statementPeriodTo && (
              <p className="text-[10px] text-destructive">End date must be on or after start date.</p>
            )}
          </div>

          {periodReport && societyId && (
            <FinancePeriodReportSendPanel
              societyId={societyId}
              societyName={societyName}
              adminName={adminName}
              periodFrom={statementPeriodFrom}
              periodTo={statementPeriodTo}
              periodLabel={statementPeriodLabel}
              periodReport={periodReport}
              flatNumbers={flats.map((f) => f.flat_number)}
            />
          )}

          <div className="space-y-5">
            {selectedFinancialReports.includes('collection_receipts') && periodReport && (
              <FinancePeriodHeadTables report={periodReport} section="receipts" />
            )}

            {selectedFinancialReports.includes('expenses') && periodReport && (
              <FinancePeriodHeadTables report={periodReport} section="expenses" />
            )}

            {selectedFinancialReports.includes('flat_wise') && flats.length > 0 && (
              <FinanceFlatReportTab
                from={flatReportFrom}
                to={flatReportTo}
                selectedFlat={flatReportSelectedFlat}
                onFromChange={setFlatReportFrom}
                onToChange={setFlatReportTo}
                onSelectedFlatChange={setFlatReportSelectedFlat}
                flats={flats}
                primaryByFlatId={primaryByFlatId}
                isLoading={flatReportLoading || financeCoreLoading}
                rows={flatReportRows}
              />
            )}

            {selectedFinancialReports.includes('cash_flow') && (
              <CashFlowStatement
                periodFrom={statementPeriodFrom}
                periodTo={statementPeriodTo}
                periodLabel={statementPeriodLabel}
                societyName={societyName}
                loading={financeLoading}
                payments={payments}
                societyLedgerEntries={societyLedgerEntries}
                expenseCategoryById={expenseCategoryById}
                reserveTransfers={reserveTransfers}
                openingBalanceAnchors={openingBalanceAnchors}
              />
            )}

            {selectedFinancialReports.includes('donation_statuses') && (
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
                  <p className="text-xs text-muted-foreground mt-2">No donations for this period.</p>
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
            )}
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
          <h2 className="text-sm font-semibold mb-3">
            {t('report.entries')} ({displayVisitors.length}
            {searchQuery.trim() && displayVisitors.length !== monthVisitors.length ? ` / ${monthVisitors.length}` : ''})
          </h2>
          {displayVisitors.length === 0 ? (
            <p className="text-xs text-muted-foreground text-center py-4">
              {searchQuery.trim() ? t('report.searchNoResults') : t('report.noEntries')}
            </p>
          ) : (
            <div className="flex flex-col gap-1.5">
              {displayVisitors.map(v => (
                <div key={v.id} className="card-section py-2.5 flex items-center gap-2">
                  <div className={`w-1.5 h-1.5 rounded-full ${v.exitTime ? 'bg-muted-foreground' : 'bg-success'}`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium truncate">{v.name} <span className="text-muted-foreground">· {v.flatNumber}</span></p>
                    <p className="text-[10px] text-muted-foreground">{v.category} · {fmtDateTime(v.entryTime)}</p>
                  </div>
                  {v.vehicleNumber && <span className="text-[10px] font-mono bg-muted px-1.5 py-0.5 rounded">{v.vehicleNumber}</span>}
                </div>
              ))}
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
          <h2 className="text-sm font-semibold mb-3">
            Vehicle Entries ({displayVehicleEntries.length}
            {searchQuery.trim() && displayVehicleEntries.length !== monthVisitors.filter((v) => v.vehicleNumber).length
              ? ` / ${monthVisitors.filter((v) => v.vehicleNumber).length}`
              : ''})
          </h2>
          {displayVehicleEntries.length === 0 ? (
            <p className="text-xs text-muted-foreground text-center py-4">
              {searchQuery.trim() ? t('report.searchNoResults') : 'No vehicle entries this month'}
            </p>
          ) : (
            <div className="flex flex-col gap-1.5">
              {displayVehicleEntries.map(v => (
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
            </div>
          )}
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
              value={`₹${monthFinanceTotal.toLocaleString('en-IN')}`}
              onNavigate={openMonthFinanceModal}
              navigateLabel="View finance detail"
              className="border border-border rounded-xl bg-card/50 shadow-none"
            >
              <p className="text-[10px] text-muted-foreground mt-1">{searchedMonthFinanceEntries.length} entries</p>
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
              value={searchedShifts.length}
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

      {/* ═══ METADATA-DRIVEN CUSTOM REPORTS ═══ */}
      {activeTab === 'engine' && societyId && (
        <MetadataReportEngine
          societyId={societyId}
          societyName={societyName}
          adminName={adminName}
          permissions={permissions}
          periodFrom={monthFrom}
          periodTo={monthTo}
          searchQuery={searchQuery}
          onExportReady={onEngineExportReady}
        />
      )}

      {/* Detail Modal */}
      <ReportDetailModal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={modalTitle}
        subtitle={modalSubtitle}
        totalAmount={modalTotal}
        rows={modalRows}
        initialSearchQuery={searchQuery}
        societyName={societyName}
      />
    </div>
  );
};

export default ReportPage;
