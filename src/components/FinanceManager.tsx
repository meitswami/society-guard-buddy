import { useState, useEffect, useMemo, useCallback, type ReactNode } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { IndianRupee, Plus, Check, X, Upload, AlertTriangle, Pencil, Trash2, Wallet, CalendarRange, Users, Calendar, UtensilsCrossed, Scale, ChevronRight, Undo2 } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { format } from 'date-fns';
import { fmtDate, fmtDateTimeFull, fmtIsoDateToDisplay, fmtIsoMonthToDisplay, fmtTime } from '@/lib/dateFormat';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { flatOptionsWithPrimaryLabel, residentLabelForFlatRow } from '@/lib/flatMultiSelectOptions';
import { notifyResidentsOfRecord, type AdminRecordNotifyAudience } from '@/lib/adminRecordNotifications';
import { DateInput } from '@/components/DateInput';
import { buildFinancePeriodReportPdfBlob } from '@/lib/financePeriodReportPdf';
import ExportFormatMenu from '@/components/ExportFormatMenu';
import {
  buildTransactionExportRows,
  downloadFinancePeriodReport,
  downloadTransactionStatement,
} from '@/lib/transactionStatementExport';
import { toFinancePeriodReportExportInput } from '@/lib/financePeriodReportExport';
import type { ExportFormat } from '@/lib/reportExportUtils';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import ReportDetailModal, { type ReportDetailRow } from '@/components/ReportDetailModal';
import { DescriptiveStatCard, DescriptiveStatSummary, DescriptiveValueButton, TableSumInsight } from '@/components/DescriptiveStatCard';
import { capsFieldChange } from '@/lib/entryCaps';
import { RecordingDateBanner } from '@/components/RecordingDateBanner';
import {
  billingMonthFromDate,
  isBillingDateInEntryMonth,
  ledgerEntryMonthFromBilling,
  ledgerTransactionDate,
  paymentBillingDate,
  todayRecordingDate,
} from '@/lib/financeDates';
import {
  FINANCE_FLAT_REPORT_METRICS,
  FINANCE_LEDGER_GROUP_METRICS,
  FINANCE_PERIOD_METRICS,
  FINANCE_TOTALS_METRICS,
  SUM_INSIGHT_METRICS,
} from '@/lib/descriptiveMetricCopy';
import ExpenseSplitter from '@/components/ExpenseSplitter';
import HeadFundReconciliation from '@/components/HeadFundReconciliation';
import MonthlyOperatingFundPanel from '@/components/MonthlyOperatingFundPanel';
import CashBankBreakdown, { ChannelBadge } from '@/components/CashBankBreakdown';
import { sumByChannel, addToChannel, type ChannelTotals } from '@/lib/cashBankChannel';
import {
  computeFinancePeriodReport,
  createDefaultOpeningAnchorForm,
  filterSocietyLedgerEntries,
  isManualOpeningBalanceSetupPeriod,
  openingAnchorRowToForm,
  parseOptionalAnchorAmount,
} from '@/lib/financePeriodReport';
import { useSocietyOpeningBalanceAnchors } from '@/hooks/useSocietyOpeningBalanceAnchors';
import {
  financeExpenseHeadFromLedgerEntry,
  SOCIETY_PAYMENT_MAJOR_HEADS,
  inferMajorHeadFromGroupName,
  resolveGroupMajorHead,
  type SocietyPaymentMajorHead,
} from '@/lib/financeExpenseHead';
import {
  findReceiptHeadConflicts,
  type AuditPaymentRow,
} from '@/lib/financeAuditDetection';
import { queryReceiptHeadConflicts } from '@/lib/financeAuditRemediation';

export type FinanceSubTab =
  | 'maintenance'
  | 'payments'
  | 'record_payment'
  | 'receipts'
  | 'period'
  | 'totals'
  | 'reminders'
  | 'flat_report';

interface Props {
  adminName?: string;
  adminId?: string;
  initialSubTab?: FinanceSubTab;
  onInitialSubTabConsumed?: () => void;
}

const normalizeTitle = (value: unknown) => String(value ?? '').trim().toLowerCase();

const isMonthlyMaintenanceCharge = (charge: any) => {
  const title = normalizeTitle(charge?.title);
  const frequency = normalizeTitle(charge?.frequency);
  return frequency === 'monthly' && title.includes('maint');
};

const isCurrentMonthChargeTitle = (title: string, date = new Date()) => {
  const lower = normalizeTitle(title);
  const monthName = format(date, 'MMMM').toLowerCase();
  return lower.includes(monthName) || lower.includes(format(date, 'MM/yyyy')) || lower.includes(format(date, 'MM-yyyy'));
};

const buildCurrentMonthChargeTitle = (date = new Date()) => `${format(date, 'MMMM')} Monthly Maintenance`;

const paymentMonthValue = (payment: any) => {
  const raw = paymentBillingDate(payment);
  if (!raw) return '';
  return billingMonthFromDate(raw);
};

const paymentMonthLabel = (payment: any) => {
  const raw = paymentBillingDate(payment);
  if (!raw) return 'Unknown month';
  return fmtIsoMonthToDisplay(billingMonthFromDate(raw));
};

const defaultFinancePeriodFrom = () => {
  const y = new Date().getFullYear();
  return `${y}-04-01`;
};

const defaultFinancePeriodTo = () => format(new Date(), 'yyyy-MM-dd');

const paymentVerifiedAtOrDate = (p: any) => String(p?.payment_date || p?.verified_at || p?.created_at || '');

const normalizePaymentChannel = (method: unknown): 'cash' | 'bank' | 'other' => {
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
};

const dateInInclusiveRange = (iso: string, fromYmd: string, toYmd: string) => {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return false;
  const fromMs = new Date(`${fromYmd}T00:00:00`).getTime();
  const toMs = new Date(`${toYmd}T23:59:59.999`).getTime();
  return t >= fromMs && t <= toMs;
};

type FinanceLedgerRow = {
  id: string;
  society_id: string;
  record_mode: string;
  destination: string;
  allocation_style: string;
  include_vacant: boolean;
  entry_month: string | null;
  transaction_date: string | null;
  total_amount: number;
  aggregate_flat_count: number;
  charge_id: string | null;
  expense_id: string | null;
  distributed_at: string | null;
  title: string | null;
  notes: string | null;
  screenshot_url: string | null;
  transaction_id: string | null;
  payment_method: string;
  payment_status: string;
  created_by: string | null;
  created_at: string;
  finance_entry_counterparties: { name: string; relation_to_society: string | null }[] | null;
  finance_entry_allocations: { flat_number: string; amount: number; flat_id: string | null }[] | null;
};

type EventContribRefRow = {
  id: string;
  event_id: string;
  flat_number: string | null;
  amount: number;
  payment_method: string;
  verified_at: string | null;
  resident_name: string | null;
  receipt_basis: string | null;
  batch_label: string | null;
  outsider_name: string | null;
  split_mode: string | null;
  screenshot_url: string | null;
  event_title?: string;
};

type EventFoodRefRow = {
  id: string;
  title: string;
  total_amount: number;
  expense_date: string;
  payment_method: string;
  bill_screenshot_url: string | null;
  group_name: string;
  event_title: string | null;
};

const eventContribRefLabel = (c: EventContribRefRow): string => {
  if (c.receipt_basis === 'non_flat' || !c.flat_number) {
    return c.batch_label || c.outsider_name || c.resident_name || 'Receipt (no flat)';
  }
  const parts = [`Flat ${c.flat_number}`];
  if (c.resident_name) parts.push(c.resident_name);
  if (c.split_mode === 'headcount') parts.push('headcount');
  return parts.join(' · ');
};

const isGroupExpenseLedgerEntry = (e: FinanceLedgerRow) => Boolean(e.expense_id);

const isLedgerInSocietyPool = (e: FinanceLedgerRow) => {
  if (isGroupExpenseLedgerEntry(e)) return false;
  if (e.distributed_at) return false;
  const allocCount = e.finance_entry_allocations?.length ?? 0;
  if (e.record_mode === 'society_pool') return allocCount === 0;
  return e.allocation_style === 'none' && allocCount === 0 && e.aggregate_flat_count === 0;
};

type TransactionHeadSummaryRow = {
  head: string;
  total: number;
  entries: number;
  byChannel: ChannelTotals;
};

function addTransactionHeadRow(
  map: Map<string, TransactionHeadSummaryRow>,
  head: string,
  amount: number,
  paymentMethod: string | null | undefined,
) {
  const label = head.trim() || 'Uncategorized';
  const cur = map.get(label) ?? {
    head: label,
    total: 0,
    entries: 0,
    byChannel: { cash: 0, bank: 0, other: 0 },
  };
  const amt = Number(amount || 0);
  cur.total += amt;
  cur.entries += 1;
  addToChannel(cur.byChannel, paymentMethod, amt);
  map.set(label, cur);
}

function transactionHeadSummaryRows(map: Map<string, TransactionHeadSummaryRow>) {
  return [...map.values()].sort((a, b) => b.total - a.total || a.head.localeCompare(b.head));
}

type TransactionHeadModalLayer = {
  title: string;
  subtitle?: string;
  total?: number;
  rows: ReportDetailRow[];
  drillable: boolean;
};

const transactionFilterHint = (filter: string): string => {
  switch (filter) {
    case 'all_payments':
      return 'Society payments recorded via Record payment — vendor bills, utilities, repairs split across flats (not event food or maintenance receipts).';
    case 'all_receipts':
      return 'Society collections — flat owners, outsiders, monthly/one-time charges; pooled until you distribute to flats.';
    case 'all':
      return 'Society receipts and society-payment rows. Event contribution and food bills appear below as reference only (not in the society ledger).';
    case 'society_pool_pending':
      return 'Receipts recorded in the society pool that are not yet split equally across flats.';
    default:
      return 'Filter by charge type or recording mode. Use society pool when recording, then distribute from the receipt row when needed.';
  }
};

const ledgerMonthValue = (e: FinanceLedgerRow) => billingMonthFromDate(ledgerTransactionDate(e));

const ledgerMonthDisplay = (e: FinanceLedgerRow) => fmtIsoMonthToDisplay(ledgerMonthValue(e));

async function uploadPaymentReceipt(file: File): Promise<string | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `maintenance-receipts/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, file, { cacheControl: '3600', upsert: false });
  if (error) return null;
  const { data } = supabase.storage.from('notification-media').getPublicUrl(path);
  return data.publicUrl;
}

function PeriodMetric({
  metricKey,
  value,
  valueClassName,
  className,
}: {
  metricKey: keyof typeof FINANCE_PERIOD_METRICS;
  value: ReactNode;
  valueClassName?: string;
  className?: string;
}) {
  const copy = FINANCE_PERIOD_METRICS[metricKey];
  return (
    <DescriptiveStatCard
      variant="stat"
      title={copy.title}
      caption={copy.title}
      description={copy.description}
      howCalculated={copy.howCalculated}
      value={value}
      valueClassName={valueClassName}
      className={className}
    />
  );
}

const FinanceManager = ({
  adminName = 'Admin',
  adminId: _adminId,
  initialSubTab,
  onInitialSubTabConsumed,
}: Props) => {
  const { t } = useLanguage();
  const societyId = useStore((s) => s.societyId);
  const [subTab, setSubTab] = useState<FinanceSubTab>('maintenance');
  const [headReconciliationKey, setHeadReconciliationKey] = useState(0);
  const [showHeadFundRecon, setShowHeadFundRecon] = useState(false);
  const bumpHeadReconciliation = useCallback(() => setHeadReconciliationKey((k) => k + 1), []);
  const [expenseCategoryById, setExpenseCategoryById] = useState<Map<string, string>>(new Map());
  const [charges, setCharges] = useState<any[]>([]);
  const [payments, setPayments] = useState<any[]>([]);
  const [ledgerEntries, setLedgerEntries] = useState<FinanceLedgerRow[]>([]);

  useEffect(() => {
    if (!initialSubTab) return;
    setSubTab(initialSubTab);
    onInitialSubTabConsumed?.();
  }, [initialSubTab, onInitialSubTabConsumed]);

  const isSocietyPaymentLedgerEntry = useCallback(
    (e: FinanceLedgerRow) => {
      if (!e.expense_id) return false;
      const cat = expenseCategoryById.get(e.expense_id);
      return cat !== 'food';
    },
    [expenseCategoryById],
  );

  /** Finance module ledger — excludes event food (reconciled under Events & food). */
  const societyLedgerEntries = useMemo(
    () => filterSocietyLedgerEntries(ledgerEntries, expenseCategoryById),
    [ledgerEntries, expenseCategoryById],
  );

  const ledgerEntryKindLabel = useCallback(
    (e: FinanceLedgerRow) => {
      if (!e.expense_id) {
        return isLedgerInSocietyPool(e)
          ? 'Society pool — not yet distributed'
          : 'Ledger-only (no maintenance payment rows)';
      }
      if (expenseCategoryById.get(e.expense_id) === 'food') return 'Event food expense';
      return 'Society payment (split across flats)';
    },
    [expenseCategoryById],
  );
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null; is_occupied: boolean | null }[]>([]);
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [showForm, setShowForm] = useState(false);
  const [showPaymentForm, setShowPaymentForm] = useState(false);
  const [form, setForm] = useState({
    title: '',
    amount: '',
    frequency: 'monthly',
    due_day: '1',
    major_head: '' as SocietyPaymentMajorHead | '',
    expense_group_id: '',
    new_sub_head: '',
  });
  const [paymentExpenseGroups, setPaymentExpenseGroups] = useState<
    { id: string; name: string; major_head: string | null }[]
  >([]);
  const [distributingPoolEntryId, setDistributingPoolEntryId] = useState<string | null>(null);
  const [payForm, setPayForm] = useState({
    recordMode: 'society_pool' as 'society_pool' | 'flats_only' | 'flats_plus_outsider' | 'outsider_only',
    destination: 'current_month_maintenance' as 'current_month_maintenance' | 'corpus' | 'separate_entry',
    allocationStyle: 'same_per_flat' as 'same_per_flat' | 'split_total_equally',
    allocationIncludeVacant: false,
    outsiderName: '',
    outsiderRelation: '',
    outsiderAmount: '',
    entryTitle: '',
    charge_id: '',
    selected_flats: [] as string[],
    amount: '',
    payment_method: 'cash',
    transaction_id: '',
    screenshot_url: '',
    notes: '',
    due_date: format(new Date(), 'yyyy-MM-dd'),
  });
  const [filterStatus, setFilterStatus] = useState('all');
  const [editingChargeId, setEditingChargeId] = useState<string | null>(null);
  const [receiptUploading, setReceiptUploading] = useState(false);
  const [paymentNotifyAudience, setPaymentNotifyAudience] = useState<AdminRecordNotifyAudience>('none');
  const [autoSelectedChargeHint, setAutoSelectedChargeHint] = useState('');
  const [useSameDateForSelectedFlats, setUseSameDateForSelectedFlats] = useState(true);
  const [flatDueDates, setFlatDueDates] = useState<Record<string, string>>({});
  const [flatDateModal, setFlatDateModal] = useState<{ open: boolean; flatNumber: string; date: string }>({
    open: false,
    flatNumber: '',
    date: format(new Date(), 'yyyy-MM-dd'),
  });
  const [paymentTypeFilter, setPaymentTypeFilter] = useState('all');
  const [paymentMonthFilter, setPaymentMonthFilter] = useState('all');
  const [receiptModeFilter, setReceiptModeFilter] = useState<
    'all' | 'society_pool' | 'flats_only' | 'flats_plus_outsider' | 'outsider_only'
  >('all');
  const [totalsMonth, setTotalsMonth] = useState(format(new Date(), 'yyyy-MM'));
  const [periodFrom, setPeriodFrom] = useState(defaultFinancePeriodFrom);
  const [periodTo, setPeriodTo] = useState(defaultFinancePeriodTo);
  const [societyName, setSocietyName] = useState('');
  const [residentUsers, setResidentUsers] = useState<{ id: string; name: string; flat_number: string; flat_id: string }[]>([]);
  const [reportAudience, setReportAudience] = useState<'all' | 'flats' | 'picked'>('all');
  const [reportFlats, setReportFlats] = useState<string[]>([]);
  const [reportResidentIds, setReportResidentIds] = useState<string[]>([]);
  const [reportPushBusy, setReportPushBusy] = useState(false);
  const [lastDeliveryBatchId, setLastDeliveryBatchId] = useState<string | null>(null);
  const [readStatusOpen, setReadStatusOpen] = useState(false);
  const [readStatusBatchId, setReadStatusBatchId] = useState<string | null>(null);
  const [readStatusRows, setReadStatusRows] = useState<{ id: string; target_id: string | null; is_read: boolean; read_at: string | null }[]>([]);
  const [paymentSearchQuery, setPaymentSearchQuery] = useState('');
  const [selectedPayment, setSelectedPayment] = useState<any | null>(null);
  const [selectedLedger, setSelectedLedger] = useState<FinanceLedgerRow | null>(null);
  const [headSummaryModalOpen, setHeadSummaryModalOpen] = useState(false);
  const [headSummaryModalStack, setHeadSummaryModalStack] = useState<TransactionHeadModalLayer[]>([]);
  const [selectedReceiptKeys, setSelectedReceiptKeys] = useState<Set<string>>(new Set());
  const [paymentEdit, setPaymentEdit] = useState<{
    id: string;
    charge_id: string;
    amount: string;
    payment_method: string;
    transaction_id: string;
    notes: string;
    due_date: string;
    recording_date: string;
    payment_status: string;
    rejection_reason: string;
  } | null>(null);
  const [ledgerEdit, setLedgerEdit] = useState<{
    id: string;
    title: string;
    notes: string;
    payment_status: string;
    transaction_id: string;
    payment_method: string;
    total_amount: string;
    entry_month: string;
    transaction_date: string;
  } | null>(null);
  const [autoReminderEnabled, setAutoReminderEnabled] = useState(true);
  const [autoReminderSchedule, setAutoReminderSchedule] = useState<'once_12pm' | 'twice_12pm_7pm'>('once_12pm');
  const [savingAutoReminder, setSavingAutoReminder] = useState(false);
  const [testingAutoReminder, setTestingAutoReminder] = useState(false);
  const [lastReminderTestStatus, setLastReminderTestStatus] = useState<string>('');
  const [flatReportFrom, setFlatReportFrom] = useState(defaultFinancePeriodFrom);
  const [flatReportTo, setFlatReportTo] = useState(defaultFinancePeriodTo);
  const [flatReportSelectedFlat, setFlatReportSelectedFlat] = useState<string>('all');
  const [flatReportExpenses, setFlatReportExpenses] = useState<any[]>([]);
  const [flatReportSplits, setFlatReportSplits] = useState<any[]>([]);
  const [flatReportLoading, setFlatReportLoading] = useState(false);
  const [eventContribRef, setEventContribRef] = useState<EventContribRefRow[]>([]);
  const [eventFoodRef, setEventFoodRef] = useState<EventFoodRefRow[]>([]);
  const [eventRefLoading, setEventRefLoading] = useState(false);
  const { anchors: openingBalanceAnchors, saveAnchor, deleteAnchor } = useSocietyOpeningBalanceAnchors(societyId);
  const [anchorForm, setAnchorForm] = useState(createDefaultOpeningAnchorForm);
  const [savingOpeningAnchor, setSavingOpeningAnchor] = useState(false);
  useEffect(() => {
    void loadAll();
  }, [societyId]);

  useEffect(() => {
    if (!societyId || subTab !== 'period') return;
    const loadLatestReportBatch = async () => {
      const { data } = await supabase
        .from('notifications')
        .select('delivery_batch_id')
        .eq('society_id', societyId)
        .eq('type', 'finance_period_report')
        .not('delivery_batch_id', 'is', null)
        .order('created_at', { ascending: false })
        .limit(1);
      const batchId = (data?.[0] as { delivery_batch_id?: string } | undefined)?.delivery_batch_id ?? null;
      if (batchId) setLastDeliveryBatchId(batchId);
    };
    void loadLatestReportBatch();
  }, [societyId, subTab]);

  const loadAll = async () => {
    if (!societyId) {
      setCharges([]);
      setPayments([]);
      setFlats([]);
      setPrimaryByFlatId(new Map());
      setSocietyName('');
      setResidentUsers([]);
      return;
    }
    const { data: f } = await supabase
      .from('flats')
      .select('flat_number, id, owner_name, is_occupied')
      .eq('society_id', societyId)
      .order('flat_number');
    if (f) setFlats(f);
    const flatIds = (f ?? []).map((x) => x.id);
    const mRes =
      flatIds.length > 0
        ? await supabase.from('members').select('flat_id, name').eq('is_primary', true).in('flat_id', flatIds)
        : { data: [] as { flat_id: string; name: string }[] };
    const map = new Map<string, string>();
    for (const row of mRes.data ?? []) {
      if (row.flat_id && row.name?.trim()) map.set(row.flat_id, row.name.trim());
    }
    setPrimaryByFlatId(map);

    const { data: soc } = await supabase.from('societies').select('name').eq('id', societyId).maybeSingle();
    setSocietyName((soc as { name?: string } | null)?.name ?? '');

    const ruRes =
      flatIds.length > 0
        ? await supabase.from('resident_users').select('id, name, flat_number, flat_id').in('flat_id', flatIds).order('flat_number')
        : { data: [] as { id: string; name: string; flat_number: string; flat_id: string }[] };
    setResidentUsers((ruRes.data ?? []) as { id: string; name: string; flat_number: string; flat_id: string }[]);

    const { data: reminderSetting } = await (supabase as any)
      .from('finance_reminder_settings')
      .select('enabled, schedule')
      .eq('society_id', societyId)
      .maybeSingle();
    if (reminderSetting) {
      setAutoReminderEnabled(!!reminderSetting.enabled);
      setAutoReminderSchedule(
        reminderSetting.schedule === 'twice_12pm_7pm' ? 'twice_12pm_7pm' : 'once_12pm',
      );
    } else {
      setAutoReminderEnabled(true);
      setAutoReminderSchedule('once_12pm');
    }

    const { data: c } = await supabase
      .from('maintenance_charges')
      .select('*')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false });
    let chargeRows = c ?? [];

    const monthlyMaintenanceCharges = chargeRows.filter(isMonthlyMaintenanceCharge);
    const hasCurrentMonthCharge = monthlyMaintenanceCharges.some((row) => isCurrentMonthChargeTitle(row.title));
    const templateCharge = monthlyMaintenanceCharges[0];

    if (!hasCurrentMonthCharge && templateCharge) {
      const currentTitle = buildCurrentMonthChargeTitle();
      const looksLikeCurrentChargeAlreadyExists = chargeRows.some(
        (row) => normalizeTitle(row.title) === normalizeTitle(currentTitle),
      );
      if (!looksLikeCurrentChargeAlreadyExists) {
        const { error: createMonthErr } = await supabase.from('maintenance_charges').insert([
          {
            title: currentTitle,
            amount: Number(templateCharge.amount) || 0,
            frequency: 'monthly',
            due_day: Number(templateCharge.due_day) || 1,
            created_by: adminName,
            society_id: societyId,
          },
        ]);
        if (!createMonthErr) {
          const { data: refreshedCharges } = await supabase
            .from('maintenance_charges')
            .select('*')
            .eq('society_id', societyId)
            .order('created_at', { ascending: false });
          chargeRows = refreshedCharges ?? chargeRows;
        }
      }
    }

    setCharges(chargeRows);

    const { data: pGroups } = await supabase
      .from('expense_groups')
      .select('id, name, major_head')
      .eq('society_id', societyId)
      .eq('group_kind', 'general')
      .order('name');
    setPaymentExpenseGroups((pGroups ?? []) as { id: string; name: string; major_head: string | null }[]);

    const chargeIds = chargeRows.map((x) => x.id);
    let payRows: any[] = [];
    if (chargeIds.length > 0) {
      const { data: p } = await supabase
        .from('maintenance_payments')
        .select('*')
        .in('charge_id', chargeIds)
        .order('created_at', { ascending: false })
        .limit(2500);
      payRows = p ?? [];
    }
    setPayments(payRows);

    const { data: led } = await supabase
      .from('finance_entries')
      .select(
        '*, finance_entry_counterparties(*), finance_entry_allocations(*)',
      )
      .eq('society_id', societyId)
      .order('created_at', { ascending: false })
      .limit(2500);
    const ledRows = (led as FinanceLedgerRow[]) ?? [];
    setLedgerEntries(ledRows);

    const linkedExpenseIds = ledRows.map((e) => e.expense_id).filter((id): id is string => Boolean(id));
    if (linkedExpenseIds.length > 0) {
      const { data: expCats } = await supabase
        .from('expenses')
        .select('id, expense_category')
        .in('id', linkedExpenseIds);
      setExpenseCategoryById(
        new Map((expCats ?? []).map((row) => [String((row as { id: string }).id), String((row as { expense_category?: string }).expense_category ?? '')])),
      );
    } else {
      setExpenseCategoryById(new Map());
    }
  };

  const loadFlatReportData = async () => {
    if (!societyId) return;
    setFlatReportLoading(true);
    try {
      // Society payments (Record payment) — not event food
      const { data: groupRows } = await supabase
        .from('expense_groups')
        .select('id, name')
        .eq('society_id', societyId)
        .eq('group_kind', 'general');
      const groupIds = (groupRows ?? []).map((g) => g.id);
      let expRows: any[] = [];
      let splitRows: any[] = [];
      if (groupIds.length > 0) {
        const { data: exps } = await supabase
          .from('expenses')
          .select('id, title, total_amount, expense_date, payment_method, vendor_or_service, service_kind, group_id, split_type, paid_by_flat, paid_by_flats, record_status')
          .in('group_id', groupIds)
          .eq('record_status', 'active')
          .eq('expense_category', 'payment');
        expRows = exps ?? [];
        const expIds = expRows.map((e) => e.id);
        if (expIds.length > 0) {
          const { data: sp } = await supabase
            .from('expense_splits')
            .select('id, expense_id, flat_number, amount, is_settled, settled_at')
            .in('expense_id', expIds);
          splitRows = sp ?? [];
        }
      }
      setFlatReportExpenses(expRows.map((e) => ({
        ...e,
        group_name: groupRows?.find((g) => g.id === e.group_id)?.name ?? 'Unknown group',
      })));
      setFlatReportSplits(splitRows);
    } catch (err) {
      console.error('Flat report data load error:', err);
    } finally {
      setFlatReportLoading(false);
    }
  };

  useEffect(() => {
    if (subTab === 'flat_report') {
      void loadFlatReportData();
    }
  }, [subTab, societyId]);

  const loadEventFoodReference = async () => {
    if (!societyId) {
      setEventContribRef([]);
      setEventFoodRef([]);
      return;
    }
    setEventRefLoading(true);
    try {
      const { data: events } = await supabase
        .from('events')
        .select('id, title')
        .eq('society_id', societyId)
        .order('event_date', { ascending: false })
        .limit(100);
      const eventIds = (events ?? []).map((e) => e.id);
      const eventTitleById = new Map((events ?? []).map((e) => [String(e.id), String(e.title)]));

      const { data: groups } = await supabase
        .from('expense_groups')
        .select('id, name, event_id')
        .eq('society_id', societyId)
        .eq('group_kind', 'event');
      const groupIds = (groups ?? []).map((g) => g.id);
      const groupById = new Map((groups ?? []).map((g) => [String(g.id), g]));

      const [contribRes, expRes] = await Promise.all([
        eventIds.length
          ? supabase
              .from('event_contributions')
              .select('*')
              .in('event_id', eventIds)
              .order('verified_at', { ascending: false })
              .limit(150)
          : Promise.resolve({ data: [] as EventContribRefRow[] }),
        groupIds.length
          ? supabase
              .from('expenses')
              .select('id, title, total_amount, expense_date, payment_method, bill_screenshot_url, group_id')
              .in('group_id', groupIds)
              .eq('expense_category', 'food')
              .eq('record_status', 'active')
              .order('expense_date', { ascending: false })
              .limit(150)
          : Promise.resolve({ data: [] as Omit<EventFoodRefRow, 'group_name' | 'event_title'>[] }),
      ]);

      setEventContribRef(
        (contribRes.data ?? []).map((c) => ({
          ...(c as EventContribRefRow),
          event_title: eventTitleById.get(String(c.event_id)) ?? 'Event',
        })),
      );

      setEventFoodRef(
        (expRes.data ?? []).map((ex) => {
          const g = groupById.get(String(ex.group_id));
          return {
            ...(ex as Omit<EventFoodRefRow, 'group_name' | 'event_title'>),
            group_name: g?.name ?? 'Food group',
            event_title: g?.event_id ? eventTitleById.get(String(g.event_id)) ?? null : null,
          };
        }),
      );
    } catch (err) {
      console.error('Event food reference load error:', err);
    } finally {
      setEventRefLoading(false);
    }
  };

  useEffect(() => {
    if (subTab === 'receipts') {
      void loadEventFoodReference();
    }
  }, [subTab, societyId]);

  useEffect(() => {
    if (!showPaymentForm || payForm.charge_id || charges.length === 0) return;
    const preferredCharge =
      charges.find((c) => isMonthlyMaintenanceCharge(c) && isCurrentMonthChargeTitle(c.title)) ??
      charges.find(isMonthlyMaintenanceCharge) ??
      charges[0];
    if (!preferredCharge) return;
    setAutoSelectedChargeHint(
      isMonthlyMaintenanceCharge(preferredCharge) && isCurrentMonthChargeTitle(preferredCharge.title)
        ? `Auto-selected ${preferredCharge.title}`
        : '',
    );
    setPayForm((prev) => ({
      ...prev,
      charge_id: preferredCharge.id,
      amount: preferredCharge?.amount?.toString?.() ?? prev.amount,
    }));
  }, [showPaymentForm, payForm.charge_id, charges]);

  const paymentGroupById = useMemo(
    () => new Map(paymentExpenseGroups.map((g) => [g.id, g])),
    [paymentExpenseGroups],
  );

  const majorHeadForCharge = useCallback(
    (c: { title: string; expense_group_id?: string | null }) => {
      const g = c.expense_group_id ? paymentGroupById.get(String(c.expense_group_id)) : undefined;
      if (g) return resolveGroupMajorHead(g);
      return inferMajorHeadFromGroupName(c.title);
    },
    [paymentGroupById],
  );

  const chargesByMajorHead = useMemo(() => {
    const map = new Map<string, typeof charges>();
    for (const head of SOCIETY_PAYMENT_MAJOR_HEADS) map.set(head, []);
    map.set('Uncategorized', []);
    for (const c of charges) {
      const major = majorHeadForCharge(c as { title: string; expense_group_id?: string | null });
      const bucket = map.get(major) ?? map.get('Uncategorized')!;
      bucket.push(c);
    }
    return map;
  }, [charges, majorHeadForCharge]);

  const subHeadsForFormMajor = useMemo(() => {
    if (!form.major_head) return [];
    return paymentExpenseGroups.filter((g) => resolveGroupMajorHead(g) === form.major_head);
  }, [paymentExpenseGroups, form.major_head]);

  const renderGroupedChargeOptions = () =>
    [...SOCIETY_PAYMENT_MAJOR_HEADS, 'Uncategorized' as const].map((major) => {
      const list = chargesByMajorHead.get(major) ?? [];
      if (list.length === 0) return null;
      return (
        <optgroup key={major} label={major}>
          {list.map((c) => (
            <option key={c.id} value={c.id}>
              {c.title} — ₹{Number(c.amount).toLocaleString('en-IN')}
            </option>
          ))}
        </optgroup>
      );
    });

  const addCharge = async () => {
    if (!societyId) {
      toast.error('No society selected');
      return;
    }
    if (!form.title || !form.amount) return;

    let expenseGroupId: string | null =
      form.expense_group_id && form.expense_group_id !== '__new__' ? form.expense_group_id : null;

    if (form.expense_group_id === '__new__') {
      if (!form.major_head) {
        toast.error('Choose a major head for the new payment sub-head');
        return;
      }
      const subName = form.new_sub_head.trim() || form.title.trim();
      if (!subName) {
        toast.error('Enter sub-head name or use receipt title');
        return;
      }
      const { data: newGroup, error: gErr } = await supabase
        .from('expense_groups')
        .insert({
          society_id: societyId,
          name: subName,
          major_head: form.major_head,
          group_kind: 'general',
          created_by: adminName,
        })
        .select('id')
        .single();
      if (gErr || !newGroup) {
        toast.error(gErr?.message ?? 'Could not create payment sub-head');
        return;
      }
      expenseGroupId = newGroup.id;
    }

    if (editingChargeId) {
      const { error } = await supabase
        .from('maintenance_charges')
        .update({
          title: form.title,
          amount: Number(form.amount),
          frequency: form.frequency,
          due_day: Number(form.due_day),
          expense_group_id: expenseGroupId,
        })
        .eq('id', editingChargeId)
        .eq('society_id', societyId);
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success('Receipt type updated');
      setEditingChargeId(null);
    } else {
      const { error } = await supabase.from('maintenance_charges').insert([
        {
          title: form.title,
          amount: Number(form.amount),
          frequency: form.frequency,
          due_day: Number(form.due_day),
          created_by: adminName,
          society_id: societyId,
          expense_group_id: expenseGroupId,
        },
      ]);
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success('Receipt type added');
    }
    setForm({
      title: '',
      amount: '',
      frequency: 'monthly',
      due_day: '1',
      major_head: '',
      expense_group_id: '',
      new_sub_head: '',
    });
    setShowForm(false);
    await loadAll();
  };

  const startEditCharge = (charge: {
    id: string;
    title: string;
    amount: number;
    frequency?: string | null;
    due_day?: number | null;
    expense_group_id?: string | null;
  }) => {
    const g = charge.expense_group_id ? paymentGroupById.get(charge.expense_group_id) : undefined;
    const major = g ? resolveGroupMajorHead(g) : inferMajorHeadFromGroupName(charge.title);
    setEditingChargeId(charge.id);
    setForm({
      title: charge.title,
      amount: String(charge.amount),
      frequency: charge.frequency || 'monthly',
      due_day: String(charge.due_day ?? 1),
      major_head: major,
      expense_group_id: charge.expense_group_id ?? '',
      new_sub_head: '',
    });
    setShowForm(true);
  };

  const deleteCharge = async (id: string) => {
    const hasDeps =
      payments.some((p) => p.charge_id === id) || ledgerEntries.some((e) => e.charge_id === id);
    if (hasDeps) {
      toast.error('This receipt type has linked payments or ledger rows. Delete those entries first.');
      return;
    }
    const ok = await confirmAction(
      'Delete this receipt type?',
      'This will remove the receipt type definition only.',
      'Delete',
      'Cancel',
    );
    if (!ok) return;
    await supabase.from('maintenance_charges').delete().eq('id', id).eq('society_id', societyId);
    toast.success('Receipt type deleted');
    if (editingChargeId === id) {
      setEditingChargeId(null);
      setForm({
      title: '',
      amount: '',
      frequency: 'monthly',
      due_day: '1',
      major_head: '',
      expense_group_id: '',
      new_sub_head: '',
    });
      setShowForm(false);
    }
    await loadAll();
  };

  const distributePoolToAllFlats = async (entry: FinanceLedgerRow) => {
    if (!societyId || !isLedgerInSocietyPool(entry)) return;
    const scopeFlats = entry.include_vacant ? flats : flats.filter((f) => f.is_occupied);
    if (scopeFlats.length === 0) {
      toast.error('No flats available to distribute to');
      return;
    }
    const perFlat = Number((Number(entry.total_amount) / scopeFlats.length).toFixed(2));
    const ok = await confirmAction(
      'Distribute to all flats equally?',
      `₹${Number(entry.total_amount).toLocaleString('en-IN')} across ${scopeFlats.length} flat(s) ≈ ₹${perFlat.toLocaleString('en-IN')} each.${
        entry.destination === 'current_month_maintenance' && entry.charge_id
          ? ' Verified maintenance payment rows will be created per flat.'
          : ''
      }`,
      'Distribute',
      'Cancel',
    );
    if (!ok) return;

    setDistributingPoolEntryId(entry.id);
    try {
      let allocated = 0;
      const allocationRows: { flat_number: string; flat_id: string | null; amount: number }[] = [];
      const mpRows: Record<string, unknown>[] = [];
      const now = new Date().toISOString();
      const chargeTitle = entry.charge_id ? charges.find((c) => c.id === entry.charge_id)?.title ?? '' : '';

      if (entry.destination === 'current_month_maintenance' && entry.charge_id) {
        const billingDate = ledgerTransactionDate(entry);
        const targets = scopeFlats.map((f) => ({ flatNumber: f.flat_number, dueDate: billingDate }));
        const conflicts = await queryReceiptHeadConflicts(supabase, {
          chargeId: entry.charge_id,
          paymentMethod: entry.payment_method,
          targets,
        });
        if (conflicts.length > 0) {
          const flatList = [...new Set(conflicts.map((c) => c.flat_number))].join(', ');
          toast.error(
            `Cannot distribute — receipt head already recorded for Flat ${flatList} (${chargeTitle || 'maintenance'}). Edit or delete in Audit → Finance Alarms.`,
            { duration: 8000 },
          );
          return;
        }
      }

      for (let i = 0; i < scopeFlats.length; i++) {
        const flat = scopeFlats[i];
        const isLast = i === scopeFlats.length - 1;
        const amount = isLast
          ? Number((Number(entry.total_amount) - allocated).toFixed(2))
          : perFlat;
        allocated += amount;
        allocationRows.push({ flat_number: flat.flat_number, flat_id: flat.id, amount });
        if (entry.destination === 'current_month_maintenance' && entry.charge_id) {
          mpRows.push({
            charge_id: entry.charge_id,
            flat_id: flat.id,
            flat_number: flat.flat_number,
            resident_name: residentLabelForFlatRow(flat.id, flat.owner_name, primaryByFlatId),
            amount,
            payment_method: entry.payment_method,
            payment_status: 'verified',
            payment_date: now,
            due_date: ledgerTransactionDate(entry),
            recording_date: todayRecordingDate(),
            transaction_id: entry.transaction_id,
            screenshot_url: entry.screenshot_url,
            notes: entry.notes,
            submitted_by: 'admin',
            submitted_by_user_id: null,
            verified_by: adminName,
            verified_at: now,
            reviewed_at: now,
            rejection_reason: null,
            finance_entry_id: entry.id,
          });
        }
      }

      const { error: allocErr } = await supabase.from('finance_entry_allocations').insert(
        allocationRows.map((a) => ({
          finance_entry_id: entry.id,
          flat_id: a.flat_id,
          flat_number: a.flat_number,
          amount: a.amount,
        })),
      );
      if (allocErr) {
        toast.error(allocErr.message);
        return;
      }

      if (mpRows.length > 0) {
        const { error: payErr } = await supabase.from('maintenance_payments').insert(mpRows);
        if (payErr) {
          await supabase.from('finance_entry_allocations').delete().eq('finance_entry_id', entry.id);
          toast.error(payErr.message);
          return;
        }
      }

      const { error: updErr } = await supabase
        .from('finance_entries')
        .update({
          allocation_style: 'split_total_equally',
          aggregate_flat_count: scopeFlats.length,
          distributed_at: now,
          title: entry.title || chargeTitle || 'Society receipt (distributed)',
        })
        .eq('id', entry.id);
      if (updErr) {
        toast.error(updErr.message);
        return;
      }

      toast.success(`Distributed across ${scopeFlats.length} flat(s)`);
      setSelectedLedger(null);
      await loadAll();
    } finally {
      setDistributingPoolEntryId(null);
    }
  };

  const recordPayment = async () => {
    if (!societyId) return;
    const mode = payForm.recordMode;
    const n = payForm.selected_flats.length;

    if (mode === 'society_pool') {
      if (!payForm.amount || Number(payForm.amount) <= 0) {
        toast.error('Enter the total receipt amount for the society pool');
        return;
      }
    } else if (n === 0) {
      toast.error('Select at least one flat');
      return;
    }

    if (mode === 'flats_only') {
      if (!payForm.amount || !payForm.charge_id) return;
    }
    if (mode === 'outsider_only') {
      if (!payForm.outsiderName.trim()) {
        toast.error('Enter outsider / payer name');
        return;
      }
      if (!payForm.outsiderAmount) {
        toast.error('Enter outsider amount');
        return;
      }
      if (payForm.destination === 'current_month_maintenance' && !payForm.charge_id) {
        toast.error('Select a receipt type when adjusting current month maintenance');
        return;
      }
    }
    if (mode === 'flats_plus_outsider') {
      if (!payForm.charge_id || !payForm.amount) {
        toast.error('Select receipt type and enter maintenance amount per flat');
        return;
      }
      if (!payForm.outsiderName.trim() || !payForm.outsiderAmount) {
        toast.error('Enter outsider name and outsider amount');
        return;
      }
    }

    if (!useSameDateForSelectedFlats) {
      const missingDateFlat = payForm.selected_flats.find((flat) => !flatDueDates[flat]);
      if (missingDateFlat) {
        setFlatDateModal({
          open: true,
          flatNumber: missingDateFlat,
          date: payForm.due_date,
        });
        toast.error(`Select due date for Flat ${missingDateFlat}`);
        return;
      }
    }

    // Block when receipt head is already recorded (flat + charge + month + channel).
    if (mode !== 'society_pool' && (mode === 'flats_only' || mode === 'flats_plus_outsider')) {
      if (payForm.charge_id && payForm.selected_flats.length > 0) {
        const targets = payForm.selected_flats.map((flatNum) => ({
          flatNumber: flatNum,
          dueDate: useSameDateForSelectedFlats ? payForm.due_date : (flatDueDates[flatNum] || payForm.due_date),
        }));
        const conflicts = await queryReceiptHeadConflicts(supabase, {
          chargeId: payForm.charge_id,
          paymentMethod: payForm.payment_method,
          targets,
        });
        if (conflicts.length > 0) {
          const chargeTitle = charges.find((c) => c.id === payForm.charge_id)?.title ?? 'Receipt head';
          const flatList = [...new Set(conflicts.map((c) => c.flat_number))].join(', ');
          toast.error(
            `Receipt head already recorded for Flat ${flatList} (${chargeTitle}). Edit or delete the existing entry in Audit → Finance Alarms before recording again.`,
            { duration: 8000 },
          );
          return;
        }
      }
    }

    let screenshotUrl = payForm.screenshot_url.trim() || null;
    const fileInput = document.getElementById('finance-payment-receipt') as HTMLInputElement | null;
    const file = fileInput?.files?.[0];
    if (file) {
      if (file.size > 8 * 1024 * 1024) {
        toast.error('Receipt file must be 8MB or smaller');
        return;
      }
      setReceiptUploading(true);
      const url = await uploadPaymentReceipt(file);
      setReceiptUploading(false);
      if (!url) {
        toast.error('Could not upload receipt');
        return;
      }
      screenshotUrl = url;
      if (fileInput) fileInput.value = '';
    }

    const poolFlats = payForm.selected_flats.map((fn) => {
      const flat = flats.find((f) => f.flat_number === fn);
      return { flat_number: fn, flat_id: flat?.id ?? null };
    });

    let allocationStyle: 'same_per_flat' | 'split_total_equally' | 'none' = 'none';
    let totalAmount = 0;
    const allocationRows: { flat_number: string; flat_id: string | null; amount: number }[] = [];
    const mpRows: Record<string, unknown>[] = [];
    const now = new Date().toISOString();
    const recordingDate = todayRecordingDate();
    const primaryBillingDate = payForm.due_date;
    const entryMonth = billingMonthFromDate(primaryBillingDate);
    if (!isBillingDateInEntryMonth(primaryBillingDate, entryMonth)) {
      toast.error('Billing date must fall within the entry month shown below.');
      return;
    }
    const chargeTitle = charges.find((c) => c.id === payForm.charge_id)?.title ?? '';

    const buildMpRow = (flat_number: string, amount: number, flat_id: string | null) => ({
      charge_id: payForm.charge_id,
      flat_id,
      flat_number,
      resident_name: residentLabelForFlatRow(
        flat_id,
        flats.find((f) => f.flat_number === flat_number)?.owner_name ?? null,
        primaryByFlatId,
      ),
      amount,
      payment_method: payForm.payment_method,
      payment_status:
        payForm.payment_method === 'cash' || payForm.payment_method === 'upi' ? 'verified' : 'pending',
      payment_date: now,
      due_date: useSameDateForSelectedFlats ? payForm.due_date : flatDueDates[flat_number] || payForm.due_date,
      recording_date: recordingDate,
      transaction_id: payForm.transaction_id || null,
      screenshot_url: screenshotUrl,
      notes: payForm.notes || null,
      submitted_by: 'admin',
      submitted_by_user_id: null,
      verified_by: adminName,
      verified_at: now,
      reviewed_at: now,
      rejection_reason: null,
    });

    if (mode === 'society_pool') {
      allocationStyle = 'none';
      totalAmount = Number(payForm.amount);
    }

    if (mode === 'flats_only') {
      const perFlat = Number(payForm.amount);
      allocationStyle = n > 1 ? 'same_per_flat' : 'none';
      totalAmount = perFlat * n;
      for (const { flat_number, flat_id } of poolFlats) {
        allocationRows.push({ flat_number, flat_id, amount: perFlat });
        mpRows.push(buildMpRow(flat_number, perFlat, flat_id));
      }
    }

    if (mode === 'outsider_only') {
      const raw = Number(payForm.outsiderAmount);
      if (payForm.allocationStyle === 'same_per_flat') {
        allocationStyle = 'same_per_flat';
        const perFlat = raw;
        totalAmount = perFlat * n;
        for (const { flat_number, flat_id } of poolFlats) {
          allocationRows.push({ flat_number, flat_id, amount: perFlat });
          if (payForm.destination === 'current_month_maintenance') {
            mpRows.push(buildMpRow(flat_number, perFlat, flat_id));
          }
        }
      } else {
        allocationStyle = 'split_total_equally';
        const perFlat = raw / n;
        totalAmount = raw;
        for (const { flat_number, flat_id } of poolFlats) {
          allocationRows.push({ flat_number, flat_id, amount: perFlat });
          if (payForm.destination === 'current_month_maintenance') {
            mpRows.push(buildMpRow(flat_number, perFlat, flat_id));
          }
        }
      }
    }

    if (mode === 'flats_plus_outsider') {
      const mAmt = Number(payForm.amount);
      const rawOut = Number(payForm.outsiderAmount);
      let outsiderPerFlat = 0;
      let outsiderTotal = 0;
      if (payForm.allocationStyle === 'same_per_flat') {
        allocationStyle = 'same_per_flat';
        outsiderPerFlat = rawOut;
        outsiderTotal = rawOut * n;
      } else {
        allocationStyle = 'split_total_equally';
        outsiderPerFlat = rawOut / n;
        outsiderTotal = rawOut;
      }
      totalAmount = mAmt * n + outsiderTotal;
      for (const { flat_number, flat_id } of poolFlats) {
        const allocAmt = mAmt + outsiderPerFlat;
        allocationRows.push({ flat_number, flat_id, amount: allocAmt });
        const mpAmt =
          payForm.destination === 'current_month_maintenance' ? mAmt + outsiderPerFlat : mAmt;
        mpRows.push(buildMpRow(flat_number, mpAmt, flat_id));
      }
    }

    const needsCounterparty =
      mode === 'outsider_only' ||
      mode === 'flats_plus_outsider' ||
      (mode === 'society_pool' && payForm.outsiderName.trim().length > 0);
    const entryTitle =
      mode === 'society_pool'
        ? payForm.entryTitle.trim() ||
          (payForm.outsiderName.trim() ? `Receipt: ${payForm.outsiderName.trim()}` : '') ||
          chargeTitle ||
          'Society pool receipt'
        : mode === 'outsider_only'
          ? payForm.entryTitle.trim() || `Outsider: ${payForm.outsiderName.trim()}`
          : mode === 'flats_plus_outsider'
            ? payForm.entryTitle.trim() || `${chargeTitle} + outsider (${payForm.outsiderName.trim()})`
            : chargeTitle;

    const chargeIdForEntry =
      mode === 'outsider_only' && payForm.destination !== 'current_month_maintenance'
        ? null
        : payForm.charge_id || null;

    const destForEntry =
      mode === 'flats_only'
        ? 'current_month_maintenance'
        : mode === 'society_pool' && payForm.destination === 'separate_entry'
          ? 'corpus'
          : payForm.destination;

    const aggregateFlatCount = mode === 'society_pool' ? 0 : n;

    const billingDatesForRows = mpRows.map((r) => String((r as { due_date: string }).due_date || primaryBillingDate));
    for (const d of billingDatesForRows) {
      if (!isBillingDateInEntryMonth(d, entryMonth)) {
        toast.error(`Each flat billing date must be in ${fmtIsoMonthToDisplay(entryMonth)}. Check: ${fmtIsoDateToDisplay(d)}`);
        return;
      }
    }
    const transactionDate =
      billingDatesForRows.length > 0
        ? billingDatesForRows.reduce((a, b) => (a < b ? a : b))
        : primaryBillingDate;

    const { data: feRow, error: feErr } = await supabase
      .from('finance_entries')
      .insert({
        society_id: societyId,
        record_mode: mode,
        destination: destForEntry,
        allocation_style: allocationStyle,
        include_vacant: payForm.allocationIncludeVacant,
        entry_month: entryMonth,
        transaction_date: transactionDate,
        total_amount: totalAmount,
        aggregate_flat_count: aggregateFlatCount,
        charge_id: chargeIdForEntry,
        title: entryTitle,
        notes: payForm.notes || null,
        screenshot_url: screenshotUrl,
        transaction_id: payForm.transaction_id || null,
        payment_method: payForm.payment_method,
        payment_status: 'verified',
        created_by: adminName,
      })
      .select('id')
      .single();

    if (feErr || !feRow?.id) {
      toast.error(feErr?.message ?? 'Could not save finance entry');
      return;
    }

    const entryId = feRow.id as string;

    if (needsCounterparty) {
      const { error: cpErr } = await supabase.from('finance_entry_counterparties').insert({
        finance_entry_id: entryId,
        name: payForm.outsiderName.trim(),
        relation_to_society: payForm.outsiderRelation.trim() || null,
      });
      if (cpErr) {
        toast.error(cpErr.message);
        return;
      }
    }

    if (allocationRows.length > 0) {
      const { error: allocErr } = await supabase.from('finance_entry_allocations').insert(
        allocationRows.map((a) => ({
          finance_entry_id: entryId,
          flat_id: a.flat_id,
          flat_number: a.flat_number,
          amount: a.amount,
        })),
      );
      if (allocErr) {
        toast.error(allocErr.message);
        return;
      }
    }

    if (mpRows.length > 0) {
      const { error: payErr } = await supabase
        .from('maintenance_payments')
        .insert(mpRows.map((row) => ({ ...row, finance_entry_id: entryId })));
      if (payErr) {
        toast.error(payErr.message);
        return;
      }
    }

    const notifyAudience = paymentNotifyAudience;
    const snapshotFlats = [...payForm.selected_flats];
    const payMethod = payForm.payment_method;
    const payTxn = payForm.transaction_id;
    const payNotes = payForm.notes;
    const allFlatNumbers = flats.map((f) => f.flat_number);

    setPayForm({
      recordMode: 'society_pool',
      destination: 'current_month_maintenance',
      allocationStyle: 'same_per_flat',
      allocationIncludeVacant: false,
      outsiderName: '',
      outsiderRelation: '',
      outsiderAmount: '',
      entryTitle: '',
      charge_id: '',
      selected_flats: [],
      amount: '',
      payment_method: 'cash',
      transaction_id: '',
      screenshot_url: '',
      notes: '',
      due_date: format(new Date(), 'yyyy-MM-dd'),
    });
    setUseSameDateForSelectedFlats(true);
    setFlatDueDates({});
    setAutoSelectedChargeHint('');
    setPaymentNotifyAudience('none');
    setShowPaymentForm(false);
    const recordedCount = mode === 'society_pool' ? 1 : mpRows.length || n;

    let notifySuffix = '';
    if (notifyAudience !== 'none') {
      const methodLabel = payMethod.replace(/_/g, ' ');
      const title = `Payment recorded: ${entryTitle}`;
      const lines = [
        `${adminName} recorded a ${methodLabel} finance entry (“${entryTitle}”).`,
        mode === 'society_pool'
          ? `₹${totalAmount.toLocaleString('en-IN')} is in the society pool until you distribute it equally to flats.`
          : `Flats in this record: ${snapshotFlats.join(', ')}. Total ₹${totalAmount.toLocaleString('en-IN')}.`,
      ];
      if (notifyAudience === 'all') {
        lines.push(`This update was shared with all ${allFlatNumbers.length} society flat(s).`);
      }
      if (payTxn.trim()) lines.push(`Reference: ${payTxn.trim()}.`);
      if (payNotes.trim()) lines.push(payNotes.trim());
      if (screenshotUrl) lines.push('Open the notification to view the attached receipt (if available).');
      const message = lines.join(' ');
      const ok = await notifyResidentsOfRecord({
        societyId,
        adminName,
        audience: notifyAudience,
        selectedFlatNumbers: snapshotFlats,
        title,
        message,
        notificationType: 'maintenance_payment',
        billUrl: screenshotUrl,
        saveSucceededHint:
          'Payment saved, but notifying residents failed. You can send a manual notice from Notifications.',
      });
      if (ok) notifySuffix = ' · Residents notified';
    }

    toast.success(
      (recordedCount > 1 ? `Recorded ${recordedCount} flat lines` : 'Finance entry recorded') + notifySuffix,
    );
    await loadAll();
    bumpHeadReconciliation();
  };

  const verifyPayment = async (id: string) => {
    const ok = await confirmAction('Verify Payment?', 'Confirm this payment as verified?', 'Yes, Verify', 'Cancel');
    if (!ok) return;
    const row = payments.find((p) => p.id === id);
    const reviewedAt = new Date().toISOString();
    await (supabase as any)
      .from('maintenance_payments')
      .update({
        payment_status: 'verified',
        verified_by: adminName,
        verified_at: reviewedAt,
        reviewed_at: reviewedAt,
        rejection_reason: null,
      })
      .eq('id', id);
    if (row?.flat_number) {
      const chargeTitle = charges.find((c) => c.id === row.charge_id)?.title || 'Maintenance charge';
      const title = `Payment approved: ${chargeTitle}`;
      const message = `Your payment of ₹${Number(row.amount || 0).toLocaleString('en-IN')} has been approved by ${adminName}.`;
      await (supabase as any).from('notifications').insert([
        {
          society_id: societyId,
          title,
          message,
          type: 'maintenance_payment_decision',
          target_type: 'flat',
          target_id: row.flat_number,
          created_by: adminName,
        },
      ]);
      await supabase.functions.invoke('send-push-notification', {
        body: {
          title,
          message,
          target_type: 'flat',
          target_flat_numbers: [row.flat_number],
          target_ids: [],
          media_items: [],
          society_id: societyId,
          sound_key: 'digital',
          sound_custom_url: '',
        },
      });
    }
    showSuccess('Verified!', 'Payment verified successfully');
    await loadAll();
  };

  const rejectPayment = async (id: string) => {
    const ok = await confirmAction('Reject Payment?', 'Are you sure you want to reject this payment?', 'Yes, Reject', 'Cancel');
    if (!ok) return;
    const reasonInput = window.prompt('Enter rejection reason (required):', '');
    if (reasonInput === null) return;
    const reason = reasonInput.trim();
    if (!reason) {
      toast.error('Rejection reason is required');
      return;
    }
    const row = payments.find((p) => p.id === id);
    const reviewedAt = new Date().toISOString();
    await (supabase as any)
      .from('maintenance_payments')
      .update({
        payment_status: 'rejected',
        verified_by: adminName,
        verified_at: reviewedAt,
        reviewed_at: reviewedAt,
        rejection_reason: reason,
      })
      .eq('id', id);
    if (row?.flat_number) {
      const chargeTitle = charges.find((c) => c.id === row.charge_id)?.title || 'Maintenance charge';
      const title = `Payment rejected: ${chargeTitle}`;
      const message = `Your payment entry was rejected by ${adminName}. Reason: ${reason}`;
      await (supabase as any).from('notifications').insert([
        {
          society_id: societyId,
          title,
          message,
          type: 'maintenance_payment_decision',
          target_type: 'flat',
          target_id: row.flat_number,
          created_by: adminName,
        },
      ]);
      await supabase.functions.invoke('send-push-notification', {
        body: {
          title,
          message,
          target_type: 'flat',
          target_flat_numbers: [row.flat_number],
          target_ids: [],
          media_items: [],
          society_id: societyId,
          sound_key: 'digital',
          sound_custom_url: '',
        },
      });
    }
    showSuccess('Rejected', 'Payment has been rejected');
    await loadAll();
  };

  const deleteMaintenancePaymentRowInternal = async (p: any) => {
    const feId = p.finance_entry_id as string | null | undefined;
    if (feId) {
      await supabase
        .from('finance_entry_allocations')
        .delete()
        .eq('finance_entry_id', feId)
        .eq('flat_number', String(p.flat_number));
    }
    await supabase.from('maintenance_payments').delete().eq('id', p.id);
    if (feId) {
      const { data: restAllocs } = await supabase
        .from('finance_entry_allocations')
        .select('amount')
        .eq('finance_entry_id', feId);
      const { data: restMps } = await supabase
        .from('maintenance_payments')
        .select('id')
        .eq('finance_entry_id', feId);
      const total = restAllocs?.reduce((s, a) => s + Number(a.amount), 0) ?? 0;
      const acount = restAllocs?.length ?? 0;
      const mpLeft = restMps?.length ?? 0;
      if (acount === 0 && mpLeft === 0) {
        await supabase.from('finance_entries').delete().eq('id', feId);
      } else if (acount > 0) {
        await supabase
          .from('finance_entries')
          .update({ total_amount: total, aggregate_flat_count: acount })
          .eq('id', feId);
      } else if (mpLeft > 0) {
        await supabase.from('maintenance_payments').update({ finance_entry_id: null }).eq('finance_entry_id', feId);
        await supabase.from('finance_entries').delete().eq('id', feId);
      }
    }
  };

  const deleteMaintenancePaymentRow = async (p: any) => {
    const ok = await confirmAction(
      'Delete this payment?',
      'This removes the payment record and updates linked ledger rows when applicable.',
      'Delete',
      'Cancel',
    );
    if (!ok) return;
    await deleteMaintenancePaymentRowInternal(p);
    toast.success('Payment deleted');
    setSelectedReceiptKeys((prev) => {
      const next = new Set(prev);
      next.delete(`mp-${p.id}`);
      return next;
    });
    await loadAll();
  };

  const updateLedgerEntryStatus = async (entryId: string, payment_status: string) => {
    const { error } = await supabase.from('finance_entries').update({ payment_status }).eq('id', entryId);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Status updated');
    await loadAll();
  };

  const deleteLedgerRow = async (e: FinanceLedgerRow) => {
    const ok = await confirmAction(
      'Delete this ledger entry?',
      'Removes ledger allocations and counterparty data. Ledger-only rows have no maintenance payments.',
      'Delete',
      'Cancel',
    );
    if (!ok) return;
    await supabase.from('finance_entries').delete().eq('id', e.id);
    toast.success('Ledger entry deleted');
    setSelectedReceiptKeys((prev) => {
      const next = new Set(prev);
      next.delete(`ledger-${e.id}`);
      return next;
    });
    await loadAll();
  };

  const applyMaintenancePaymentStatus = async (
    id: string,
    nextStatus: 'pending' | 'verified' | 'rejected',
    opts?: { reason?: string; notify?: boolean; skipReload?: boolean },
  ) => {
    const row = payments.find((x) => x.id === id);
    if (!row) return;
    const reviewedAt = new Date().toISOString();
    const notify = opts?.notify !== false;

    if (nextStatus === 'verified') {
      await (supabase as any).from('maintenance_payments').update({
        payment_status: 'verified',
        verified_by: adminName,
        verified_at: reviewedAt,
        reviewed_at: reviewedAt,
        rejection_reason: null,
      }).eq('id', id);
      if (notify && row.flat_number) {
        const chargeTitle = charges.find((c) => c.id === row.charge_id)?.title || 'Maintenance charge';
        const title = `Payment approved: ${chargeTitle}`;
        const message = `Your payment of ₹${Number(row.amount || 0).toLocaleString('en-IN')} has been approved by ${adminName}.`;
        await (supabase as any).from('notifications').insert([
          {
            society_id: societyId,
            title,
            message,
            type: 'maintenance_payment_decision',
            target_type: 'flat',
            target_id: row.flat_number,
            created_by: adminName,
          },
        ]);
        await supabase.functions.invoke('send-push-notification', {
          body: {
            title,
            message,
            target_type: 'flat',
            target_flat_numbers: [row.flat_number],
            target_ids: [],
            media_items: [],
            society_id: societyId,
            sound_key: 'digital',
            sound_custom_url: '',
          },
        });
      }
    } else if (nextStatus === 'rejected') {
      const reason = opts?.reason?.trim() || 'Rejected by admin';
      await (supabase as any).from('maintenance_payments').update({
        payment_status: 'rejected',
        verified_by: adminName,
        verified_at: reviewedAt,
        reviewed_at: reviewedAt,
        rejection_reason: reason,
      }).eq('id', id);
      if (notify && row.flat_number) {
        const chargeTitle = charges.find((c) => c.id === row.charge_id)?.title || 'Maintenance charge';
        const title = `Payment rejected: ${chargeTitle}`;
        const message = `Your payment entry was rejected by ${adminName}. Reason: ${reason}`;
        await (supabase as any).from('notifications').insert([
          {
            society_id: societyId,
            title,
            message,
            type: 'maintenance_payment_decision',
            target_type: 'flat',
            target_id: row.flat_number,
            created_by: adminName,
          },
        ]);
        await supabase.functions.invoke('send-push-notification', {
          body: {
            title,
            message,
            target_type: 'flat',
            target_flat_numbers: [row.flat_number],
            target_ids: [],
            media_items: [],
            society_id: societyId,
            sound_key: 'digital',
            sound_custom_url: '',
          },
        });
      }
    } else {
      await (supabase as any).from('maintenance_payments').update({
        payment_status: 'pending',
        verified_by: null,
        verified_at: null,
        reviewed_at: null,
        rejection_reason: null,
      }).eq('id', id);
    }
    if (!opts?.skipReload) await loadAll();
  };

  const savePaymentEdit = async () => {
    if (!paymentEdit || !societyId) return;
    const reviewedAt = new Date().toISOString();
    const payload: Record<string, unknown> = {
      charge_id: paymentEdit.charge_id || null,
      amount: Number(paymentEdit.amount),
      payment_method: paymentEdit.payment_method,
      transaction_id: paymentEdit.transaction_id.trim() || null,
      notes: paymentEdit.notes.trim() || null,
      due_date: paymentEdit.due_date,
      recording_date: paymentEdit.recording_date,
      payment_status: paymentEdit.payment_status,
    };
    if (paymentEdit.payment_status === 'verified') {
      payload.verified_by = adminName;
      payload.verified_at = reviewedAt;
      payload.reviewed_at = reviewedAt;
      payload.rejection_reason = null;
    } else if (paymentEdit.payment_status === 'rejected') {
      payload.verified_by = adminName;
      payload.verified_at = reviewedAt;
      payload.reviewed_at = reviewedAt;
      payload.rejection_reason = paymentEdit.rejection_reason.trim() || 'Rejected by admin';
    } else {
      payload.verified_by = null;
      payload.verified_at = null;
      payload.reviewed_at = null;
      payload.rejection_reason = null;
    }
    const { error } = await (supabase as any).from('maintenance_payments').update(payload).eq('id', paymentEdit.id);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Payment updated');
    setPaymentEdit(null);
    await loadAll();
  };

  const saveLedgerEdit = async () => {
    if (!ledgerEdit) return;
    const entryMonth = ledgerEntryMonthFromBilling(ledgerEdit.transaction_date);
    if (!isBillingDateInEntryMonth(ledgerEdit.transaction_date, entryMonth)) {
      toast.error('Billing date must fall within the entry month.');
      return;
    }
    const { error } = await supabase
      .from('finance_entries')
      .update({
        title: ledgerEdit.title.trim() || null,
        notes: ledgerEdit.notes.trim() || null,
        payment_status: ledgerEdit.payment_status,
        transaction_id: ledgerEdit.transaction_id.trim() || null,
        payment_method: ledgerEdit.payment_method,
        total_amount: Number(ledgerEdit.total_amount) || 0,
        entry_month: entryMonth,
        transaction_date: ledgerEdit.transaction_date,
      })
      .eq('id', ledgerEdit.id);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Ledger entry updated');
    setLedgerEdit(null);
    await loadAll();
  };

  const bulkDeleteSelectedReceipts = async () => {
    if (selectedReceiptKeys.size === 0) return;
    const ok = await confirmAction(
      `Delete ${selectedReceiptKeys.size} selected entries?`,
      'This cannot be undone.',
      'Delete all',
      'Cancel',
    );
    if (!ok) return;
    for (const key of selectedReceiptKeys) {
      if (key.startsWith('mp-')) {
        const id = key.slice(3);
        const p = payments.find((x) => x.id === id);
        if (p) await deleteMaintenancePaymentRowInternal(p);
      } else if (key.startsWith('ledger-')) {
        const id = key.slice(7);
        await supabase.from('finance_entries').delete().eq('id', id);
      }
    }
    setSelectedReceiptKeys(new Set());
    toast.success('Selected entries deleted');
    await loadAll();
  };

  const bulkSetPaymentStatus = async (nextStatus: 'pending' | 'verified' | 'rejected') => {
    const mpIds = [...selectedReceiptKeys].filter((k) => k.startsWith('mp-')).map((k) => k.slice(3));
    if (mpIds.length === 0) {
      toast.error('Select maintenance payment rows (not ledger-only) for bulk status');
      return;
    }
    let reason = '';
    if (nextStatus === 'rejected') {
      reason = window.prompt('Rejection reason for all selected (required):', '') ?? '';
      if (!reason.trim()) {
        toast.error('Reason required');
        return;
      }
    }
    const ok = await confirmAction(
      `Set ${mpIds.length} payments to ${nextStatus}?`,
      nextStatus === 'rejected' ? `Reason: ${reason}` : 'Residents will not be notified in bulk mode.',
      'Apply',
      'Cancel',
    );
    if (!ok) return;
    for (const id of mpIds) {
      await applyMaintenancePaymentStatus(id, nextStatus, {
        reason: reason.trim(),
        notify: false,
        skipReload: true,
      });
    }
    setSelectedReceiptKeys(new Set());
    toast.success('Status updated for selected payments');
    await loadAll();
  };

  const toggleReceiptKey = (key: string, checked: boolean) => {
    setSelectedReceiptKeys((prev) => {
      const next = new Set(prev);
      if (checked) next.add(key);
      else next.delete(key);
      return next;
    });
  };

  const changeReceiptPaymentStatus = async (p: any, v: string) => {
    const next = v as 'pending' | 'verified' | 'rejected';
    if (next === 'rejected') {
      const reason = window.prompt('Rejection reason:', p.rejection_reason || '');
      if (reason === null) return;
      if (!reason.trim()) {
        toast.error('Reason required');
        return;
      }
      await applyMaintenancePaymentStatus(p.id, 'rejected', { reason: reason.trim() });
      return;
    }
    await applyMaintenancePaymentStatus(p.id, next);
  };

  const openPaymentEdit = (p: any) => {
    setPaymentEdit({
      id: p.id,
      charge_id: p.charge_id ?? '',
      amount: String(p.amount ?? ''),
      payment_method: p.payment_method ?? 'cash',
      transaction_id: p.transaction_id ?? '',
      notes: p.notes ?? '',
      due_date: (p.due_date || '').toString().slice(0, 10),
      recording_date: (p.recording_date || p.created_at || '').toString().slice(0, 10),
      payment_status: p.payment_status ?? 'pending',
      rejection_reason: p.rejection_reason ?? '',
    });
  };

  const openLedgerEdit = (e: FinanceLedgerRow) => {
    const txDate = ledgerTransactionDate(e);
    setLedgerEdit({
      id: e.id,
      title: e.title ?? '',
      notes: e.notes ?? '',
      payment_status: e.payment_status ?? 'verified',
      transaction_id: e.transaction_id ?? '',
      payment_method: e.payment_method ?? 'cash',
      total_amount: String(e.total_amount ?? ''),
      entry_month: e.entry_month ?? billingMonthFromDate(txDate),
      transaction_date: txDate,
    });
  };

  const targetFlats = includeVacantFlats ? flats : flats.filter((f) => f.is_occupied);
  const paymentScopeFlats = useMemo(
    () => (payForm.allocationIncludeVacant ? flats : flats.filter((f) => f.is_occupied)),
    [flats, payForm.allocationIncludeVacant],
  );

  const receiptHeadConflictsPreview = useMemo(() => {
    if (
      !payForm.charge_id ||
      payForm.recordMode === 'society_pool' ||
      (payForm.recordMode !== 'flats_only' && payForm.recordMode !== 'flats_plus_outsider') ||
      payForm.selected_flats.length === 0
    ) {
      return [] as AuditPaymentRow[];
    }
    const targets = payForm.selected_flats
      .map((flatNumber) => ({
        flatNumber,
        dueDate: useSameDateForSelectedFlats ? payForm.due_date : (flatDueDates[flatNumber] || payForm.due_date),
        chargeId: payForm.charge_id,
        paymentMethod: payForm.payment_method,
      }))
      .filter((t) => t.dueDate);
    return findReceiptHeadConflicts(payments as AuditPaymentRow[], targets);
  }, [
    payForm.charge_id,
    payForm.recordMode,
    payForm.selected_flats,
    payForm.due_date,
    payForm.payment_method,
    payments,
    useSameDateForSelectedFlats,
    flatDueDates,
  ]);

  const unpaidFlats = targetFlats.filter(f => !payments.some(p => p.flat_number === f.flat_number && p.payment_status === 'verified'));

  const chargeById = useMemo(() => {
    const m = new Map<string, any>();
    for (const c of charges) {
      if (c?.id) m.set(c.id, c);
    }
    return m;
  }, [charges]);

  const chargeIdsWithDependents = useMemo(() => {
    const s = new Set<string>();
    for (const p of payments) {
      if (p.charge_id) s.add(p.charge_id as string);
    }
    for (const e of ledgerEntries) {
      if (e.charge_id) s.add(e.charge_id);
    }
    return s;
  }, [payments, ledgerEntries]);

  const financeEntryById = useMemo(() => {
    const m = new Map<string, FinanceLedgerRow>();
    for (const e of ledgerEntries) m.set(e.id, e);
    return m;
  }, [ledgerEntries]);

  const financeEntryIdsWithPayments = useMemo(() => {
    const s = new Set<string>();
    for (const p of payments) {
      if (p.finance_entry_id) s.add(p.finance_entry_id as string);
    }
    return s;
  }, [payments]);

  const paymentTypeOptions = useMemo(() => {
    const keys = new Set<string>();
    for (const p of payments) {
      const ch = chargeById.get(p.charge_id);
      if (ch && isMonthlyMaintenanceCharge(ch)) {
        keys.add('monthly_maintenance');
      } else if (ch?.frequency) {
        keys.add(String(ch.frequency).toLowerCase());
      } else {
        keys.add('other');
      }
    }

    const options: { value: string; label: string }[] = [
      { value: 'all', label: '--All--' },
      { value: 'all_payments', label: 'Society payment records' },
      { value: 'all_receipts', label: 'All society receipt records' },
    ];
    if (ledgerEntries.some((e) => isLedgerInSocietyPool(e))) {
      options.push({ value: 'society_pool_pending', label: 'In society pool (not yet distributed)' });
    }
    if (keys.has('monthly_maintenance')) options.push({ value: 'monthly_maintenance', label: 'Monthly Maintenance Charges' });
    if (keys.has('monthly')) options.push({ value: 'monthly', label: 'Monthly (non-maintenance)' });
    if (keys.has('quarterly')) options.push({ value: 'quarterly', label: 'Quarterly charges' });
    if (keys.has('yearly')) options.push({ value: 'yearly', label: 'Yearly charges' });
    if (keys.has('one-time')) options.push({ value: 'one-time', label: 'One-time charges' });
    if (keys.has('other')) options.push({ value: 'other', label: 'Other / unknown charges' });
    if (ledgerEntries.some((e) => e.destination === 'corpus')) {
      options.push({ value: 'corpus', label: 'Corpus / sinking (ledger only)' });
    }
    if (ledgerEntries.some((e) => e.record_mode !== 'flats_only')) {
      options.push({ value: 'outsider_mixed', label: 'Outsider / mixed (ledger only)' });
    }
    return options;
  }, [payments, chargeById, ledgerEntries]);

  const monthOptionsForReceipts = useMemo(() => {
    const uniq = new Map<string, string>();
    for (const p of payments) {
      const value = paymentMonthValue(p);
      if (!value) continue;
      if (!uniq.has(value)) uniq.set(value, paymentMonthLabel(p));
    }
    for (const e of societyLedgerEntries) {
      const value = ledgerMonthValue(e);
      const d = new Date(`${value}-15T12:00:00`);
      const label = Number.isNaN(d.getTime()) ? value : fmtIsoMonthToDisplay(value);
      if (!uniq.has(value)) uniq.set(value, label);
    }
    return [{ value: 'all', label: 'All months' }, ...[...uniq.entries()].sort((a, b) => (a[0] < b[0] ? 1 : -1)).map(([value, label]) => ({ value, label }))];
  }, [payments, societyLedgerEntries]);

  const selectedFlatDateBadges = useMemo(() => {
    const out: Record<string, string> = {};
    for (const flatNum of payForm.selected_flats) {
      const rawDate = useSameDateForSelectedFlats ? payForm.due_date : (flatDueDates[flatNum] || '');
      if (!rawDate) continue;
      const d = new Date(rawDate);
      out[flatNum] = Number.isNaN(d.getTime()) ? rawDate : fmtDate(d);
    }
    return out;
  }, [payForm.selected_flats, payForm.due_date, useSameDateForSelectedFlats, flatDueDates]);

  const scopedReceiptPayments = payments.filter((p) => {
    if (
      paymentTypeFilter === 'corpus' ||
      paymentTypeFilter === 'outsider_mixed' ||
      paymentTypeFilter === 'all_payments' ||
      paymentTypeFilter === 'society_pool_pending'
    )
      return false;
    const fe = p.finance_entry_id ? financeEntryById.get(p.finance_entry_id as string) : undefined;
    if (fe && isGroupExpenseLedgerEntry(fe)) return false;
    if (receiptModeFilter !== 'all') {
      const mode = fe?.record_mode ?? 'flats_only';
      if (mode !== receiptModeFilter) return false;
    }
    const ch = chargeById.get(p.charge_id);
    if (paymentTypeFilter === 'monthly_maintenance') {
      if (!ch || !isMonthlyMaintenanceCharge(ch)) return false;
    } else if (paymentTypeFilter === 'other') {
      if (ch) return false;
    } else if (paymentTypeFilter !== 'all' && paymentTypeFilter !== 'all_receipts') {
      if (!ch || String(ch.frequency).toLowerCase() !== paymentTypeFilter) return false;
    }
    if (paymentMonthFilter !== 'all') {
      if (paymentMonthValue(p) !== paymentMonthFilter) return false;
    }
    const q = paymentSearchQuery.trim().toLowerCase();
    if (q) {
      const chargeTitle = String(chargeById.get(p.charge_id)?.title || '').toLowerCase();
      const flatMeta = flats.find((f) => f.flat_number === p.flat_number);
      const flatOwner = String(flatMeta?.owner_name || '').toLowerCase();
      const haystack = [
        String(p.flat_number || ''),
        String(p.resident_name || ''),
        String(p.transaction_id || ''),
        String(p.notes || ''),
        String(p.payment_method || ''),
        chargeTitle,
        flatOwner,
      ]
        .join(' ')
        .toLowerCase();
      if (!haystack.includes(q)) return false;
    }
    return true;
  });

  const filteredPayments = scopedReceiptPayments.filter((p) => {
    if (filterStatus === 'all') return true;
    if (filterStatus === 'unpaid') return false;
    return p.payment_status === filterStatus;
  });

  const scopedLedgerOnly = useMemo(() => {
    return societyLedgerEntries.filter((e) => {
      const societyPayment = isSocietyPaymentLedgerEntry(e);
      if (paymentTypeFilter === 'all_payments' && !societyPayment) return false;
      if (
        (paymentTypeFilter === 'all_receipts' ||
          paymentTypeFilter === 'society_pool_pending' ||
          paymentTypeFilter === 'monthly_maintenance' ||
          paymentTypeFilter === 'corpus' ||
          paymentTypeFilter === 'outsider_mixed' ||
          paymentTypeFilter === 'other' ||
          paymentTypeFilter === 'monthly' ||
          paymentTypeFilter === 'quarterly' ||
          paymentTypeFilter === 'yearly' ||
          paymentTypeFilter === 'one-time') &&
        societyPayment
      )
        return false;
      if (paymentTypeFilter === 'society_pool_pending' && !isLedgerInSocietyPool(e)) return false;

      if (financeEntryIdsWithPayments.has(e.id)) return false;
      if (receiptModeFilter !== 'all' && e.record_mode !== receiptModeFilter) return false;
      if (paymentMonthFilter !== 'all' && ledgerMonthValue(e) !== paymentMonthFilter) return false;

      // Apply payment status filter to ledger entries as well
      if (filterStatus !== 'all' && filterStatus !== 'unpaid') {
        if (e.payment_status !== filterStatus) return false;
      }

      if (paymentTypeFilter === 'all' || paymentTypeFilter === 'all_payments' || paymentTypeFilter === 'all_receipts') {
        // include (society payment / receipt filters applied above)
      } else if (paymentTypeFilter === 'society_pool_pending') {
        // include pooled rows only
      } else if (paymentTypeFilter === 'monthly_maintenance') {
        if (e.destination === 'corpus') return false;
        const ch = e.charge_id ? chargeById.get(e.charge_id) : null;
        if (ch && isMonthlyMaintenanceCharge(ch)) return true;
        if (
          e.destination === 'current_month_maintenance' &&
          (e.record_mode === 'outsider_only' || e.record_mode === 'flats_plus_outsider')
        )
          return true;
        if (e.record_mode === 'flats_only' && e.charge_id && ch && isMonthlyMaintenanceCharge(ch)) return true;
        return false;
      } else if (paymentTypeFilter === 'corpus') {
        if (e.destination !== 'corpus') return false;
      } else if (paymentTypeFilter === 'outsider_mixed') {
        if (e.record_mode === 'flats_only') return false;
      } else {
        const ch = e.charge_id ? chargeById.get(e.charge_id) : null;
        if (!ch || String(ch.frequency).toLowerCase() !== paymentTypeFilter) return false;
      }

      const q = paymentSearchQuery.trim().toLowerCase();
      if (!q) return true;
      const rawCp = e.finance_entry_counterparties;
      const cp = Array.isArray(rawCp) ? rawCp[0] : rawCp;
      const parts = [e.title, e.notes, e.transaction_id, (cp as any)?.name, (cp as any)?.relation_to_society]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return parts.includes(q);
    });
  }, [
    societyLedgerEntries,
    financeEntryIdsWithPayments,
    receiptModeFilter,
    paymentMonthFilter,
    paymentTypeFilter,
    filterStatus,
    paymentSearchQuery,
    chargeById,
    isSocietyPaymentLedgerEntry,
  ]);

  const unpaidReceiptRows = useMemo(() => {
    if (filterStatus !== 'unpaid') return [] as { flat_number: string; primary_name: string }[];
    const paidSet = new Set(
      scopedReceiptPayments
        .filter((p) => p.payment_status === 'verified')
        .map((p) => String(p.flat_number))
        .filter(Boolean),
    );
    const q = paymentSearchQuery.trim().toLowerCase();
    return targetFlats
      .filter((f) => !paidSet.has(String(f.flat_number)))
      .map((f) => ({
        flat_number: f.flat_number,
        primary_name: residentLabelForFlatRow(f.id, f.owner_name ?? null, primaryByFlatId),
      }))
      .filter((row) => {
        if (!q) return true;
        return `${row.flat_number} ${row.primary_name}`.toLowerCase().includes(q);
      });
  }, [filterStatus, scopedReceiptPayments, targetFlats, paymentSearchQuery, primaryByFlatId]);

  const receiptSummary = useMemo(() => {
    if (filterStatus === 'unpaid') {
      return {
        count: unpaidReceiptRows.length,
        sum: 0,
        flatCount: unpaidReceiptRows.length,
      };
    }
    const flatSet = new Set<string>();
    let sum = 0;
    for (const p of filteredPayments) {
      sum += Number(p.amount || 0);
      if (p.flat_number) flatSet.add(String(p.flat_number));
    }
    for (const e of scopedLedgerOnly) {
      sum += Number(e.total_amount || 0);
      for (const a of e.finance_entry_allocations ?? []) flatSet.add(a.flat_number);
    }
    return {
      count: filteredPayments.length + scopedLedgerOnly.length,
      sum,
      flatCount: flatSet.size,
    };
  }, [filterStatus, unpaidReceiptRows, filteredPayments, scopedLedgerOnly]);

  const ledgerReceiptHead = useCallback(
    (e: FinanceLedgerRow): string => {
      const ch = e.charge_id ? chargeById.get(e.charge_id) : null;
      if (ch) return majorHeadForCharge(ch);
      if (e.destination === 'corpus') return 'SOCIETY CORPUS FUND';
      if (e.destination === 'current_month_maintenance') return 'OPERATION & MAINTENANCE';
      const title = (e.title ?? '').trim();
      if (title) return inferMajorHeadFromGroupName(title);
      return 'Uncategorized';
    },
    [chargeById, majorHeadForCharge],
  );

  const transactionReceiptHeadSummary = useMemo((): TransactionHeadSummaryRow[] => {
    if (filterStatus === 'unpaid') return [];
    const map = new Map<string, TransactionHeadSummaryRow>();
    for (const p of filteredPayments) {
      const ch = chargeById.get(p.charge_id);
      const head = ch ? majorHeadForCharge(ch) : 'Uncategorized';
      addTransactionHeadRow(map, head, Number(p.amount || 0), p.payment_method);
    }
    for (const e of scopedLedgerOnly) {
      if (isSocietyPaymentLedgerEntry(e)) continue;
      addTransactionHeadRow(map, ledgerReceiptHead(e), Number(e.total_amount || 0), e.payment_method);
    }
    return transactionHeadSummaryRows(map);
  }, [
    filterStatus,
    filteredPayments,
    scopedLedgerOnly,
    chargeById,
    majorHeadForCharge,
    isSocietyPaymentLedgerEntry,
    ledgerReceiptHead,
  ]);

  const transactionPaymentHeadSummary = useMemo((): TransactionHeadSummaryRow[] => {
    if (filterStatus === 'unpaid') return [];
    const map = new Map<string, TransactionHeadSummaryRow>();
    for (const e of scopedLedgerOnly) {
      if (!isSocietyPaymentLedgerEntry(e)) continue;
      const head = financeExpenseHeadFromLedgerEntry(
        e.title,
        e.expense_id ? expenseCategoryById.get(e.expense_id) : null,
      );
      addTransactionHeadRow(map, head, Number(e.total_amount || 0), e.payment_method);
    }
    return transactionHeadSummaryRows(map);
  }, [filterStatus, scopedLedgerOnly, isSocietyPaymentLedgerEntry, expenseCategoryById]);

  const transactionReceiptChannelTotals = useMemo(
    () =>
      transactionReceiptHeadSummary.reduce(
        (acc, r) => {
          acc.cash += r.byChannel.cash;
          acc.bank += r.byChannel.bank;
          acc.other += r.byChannel.other;
          return acc;
        },
        { cash: 0, bank: 0, other: 0 } as ChannelTotals,
      ),
    [transactionReceiptHeadSummary],
  );

  const transactionPaymentChannelTotals = useMemo(
    () =>
      transactionPaymentHeadSummary.reduce(
        (acc, r) => {
          acc.cash += r.byChannel.cash;
          acc.bank += r.byChannel.bank;
          acc.other += r.byChannel.other;
          return acc;
        },
        { cash: 0, bank: 0, other: 0 } as ChannelTotals,
      ),
    [transactionPaymentHeadSummary],
  );

  const pushHeadSummaryModal = useCallback((layer: TransactionHeadModalLayer) => {
    setHeadSummaryModalStack((s) => [...s, layer]);
    setHeadSummaryModalOpen(true);
  }, []);

  const closeHeadSummaryModal = useCallback(() => {
    setHeadSummaryModalOpen(false);
    setHeadSummaryModalStack([]);
  }, []);

  const headSummaryModalBack = useCallback(() => {
    setHeadSummaryModalStack((s) => {
      const next = s.slice(0, -1);
      if (next.length === 0) setHeadSummaryModalOpen(false);
      return next;
    });
  }, []);

  const buildReceiptHeadEntryRows = useCallback(
    (head: string): ReportDetailRow[] => {
      const items: { t: string; row: ReportDetailRow }[] = [];
      for (const p of filteredPayments) {
        const ch = chargeById.get(p.charge_id);
        const h = ch ? majorHeadForCharge(ch) : 'Uncategorized';
        if (h !== head) continue;
        items.push({
          t: p.created_at ?? '',
          row: {
            id: `mp-${p.id}`,
            label: `Flat ${p.flat_number}`,
            sublabel: `${chargeById.get(p.charge_id)?.title || 'Unknown charge'} · ${p.resident_name || '—'}`,
            amount: Number(p.amount || 0),
            date: fmtDate(p.created_at),
            dateIso: String(p.created_at ?? ''),
            status: p.payment_status,
            extra: String(p.payment_method || '').toUpperCase() || undefined,
            meta: { kind: 'mp', payment: p },
          },
        });
      }
      for (const e of scopedLedgerOnly) {
        if (isSocietyPaymentLedgerEntry(e)) continue;
        if (ledgerReceiptHead(e) !== head) continue;
        items.push({
          t: e.created_at ?? '',
          row: {
            id: `ledger-${e.id}`,
            label: e.title || 'Finance entry',
            sublabel: `${e.record_mode.replace(/_/g, ' ')} · ${e.destination.replace(/_/g, ' ')}`,
            amount: Number(e.total_amount || 0),
            date: fmtDate(e.created_at),
            dateIso: String(e.created_at ?? ''),
            status: e.payment_status,
            extra: String(e.payment_method || '').toUpperCase() || undefined,
            meta: { kind: 'ledger', entry: e },
          },
        });
      }
      items.sort((a, b) => (a.t < b.t ? 1 : -1));
      return items.map((i) => i.row);
    },
    [
      filteredPayments,
      scopedLedgerOnly,
      chargeById,
      majorHeadForCharge,
      isSocietyPaymentLedgerEntry,
      ledgerReceiptHead,
    ],
  );

  const buildPaymentHeadEntryRows = useCallback(
    (head: string): ReportDetailRow[] => {
      const items: { t: string; row: ReportDetailRow }[] = [];
      for (const e of scopedLedgerOnly) {
        if (!isSocietyPaymentLedgerEntry(e)) continue;
        const h = financeExpenseHeadFromLedgerEntry(
          e.title,
          e.expense_id ? expenseCategoryById.get(e.expense_id) : null,
        );
        if (h !== head) continue;
        items.push({
          t: e.created_at ?? '',
          row: {
            id: `ledger-${e.id}`,
            label: e.title || 'Society payment',
            sublabel: `${e.record_mode.replace(/_/g, ' ')} · ${e.destination.replace(/_/g, ' ')}`,
            amount: Number(e.total_amount || 0),
            date: fmtDate(e.created_at),
            dateIso: String(e.created_at ?? ''),
            status: e.payment_status,
            extra: String(e.payment_method || '').toUpperCase() || undefined,
            meta: { kind: 'ledger', entry: e },
          },
        });
      }
      items.sort((a, b) => (a.t < b.t ? 1 : -1));
      return items.map((i) => i.row);
    },
    [scopedLedgerOnly, isSocietyPaymentLedgerEntry, expenseCategoryById],
  );

  const openHeadSummaryEntryDetail = useCallback(
    (row: ReportDetailRow) => {
      const kind = row.meta?.kind;
      if (kind === 'mp') {
        const p = row.meta?.payment as Record<string, unknown> | undefined;
        if (!p) return;
        const charge = chargeById.get(p.charge_id as string);
        pushHeadSummaryModal({
          title: 'Receipt detail',
          subtitle: `Flat ${p.flat_number}`,
          total: Number(p.amount || 0),
          drillable: false,
          rows: [
            { id: 'd-charge', label: 'Charge', sublabel: charge?.title || 'Unknown charge' },
            { id: 'd-flat', label: 'Flat', sublabel: String(p.flat_number ?? '—') },
            { id: 'd-resident', label: 'Resident', sublabel: String(p.resident_name || '—') },
            { id: 'd-amt', label: 'Amount', amount: Number(p.amount || 0) },
            { id: 'd-type', label: 'Type', sublabel: charge?.frequency || '—' },
            { id: 'd-method', label: 'Payment method', sublabel: String(p.payment_method || '—') },
            { id: 'd-status', label: 'Status', sublabel: String(p.payment_status || '—') },
            { id: 'd-month', label: 'Payment month', sublabel: paymentMonthLabel(p) },
            {
              id: 'd-due',
              label: 'Due date',
              sublabel: p.due_date ? fmtIsoDateToDisplay(String(p.due_date)) : '—',
            },
            { id: 'd-txn', label: 'Transaction ID', sublabel: String(p.transaction_id || '—') },
            { id: 'd-notes', label: 'Notes', sublabel: String(p.notes || '—') },
          ],
        });
        return;
      }
      if (kind === 'ledger') {
        const e = row.meta?.entry as FinanceLedgerRow | undefined;
        if (!e) return;
        const rawCp = e.finance_entry_counterparties;
        const cp = Array.isArray(rawCp) ? rawCp[0] : rawCp;
        const detailRows: ReportDetailRow[] = [
          { id: 'd-title', label: 'Title', sublabel: e.title || '—' },
          { id: 'd-mode', label: 'Record mode', sublabel: e.record_mode.replace(/_/g, ' ') },
          { id: 'd-dest', label: 'Destination', sublabel: e.destination.replace(/_/g, ' ') },
          { id: 'd-amt', label: 'Amount', amount: Number(e.total_amount || 0) },
          { id: 'd-month', label: 'Entry month', sublabel: ledgerMonthDisplay(e) },
          { id: 'd-flats', label: 'Flats in entry', sublabel: String(e.aggregate_flat_count) },
          { id: 'd-method', label: 'Payment method', sublabel: e.payment_method || '—' },
          { id: 'd-txn', label: 'Transaction ID', sublabel: e.transaction_id || '—' },
          { id: 'd-status', label: 'Status', sublabel: e.payment_status },
          { id: 'd-notes', label: 'Notes', sublabel: e.notes || '—' },
        ];
        if (cp) {
          detailRows.splice(4, 0, {
            id: 'd-from',
            label: 'From',
            sublabel: `${(cp as { name?: string }).name ?? '—'}${
              (cp as { relation_to_society?: string | null }).relation_to_society
                ? ` · ${(cp as { relation_to_society?: string | null }).relation_to_society}`
                : ''
            }`,
          });
        }
        for (const a of e.finance_entry_allocations ?? []) {
          detailRows.push({
            id: `d-alloc-${a.flat_number}`,
            label: `Flat ${a.flat_number}`,
            amount: Number(a.amount || 0),
          });
        }
        pushHeadSummaryModal({
          title: 'Entry detail',
          subtitle: e.title || ledgerEntryKindLabel(e),
          total: Number(e.total_amount || 0),
          drillable: false,
          rows: detailRows,
        });
      }
    },
    [pushHeadSummaryModal, chargeById, ledgerEntryKindLabel],
  );

  const receiptLineItems = useMemo(() => {
    if (filterStatus === 'unpaid') return [] as { kind: 'mp' | 'ledger'; t: string; p?: any; e?: FinanceLedgerRow }[];
    const items: { kind: 'mp' | 'ledger'; t: string; p?: any; e?: FinanceLedgerRow }[] = [
      ...filteredPayments.map((p) => ({ kind: 'mp' as const, t: p.created_at, p })),
      ...scopedLedgerOnly.map((e) => ({ kind: 'ledger' as const, t: e.created_at, e })),
    ];
    items.sort((a, b) => (a.t < b.t ? 1 : -1));
    return items;
  }, [filterStatus, filteredPayments, scopedLedgerOnly]);

  const selectAllVisibleReceipts = () => {
    const keys = receiptLineItems
      .map((item) =>
        item.kind === 'mp' && item.p
          ? `mp-${item.p.id}`
          : item.kind === 'ledger' && item.e
            ? `ledger-${item.e.id}`
            : '',
      )
      .filter(Boolean);
    setSelectedReceiptKeys(new Set(keys));
  };

  const selectedReceiptTypeLabel =
    paymentTypeOptions.find((o) => o.value === paymentTypeFilter)?.label ?? '--All--';
  const selectedReceiptMonthLabel =
    monthOptionsForReceipts.find((o) => o.value === paymentMonthFilter)?.label ?? 'All months';

  const openReceiptHeadSummary = useCallback(
    (head: string, total: number) => {
      pushHeadSummaryModal({
        title: head,
        subtitle: `${selectedReceiptTypeLabel} · ${selectedReceiptMonthLabel}`,
        total,
        rows: buildReceiptHeadEntryRows(head),
        drillable: true,
      });
    },
    [
      pushHeadSummaryModal,
      buildReceiptHeadEntryRows,
      selectedReceiptTypeLabel,
      selectedReceiptMonthLabel,
    ],
  );

  const openPaymentHeadSummary = useCallback(
    (head: string, total: number) => {
      pushHeadSummaryModal({
        title: head,
        subtitle: `Society payment · ${selectedReceiptTypeLabel} · ${selectedReceiptMonthLabel}`,
        total,
        rows: buildPaymentHeadEntryRows(head),
        drillable: true,
      });
    },
    [
      pushHeadSummaryModal,
      buildPaymentHeadEntryRows,
      selectedReceiptTypeLabel,
      selectedReceiptMonthLabel,
    ],
  );

  const currentHeadSummaryModal = headSummaryModalStack[headSummaryModalStack.length - 1];

  const totalsBreakdown = useMemo(() => {
    const map = new Map<string, { total: number; flatUnits: number; entries: number; byChannel: ChannelTotals }>();
    for (const e of ledgerEntries) {
      const m = ledgerMonthValue(e);
      if (m !== totalsMonth) continue;
      if (e.destination === 'separate_entry') continue;
      const k = `${e.record_mode}||${e.destination}`;
      const cur = map.get(k) ?? { total: 0, flatUnits: 0, entries: 0, byChannel: { cash: 0, bank: 0, other: 0 } };
      const amt = Number(e.total_amount || 0);
      cur.total += amt;
      cur.flatUnits += Number(e.aggregate_flat_count || 0);
      cur.entries += 1;
      addToChannel(cur.byChannel, e.payment_method, amt);
      map.set(k, cur);
    }
    return [...map.entries()]
      .map(([k, v]) => {
        const [mode, destination] = k.split('||');
        return { mode, destination, ...v };
      })
      .sort((a, b) => `${a.mode}${a.destination}`.localeCompare(`${b.mode}${b.destination}`));
  }, [ledgerEntries, totalsMonth]);

  const totalsMonthReceiptChannels = useMemo(
    () =>
      totalsBreakdown.reduce(
        (acc, r) => {
          acc.cash += r.byChannel.cash;
          acc.bank += r.byChannel.bank;
          acc.other += r.byChannel.other;
          return acc;
        },
        { cash: 0, bank: 0, other: 0 } as ChannelTotals,
      ),
    [totalsBreakdown],
  );

  const totalsMonthNet = useMemo(
    () => totalsBreakdown.reduce((s, r) => s + r.total, 0),
    [totalsBreakdown],
  );

  const totalsOutflowBreakdown = useMemo(() => {
    const map = new Map<string, { total: number; flatUnits: number; entries: number; byChannel: ChannelTotals }>();
    for (const e of societyLedgerEntries) {
      const m = ledgerMonthValue(e);
      if (m !== totalsMonth) continue;
      if (e.destination !== 'separate_entry') continue;
      const head = financeExpenseHeadFromLedgerEntry(e.title, e.expense_id ? expenseCategoryById.get(e.expense_id) : null);
      const cur = map.get(head) ?? { total: 0, flatUnits: 0, entries: 0, byChannel: { cash: 0, bank: 0, other: 0 } };
      const amt = Number(e.total_amount || 0);
      cur.total += amt;
      cur.flatUnits += Number(e.aggregate_flat_count || 0);
      cur.entries += 1;
      addToChannel(cur.byChannel, e.payment_method, amt);
      map.set(head, cur);
    }
    return [...map.entries()]
      .map(([head, v]) => ({ head, ...v }))
      .sort((a, b) => a.head.localeCompare(b.head));
  }, [societyLedgerEntries, totalsMonth, expenseCategoryById]);

  const totalsMonthPaymentChannels = useMemo(
    () =>
      totalsOutflowBreakdown.reduce(
        (acc, r) => {
          acc.cash += r.byChannel.cash;
          acc.bank += r.byChannel.bank;
          acc.other += r.byChannel.other;
          return acc;
        },
        { cash: 0, bank: 0, other: 0 } as ChannelTotals,
      ),
    [totalsOutflowBreakdown],
  );

  const totalsMonthOutflow = useMemo(
    () => totalsOutflowBreakdown.reduce((s, r) => s + r.total, 0),
    [totalsOutflowBreakdown],
  );

  const eventRefChannelTotals = useMemo(
    () => ({
      receiptChannels: sumByChannel(eventContribRef, (c) => Number(c.amount || 0), (c) => c.payment_method),
      paymentChannels: sumByChannel(eventFoodRef, (ex) => Number(ex.total_amount || 0), (ex) => ex.payment_method),
    }),
    [eventContribRef, eventFoodRef],
  );

  type FlatReportRow = {
    flat_number: string;
    resident_name: string;
    maintenance_paid: number;
    maintenance_count: number;
    expense_share: number;
    expense_count: number;
    settled_amount: number;
    unsettled_amount: number;
    net_position: number;
    details: {
      type: 'maintenance' | 'expense';
      title: string;
      amount: number;
      date: string;
      method: string;
      status: string;
      group_name?: string;
    }[];
  };

  const flatReportData = useMemo((): FlatReportRow[] => {
    if (subTab !== 'flat_report') return [];
    const fromMs = new Date(`${flatReportFrom}T00:00:00`).getTime();
    const toMs = new Date(`${flatReportTo}T23:59:59.999`).getTime();
    const isInRange = (iso: string) => {
      const t = new Date(iso).getTime();
      return !Number.isNaN(t) && t >= fromMs && t <= toMs;
    };

    const flatMap = new Map<string, FlatReportRow>();
    const getRow = (flatNum: string): FlatReportRow => {
      if (!flatMap.has(flatNum)) {
        const flat = flats.find((f) => f.flat_number === flatNum);
        const resName = flat?.id
          ? (primaryByFlatId.get(flat.id) || flat.owner_name || flatNum)
          : flatNum;
        flatMap.set(flatNum, {
          flat_number: flatNum,
          resident_name: resName ?? flatNum,
          maintenance_paid: 0,
          maintenance_count: 0,
          expense_share: 0,
          expense_count: 0,
          settled_amount: 0,
          unsettled_amount: 0,
          net_position: 0,
          details: [],
        });
      }
      return flatMap.get(flatNum)!;
    };

    // Maintenance payments in range
    const countedFinanceEntryIds = new Set<string>();
    for (const p of payments) {
      if (String(p.payment_status) !== 'verified') continue;
      const d = paymentBillingDate(p);
      if (!d || !isInRange(d)) continue;
      const flatNum = String(p.flat_number || '');
      if (!flatNum) continue;
      const amt = Number(p.amount || 0);
      const row = getRow(flatNum);
      row.maintenance_paid += amt;
      row.maintenance_count += 1;
      const chargeTitle = charges.find((c) => c.id === p.charge_id)?.title ?? 'Maintenance';
      row.details.push({
        type: 'maintenance',
        title: chargeTitle,
        amount: amt,
        date: d.slice(0, 10),
        method: String(p.payment_method || 'cash'),
        status: 'paid',
      });
      const feId = (p as any).finance_entry_id;
      if (typeof feId === 'string' && feId.length > 0) countedFinanceEntryIds.add(feId);
    }

    // Ledger allocations (outsider/corpus entries allocated to flats) in range
    for (const e of ledgerEntries) {
      if (e.destination === 'separate_entry') continue;
      const ledgerDate = ledgerTransactionDate(e);
      if (!ledgerDate || !isInRange(ledgerDate)) continue;
      // Skip flats_only entries that are already counted via their linked maintenance_payments
      if (e.record_mode === 'flats_only' && countedFinanceEntryIds.has(e.id)) continue;
      const allocations = e.finance_entry_allocations ?? [];
      for (const alloc of allocations) {
        const flatNum = alloc.flat_number;
        if (!flatNum || flatNum === 'SOCIETY') continue;
        const amt = Number(alloc.amount || 0);
        const row = getRow(flatNum);
        row.maintenance_paid += amt;
        row.maintenance_count += 1;
        row.details.push({
          type: 'maintenance',
          title: e.title || 'Ledger receipt',
          amount: amt,
          date: ledgerDate.slice(0, 10),
          method: e.payment_method || 'other',
          status: 'verified',
        });
      }
    }

    // Society payment splits (Record payment) in range
    for (const split of flatReportSplits) {
      const exp = flatReportExpenses.find((e) => e.id === split.expense_id);
      if (!exp) continue;
      const expDate = String(exp.expense_date || '');
      if (!isInRange(expDate)) continue;
      const flatNum = String(split.flat_number || '');
      if (!flatNum || flatNum === 'SOCIETY') continue;
      const amt = Number(split.amount || 0);
      const row = getRow(flatNum);
      row.expense_share += amt;
      row.expense_count += 1;
      if (split.is_settled) {
        row.settled_amount += amt;
      } else {
        row.unsettled_amount += amt;
      }
      row.details.push({
        type: 'expense',
        title: exp.title || 'Expense',
        amount: amt,
        date: expDate.slice(0, 10),
        method: exp.payment_method || 'cash',
        status: split.is_settled ? 'settled' : 'pending',
        group_name: exp.group_name,
      });
    }

    // Compute net position: maintenance paid minus expense share
    for (const row of flatMap.values()) {
      row.net_position = row.maintenance_paid - row.expense_share;
      row.details.sort((a, b) => b.date.localeCompare(a.date));
    }

    let rows = [...flatMap.values()].sort((a, b) => a.flat_number.localeCompare(b.flat_number, undefined, { numeric: true }));
    if (flatReportSelectedFlat !== 'all') {
      rows = rows.filter((r) => r.flat_number === flatReportSelectedFlat);
    }
    return rows;
  }, [subTab, flatReportFrom, flatReportTo, flatReportSelectedFlat, payments, ledgerEntries, flatReportExpenses, flatReportSplits, flats, primaryByFlatId, charges]);

  const flatMultiOptions = useMemo(
    () => flatOptionsWithPrimaryLabel(flats, primaryByFlatId),
    [flats, primaryByFlatId],
  );

  const chargeMajorHeadById = useMemo(() => {
    const map = new Map<string, string>();
    for (const c of charges) {
      map.set(c.id, majorHeadForCharge(c as { title: string; expense_group_id?: string | null }));
    }
    return map;
  }, [charges, majorHeadForCharge]);

  const financePeriodReport = useMemo(
    () =>
      computeFinancePeriodReport({
        periodFrom,
        periodTo,
        payments,
        ledgerEntries: societyLedgerEntries,
        expenseCategoryById,
        chargeMajorHeadById,
        openingBalanceAnchors,
      }),
    [periodFrom, periodTo, payments, societyLedgerEntries, expenseCategoryById, chargeMajorHeadById, openingBalanceAnchors],
  );

  const showManualOpeningBalanceSetup = isManualOpeningBalanceSetupPeriod(periodFrom);

  const parseOptionalAmount = parseOptionalAnchorAmount;

  const saveOpeningBalanceAnchor = async () => {
    if (!societyId) return;
    setSavingOpeningAnchor(true);
    try {
      await saveAnchor({
        id: anchorForm.id || undefined,
        as_on_date: anchorForm.as_on_date,
        cash_amount: parseOptionalAmount(anchorForm.cash_amount),
        bank_amount: parseOptionalAmount(anchorForm.bank_amount),
        other_amount: parseOptionalAmount(anchorForm.other_amount),
        notes: anchorForm.notes,
      });
      toast.success('Opening balance anchor saved');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save opening balance');
    } finally {
      setSavingOpeningAnchor(false);
    }
  };

  const editOpeningBalanceAnchor = (row: (typeof openingBalanceAnchors)[number]) => {
    setAnchorForm(openingAnchorRowToForm(row));
  };

  const resetOpeningBalanceAnchorForm = () => {
    setAnchorForm(createDefaultOpeningAnchorForm());
  };

  const applyCashZeroFeb2026Preset = () => {
    setAnchorForm((f) => ({
      ...createDefaultOpeningAnchorForm(),
      id: f.id,
      bank_amount: f.bank_amount,
      other_amount: f.other_amount,
      notes: f.notes,
    }));
  };

  const collectReportAudienceIds = (): string[] => {
    if (reportAudience === 'all') return residentUsers.map((r) => r.id);
    if (reportAudience === 'flats') {
      const set = new Set<string>();
      const nums = new Set(reportFlats.map((x) => String(x).trim()).filter(Boolean));
      for (const r of residentUsers) {
        if (nums.has(String(r.flat_number))) set.add(r.id);
      }
      return [...set];
    }
    return [...new Set(reportResidentIds.filter(Boolean))];
  };

  const periodReportExportInput = () =>
    toFinancePeriodReportExportInput(financePeriodReport, {
      societyName: societyName || 'Society',
      periodFrom,
      periodTo,
    });

  const exportPeriodReport = (format: ExportFormat) => {
    if (periodFrom > periodTo) {
      toast.error('Fix the date range first');
      return;
    }
    downloadFinancePeriodReport(format, periodReportExportInput(), `finance-report-${periodFrom}-to-${periodTo}`);
    toast.success(`${format.toUpperCase()} downloaded`);
  };

  const exportTransactionStatement = (format: ExportFormat) => {
    if (filterStatus === 'unpaid') {
      toast.error('Switch to a transaction status filter to export entries');
      return;
    }
    const rows = buildTransactionExportRows({
      items: receiptLineItems,
      chargeTitleById: new Map([...chargeById.entries()].map(([id, ch]) => [id, ch.title])),
    });
    if (rows.length === 0) {
      toast.error('No transactions match the current filters');
      return;
    }
    downloadTransactionStatement(format, {
      societyName: societyName || 'Society',
      title: 'Transaction statement',
      subtitle: `${receiptSummary.count} entries · ₹${receiptSummary.sum.toLocaleString('en-IN')} total · ${selectedReceiptTypeLabel} · ${selectedReceiptMonthLabel}`,
      filenameBase: `transactions-${selectedReceiptMonthLabel.replace(/\s+/g, '-')}-${Date.now()}`,
      rows,
    });
    toast.success(`${format.toUpperCase()} downloaded`);
  };

  const sendPeriodReportToMembers = async () => {
    if (!societyId || periodFrom > periodTo) {
      toast.error('Check society and date range');
      return;
    }
    const ids = collectReportAudienceIds();
    if (ids.length === 0) {
      toast.error('No residents match this audience');
      return;
    }
    setReportPushBusy(true);
    try {
      const blob = buildFinancePeriodReportPdfBlob(
        toFinancePeriodReportExportInput(financePeriodReport, {
          societyName: societyName || 'Society',
          periodFrom,
          periodTo,
        }),
      );
      const batchId = crypto.randomUUID();
      const path = `finance-reports/${societyId}/${batchId}.pdf`;
      const { error: upErr } = await supabase.storage.from('notification-media').upload(path, blob, {
        contentType: 'application/pdf',
        upsert: true,
      });
      if (upErr) {
        toast.error(upErr.message);
        return;
      }
      const { data: pub } = supabase.storage.from('notification-media').getPublicUrl(path);
      const pdfUrl = pub.publicUrl;
      const title = `Finance report (${fmtIsoDateToDisplay(periodFrom)} → ${fmtIsoDateToDisplay(periodTo)})`;
      const message = `Society finance period report is attached as PDF.\n\nTotal receipts: ₹${financePeriodReport.totalReceipts.toLocaleString('en-IN')}\nTotal expenses: ₹${financePeriodReport.totalExpenses.toLocaleString('en-IN')}\nBalance: ₹${financePeriodReport.totalBalance.toLocaleString('en-IN')}\n\nOpen PDF: ${pdfUrl}\n\nOpen the Alerts tab and tap this message — we record when you have seen it.`;
      const chunk = 40;
      for (let i = 0; i < ids.length; i += chunk) {
        const slice = ids.slice(i, i + chunk);
        const rows = slice.map((rid) => ({
          title,
          message,
          type: 'finance_period_report',
          target_type: 'user',
          target_id: rid,
          society_id: societyId,
          created_by: adminName,
          sound_key: 'digital',
          sound_custom_url: null as string | null,
          delivery_batch_id: batchId,
          is_read: false,
        }));
        const { error: insErr } = await supabase.from('notifications').insert(rows);
        if (insErr) {
          toast.error(insErr.message);
          return;
        }
      }
      try {
        await supabase.functions.invoke('send-push-notification', {
          body: {
            title,
            message: `Finance report ${fmtIsoDateToDisplay(periodFrom)}–${fmtIsoDateToDisplay(periodTo)}. Open Alerts in the app.`,
            target_type: 'user',
            target_ids: ids,
            society_id: societyId,
            sound_key: 'digital',
            sound_custom_url: '',
          },
        });
      } catch (e) {
        console.warn('Push invoke failed', e);
      }
      setLastDeliveryBatchId(batchId);
      toast.success(`Sent to ${ids.length} resident(s). Open “Read receipts” to see who opened it.`);
    } finally {
      setReportPushBusy(false);
    }
  };

  const loadReadStatusForBatch = async (batchId: string) => {
    setReadStatusBatchId(batchId);
    const { data, error } = await supabase
      .from('notifications')
      .select('id, target_id, is_read, read_at')
      .eq('delivery_batch_id', batchId)
      .order('target_id');
    if (error) {
      toast.error(error.message);
      return;
    }
    setReadStatusRows((data ?? []) as { id: string; target_id: string | null; is_read: boolean; read_at: string | null }[]);
    setReadStatusOpen(true);
  };

  const recallPeriodReportSend = async (batchId: string) => {
    if (!societyId) return;
    const ok = await confirmAction(
      'Recall this report?',
      'This removes the finance report alerts from every recipient\'s inbox. Residents who already opened the PDF may still have a copy. You can send a corrected report afterward.',
      'Recall send',
      'Cancel',
    );
    if (!ok) return;
    setReportPushBusy(true);
    try {
      const { data: batchRows, error: fetchErr } = await supabase
        .from('notifications')
        .select('target_id')
        .eq('delivery_batch_id', batchId)
        .eq('society_id', societyId)
        .eq('type', 'finance_period_report');
      if (fetchErr) {
        toast.error(fetchErr.message);
        return;
      }
      const targetIds = [...new Set((batchRows ?? []).map((r) => r.target_id).filter(Boolean))] as string[];

      const { error: delErr } = await supabase
        .from('notifications')
        .delete()
        .eq('delivery_batch_id', batchId)
        .eq('society_id', societyId)
        .eq('type', 'finance_period_report');
      if (delErr) {
        toast.error(delErr.message);
        return;
      }

      const path = `finance-reports/${societyId}/${batchId}.pdf`;
      await supabase.storage.from('notification-media').remove([path]);

      if (targetIds.length > 0) {
        const title = 'Finance report withdrawn';
        const message =
          'The finance period report sent earlier was sent in error and has been removed. Please ignore the previous PDF link. A corrected report may follow.';
        const chunk = 40;
        for (let i = 0; i < targetIds.length; i += chunk) {
          const slice = targetIds.slice(i, i + chunk);
          const rows = slice.map((rid) => ({
            title,
            message,
            type: 'general',
            target_type: 'user',
            target_id: rid,
            society_id: societyId,
            created_by: adminName,
            sound_key: 'digital',
            sound_custom_url: null as string | null,
            is_read: false,
          }));
          const { error: insErr } = await supabase.from('notifications').insert(rows);
          if (insErr) {
            toast.error(insErr.message);
            return;
          }
        }
        try {
          await supabase.functions.invoke('send-push-notification', {
            body: {
              title,
              message: 'The finance report sent earlier was withdrawn. Please ignore it.',
              target_type: 'user',
              target_ids: targetIds,
              society_id: societyId,
              sound_key: 'digital',
              sound_custom_url: '',
            },
          });
        } catch (e) {
          console.warn('Push invoke failed', e);
        }
      }

      if (lastDeliveryBatchId === batchId) setLastDeliveryBatchId(null);
      if (readStatusBatchId === batchId) {
        setReadStatusOpen(false);
        setReadStatusRows([]);
        setReadStatusBatchId(null);
      }
      toast.success(targetIds.length > 0 ? `Recalled send for ${targetIds.length} resident(s)` : 'Report send recalled');
    } finally {
      setReportPushBusy(false);
    }
  };

  const sendReminders = async () => {
    for (const flat of unpaidFlats) {
      await supabase.from('notifications').insert([
        {
          society_id: societyId,
          title: 'Maintenance Due Reminder',
          message: `Dear resident of Flat ${flat.flat_number}, your maintenance payment is due. Please pay at the earliest.`,
          type: 'payment_reminder',
          target_type: 'flat',
          target_id: flat.flat_number,
          created_by: adminName,
        },
      ]);
    }
    toast.success(`Reminders sent to ${unpaidFlats.length} flats`);
  };

  const saveAutoReminderSettings = async () => {
    if (!societyId) return;
    setSavingAutoReminder(true);
    const { error } = await (supabase as any).from('finance_reminder_settings').upsert(
      {
        society_id: societyId,
        enabled: autoReminderEnabled,
        schedule: autoReminderSchedule,
        timezone: 'Asia/Kolkata',
      },
      { onConflict: 'society_id' },
    );
    setSavingAutoReminder(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Auto reminder settings saved');
  };

  const testAutoReminderNow = async () => {
    if (!societyId) return;
    setTestingAutoReminder(true);
    const { data, error } = await supabase.functions.invoke('maintenance-reminder', {
      body: {
        society_id: societyId,
        force_slot: '12pm',
      },
    });
    setTestingAutoReminder(false);
    if (error) {
      let detail = String((error as any)?.message || 'Unknown function error');
      const ctx = (error as any)?.context;
      if (ctx) {
        if (typeof ctx.json === 'function') {
          try {
            const body = await ctx.json();
            if (body?.error) detail = String(body.error);
          } catch {
            // no-op
          }
        }
        if ((detail.includes('non-2xx') || detail.includes('FunctionsHttpError')) && typeof ctx.text === 'function') {
          try {
            const text = await ctx.text();
            if (text?.trim()) {
              try {
                const parsed = JSON.parse(text);
                if (parsed?.error) detail = String(parsed.error);
                else detail = text.trim();
              } catch {
                detail = text.trim();
              }
            }
          } catch {
            // no-op
          }
        }
      }
      const generic = detail.includes('non-2xx') || detail.includes('FunctionsHttpError') || detail === 'Unknown function error';
      const hint =
        detail.includes('finance_reminder_settings') || detail.includes('finance_reminder_dispatch_log')
          ? 'DB migration missing. Run `npx supabase db push` and redeploy `maintenance-reminder`.'
          : generic
            ? 'Reminder test failed. Run DB push + deploy `maintenance-reminder` + deploy `send-push-notification`, then retry.'
            : detail;
      toast.error(hint);
      setLastReminderTestStatus(`Last test failed at ${fmtTime(new Date())}: ${hint}`);
      return;
    }
    const sent = Number((data as any)?.sent ?? 0);
    toast.success(sent > 0 ? `Test reminder sent to ${sent} flat(s)` : 'No pending dues found for test run');
    setLastReminderTestStatus(`Last test at ${fmtTime(new Date())}: sent to ${sent} flat(s)`);
  };

  const openFlatDateModal = (flatNumber: string, fallbackDate: string) => {
    setFlatDateModal({
      open: true,
      flatNumber,
      date: flatDueDates[flatNumber] || fallbackDate,
    });
  };

  const saveFlatDateFromModal = () => {
    if (!flatDateModal.flatNumber || !flatDateModal.date) return;
    setFlatDueDates((prev) => ({ ...prev, [flatDateModal.flatNumber]: flatDateModal.date }));
    setFlatDateModal({ open: false, flatNumber: '', date: payForm.due_date });
  };

  if (!societyId) {
    return (
      <div className="page-container pb-24">
        <p className="text-sm text-muted-foreground text-center py-12">Select a society to manage finance.</p>
      </div>
    );
  }

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-green-500/10 flex items-center justify-center">
          <IndianRupee className="w-5 h-5 text-green-600" />
        </div>
        <div>
          <h1 className="page-title">Finance Management</h1>
          <DescriptiveStatSummary
            className="!px-0 !py-0 !mb-0 !border-0 !bg-transparent"
            label={
              <span className="text-xs">
                {charges.length} receipt types · {payments.length} receipts · {ledgerEntries.length} ledger entries
              </span>
            }
            description="Quick counts for this society’s finance module scope."
            howCalculated="Receipt types = maintenance_charges rows. Receipts = maintenance_payments. Ledger entries = finance_entries (pool, direct, event mirror)."
          />
        </div>
      </div>

      <RecordingDateBanner className="mb-4" />

      <div className="card-section p-3 mb-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <p className="text-xs font-medium text-foreground">Reminder base</p>
            <p className="text-[10px] text-muted-foreground">
              {includeVacantFlats
                ? `Using all flats (${flats.length})`
                : `Using occupied/sold flats (${targetFlats.length})`}
            </p>
          </div>
          <button
            type="button"
            onClick={() => setIncludeVacantFlats((v) => !v)}
            className="text-xs px-2.5 py-1.5 rounded-lg border border-border"
          >
            {includeVacantFlats ? 'Include vacant: ON' : 'Include vacant: OFF'}
          </button>
        </div>
      </div>

      <div className="flex gap-1 mb-4 overflow-x-auto">
        {(
          [
            { id: 'maintenance' as const, label: 'Create Receipts' },
            { id: 'payments' as const, label: 'Record receipt' },
            { id: 'record_payment' as const, label: 'Record payment' },
            { id: 'receipts' as const, label: 'Transactions' },
            { id: 'period' as const, label: 'Period report' },
            { id: 'totals' as const, label: 'Totals' },
            { id: 'flat_report' as const, label: 'Flat Report' },
            { id: 'reminders' as const, label: 'Reminders' },
          ] as const
        ).map(({ id: s, label }) => (
          <button
            key={s}
            onClick={() => setSubTab(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap ${subTab === s ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
          >
            {label}
          </button>
        ))}
      </div>

      {subTab === 'maintenance' && (
        <div>
          <div className="card-section p-3 mb-3 space-y-2">
            <p className="text-xs font-medium text-foreground">Automatic due reminders</p>
            <label className="flex items-center gap-2 text-xs">
              <input
                type="checkbox"
                checked={autoReminderEnabled}
                onChange={(e) => setAutoReminderEnabled(e.target.checked)}
              />
              Enable daily due reminders after monthly due date
            </label>
            <select
              className="input-field"
              value={autoReminderSchedule}
              onChange={(e) => setAutoReminderSchedule(e.target.value as 'once_12pm' | 'twice_12pm_7pm')}
              disabled={!autoReminderEnabled}
            >
              <option value="once_12pm">Once daily at 12:00 PM</option>
              <option value="twice_12pm_7pm">Twice daily at 12:00 PM and 7:00 PM</option>
            </select>
            <button
              type="button"
              className="btn-secondary w-full"
              onClick={() => void saveAutoReminderSettings()}
              disabled={savingAutoReminder}
            >
              {savingAutoReminder ? 'Saving…' : 'Save reminder settings'}
            </button>
            <button
              type="button"
              className="btn-secondary w-full"
              onClick={() => void testAutoReminderNow()}
              disabled={testingAutoReminder}
            >
              {testingAutoReminder ? 'Testing…' : 'Test reminder now'}
            </button>
            {lastReminderTestStatus ? (
              <p className="text-[10px] text-muted-foreground">{lastReminderTestStatus}</p>
            ) : null}
            <p className="text-[10px] text-muted-foreground leading-snug">
              Auto-reminders are sent only to flats that have not paid the current month maintenance after the due day.
            </p>
          </div>

          <button
            type="button"
            onClick={() => {
              if (showForm && !editingChargeId) {
                setShowForm(false);
                return;
              }
              setEditingChargeId(null);
              setForm({
      title: '',
      amount: '',
      frequency: 'monthly',
      due_day: '1',
      major_head: '',
      expense_group_id: '',
      new_sub_head: '',
    });
              setShowForm(true);
            }}
            className="btn-primary w-full mb-4 flex items-center justify-center gap-2"
          >
            <Plus className="w-4 h-4" /> {showForm && !editingChargeId ? 'Close form' : 'Add receipt type'}
          </button>
          {showForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <p className="text-xs font-medium text-muted-foreground">{editingChargeId ? 'Edit receipt type' : 'New receipt type'}</p>
              <input className="input-field" placeholder="Title (e.g. Monthly Maintenance)" value={form.title} onChange={capsFieldChange(setForm, 'title')} />
              <input className="input-field" placeholder="Amount (₹)" type="number" value={form.amount} onChange={e => setForm({...form, amount: e.target.value})} />
              <select className="input-field" value={form.frequency} onChange={e => setForm({...form, frequency: e.target.value})}>
                <option value="monthly">Monthly</option>
                <option value="quarterly">Quarterly</option>
                <option value="yearly">Yearly</option>
                <option value="one-time">One-time</option>
              </select>
              <input className="input-field" placeholder="Due Day (1-28)" type="number" min="1" max="28" value={form.due_day} onChange={e => setForm({...form, due_day: e.target.value})} />
              <select
                className="input-field"
                value={form.major_head}
                onChange={(e) =>
                  setForm({
                    ...form,
                    major_head: e.target.value as SocietyPaymentMajorHead | '',
                    expense_group_id: '',
                    new_sub_head: '',
                  })
                }
              >
                <option value="">Major head (category)</option>
                {SOCIETY_PAYMENT_MAJOR_HEADS.map((h) => (
                  <option key={h} value={h}>
                    {h}
                  </option>
                ))}
              </select>
              {form.major_head && (
                <>
                  <select
                    className="input-field"
                    value={form.expense_group_id}
                    onChange={(e) => setForm({ ...form, expense_group_id: e.target.value, new_sub_head: '' })}
                  >
                    <option value="">Payment sub-head (optional link)</option>
                    {subHeadsForFormMajor.map((g) => (
                      <option key={g.id} value={g.id}>
                        {g.name}
                      </option>
                    ))}
                    <option value="__new__">+ Create new sub-head under {form.major_head}</option>
                  </select>
                  {form.expense_group_id === '__new__' && (
                    <input
                      className="input-field"
                      placeholder="New sub-head name (defaults to receipt title)"
                      value={form.new_sub_head}
                      onChange={(e) => setForm({ ...form, new_sub_head: e.target.value })}
                    />
                  )}
                </>
              )}
              <p className="text-[10px] text-muted-foreground leading-snug">
                Each receipt type is grouped under one major head for head-fund reconciliation and payment recording.
              </p>
              <div className="flex gap-2">
                <button type="button" onClick={addCharge} className="btn-primary flex-1">
                  {editingChargeId ? 'Update receipt type' : 'Save receipt type'}
                </button>
                {editingChargeId && (
                  <button
                    type="button"
                    className="btn-secondary flex-1"
                    onClick={() => {
                      setEditingChargeId(null);
                      setForm({
      title: '',
      amount: '',
      frequency: 'monthly',
      due_day: '1',
      major_head: '',
      expense_group_id: '',
      new_sub_head: '',
    });
                    }}
                  >
                    Cancel edit
                  </button>
                )}
              </div>
            </div>
          )}
          {[...SOCIETY_PAYMENT_MAJOR_HEADS, 'Uncategorized' as const].map((major) => {
            const list = chargesByMajorHead.get(major) ?? [];
            if (list.length === 0) return null;
            return (
              <div key={major} className="mb-4">
                <h3 className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground mb-2 border-b border-border/60 pb-1">
                  {major}
                </h3>
                {list.map((c) => (
            <div key={c.id} className="card-section p-3 mb-2">
              <div className="flex justify-between items-start gap-2">
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{c.title}</p>
                  <p className="text-xs text-muted-foreground">{c.frequency} · Due on {c.due_day}th</p>
                  {(c as { expense_group_id?: string | null }).expense_group_id && (
                    <p className="text-[10px] text-muted-foreground mt-0.5">
                      Sub-head:{' '}
                      {paymentGroupById.get(String((c as { expense_group_id?: string | null }).expense_group_id))?.name ??
                        'Linked'}
                    </p>
                  )}
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <p className="text-lg font-bold text-green-600">₹{c.amount}</p>
                  <button type="button" className="p-1.5 text-muted-foreground hover:text-primary" title="Edit" onClick={() => startEditCharge(c as Parameters<typeof startEditCharge>[0])}>
                    <Pencil className="w-4 h-4" />
                  </button>
                  {!chargeIdsWithDependents.has(c.id) ? (
                    <button
                      type="button"
                      className="p-1.5 text-muted-foreground hover:text-destructive"
                      title="Delete receipt type"
                      onClick={() => void deleteCharge(c.id)}
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  ) : (
                    <span className="text-[9px] text-muted-foreground max-w-[72px] text-right leading-tight" title="Remove linked receipt or ledger rows first">
                      In use
                    </span>
                  )}
                </div>
              </div>
            </div>
                ))}
              </div>
            );
          })}
        </div>
      )}

      {subTab === 'payments' && (
        <div>
          <button onClick={() => setShowPaymentForm(!showPaymentForm)} className="btn-primary w-full mb-3 flex items-center justify-center gap-2">
            <Upload className="w-4 h-4" /> Record Reciept / Upload Reciept
          </button>
          {showPaymentForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <div>
                <p className="text-[10px] font-medium text-muted-foreground uppercase mb-1">Recording style</p>
                <select
                  className="input-field"
                  value={payForm.recordMode}
                  onChange={(e) =>
                    setPayForm({
                      ...payForm,
                      recordMode: e.target.value as typeof payForm.recordMode,
                    })
                  }
                >
                  <option value="society_pool">Society pool (default — distribute to flats later)</option>
                  <option value="flats_only">Direct to selected flats (per-flat amount)</option>
                  <option value="flats_plus_outsider">Selected flats + outsider share</option>
                  <option value="outsider_only">Outsider only (split across selected flats now)</option>
                </select>
                <p className="text-[10px] text-muted-foreground mt-1 leading-snug">
                  {payForm.recordMode === 'society_pool'
                    ? 'Receipt stays in the society pool. Open it under Transactions and use “Distribute equally to all flats” when ready.'
                    : 'Amount is allocated to the flats you select below at record time.'}
                </p>
              </div>
              <div>
                <label className="text-[10px] font-medium text-muted-foreground uppercase">Billing / transaction date</label>
                <DateInput
                  className="input-field"
                  value={payForm.due_date}
                  onChange={e => {
                    const nextDate = e.target.value;
                    setPayForm({ ...payForm, due_date: nextDate });
                    if (useSameDateForSelectedFlats) {
                      setFlatDueDates((prev) => {
                        const next = { ...prev };
                        for (const flat of payForm.selected_flats) next[flat] = nextDate;
                        return next;
                      });
                    }
                  }}
                />
                <p className="text-[10px] text-muted-foreground mt-1">
                  Entry month for reports: {fmtIsoMonthToDisplay(billingMonthFromDate(payForm.due_date))} (billing date must
                  fall in this month)
                </p>
              </div>
              {(payForm.recordMode === 'society_pool' || payForm.recordMode !== 'flats_only') && (
                <div>
                  <p className="text-[10px] font-medium text-muted-foreground uppercase mb-1">
                    {payForm.recordMode === 'society_pool' ? 'Ledger destination' : 'Destination (outsider / ledger)'}
                  </p>
                  <select
                    className="input-field"
                    value={payForm.destination}
                    onChange={(e) =>
                      setPayForm({
                        ...payForm,
                        destination: e.target.value as typeof payForm.destination,
                      })
                    }
                  >
                    <option value="current_month_maintenance">Current month maintenance / collections</option>
                    <option value="corpus">Corpus / sinking fund</option>
                    {payForm.recordMode !== 'society_pool' && (
                      <option value="separate_entry">Separate ledger entry (expense-style, no flat posting)</option>
                    )}
                  </select>
                </div>
              )}
              {payForm.recordMode === 'society_pool' && (
                <div className="rounded-lg border border-primary/30 bg-primary/5 p-3 space-y-2">
                  <p className="text-xs font-medium text-foreground">Society pool receipt</p>
                  <input
                    className="input-field"
                    type="number"
                    placeholder="Total amount received (₹)"
                    value={payForm.amount}
                    onChange={(e) => setPayForm({ ...payForm, amount: e.target.value })}
                  />
                  <input
                    className="input-field"
                    placeholder="Payer name (flat owner, outsider, vendor — optional)"
                    value={payForm.outsiderName}
                    onChange={(e) => setPayForm({ ...payForm, outsiderName: e.target.value })}
                  />
                  <input
                    className="input-field"
                    placeholder="Reference / relation (optional)"
                    value={payForm.outsiderRelation}
                    onChange={(e) => setPayForm({ ...payForm, outsiderRelation: e.target.value })}
                  />
                  <input
                    className="input-field"
                    placeholder="Title override (optional)"
                    value={payForm.entryTitle}
                    onChange={(e) => setPayForm({ ...payForm, entryTitle: e.target.value })}
                  />
                </div>
              )}
              {payForm.recordMode !== 'society_pool' && (
              <label className="flex items-center gap-2 text-xs text-muted-foreground">
                <input
                  type="checkbox"
                  checked={payForm.allocationIncludeVacant}
                  onChange={(e) => setPayForm({ ...payForm, allocationIncludeVacant: e.target.checked })}
                />
                Include vacant flats in this picker (allocation scope)
              </label>
              )}
              {(payForm.recordMode === 'outsider_only' || payForm.recordMode === 'flats_plus_outsider') && (
                <div className="rounded-lg border border-border p-3 space-y-2 bg-muted/20">
                  <p className="text-xs font-medium text-foreground">Outsider / payer</p>
                  <input
                    className="input-field"
                    placeholder="Name (vendor, guest sponsor, etc.)"
                    value={payForm.outsiderName}
                    onChange={(e) => setPayForm({ ...payForm, outsiderName: e.target.value })}
                  />
                  <input
                    className="input-field"
                    placeholder="Relation or reference (optional)"
                    value={payForm.outsiderRelation}
                    onChange={(e) => setPayForm({ ...payForm, outsiderRelation: e.target.value })}
                  />
                  <input
                    className="input-field"
                    placeholder="Entry title override (optional)"
                    value={payForm.entryTitle}
                    onChange={(e) => setPayForm({ ...payForm, entryTitle: e.target.value })}
                  />
                  <p className="text-[10px] font-medium text-muted-foreground uppercase">Outsider amount split</p>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name="alloc-style"
                      checked={payForm.allocationStyle === 'same_per_flat'}
                      onChange={() => setPayForm({ ...payForm, allocationStyle: 'same_per_flat' })}
                    />
                    Same amount per selected flat
                  </label>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name="alloc-style"
                      checked={payForm.allocationStyle === 'split_total_equally'}
                      onChange={() => setPayForm({ ...payForm, allocationStyle: 'split_total_equally' })}
                    />
                    One total split equally across selected flats
                  </label>
                  <input
                    className="input-field"
                    type="number"
                    placeholder={
                      payForm.allocationStyle === 'same_per_flat'
                        ? '₹ per flat (outsider portion)'
                        : '₹ total (outsider pool)'
                    }
                    value={payForm.outsiderAmount}
                    onChange={(e) => setPayForm({ ...payForm, outsiderAmount: e.target.value })}
                  />
                </div>
              )}
              {autoSelectedChargeHint && (
                <p className="text-[11px] text-muted-foreground">{autoSelectedChargeHint}</p>
              )}
              {(payForm.recordMode === 'society_pool' ||
                payForm.recordMode === 'flats_only' ||
                payForm.recordMode === 'flats_plus_outsider' ||
                (payForm.recordMode === 'outsider_only' && payForm.destination === 'current_month_maintenance')) && (
                <select
                  className="input-field"
                  value={payForm.charge_id}
                  onChange={(e) => {
                    const ch = charges.find((c) => c.id === e.target.value);
                    setAutoSelectedChargeHint('');
                    setPayForm({
                      ...payForm,
                      charge_id: e.target.value,
                      amount: ch?.amount?.toString() || payForm.amount,
                    });
                  }}
                >
                  <option value="">Select Receipt Type</option>
                  {renderGroupedChargeOptions()}
                </select>
              )}
              {payForm.recordMode !== 'society_pool' && (
              <FlatMultiSelect
                flats={flatOptionsWithPrimaryLabel(paymentScopeFlats, primaryByFlatId)}
                selected={payForm.selected_flats}
                onChange={nums => {
                  const removed = payForm.selected_flats.filter((flat) => !nums.includes(flat));
                  if (removed.length > 0) {
                    setFlatDueDates((prev) => {
                      const copy = { ...prev };
                      for (const flat of removed) delete copy[flat];
                      return copy;
                    });
                  }
                  if (useSameDateForSelectedFlats) {
                    setFlatDueDates((prev) => {
                      const next = { ...prev };
                      for (const flat of nums) next[flat] = payForm.due_date;
                      return next;
                    });
                  }
                  setPayForm({ ...payForm, selected_flats: nums });
                }}
                onToggleFlat={(flatNumber, nextSelected) => {
                  if (!nextSelected) return;
                  if (useSameDateForSelectedFlats) {
                    setFlatDueDates((prev) => ({ ...prev, [flatNumber]: payForm.due_date }));
                    return;
                  }
                  openFlatDateModal(flatNumber, payForm.due_date);
                }}
                selectedBadgeByFlat={selectedFlatDateBadges}
                label="Flats (multi-select)"
              />
              )}
              {payForm.recordMode === 'society_pool' && (
                <label className="flex items-center gap-2 text-xs text-muted-foreground">
                  <input
                    type="checkbox"
                    checked={payForm.allocationIncludeVacant}
                    onChange={(e) => setPayForm({ ...payForm, allocationIncludeVacant: e.target.checked })}
                  />
                  When distributing later, include vacant flats in the equal split
                </label>
              )}
              {payForm.recordMode !== 'society_pool' && (
              <label className="flex items-center gap-2 text-xs text-muted-foreground">
                <input
                  type="checkbox"
                  checked={useSameDateForSelectedFlats}
                  onChange={(e) => {
                    const checked = e.target.checked;
                    setUseSameDateForSelectedFlats(checked);
                    if (checked) {
                      setFlatDueDates((prev) => {
                        const next = { ...prev };
                        for (const flat of payForm.selected_flats) next[flat] = payForm.due_date;
                        return next;
                      });
                    }
                  }}
                />
                Use same due date for selected flats
              </label>
              )}
              {(payForm.recordMode === 'flats_only' || payForm.recordMode === 'flats_plus_outsider') && (
                <input
                  className="input-field"
                  placeholder="Maintenance amount (₹ per flat)"
                  type="number"
                  value={payForm.amount}
                  onChange={(e) => setPayForm({ ...payForm, amount: e.target.value })}
                />
              )}
              <select className="input-field" value={payForm.payment_method} onChange={e => setPayForm({...payForm, payment_method: e.target.value})}>
                <option value="cash">Cash</option>
                <option value="upi">UPI</option>
                <option value="razorpay">Razorpay (Online)</option>
                <option value="bank_transfer">Bank transfer</option>
              </select>
              <input className="input-field" placeholder="Transaction / reference ID (optional)" value={payForm.transaction_id} onChange={e => setPayForm({...payForm, transaction_id: e.target.value})} />
              <input className="input-field" placeholder="Screenshot URL (paste link, optional)" value={payForm.screenshot_url} onChange={e => setPayForm({...payForm, screenshot_url: e.target.value})} />
              <label className="text-[10px] font-medium text-muted-foreground uppercase">Or upload receipt / bill</label>
              <input id="finance-payment-receipt" type="file" accept="image/*,application/pdf" className="text-xs" />
              {payForm.recordMode !== 'society_pool' && !useSameDateForSelectedFlats && payForm.selected_flats.length > 0 && (
                <div className="rounded-lg border border-border p-2 space-y-1.5">
                  <p className="text-[10px] uppercase font-medium text-muted-foreground">Per-flat due dates</p>
                  {payForm.selected_flats.map((flatNum) => (
                    <button
                      key={flatNum}
                      type="button"
                      className="w-full flex items-center justify-between text-xs px-2 py-1.5 rounded border border-border"
                      onClick={() => openFlatDateModal(flatNum, payForm.due_date)}
                    >
                      <span>Flat {flatNum}</span>
                      <span className="font-medium">{flatDueDates[flatNum] || 'Set date'}</span>
                    </button>
                  ))}
                </div>
              )}
              <textarea className="input-field" placeholder="Notes" value={payForm.notes} onChange={capsFieldChange(setPayForm, 'notes')} />

              <div className="rounded-lg border border-border p-3 space-y-2 bg-muted/30">
                <p className="text-xs font-medium text-foreground">Notify residents</p>
                <p className="text-[10px] text-muted-foreground leading-snug">
                  After saving, send an in-app notification (and push, if configured) so flats know a committee payment or receipt was posted—e.g. society electricity, guard salary, or maintenance collected in cash/UPI.
                </p>
                <label className="flex items-start gap-2 text-xs cursor-pointer">
                  <input
                    type="radio"
                    name="pay-notify"
                    className="mt-0.5"
                    checked={paymentNotifyAudience === 'none'}
                    onChange={() => setPaymentNotifyAudience('none')}
                  />
                  <span>Do not notify</span>
                </label>
                <label className="flex items-start gap-2 text-xs cursor-pointer">
                  <input
                    type="radio"
                    name="pay-notify"
                    className="mt-0.5"
                    checked={paymentNotifyAudience === 'selected_flats'}
                    onChange={() => setPaymentNotifyAudience('selected_flats')}
                  />
                  <span>
                    Flats in this payment only ({payForm.selected_flats.length} selected above)
                  </span>
                </label>
                <label className="flex items-start gap-2 text-xs cursor-pointer">
                  <input
                    type="radio"
                    name="pay-notify"
                    className="mt-0.5"
                    checked={paymentNotifyAudience === 'all'}
                    onChange={() => setPaymentNotifyAudience('all')}
                  />
                  <span>All society flats ({flats.length}) — for transparency (e.g. common-area bills)</span>
                </label>
              </div>

              {receiptHeadConflictsPreview.length > 0 && (
                <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-3 space-y-1.5">
                  <p className="text-xs font-semibold text-destructive flex items-center gap-1.5">
                    <AlertTriangle className="w-3.5 h-3.5" />
                    Receipt head already recorded — cannot save
                  </p>
                  <p className="text-[10px] text-muted-foreground leading-snug">
                    These flats already have this receipt head for the selected month and payment channel. Edit or delete
                    the existing entry in <span className="font-medium">Audit → Finance Alarms</span> before recording again.
                  </p>
                  <ul className="text-[10px] text-foreground space-y-0.5 pt-1">
                    {receiptHeadConflictsPreview.map((p) => (
                      <li key={p.id}>
                        Flat {p.flat_number} · ₹{Number(p.amount).toLocaleString('en-IN')} · {p.payment_method} ·{' '}
                        {p.payment_status}
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              <button
                type="button"
                onClick={() => void recordPayment()}
                className="btn-primary"
                disabled={receiptUploading || receiptHeadConflictsPreview.length > 0}
              >
                {receiptUploading ? 'Uploading…' : 'Record Reciept'}
              </button>
            </div>
          )}

          <p className="text-[11px] text-muted-foreground mt-1 leading-snug">
            Pool receipts and flat-wise records appear under <span className="font-medium">Transactions</span>.
            Food / catering for functions → <span className="font-medium">Events &amp; food</span> (split by family). All other
            payments (vendors, utilities, repairs) → record here as society payment / expense.
          </p>

          {flatDateModal.open && (
            <div className="fixed inset-0 z-[60] bg-black/45 p-4 flex items-center justify-center">
              <div className="w-full max-w-xs bg-card border border-border rounded-xl p-4">
                <p className="text-sm font-semibold mb-1">Select due date</p>
                <p className="text-xs text-muted-foreground mb-3">Flat {flatDateModal.flatNumber}</p>
                <DateInput
                  className="input-field"
                  value={flatDateModal.date}
                  onChange={(e) => setFlatDateModal((prev) => ({ ...prev, date: e.target.value }))}
                />
                <div className="flex gap-2 mt-3">
                  <button
                    type="button"
                    className="btn-primary flex-1"
                    onClick={saveFlatDateFromModal}
                  >
                    Save date
                  </button>
                  <button
                    type="button"
                    className="btn-secondary flex-1"
                    onClick={() => setFlatDateModal({ open: false, flatNumber: '', date: payForm.due_date })}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {subTab === 'record_payment' && (
        <div>
          <p className="text-xs text-muted-foreground mb-3 leading-snug">
            Record society outflows (electricity, vendors, repairs) and split across flats — same pattern as{' '}
            <span className="text-foreground font-medium">Record receipt</span> for inflows. Event food/catering →{' '}
            <span className="text-foreground font-medium">Events &amp; food</span>.
          </p>
          <ExpenseSplitter
            adminName={adminName}
            paymentOnly
            embedded
            onRecordsChanged={bumpHeadReconciliation}
          />
          <div className="mt-4 pt-3 border-t border-border/60">
            <button
              type="button"
              className="btn-secondary w-full flex items-center justify-center gap-2"
              onClick={() => setShowHeadFundRecon((v) => !v)}
            >
              <Scale className="w-4 h-4" />
              {showHeadFundRecon ? 'Hide head fund reconciliation' : 'Head fund reconciliation'}
            </button>
            {showHeadFundRecon && (
              <div className="mt-3">
                <HeadFundReconciliation
                  adminName={adminName}
                  refreshKey={headReconciliationKey}
                  onOpenRecordReceipt={() => setSubTab('payments')}
                />
              </div>
            )}
          </div>
        </div>
      )}

      {subTab === 'receipts' && (
        <div>
          <p className="text-[11px] text-muted-foreground mb-3 leading-snug rounded-lg border border-border/80 bg-card/40 p-2.5">
            Maintenance and society-payment receipts below. Event contribution and food bills are listed at the bottom for
            reference only — they are recorded under{' '}
            <span className="font-medium text-foreground">Events &amp; food</span> and do not affect the society ledger.
          </p>
          <input
            className="input-field mb-3"
            type="search"
            placeholder="Search by flat, member name, charge, txn, notes..."
            value={paymentSearchQuery}
            onChange={(e) => setPaymentSearchQuery(e.target.value)}
          />

          <div className="flex gap-1 mb-3 overflow-x-auto">
            {[
              { key: 'all', label: 'ALL' },
              { key: 'pending', label: 'VERIFICATION PENDING' },
              { key: 'verified', label: 'VERIFIED' },
              { key: 'rejected', label: 'REJECTED' },
              { key: 'unpaid', label: 'FLATS UNPAID' },
            ].map((s) => (
              <button
                key={s.key}
                onClick={() => setFilterStatus(s.key)}
                className={`px-2 py-1 rounded text-[10px] font-medium whitespace-nowrap ${filterStatus === s.key ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'}`}
              >
                {s.label}
              </button>
            ))}
          </div>

          <div className="card-section p-3 mb-3 space-y-2">
            <p className="text-[11px] font-medium text-muted-foreground uppercase">Transaction filters</p>
            <select
              className="input-field"
              value={paymentTypeFilter}
              onChange={(e) => {
                setPaymentTypeFilter(e.target.value);
                setPaymentMonthFilter('all');
              }}
            >
              {paymentTypeOptions.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
            <select className="input-field" value={paymentMonthFilter} onChange={(e) => setPaymentMonthFilter(e.target.value)}>
              {monthOptionsForReceipts.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
            <select
              className="input-field"
              value={receiptModeFilter}
              onChange={(e) =>
                setReceiptModeFilter(e.target.value as typeof receiptModeFilter)
              }
            >
              <option value="all">All recording modes</option>
              <option value="society_pool">Society pool (undistributed)</option>
              <option value="flats_only">Flats only</option>
              <option value="flats_plus_outsider">Flats + outsider</option>
              <option value="outsider_only">Outsider only</option>
            </select>
            <p className="text-[10px] text-muted-foreground leading-snug">{transactionFilterHint(paymentTypeFilter)}</p>
          </div>

          {filterStatus === 'unpaid' ? (
            <DescriptiveStatSummary
              label={
                <>
                  {unpaidReceiptRows.length} unpaid flats · Type: {selectedReceiptTypeLabel} · Month:{' '}
                  {selectedReceiptMonthLabel}
                </>
              }
              description="Flats that have not paid for the filters you selected (verified payments only)."
              howCalculated="Target flats minus flats with at least one verified payment matching charge/type/month filters."
            />
          ) : (
            <div className="flex flex-wrap items-start justify-between gap-2 mb-3">
              <DescriptiveStatSummary
                label={
                  <>
                    {receiptSummary.count} entries ·{' '}
                    <TableSumInsight
                      as="span"
                      {...SUM_INSIGHT_METRICS.transactionListTotal}
                      value={`₹${receiptSummary.sum.toLocaleString('en-IN')}`}
                      valueClassName="text-[10px] font-mono font-semibold"
                    />{' '}
                    total · {receiptSummary.flatCount} flat(s) · Type: {selectedReceiptTypeLabel} · Mode:{' '}
                    {receiptModeFilter === 'all' ? 'All' : receiptModeFilter.replace(/_/g, ' ')} · Month:{' '}
                    {selectedReceiptMonthLabel}
                  </>
                }
                description="Totals for the current transaction list after filters (status, type, month, mode)."
                howCalculated="Count and sum of visible maintenance_payment rows plus ledger-only rows in scopedLedgerOnly."
              />
              <ExportFormatMenu
                label="Export statement"
                className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1 shrink-0"
                onExport={exportTransactionStatement}
              />
            </div>
          )}

          {filterStatus !== 'unpaid' &&
            (transactionReceiptHeadSummary.length > 0 || transactionPaymentHeadSummary.length > 0) && (
              <div className="space-y-3 mb-3">
                {transactionReceiptHeadSummary.length > 0 && (
                  <div className="card-section p-3 space-y-2">
                    <p className="text-[11px] font-medium text-muted-foreground uppercase">
                      Society receipts — head-wise summary
                    </p>
                    <p className="text-[10px] text-muted-foreground leading-snug">
                      Grouped by major head from receipt type. Respects current status, type, month, and mode filters.
                      Tap a row to view entries.
                    </p>
                    <div className="overflow-x-auto">
                      <table className="w-full text-[10px] border border-border rounded-md overflow-hidden">
                        <thead>
                          <tr className="bg-muted/50 text-left">
                            <th className="p-1.5 border-b border-border">Head</th>
                            <th className="p-1.5 border-b border-border text-right">Entries</th>
                            <th className="p-1.5 border-b border-border text-right">Cash</th>
                            <th className="p-1.5 border-b border-border text-right">Bank / UPI</th>
                            <th className="p-1.5 border-b border-border text-right">Other</th>
                            <th className="p-1.5 border-b border-border text-right font-semibold">Total</th>
                            <th className="p-1.5 border-b border-border w-8" aria-label="View entries" />
                          </tr>
                        </thead>
                        <tbody>
                          {transactionReceiptHeadSummary.map((row) => (
                            <tr
                              key={row.head}
                              className="hover:bg-muted/30 cursor-pointer"
                              onClick={() => openReceiptHeadSummary(row.head, row.total)}
                            >
                              <td className="p-1.5 border-b border-border/80 max-w-[160px] truncate" title={row.head}>
                                {row.head}
                              </td>
                              <td className="p-1.5 border-b border-border/80 text-right">{row.entries}</td>
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.channelCash}
                                title={`${row.head} — cash`}
                                value={`₹${row.byChannel.cash.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.channelBank}
                                title={`${row.head} — bank / UPI`}
                                value={`₹${row.byChannel.bank.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.channelOther}
                                title={`${row.head} — other`}
                                value={`₹${row.byChannel.other.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.rowTotal}
                                title={`${row.head} — total`}
                                description={`Receipt total for head “${row.head}” under current filters.`}
                                howCalculated={`${SUM_INSIGHT_METRICS.rowTotal.howCalculated} Head: ${row.head}; ${row.entries} entr${row.entries === 1 ? 'y' : 'ies'}.`}
                                value={`₹${row.total.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono font-semibold text-green-700"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <td className="p-1.5 border-b border-border/80 text-right">
                                <button
                                  type="button"
                                  className="p-1 rounded hover:bg-muted inline-flex"
                                  aria-label={`View ${row.head} entries`}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    openReceiptHeadSummary(row.head, row.total);
                                  }}
                                >
                                  <ChevronRight className="w-3.5 h-3.5 text-muted-foreground" />
                                </button>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                        <tfoot>
                          <tr className="bg-muted/30 font-semibold">
                            <td className="p-1.5">All receipt heads</td>
                            <td className="p-1.5 text-right">
                              {transactionReceiptHeadSummary.reduce((s, r) => s + r.entries, 0)}
                            </td>
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelCash}
                              title="All receipt heads — cash"
                              value={`₹${transactionReceiptChannelTotals.cash.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelBank}
                              title="All receipt heads — bank / UPI"
                              value={`₹${transactionReceiptChannelTotals.bank.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelOther}
                              title="All receipt heads — other"
                              value={`₹${transactionReceiptChannelTotals.other.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.transactionReceiptHeadGrandTotal}
                              value={`₹${transactionReceiptHeadSummary.reduce((s, r) => s + r.total, 0).toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold text-green-700"
                              cellClassName="p-1.5"
                            />
                            <td className="p-1.5" />
                          </tr>
                        </tfoot>
                      </table>
                    </div>
                  </div>
                )}

                {transactionPaymentHeadSummary.length > 0 && (
                  <div className="card-section p-3 space-y-2">
                    <p className="text-[11px] font-medium text-muted-foreground uppercase">
                      Society payments — head-wise summary
                    </p>
                    <p className="text-[10px] text-muted-foreground leading-snug">
                      Grouped by expense head from Record payment. Respects current status, type, month, and mode filters.
                      Tap a row to view entries.
                    </p>
                    <div className="overflow-x-auto">
                      <table className="w-full text-[10px] border border-border rounded-md overflow-hidden">
                        <thead>
                          <tr className="bg-muted/50 text-left">
                            <th className="p-1.5 border-b border-border">Expense head</th>
                            <th className="p-1.5 border-b border-border text-right">Entries</th>
                            <th className="p-1.5 border-b border-border text-right">Cash</th>
                            <th className="p-1.5 border-b border-border text-right">Bank / UPI</th>
                            <th className="p-1.5 border-b border-border text-right">Other</th>
                            <th className="p-1.5 border-b border-border text-right font-semibold">Total</th>
                            <th className="p-1.5 border-b border-border w-8" aria-label="View entries" />
                          </tr>
                        </thead>
                        <tbody>
                          {transactionPaymentHeadSummary.map((row) => (
                            <tr
                              key={row.head}
                              className="hover:bg-muted/30 cursor-pointer"
                              onClick={() => openPaymentHeadSummary(row.head, row.total)}
                            >
                              <td className="p-1.5 border-b border-border/80 max-w-[160px] truncate" title={row.head}>
                                {row.head}
                              </td>
                              <td className="p-1.5 border-b border-border/80 text-right">{row.entries}</td>
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.channelCash}
                                title={`${row.head} — cash`}
                                value={`₹${row.byChannel.cash.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.channelBank}
                                title={`${row.head} — bank / UPI`}
                                value={`₹${row.byChannel.bank.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.channelOther}
                                title={`${row.head} — other`}
                                value={`₹${row.byChannel.other.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <TableSumInsight
                                {...SUM_INSIGHT_METRICS.periodExpenseHead}
                                title={row.head}
                                description={`${SUM_INSIGHT_METRICS.periodExpenseHead.description} Head: ${row.head}.`}
                                howCalculated={`${SUM_INSIGHT_METRICS.periodExpenseHead.howCalculated} ${row.entries} entr${row.entries === 1 ? 'y' : 'ies'}.`}
                                value={`₹${row.total.toLocaleString('en-IN')}`}
                                valueClassName="text-[10px] font-mono font-semibold text-orange-700"
                                cellClassName="p-1.5 border-b border-border/80"
                              />
                              <td className="p-1.5 border-b border-border/80 text-right">
                                <button
                                  type="button"
                                  className="p-1 rounded hover:bg-muted inline-flex"
                                  aria-label={`View ${row.head} entries`}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    openPaymentHeadSummary(row.head, row.total);
                                  }}
                                >
                                  <ChevronRight className="w-3.5 h-3.5 text-muted-foreground" />
                                </button>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                        <tfoot>
                          <tr className="bg-muted/30 font-semibold">
                            <td className="p-1.5">All payment heads</td>
                            <td className="p-1.5 text-right">
                              {transactionPaymentHeadSummary.reduce((s, r) => s + r.entries, 0)}
                            </td>
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelCash}
                              title="All payment heads — cash"
                              value={`₹${transactionPaymentChannelTotals.cash.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelBank}
                              title="All payment heads — bank / UPI"
                              value={`₹${transactionPaymentChannelTotals.bank.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelOther}
                              title="All payment heads — other"
                              value={`₹${transactionPaymentChannelTotals.other.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.transactionPaymentHeadGrandTotal}
                              value={`₹${transactionPaymentHeadSummary.reduce((s, r) => s + r.total, 0).toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold text-orange-700"
                              cellClassName="p-1.5"
                            />
                            <td className="p-1.5" />
                          </tr>
                        </tfoot>
                      </table>
                    </div>
                  </div>
                )}
              </div>
            )}

          {filterStatus !== 'unpaid' && (
            <div className="flex flex-wrap gap-2 items-center mb-3 card-section p-2">
              <button
                type="button"
                className="btn-secondary text-[10px] py-1.5 px-2"
                onClick={selectAllVisibleReceipts}
              >
                Select visible
              </button>
              <button
                type="button"
                className="btn-secondary text-[10px] py-1.5 px-2"
                onClick={() => setSelectedReceiptKeys(new Set())}
              >
                Clear
              </button>
              {selectedReceiptKeys.size > 0 && (
                <>
                  <span className="text-[10px] text-muted-foreground">{selectedReceiptKeys.size} selected</span>
                  <button
                    type="button"
                    className="btn-secondary text-[10px] py-1.5 px-2 border border-destructive text-destructive"
                    onClick={() => void bulkDeleteSelectedReceipts()}
                  >
                    Delete selected
                  </button>
                  <select
                    className="input-field text-[10px] py-1.5 max-w-[200px]"
                    defaultValue=""
                    onChange={(e) => {
                      const v = e.target.value as '' | 'pending' | 'verified' | 'rejected';
                      if (!v) return;
                      void bulkSetPaymentStatus(v);
                      e.target.value = '';
                    }}
                  >
                    <option value="">Bulk status (payment rows only)…</option>
                    <option value="pending">Set pending</option>
                    <option value="verified">Set verified</option>
                    <option value="rejected">Set rejected</option>
                  </select>
                </>
              )}
            </div>
          )}

          {filterStatus === 'unpaid' ? (
            <div className="space-y-2">
              {unpaidReceiptRows.length === 0 && (
                <p className="text-sm text-muted-foreground text-center py-8">No unpaid flats for selected filters</p>
              )}
              {unpaidReceiptRows.map((row) => (
                <div key={row.flat_number} className="card-section p-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-semibold">Flat {row.flat_number}</p>
                    <p className="text-xs text-muted-foreground">{row.primary_name || 'Primary member not found'}</p>
                  </div>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-destructive/20 text-destructive">Unpaid</span>
                </div>
              ))}
            </div>
          ) : (
            <>
              {receiptLineItems.map((item) =>
                item.kind === 'mp' && item.p ? (
                  <div key={`mp-${item.p.id}`} className="card-section p-3 mb-2 w-full text-left">
                    <div className="flex gap-2 items-start">
                      <input
                        type="checkbox"
                        className="mt-1.5 shrink-0"
                        checked={selectedReceiptKeys.has(`mp-${item.p.id}`)}
                        onChange={(e) => toggleReceiptKey(`mp-${item.p.id}`, e.target.checked)}
                        aria-label={`Select flat ${item.p.flat_number}`}
                      />
                      <div
                        className="flex-1 min-w-0 cursor-pointer"
                        onClick={() => {
                          setSelectedLedger(null);
                          setSelectedPayment(item.p);
                        }}
                      >
                        <div className="flex justify-between items-start gap-2">
                          <div>
                            <p className="text-[11px] text-muted-foreground">
                              {chargeById.get(item.p.charge_id)?.title || 'Unknown charge'} ·{' '}
                              {paymentMonthLabel(item.p)}
                            </p>
                            {item.p.finance_entry_id && financeEntryById.get(item.p.finance_entry_id as string) ? (
                              <p className="text-[10px] text-muted-foreground font-mono">
                                Mode:{' '}
                                {financeEntryById
                                  .get(item.p.finance_entry_id as string)
                                  ?.record_mode?.replace(/_/g, ' ') ?? '—'}
                              </p>
                            ) : null}
                            <p className="text-sm font-semibold">Flat {item.p.flat_number}</p>
                            <p className="text-xs text-muted-foreground">
                              {[item.p.resident_name, String(item.p.payment_method || '').toUpperCase()]
                                .filter(Boolean)
                                .join(' · ')}
                            </p>
                            {item.p.transaction_id && (
                              <p className="text-[10px] text-muted-foreground font-mono">TXN: {item.p.transaction_id}</p>
                            )}
                            {item.p.rejection_reason ? (
                              <p className="text-[10px] text-destructive">Reason: {item.p.rejection_reason}</p>
                            ) : null}
                            <p className="text-[10px] text-muted-foreground">{fmtDate(item.p.created_at)}</p>
                          </div>
                          <div className="text-right shrink-0">
                            <p className="font-bold">₹{item.p.amount}</p>
                            <span
                              className={`text-[10px] px-2 py-0.5 rounded-full inline-block mt-0.5 ${
                                item.p.payment_status === 'verified'
                                  ? 'bg-green-500/20 text-green-600'
                                  : item.p.payment_status === 'rejected'
                                    ? 'bg-destructive/20 text-destructive'
                                    : 'bg-amber-500/20 text-amber-600'
                              }`}
                            >
                              {item.p.payment_status}
                            </span>
                          </div>
                        </div>
                        {item.p.payment_status === 'pending' && (
                          <div className="flex gap-2 mt-2">
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                void verifyPayment(item.p.id);
                              }}
                              className="flex-1 py-1.5 bg-green-600 text-white rounded-lg text-xs flex items-center justify-center gap-1"
                            >
                              <Check className="w-3 h-3" /> Verify
                            </button>
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                void rejectPayment(item.p.id);
                              }}
                              className="flex-1 py-1.5 bg-destructive text-destructive-foreground rounded-lg text-xs flex items-center justify-center gap-1"
                            >
                              <X className="w-3 h-3" /> Reject
                            </button>
                          </div>
                        )}
                        {item.p.screenshot_url && (
                          <a
                            href={item.p.screenshot_url}
                            target="_blank"
                            rel="noreferrer"
                            onClick={(e) => e.stopPropagation()}
                            className="text-xs text-primary underline mt-1 block"
                          >
                            View Screenshot
                          </a>
                        )}
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2 mt-2 pt-2 border-t border-border items-center">
                      <button
                        type="button"
                        className="btn-secondary text-[10px] py-1 px-2 flex items-center gap-1"
                        onClick={() => openPaymentEdit(item.p)}
                      >
                        <Pencil className="w-3 h-3" /> Edit
                      </button>
                      <select
                        className="input-field text-[10px] py-1 max-w-[140px]"
                        value={item.p.payment_status}
                        onChange={(e) => void changeReceiptPaymentStatus(item.p, e.target.value)}
                      >
                        <option value="pending">pending</option>
                        <option value="verified">verified</option>
                        <option value="rejected">rejected</option>
                      </select>
                      <button
                        type="button"
                        className="text-[10px] py-1 px-2 rounded-lg border border-destructive text-destructive inline-flex items-center gap-1"
                        onClick={() => void deleteMaintenancePaymentRow(item.p)}
                      >
                        <Trash2 className="w-3 h-3" /> Delete
                      </button>
                    </div>
                  </div>
                ) : item.kind === 'ledger' && item.e ? (
                  <div
                    key={`fe-${item.e.id}`}
                    className="card-section p-3 mb-2 w-full text-left border-l-4 border-l-primary/40"
                  >
                    <div className="flex gap-2 items-start">
                      <input
                        type="checkbox"
                        className="mt-1.5 shrink-0"
                        checked={selectedReceiptKeys.has(`ledger-${item.e.id}`)}
                        onChange={(e) => toggleReceiptKey(`ledger-${item.e.id}`, e.target.checked)}
                        aria-label="Select ledger entry"
                      />
                      <div
                        className="flex-1 min-w-0 cursor-pointer"
                        onClick={() => {
                          setSelectedPayment(null);
                          setSelectedLedger(item.e!);
                        }}
                      >
                        <div className="flex justify-between items-start gap-2">
                          <div className="min-w-0">
                            <p className="text-[11px] text-muted-foreground">
                              {ledgerMonthDisplay(item.e)} ·{' '}
                              {ledgerEntryKindLabel(item.e)}
                            </p>
                            <p className="text-sm font-semibold truncate">{item.e.title || 'Finance entry'}</p>
                            <p className="text-[10px] text-muted-foreground">
                              {item.e.record_mode.replace(/_/g, ' ')} · {item.e.destination.replace(/_/g, ' ')}
                            </p>
                            {(() => {
                              const rawCp = item.e.finance_entry_counterparties;
                              const cp = Array.isArray(rawCp) ? rawCp[0] : rawCp;
                              return cp ? (
                                <p className="text-xs text-muted-foreground">
                                  From: {(cp as { name?: string }).name}
                                  {(cp as { relation_to_society?: string | null }).relation_to_society
                                    ? ` · ${(cp as { relation_to_society?: string | null }).relation_to_society}`
                                    : ''}
                                </p>
                              ) : null;
                            })()}
                            <p className="text-[10px] text-muted-foreground">{fmtDateTimeFull(item.e.created_at)}</p>
                          </div>
                          <div className="text-right shrink-0">
                            <p className="font-bold">₹{item.e.total_amount}</p>
                            <span className="text-[10px] px-2 py-0.5 rounded-full bg-green-500/20 text-green-600">
                              {item.e.payment_status}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-wrap gap-2 mt-2 pt-2 border-t border-border items-center">
                      {isLedgerInSocietyPool(item.e) && (
                        <button
                          type="button"
                          className="btn-primary text-[10px] py-1 px-2 flex items-center gap-1"
                          disabled={distributingPoolEntryId === item.e.id}
                          onClick={() => void distributePoolToAllFlats(item.e!)}
                        >
                          <Users className="w-3 h-3" />
                          {distributingPoolEntryId === item.e.id ? 'Distributing…' : 'Distribute equally to all flats'}
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn-secondary text-[10px] py-1 px-2 flex items-center gap-1"
                        onClick={() => openLedgerEdit(item.e!)}
                      >
                        <Pencil className="w-3 h-3" /> Edit
                      </button>
                      <select
                        className="input-field text-[10px] py-1 max-w-[120px]"
                        value={item.e.payment_status}
                        onChange={(e) => void updateLedgerEntryStatus(item.e!.id, e.target.value)}
                      >
                        <option value="verified">verified</option>
                        <option value="pending">pending</option>
                      </select>
                      <button
                        type="button"
                        className="text-[10px] py-1 px-2 rounded-lg border border-destructive text-destructive inline-flex items-center gap-1"
                        onClick={() => void deleteLedgerRow(item.e!)}
                      >
                        <Trash2 className="w-3 h-3" /> Delete
                      </button>
                    </div>
                  </div>
                ) : null,
              )}

              {selectedPayment && (
                <div className="fixed inset-0 z-50 bg-black/45 p-4 flex items-center justify-center">
                  <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 max-h-[85vh] overflow-auto">
                    <div className="flex items-start justify-between gap-3 mb-3">
                      <div>
                        <p className="text-sm font-semibold">Payment details</p>
                        <p className="text-xs text-muted-foreground">
                          {chargeById.get(selectedPayment.charge_id)?.title || 'Unknown charge'}
                        </p>
                      </div>
                      <button type="button" className="text-xs px-2 py-1 border rounded-md" onClick={() => setSelectedPayment(null)}>
                        Close
                      </button>
                    </div>

                    <div className="space-y-2 text-xs">
                      <p><span className="text-muted-foreground">Flat:</span> {selectedPayment.flat_number}</p>
                      <p><span className="text-muted-foreground">Resident:</span> {selectedPayment.resident_name || '-'}</p>
                      <p><span className="text-muted-foreground">Amount:</span> ₹{selectedPayment.amount}</p>
                      <p><span className="text-muted-foreground">Type:</span> {chargeById.get(selectedPayment.charge_id)?.frequency || '-'}</p>
                      <p><span className="text-muted-foreground">Payment method:</span> {selectedPayment.payment_method}</p>
                      <p><span className="text-muted-foreground">Status:</span> {selectedPayment.payment_status}</p>
                      <p><span className="text-muted-foreground">Payment month:</span> {paymentMonthLabel(selectedPayment)}</p>
                      <p>
                        <span className="text-muted-foreground">Due date:</span>{' '}
                        {selectedPayment.due_date ? fmtIsoDateToDisplay(selectedPayment.due_date) : '-'}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Paid at:</span>{' '}
                        {selectedPayment.payment_date ? fmtDateTimeFull(selectedPayment.payment_date) : '-'}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Created at:</span>{' '}
                        {selectedPayment.created_at ? fmtDateTimeFull(selectedPayment.created_at) : '-'}
                      </p>
                      <p><span className="text-muted-foreground">Transaction ID:</span> {selectedPayment.transaction_id || '-'}</p>
                      <p><span className="text-muted-foreground">Verified by:</span> {selectedPayment.verified_by || '-'}</p>
                      <p>
                        <span className="text-muted-foreground">Verified at:</span>{' '}
                        {selectedPayment.verified_at ? fmtDateTimeFull(selectedPayment.verified_at) : '-'}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Reviewed at:</span>{' '}
                        {selectedPayment.reviewed_at ? fmtDateTimeFull(selectedPayment.reviewed_at) : '-'}
                      </p>
                      <p><span className="text-muted-foreground">Rejected reason:</span> {selectedPayment.rejection_reason || '-'}</p>
                      <p><span className="text-muted-foreground">Notes:</span> {selectedPayment.notes || '-'}</p>
                    </div>

                    {selectedPayment.screenshot_url && (
                      <div className="mt-3">
                        <a href={selectedPayment.screenshot_url} target="_blank" className="text-xs text-primary underline block mb-2">
                          Open receipt in new tab
                        </a>
                        <img
                          src={selectedPayment.screenshot_url}
                          alt="Payment receipt"
                          className="w-full max-h-64 object-contain rounded-lg border border-border"
                        />
                      </div>
                    )}
                  </div>
                </div>
              )}

              {selectedLedger && (
                <div className="fixed inset-0 z-50 bg-black/45 p-4 flex items-center justify-center">
                  <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 max-h-[85vh] overflow-auto">
                    <div className="flex items-start justify-between gap-3 mb-3">
                      <div>
                        <p className="text-sm font-semibold">Ledger entry</p>
                        <p className="text-xs text-muted-foreground">{selectedLedger.title || 'Finance entry'}</p>
                      </div>
                      <button
                        type="button"
                        className="text-xs px-2 py-1 border rounded-md"
                        onClick={() => setSelectedLedger(null)}
                      >
                        Close
                      </button>
                    </div>
                    <div className="space-y-2 text-xs">
                      <p>
                        <span className="text-muted-foreground">Mode / destination:</span>{' '}
                        {selectedLedger.record_mode} · {selectedLedger.destination}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Month:</span> {ledgerMonthDisplay(selectedLedger)}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Total:</span> ₹{selectedLedger.total_amount}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Flats in entry:</span> {selectedLedger.aggregate_flat_count}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Allocation style:</span> {selectedLedger.allocation_style}
                      </p>
                      {selectedLedger.distributed_at ? (
                        <p>
                          <span className="text-muted-foreground">Distributed at:</span>{' '}
                          {fmtDateTimeFull(selectedLedger.distributed_at)}
                        </p>
                      ) : isLedgerInSocietyPool(selectedLedger) ? (
                        <p className="text-amber-600">In society pool — not yet split across flats.</p>
                      ) : null}
                      {(() => {
                        const rawCp = selectedLedger.finance_entry_counterparties;
                        const cp = Array.isArray(rawCp) ? rawCp[0] : rawCp;
                        return cp ? (
                          <p>
                            <span className="text-muted-foreground">Counterparty:</span> {(cp as { name?: string }).name}
                          </p>
                        ) : null;
                      })()}
                      <p>
                        <span className="text-muted-foreground">Method:</span> {selectedLedger.payment_method}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Txn:</span> {selectedLedger.transaction_id || '-'}
                      </p>
                      <p>
                        <span className="text-muted-foreground">Notes:</span> {selectedLedger.notes || '-'}
                      </p>
                    </div>
                    {(selectedLedger.finance_entry_allocations?.length ?? 0) > 0 && (
                      <div className="mt-3 border-t border-border pt-2">
                        <p className="text-[10px] font-medium text-muted-foreground uppercase mb-1">Flat allocations</p>
                        <ul className="space-y-1 text-xs">
                          {(selectedLedger.finance_entry_allocations ?? []).map((a) => (
                            <li key={`${selectedLedger.id}-${a.flat_number}`} className="flex justify-between gap-2">
                              <span>Flat {a.flat_number}</span>
                              <span className="font-mono">₹{a.amount}</span>
                            </li>
                          ))}
                        </ul>
                      </div>
                    )}
                    {selectedLedger.screenshot_url && (
                      <div className="mt-3">
                        <a
                          href={selectedLedger.screenshot_url}
                          target="_blank"
                          className="text-xs text-primary underline block mb-2"
                          rel="noreferrer"
                        >
                          Open attachment
                        </a>
                      </div>
                    )}
                    {isLedgerInSocietyPool(selectedLedger) && (
                      <button
                        type="button"
                        className="btn-primary w-full mt-3 flex items-center justify-center gap-2 text-xs"
                        disabled={distributingPoolEntryId === selectedLedger.id}
                        onClick={() => void distributePoolToAllFlats(selectedLedger)}
                      >
                        <Users className="w-3.5 h-3.5" />
                        {distributingPoolEntryId === selectedLedger.id
                          ? 'Distributing…'
                          : 'Distribute equally to all flats'}
                      </button>
                    )}
                  </div>
                </div>
              )}

              {paymentEdit && (
                <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
                  <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 max-h-[85vh] overflow-auto space-y-3">
                    <div className="flex justify-between items-center gap-2">
                      <p className="text-sm font-semibold">Edit payment</p>
                      <button
                        type="button"
                        className="text-xs px-2 py-1 border rounded-md shrink-0"
                        onClick={() => setPaymentEdit(null)}
                      >
                        Cancel
                      </button>
                    </div>
                    <select
                      className="input-field"
                      value={paymentEdit.charge_id}
                      onChange={(e) => setPaymentEdit({ ...paymentEdit, charge_id: e.target.value })}
                    >
                      <option value="">Select receipt type</option>
                      {renderGroupedChargeOptions()}
                    </select>
                    <input
                      className="input-field"
                      type="number"
                      value={paymentEdit.amount}
                      onChange={(e) => setPaymentEdit({ ...paymentEdit, amount: e.target.value })}
                      placeholder="Amount (₹)"
                    />
                    <select
                      className="input-field"
                      value={paymentEdit.payment_method}
                      onChange={(e) => setPaymentEdit({ ...paymentEdit, payment_method: e.target.value })}
                    >
                      <option value="cash">Cash</option>
                      <option value="upi">UPI</option>
                      <option value="razorpay">Razorpay</option>
                      <option value="bank_transfer">Bank transfer</option>
                    </select>
                    <input
                      className="input-field"
                      value={paymentEdit.transaction_id}
                      onChange={(e) => setPaymentEdit({ ...paymentEdit, transaction_id: e.target.value })}
                      placeholder="Transaction / reference ID"
                    />
                    <div>
                      <label className="text-[10px] font-medium text-muted-foreground uppercase">Billing / transaction date</label>
                      <DateInput
                        className="input-field"
                        value={paymentEdit.due_date}
                        onChange={(e) => setPaymentEdit({ ...paymentEdit, due_date: e.target.value })}
                      />
                    </div>
                    <p className="text-[10px] text-muted-foreground">
                      Recorded on: {paymentEdit.recording_date ? fmtIsoDateToDisplay(paymentEdit.recording_date) : '—'} (not
                      used in period reports)
                    </p>
                    <textarea
                      className="input-field"
                      value={paymentEdit.notes}
                      onChange={(e) => setPaymentEdit({ ...paymentEdit, notes: e.target.value })}
                      placeholder="Notes"
                    />
                    <select
                      className="input-field"
                      value={paymentEdit.payment_status}
                      onChange={(e) => setPaymentEdit({ ...paymentEdit, payment_status: e.target.value })}
                    >
                      <option value="pending">pending</option>
                      <option value="verified">verified</option>
                      <option value="rejected">rejected</option>
                    </select>
                    {paymentEdit.payment_status === 'rejected' && (
                      <input
                        className="input-field"
                        value={paymentEdit.rejection_reason}
                        onChange={(e) => setPaymentEdit({ ...paymentEdit, rejection_reason: e.target.value })}
                        placeholder="Rejection reason"
                      />
                    )}
                    <button type="button" className="btn-primary w-full" onClick={() => void savePaymentEdit()}>
                      Save changes
                    </button>
                  </div>
                </div>
              )}

              {ledgerEdit && (
                <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
                  <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3 max-h-[85vh] overflow-auto">
                    <div className="flex justify-between items-center gap-2">
                      <p className="text-sm font-semibold">Edit ledger entry</p>
                      <button
                        type="button"
                        className="text-xs px-2 py-1 border rounded-md shrink-0"
                        onClick={() => setLedgerEdit(null)}
                      >
                        Cancel
                      </button>
                    </div>
                    <input
                      className="input-field"
                      value={ledgerEdit.title}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, title: e.target.value })}
                      placeholder="Title"
                    />
                    <input
                      className="input-field"
                      type="number"
                      value={ledgerEdit.total_amount}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, total_amount: e.target.value })}
                      placeholder="Total amount (₹)"
                    />
                    <select
                      className="input-field"
                      value={ledgerEdit.payment_method}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, payment_method: e.target.value })}
                    >
                      <option value="cash">Cash</option>
                      <option value="upi">UPI</option>
                      <option value="razorpay">Razorpay</option>
                      <option value="bank_transfer">Bank transfer</option>
                      <option value="cheque">Cheque</option>
                      <option value="other">Other</option>
                    </select>
                    <input
                      className="input-field"
                      value={ledgerEdit.transaction_id}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, transaction_id: e.target.value })}
                      placeholder="Transaction / reference ID"
                    />
                    <div>
                      <label className="text-[10px] font-medium text-muted-foreground uppercase">Billing / transaction date</label>
                      <DateInput
                        className="input-field"
                        value={ledgerEdit.transaction_date}
                        onChange={(e) => {
                          const next = e.target.value;
                          setLedgerEdit({
                            ...ledgerEdit,
                            transaction_date: next,
                            entry_month: billingMonthFromDate(next),
                          });
                        }}
                      />
                      <p className="text-[10px] text-muted-foreground mt-1">
                        Entry month: {fmtIsoMonthToDisplay(ledgerEdit.entry_month)}
                      </p>
                    </div>
                    <textarea
                      className="input-field"
                      value={ledgerEdit.notes}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, notes: e.target.value })}
                      placeholder="Notes"
                    />
                    <select
                      className="input-field"
                      value={ledgerEdit.payment_status}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, payment_status: e.target.value })}
                    >
                      <option value="verified">verified</option>
                      <option value="pending">pending</option>
                    </select>
                    <button type="button" className="btn-primary w-full" onClick={() => void saveLedgerEdit()}>
                      Save changes
                    </button>
                  </div>
                </div>
              )}
            </>
          )}

          <div className="mt-8 pt-6 border-t border-border space-y-4">
            <div>
              <h3 className="text-sm font-semibold flex items-center gap-2 mb-1">
                <Calendar className="w-4 h-4 text-blue-500" />
                Events &amp; food — reference only
              </h3>
              <p className="text-[10px] text-muted-foreground leading-snug">
                Read-only view of contribution receipts and food bills. Edit or add these under Events &amp; food — not linked to
                finance_entries.
              </p>
            </div>

            {eventRefLoading ? (
              <p className="text-xs text-muted-foreground py-4 text-center">Loading event receipts…</p>
            ) : (
              <>
                {(eventContribRef.length > 0 || eventFoodRef.length > 0) && (
                  <CashBankBreakdown
                    receipts={eventRefChannelTotals.receiptChannels}
                    payments={eventRefChannelTotals.paymentChannels}
                    receiptLabel="Event contributions"
                    paymentLabel="Food bills"
                  />
                )}
                <div>
                  <p className="text-[11px] font-medium text-muted-foreground uppercase mb-2">Contribution receipts</p>
                  {eventContribRef.length === 0 ? (
                    <p className="text-xs text-muted-foreground py-3 text-center border border-dashed border-border rounded-lg">
                      No event contribution receipts yet
                    </p>
                  ) : (
                    <div className="space-y-2 max-h-64 overflow-y-auto">
                      {eventContribRef.map((c) => (
                        <div key={c.id} className="card-section p-3 flex items-start justify-between gap-3 opacity-90">
                          <div className="min-w-0">
                            <p className="text-[10px] text-muted-foreground">{c.event_title}</p>
                            <p className="text-sm font-medium truncate">{eventContribRefLabel(c)}</p>
                            <p className="text-[10px] text-muted-foreground flex items-center gap-1 flex-wrap">
                              {c.receipt_basis === 'non_flat' ? 'Without flat' : 'Flat-wise'}
                              {c.split_mode ? ` · ${c.split_mode.replace(/_/g, ' ')}` : ''}
                              <ChannelBadge method={c.payment_method} />
                              {c.verified_at ? ` · ${fmtDate(c.verified_at)}` : ''}
                            </p>
                            {c.screenshot_url && (
                              <a
                                href={c.screenshot_url}
                                target="_blank"
                                rel="noreferrer"
                                className="text-[10px] text-primary underline"
                              >
                                View proof
                              </a>
                            )}
                          </div>
                          <p className="font-bold shrink-0">₹{Number(c.amount).toLocaleString('en-IN')}</p>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div>
                  <p className="text-[11px] font-medium text-muted-foreground uppercase mb-2 flex items-center gap-1">
                    <UtensilsCrossed className="w-3 h-3" />
                    Food / catering bills
                  </p>
                  {eventFoodRef.length === 0 ? (
                    <p className="text-xs text-muted-foreground py-3 text-center border border-dashed border-border rounded-lg">
                      No food expense bills yet
                    </p>
                  ) : (
                    <div className="space-y-2 max-h-64 overflow-y-auto">
                      {eventFoodRef.map((ex) => (
                        <div key={ex.id} className="card-section p-3 flex items-start justify-between gap-3 opacity-90">
                          <div className="min-w-0">
                            <p className="text-[10px] text-muted-foreground">
                              {ex.event_title ? ex.event_title : ex.group_name}
                            </p>
                            <p className="text-sm font-medium truncate">{ex.title}</p>
                            <p className="text-[10px] text-muted-foreground flex items-center gap-1">
                              {fmtIsoDateToDisplay(ex.expense_date)}
                              <ChannelBadge method={ex.payment_method} />
                            </p>
                            {ex.bill_screenshot_url && (
                              <a
                                href={ex.bill_screenshot_url}
                                target="_blank"
                                rel="noreferrer"
                                className="text-[10px] text-primary underline"
                              >
                                View bill
                              </a>
                            )}
                          </div>
                          <p className="font-bold shrink-0">₹{Number(ex.total_amount).toLocaleString('en-IN')}</p>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {subTab === 'period' && (
        <div className="space-y-4">
          <div className="card-section p-4 flex flex-wrap items-start gap-4">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
              <CalendarRange className="w-5 h-5 text-primary" />
            </div>
            <div className="flex-1 min-w-[220px] space-y-3">
              <div>
                <h3 className="text-sm font-semibold">Finance period report</h3>
                <p className="text-[11px] text-muted-foreground mt-0.5">
                  Collections from flat owners and outsiders (verified maintenance receipts), plus ledger-only inflows.
                  Expenses are society payments (<span className="font-medium">separate entry</span>) — not event food bills.
                  Event food and contribution receipts reconcile under <span className="font-medium">Events &amp; food</span>.
                </p>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <label className="text-xs flex flex-col gap-1">
                  <span className="text-muted-foreground">Opening (from)</span>
                  <DateInput className="input-field" value={periodFrom} onChange={(e) => setPeriodFrom(e.target.value)} />
                </label>
                <label className="text-xs flex flex-col gap-1">
                  <span className="text-muted-foreground">Closing (to)</span>
                  <DateInput className="input-field" value={periodTo} onChange={(e) => setPeriodTo(e.target.value)} />
                </label>
              </div>
              {periodFrom > periodTo && (
                <p className="text-xs text-destructive">Closing date must be on or after the opening date.</p>
              )}
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  className="btn-secondary text-xs px-3 py-2"
                  onClick={() => {
                    setPeriodFrom(defaultFinancePeriodFrom());
                    setPeriodTo(defaultFinancePeriodTo());
                  }}
                >
                  Reset to FY (1 Apr → today)
                </button>
              </div>
            </div>
          </div>

          <div className="card-section p-4 space-y-4">
            <div className="flex flex-wrap gap-3 items-start justify-between">
              <div className="min-w-[200px]">
                <h3 className="text-sm font-semibold">Export & member delivery</h3>
                <p className="text-[11px] text-muted-foreground mt-0.5">
                  Download this period as PDF, Excel, Word, or CSV. Send one alert per resident with the PDF link — opening the alert records it as seen. Sent by mistake? Use <span className="font-medium">Recall send</span> to withdraw it.
                </p>
              </div>
              <div className="flex flex-wrap gap-2 shrink-0">
                <ExportFormatMenu
                  label="Download report"
                  className="btn-secondary text-xs px-3 py-2 flex items-center gap-1"
                  disabled={periodFrom > periodTo}
                  onExport={exportPeriodReport}
                />
                <button
                  type="button"
                  className="btn-primary text-xs px-3 py-2"
                  onClick={() => void sendPeriodReportToMembers()}
                  disabled={reportPushBusy || periodFrom > periodTo || !societyId}
                >
                  {reportPushBusy ? 'Sending…' : 'Send to members'}
                </button>
                {lastDeliveryBatchId && (
                  <>
                    <button
                      type="button"
                      className="btn-secondary text-xs px-3 py-2"
                      onClick={() => void loadReadStatusForBatch(lastDeliveryBatchId)}
                    >
                      Read receipts
                    </button>
                    <button
                      type="button"
                      className="btn-secondary text-xs px-3 py-2 flex items-center gap-1 text-destructive border-destructive/30 hover:bg-destructive/10"
                      onClick={() => void recallPeriodReportSend(lastDeliveryBatchId)}
                      disabled={reportPushBusy}
                    >
                      <Undo2 className="w-3.5 h-3.5" />
                      Recall send
                    </button>
                  </>
                )}
              </div>
            </div>
            <div className="space-y-2 text-xs">
              <p className="text-muted-foreground font-medium">Audience</p>
              <div className="flex flex-wrap gap-4">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="radio"
                    name="finance-report-audience"
                    checked={reportAudience === 'all'}
                    onChange={() => setReportAudience('all')}
                  />
                  All residents
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="radio"
                    name="finance-report-audience"
                    checked={reportAudience === 'flats'}
                    onChange={() => setReportAudience('flats')}
                  />
                  Selected flats
                </label>
              </div>
              {reportAudience === 'flats' && (
                <FlatMultiSelect
                  flats={flatMultiOptions}
                  selected={reportFlats}
                  onChange={setReportFlats}
                  label="Flats to include"
                  emptyHint="No flats match your search."
                />
              )}
            </div>
          </div>

          <Dialog open={readStatusOpen} onOpenChange={setReadStatusOpen}>
            <DialogContent className="max-w-lg max-h-[85vh] overflow-y-auto">
              <DialogHeader>
                <DialogTitle>Who opened this report</DialogTitle>
              </DialogHeader>
              {readStatusBatchId && (
                <div className="flex flex-wrap gap-2 pb-2 border-b border-border">
                  <button
                    type="button"
                    className="btn-secondary text-xs px-3 py-1.5 flex items-center gap-1 text-destructive border-destructive/30 hover:bg-destructive/10"
                    onClick={() => void recallPeriodReportSend(readStatusBatchId)}
                    disabled={reportPushBusy}
                  >
                    <Undo2 className="w-3.5 h-3.5" />
                    Recall this send
                  </button>
                  <p className="text-[11px] text-muted-foreground self-center">
                    Use if the wrong report was sent — removes alerts and notifies residents to ignore the PDF.
                  </p>
                </div>
              )}
              {readStatusRows.length === 0 ? (
                <p className="text-sm text-muted-foreground">No rows for this send.</p>
              ) : (
                <table className="w-full text-xs">
                  <thead>
                    <tr className="text-left border-b border-border">
                      <th className="p-2">Member</th>
                      <th className="p-2">Flat</th>
                      <th className="p-2">Seen</th>
                      <th className="p-2">When</th>
                    </tr>
                  </thead>
                  <tbody>
                    {readStatusRows.map((row) => {
                      const ru = residentUsers.find((u) => u.id === row.target_id);
                      const seen = !!(row.is_read || row.read_at);
                      return (
                        <tr key={row.id} className="border-b border-border/60">
                          <td className="p-2">{ru?.name?.trim() || '—'}</td>
                          <td className="p-2 font-mono">{ru?.flat_number ?? '—'}</td>
                          <td className="p-2">{seen ? 'Yes' : 'No'}</td>
                          <td className="p-2 text-muted-foreground">
                            {row.read_at ? fmtDateTimeFull(row.read_at) : '—'}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </DialogContent>
          </Dialog>

          <div className="card-section p-4 space-y-3">
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Collection receipts (head-wise)</p>
            <p className="text-[11px] text-muted-foreground flex flex-wrap items-center gap-1">
              <span>
                {financePeriodReport.verifiedPaymentCount} maintenance receipt row(s) in range; ledger-only inflows added:
              </span>
              <DescriptiveValueButton
                {...FINANCE_PERIOD_METRICS.extraLedgerReceipt}
                value={`₹${financePeriodReport.extraLedgerReceipt.toLocaleString('en-IN')}`}
                valueClassName="text-[11px] font-mono font-semibold"
              />
            </p>
            <div className="overflow-x-auto">
              <table className="w-full text-xs border border-border rounded-md overflow-hidden">
                <thead>
                  <tr className="bg-muted/50 text-left">
                    <th className="p-2 border-b border-border">Receipt head</th>
                    <th className="p-2 border-b border-border text-right">Cash</th>
                    <th className="p-2 border-b border-border text-right">Bank / UPI / online</th>
                    <th className="p-2 border-b border-border text-right">Other</th>
                    <th className="p-2 border-b border-border text-right font-semibold">Total</th>
                  </tr>
                </thead>
                <tbody>
                  {financePeriodReport.receiptByHead.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="p-4 text-center text-muted-foreground">
                        No verified collections in this period.
                      </td>
                    </tr>
                  ) : (
                    financePeriodReport.receiptByHead.map(([head, v]) => (
                      <tr key={head}>
                        <td className="p-2 border-b border-border/80 max-w-[200px] truncate" title={head}>
                          {head}
                        </td>
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.channelCash}
                          title={`${head} — cash`}
                          value={`₹${v.cash.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono"
                          cellClassName="p-2 border-b border-border/80"
                        />
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.channelBank}
                          title={`${head} — bank / UPI`}
                          value={`₹${v.bank.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono"
                          cellClassName="p-2 border-b border-border/80"
                        />
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.channelOther}
                          title={`${head} — other`}
                          value={`₹${v.other.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono"
                          cellClassName="p-2 border-b border-border/80"
                        />
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.periodReceiptHead}
                          title={head}
                          description={`${SUM_INSIGHT_METRICS.periodReceiptHead.description} Head: ${head}.`}
                          howCalculated={SUM_INSIGHT_METRICS.periodReceiptHead.howCalculated}
                          value={`₹${v.total.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono font-semibold"
                          cellClassName="p-2 border-b border-border/80"
                        />
                      </tr>
                    ))
                  )}
                </tbody>
                <tfoot>
                  <tr className="bg-muted/30 font-semibold">
                    <td className="p-2">All receipts</td>
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.channelCash}
                      title="All receipts — cash"
                      value={`₹${financePeriodReport.receiptByMethod.cash.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.channelBank}
                      title="All receipts — bank / UPI"
                      value={`₹${financePeriodReport.receiptByMethod.bank.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.channelOther}
                      title="All receipts — other"
                      value={`₹${financePeriodReport.receiptByMethod.other.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.periodVerifiedReceipts}
                      value={`₹${financePeriodReport.totalReceipts.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div className="card-section p-4 space-y-3">
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Expenses (head-wise)</p>
            <div className="overflow-x-auto">
              <table className="w-full text-xs border border-border rounded-md overflow-hidden">
                <thead>
                  <tr className="bg-muted/50 text-left">
                    <th className="p-2 border-b border-border">Expense head</th>
                    <th className="p-2 border-b border-border text-right">Cash</th>
                    <th className="p-2 border-b border-border text-right">Bank / UPI / online</th>
                    <th className="p-2 border-b border-border text-right">Other</th>
                    <th className="p-2 border-b border-border text-right font-semibold">Row total</th>
                  </tr>
                </thead>
                <tbody>
                  {financePeriodReport.expenseByHead.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="p-4 text-center text-muted-foreground">
                        No separate-entry expenses in this period.
                      </td>
                    </tr>
                  ) : (
                    financePeriodReport.expenseByHead.map(([head, v]) => (
                      <tr key={head}>
                        <td className="p-2 border-b border-border/80 max-w-[200px] truncate" title={head}>
                          {head}
                        </td>
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.channelCash}
                          title={`${head} — cash`}
                          value={`₹${v.cash.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono"
                          cellClassName="p-2 border-b border-border/80"
                        />
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.channelBank}
                          title={`${head} — bank / UPI`}
                          value={`₹${v.bank.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono"
                          cellClassName="p-2 border-b border-border/80"
                        />
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.channelOther}
                          title={`${head} — other`}
                          value={`₹${v.other.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono"
                          cellClassName="p-2 border-b border-border/80"
                        />
                        <TableSumInsight
                          {...SUM_INSIGHT_METRICS.periodExpenseHead}
                          title={head}
                          description={`${SUM_INSIGHT_METRICS.periodExpenseHead.description} Head: ${head}.`}
                          howCalculated={SUM_INSIGHT_METRICS.periodExpenseHead.howCalculated}
                          value={`₹${v.total.toLocaleString('en-IN')}`}
                          valueClassName="text-xs font-mono font-semibold"
                          cellClassName="p-2 border-b border-border/80"
                        />
                      </tr>
                    ))
                  )}
                </tbody>
                <tfoot>
                  <tr className="bg-muted/30 font-semibold">
                    <td className="p-2">All expenses</td>
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.channelCash}
                      title="All expenses — cash"
                      value={`₹${financePeriodReport.expenseByMethod.cash.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.channelBank}
                      title="All expenses — bank / UPI"
                      value={`₹${financePeriodReport.expenseByMethod.bank.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.channelOther}
                      title="All expenses — other"
                      value={`₹${financePeriodReport.expenseByMethod.other.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                    <TableSumInsight
                      {...SUM_INSIGHT_METRICS.periodAllExpenses}
                      value={`₹${financePeriodReport.totalExpenses.toLocaleString('en-IN')}`}
                      valueClassName="text-xs font-mono font-semibold"
                      cellClassName="p-2"
                    />
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          {showManualOpeningBalanceSetup && (
          <div className="card-section p-4 space-y-3">
            <div>
              <h3 className="text-sm font-semibold">Manual opening balances</h3>
              <p className="text-[11px] text-muted-foreground mt-0.5">
                One-time setup for the March 2026 go-live: set verified balances as on a cut-off date (default 28 Feb
                2026). Later periods roll forward from transactions — change the period to March 2026 or earlier to
                edit this anchor. Cash defaults to ₹0; leave blank to use transaction totals for that channel.
              </p>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              <label className="text-xs flex flex-col gap-1">
                <span className="text-muted-foreground">As on date</span>
                <DateInput
                  className="input-field"
                  value={anchorForm.as_on_date}
                  onChange={(e) => setAnchorForm((f) => ({ ...f, as_on_date: e.target.value }))}
                />
              </label>
              <label className="text-xs flex flex-col gap-1">
                <span className="text-muted-foreground">Cash in hand (₹)</span>
                <input
                  className="input-field"
                  type="number"
                  step="0.01"
                  placeholder="0 = no cash"
                  value={anchorForm.cash_amount}
                  onChange={(e) => setAnchorForm((f) => ({ ...f, cash_amount: e.target.value }))}
                />
              </label>
              <label className="text-xs flex flex-col gap-1">
                <span className="text-muted-foreground">Bank / UPI balance (₹)</span>
                <input
                  className="input-field"
                  type="number"
                  step="0.01"
                  placeholder="e.g. 18145"
                  value={anchorForm.bank_amount}
                  onChange={(e) => setAnchorForm((f) => ({ ...f, bank_amount: e.target.value }))}
                />
              </label>
              <label className="text-xs flex flex-col gap-1">
                <span className="text-muted-foreground">Other channels (₹)</span>
                <input
                  className="input-field"
                  type="number"
                  step="0.01"
                  placeholder="Leave blank for auto"
                  value={anchorForm.other_amount}
                  onChange={(e) => setAnchorForm((f) => ({ ...f, other_amount: e.target.value }))}
                />
              </label>
            </div>
            <input
              className="input-field text-xs"
              placeholder="Notes (optional)"
              value={anchorForm.notes}
              onChange={(e) => setAnchorForm((f) => ({ ...f, notes: e.target.value }))}
            />
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                className="btn-primary text-xs px-3 py-2"
                disabled={savingOpeningAnchor || !societyId}
                onClick={() => void saveOpeningBalanceAnchor()}
              >
                {savingOpeningAnchor ? 'Saving…' : anchorForm.id ? 'Update anchor' : 'Save anchor'}
              </button>
              <button type="button" className="btn-secondary text-xs px-3 py-2" onClick={resetOpeningBalanceAnchorForm}>
                Reset form
              </button>
              <button
                type="button"
                className="btn-secondary text-xs px-3 py-2"
                onClick={applyCashZeroFeb2026Preset}
              >
                Cash ₹0 · 28 Feb 2026
              </button>
            </div>
            {openingBalanceAnchors.length > 0 && (
              <div className="overflow-x-auto border border-border rounded-md">
                <table className="w-full text-xs">
                  <thead>
                    <tr className="bg-muted/40 text-left">
                      <th className="p-2">As on</th>
                      <th className="p-2 text-right">Bank</th>
                      <th className="p-2 text-right">Cash</th>
                      <th className="p-2 text-right">Other</th>
                      <th className="p-2">Notes</th>
                      <th className="p-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {openingBalanceAnchors.map((row) => (
                      <tr key={row.id} className="border-t border-border/60">
                        <td className="p-2 font-mono">{fmtIsoDateToDisplay(row.as_on_date)}</td>
                        <td className="p-2 text-right font-mono">
                          {row.bank_amount == null ? '—' : `₹${row.bank_amount.toLocaleString('en-IN')}`}
                        </td>
                        <td className="p-2 text-right font-mono">
                          {row.cash_amount == null ? '—' : `₹${row.cash_amount.toLocaleString('en-IN')}`}
                        </td>
                        <td className="p-2 text-right font-mono">
                          {row.other_amount == null ? '—' : `₹${row.other_amount.toLocaleString('en-IN')}`}
                        </td>
                        <td className="p-2 text-muted-foreground max-w-[140px] truncate">{row.notes || '—'}</td>
                        <td className="p-2 whitespace-nowrap">
                          <button type="button" className="text-primary text-[10px] mr-2" onClick={() => editOpeningBalanceAnchor(row)}>
                            Edit
                          </button>
                          <button
                            type="button"
                            className="text-destructive text-[10px]"
                            onClick={() => void deleteAnchor(row.id).then(() => toast.success('Anchor removed'))}
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            {financePeriodReport.appliedOpeningAnchor && (
              <p className="text-[10px] text-muted-foreground">
                This period uses anchor dated{' '}
                <span className="font-medium text-foreground">
                  {fmtIsoDateToDisplay(financePeriodReport.appliedOpeningAnchor.as_on_date)}
                </span>
                {financePeriodReport.openingCashFromManualAnchor ? ' · cash from manual anchor' : ''}
                {financePeriodReport.openingBankFromManualAnchor ? ' · bank from manual anchor' : ''}
                {financePeriodReport.openingOtherFromManualAnchor ? ' · other from manual anchor' : ''}
              </p>
            )}
          </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2">
            <PeriodMetric
              metricKey="openingCash"
              className="border-blue-500/20 bg-blue-500/5"
              value={`₹${financePeriodReport.openingCash.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.openingCash >= 0 ? 'text-blue-600' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="openingBank"
              className="border-blue-500/20 bg-blue-500/5"
              value={`₹${financePeriodReport.openingBank.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.openingBank >= 0 ? 'text-blue-600' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="openingOther"
              className="border-blue-500/20 bg-blue-500/5"
              value={`₹${financePeriodReport.openingOther.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.openingOther >= 0 ? 'text-blue-600' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="openingBalance"
              className="border-blue-500/30 bg-blue-500/10"
              value={`₹${financePeriodReport.openingBalance.toLocaleString('en-IN')}`}
              valueClassName={`text-xl ${financePeriodReport.openingBalance >= 0 ? 'text-blue-700' : 'text-destructive'}`}
            />
            {showManualOpeningBalanceSetup && financePeriodReport.openingBankFromManualAnchor && (
              <p className="sm:col-span-2 lg:col-span-4 text-[10px] text-primary -mt-1">
                Bank opening includes manual anchor
                {financePeriodReport.appliedOpeningAnchor
                  ? ` (${fmtIsoDateToDisplay(financePeriodReport.appliedOpeningAnchor.as_on_date)})`
                  : ''}
              </p>
            )}
            {showManualOpeningBalanceSetup && financePeriodReport.openingCashFromManualAnchor && (
              <p className="sm:col-span-2 lg:col-span-4 text-[10px] text-primary -mt-1">
                Cash opening includes manual anchor
                {financePeriodReport.appliedOpeningAnchor
                  ? ` (${fmtIsoDateToDisplay(financePeriodReport.appliedOpeningAnchor.as_on_date)} · ₹${Number(financePeriodReport.appliedOpeningAnchor.cash_amount ?? 0).toLocaleString('en-IN')} base)`
                  : ''}
              </p>
            )}
          </div>

          <p className="text-[10px] text-muted-foreground uppercase font-medium mt-3">Period movement (receipts − expenses)</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2">
            <PeriodMetric
              metricKey="cashInHand"
              value={`₹${financePeriodReport.cashInHand.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.cashInHand >= 0 ? 'text-green-600' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="cashInBank"
              value={`₹${financePeriodReport.cashInBank.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.cashInBank >= 0 ? 'text-green-600' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="otherNet"
              value={`₹${financePeriodReport.otherNet.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.otherNet >= 0 ? 'text-green-600' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="totalBalance"
              value={`₹${financePeriodReport.totalBalance.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.totalBalance >= 0 ? 'text-green-600' : 'text-destructive'}
            />
          </div>

          <p className="text-[10px] text-muted-foreground uppercase font-medium mt-3">Closing balances (opening + period)</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2">
            <PeriodMetric
              metricKey="closingCash"
              className="border-primary/20 bg-primary/5"
              value={`₹${financePeriodReport.closingCash.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.closingCash >= 0 ? 'text-primary' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="closingBank"
              className="border-primary/20 bg-primary/5"
              value={`₹${financePeriodReport.closingBank.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.closingBank >= 0 ? 'text-primary' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="closingOther"
              className="border-primary/20 bg-primary/5"
              value={`₹${financePeriodReport.closingOther.toLocaleString('en-IN')}`}
              valueClassName={financePeriodReport.closingOther >= 0 ? 'text-primary' : 'text-destructive'}
            />
            <PeriodMetric
              metricKey="closingBalance"
              className="border-primary/30 bg-primary/10"
              value={`₹${financePeriodReport.closingBalance.toLocaleString('en-IN')}`}
              valueClassName={`text-xl ${financePeriodReport.closingBalance >= 0 ? 'text-primary' : 'text-destructive'}`}
            />
          </div>
        </div>
      )}

      {subTab === 'totals' && (
        <div>
          <MonthlyOperatingFundPanel
            societyId={societyId}
            totalsMonth={totalsMonth}
            ledgerEntries={ledgerEntries}
            societyLedgerEntries={societyLedgerEntries}
            payments={payments}
            charges={charges}
            expenseCategoryById={expenseCategoryById}
            adminName={adminName}
            onRefresh={() => void loadAll()}
          />

          <div className="card-section p-4 mb-4 flex flex-wrap items-center gap-4">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
              <Wallet className="w-5 h-5 text-primary" />
            </div>
            <div className="flex-1 min-w-[180px]">
              <p className="text-xs font-medium text-muted-foreground mb-1">Reporting month</p>
              <input
                type="month"
                className="input-field"
                value={totalsMonth}
                onChange={(e) => setTotalsMonth(e.target.value)}
              />
            </div>
          </div>

          <CashBankBreakdown
            className="mb-4"
            receipts={totalsMonthReceiptChannels}
            payments={totalsMonthPaymentChannels}
            receiptLabel={`Ledger inflows (${totalsMonth})`}
            paymentLabel={`Ledger outflows (${totalsMonth})`}
          />

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mb-4">
            <DescriptiveStatCard
              {...FINANCE_TOTALS_METRICS.inflow}
              variant="stat"
              value={`₹${totalsMonthNet.toLocaleString('en-IN')}`}
              valueClassName="text-xl text-green-600"
            />
            <DescriptiveStatCard
              {...FINANCE_TOTALS_METRICS.groups}
              variant="stat"
              value={totalsBreakdown.length}
              valueClassName="text-xl"
            />
            <DescriptiveStatCard
              {...FINANCE_TOTALS_METRICS.flatUnits}
              variant="stat"
              value={totalsBreakdown.reduce((s, r) => s + r.flatUnits, 0)}
              valueClassName="text-xl"
            />
          </div>

          <div className="space-y-2">
            {totalsBreakdown.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-10">
                No ledger groups for {totalsMonth}. Record Reciepts or outsider entries to populate totals.
              </p>
            ) : (
              totalsBreakdown.map((row) => (
                <div
                  key={`${row.mode}-${row.destination}`}
                  className="card-section p-3 flex justify-between items-start gap-3"
                >
                  <div className="min-w-0">
                    <p className="text-sm font-semibold capitalize">{row.mode.replace(/_/g, ' ')}</p>
                    <p className="text-[10px] text-muted-foreground capitalize">
                      {row.destination.replace(/_/g, ' ')} · {row.entries} entr
                      {row.entries === 1 ? 'y' : 'ies'}
                    </p>
                    <p className="text-[10px] text-muted-foreground mt-0.5">
                      Cash ₹{row.byChannel.cash.toLocaleString('en-IN')} · Bank ₹{row.byChannel.bank.toLocaleString('en-IN')}
                      {row.byChannel.other > 0 ? ` · Other ₹${row.byChannel.other.toLocaleString('en-IN')}` : ''}
                    </p>
                  </div>
                  <div className="text-right shrink-0">
                    <DescriptiveValueButton
                      {...FINANCE_LEDGER_GROUP_METRICS.inflowGroup}
                      title={`${row.mode.replace(/_/g, ' ')} · ${row.destination.replace(/_/g, ' ')}`}
                      description={`${FINANCE_LEDGER_GROUP_METRICS.inflowGroup.description} Mode: ${row.mode.replace(/_/g, ' ')}; destination: ${row.destination.replace(/_/g, ' ')}.`}
                      howCalculated={`${FINANCE_LEDGER_GROUP_METRICS.inflowGroup.howCalculated} This group: ${row.entries} entr${row.entries === 1 ? 'y' : 'ies'}, ${row.flatUnits} flat units.`}
                      value={`₹${row.total.toLocaleString('en-IN')}`}
                    />
                    <p className="text-[10px] text-muted-foreground">{row.flatUnits} flat units</p>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Outflow Section */}
          <div className="mt-6">
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mb-4">
              <DescriptiveStatCard
                {...FINANCE_TOTALS_METRICS.outflow}
                variant="stat"
                value={`₹${totalsMonthOutflow.toLocaleString('en-IN')}`}
                valueClassName="text-xl text-red-600"
              />
              <DescriptiveStatCard
                {...FINANCE_TOTALS_METRICS.expenseHeads}
                variant="stat"
                value={totalsOutflowBreakdown.length}
                valueClassName="text-xl"
              />
              <DescriptiveStatCard
                {...FINANCE_TOTALS_METRICS.netInflowOutflow}
                variant="stat"
                value={`₹${(totalsMonthNet - totalsMonthOutflow).toLocaleString('en-IN')}`}
                valueClassName={`text-xl ${totalsMonthNet - totalsMonthOutflow >= 0 ? 'text-green-600' : 'text-red-600'}`}
              />
            </div>

            <div className="space-y-2">
              {totalsOutflowBreakdown.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-10">
                  No outflow entries for {totalsMonth}. Record separate entries (expenses / payments made) to populate this section.
                </p>
              ) : (
                totalsOutflowBreakdown.map((row) => (
                  <div
                    key={row.head}
                    className="card-section p-3 flex justify-between items-start gap-3"
                  >
                    <div className="min-w-0">
                      <p className="text-sm font-semibold">{row.head}</p>
                      <p className="text-[10px] text-muted-foreground capitalize">
                        {row.entries} entr{row.entries === 1 ? 'y' : 'ies'}
                      </p>
                      <p className="text-[10px] text-muted-foreground mt-0.5">
                        Cash ₹{row.byChannel.cash.toLocaleString('en-IN')} · Bank ₹{row.byChannel.bank.toLocaleString('en-IN')}
                        {row.byChannel.other > 0 ? ` · Other ₹${row.byChannel.other.toLocaleString('en-IN')}` : ''}
                      </p>
                    </div>
                    <div className="text-right shrink-0">
                      <DescriptiveValueButton
                        {...FINANCE_LEDGER_GROUP_METRICS.outflowHead}
                        title={row.head}
                        description={`${FINANCE_LEDGER_GROUP_METRICS.outflowHead.description} Head: ${row.head}.`}
                        howCalculated={`${FINANCE_LEDGER_GROUP_METRICS.outflowHead.howCalculated} This head: ${row.entries} entr${row.entries === 1 ? 'y' : 'ies'}.`}
                        value={`₹${row.total.toLocaleString('en-IN')}`}
                        valueClassName="text-red-600"
                      />
                      <p className="text-[10px] text-muted-foreground">{row.flatUnits} flat units</p>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      {subTab === 'flat_report' && (
        <div className="space-y-4">
          <div className="card-section p-4 flex flex-wrap items-start gap-4">
            <div className="w-10 h-10 rounded-xl bg-indigo-500/10 flex items-center justify-center shrink-0">
              <IndianRupee className="w-5 h-5 text-indigo-500" />
            </div>
            <div className="flex-1 min-w-[220px] space-y-3">
              <div>
                <h3 className="text-sm font-semibold">Flat-wise Financial Report</h3>
                <p className="text-[11px] text-muted-foreground mt-0.5">
                  Per-flat breakdown of maintenance receipts and society payment splits for reporting &amp; visibility — not for accounting.
                </p>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <label className="text-xs flex flex-col gap-1">
                  <span className="text-muted-foreground">From</span>
                  <DateInput className="input-field" value={flatReportFrom} onChange={(e) => setFlatReportFrom(e.target.value)} />
                </label>
                <label className="text-xs flex flex-col gap-1">
                  <span className="text-muted-foreground">To</span>
                  <DateInput className="input-field" value={flatReportTo} onChange={(e) => setFlatReportTo(e.target.value)} />
                </label>
                <label className="text-xs flex flex-col gap-1">
                  <span className="text-muted-foreground">Flat</span>
                  <select
                    className="input-field"
                    value={flatReportSelectedFlat}
                    onChange={(e) => setFlatReportSelectedFlat(e.target.value)}
                  >
                    <option value="all">All flats</option>
                    {flats.map((f) => (
                      <option key={f.id} value={f.flat_number}>
                        {f.flat_number} — {primaryByFlatId.get(f.id) || f.owner_name || 'Vacant'}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              {flatReportFrom > flatReportTo && (
                <p className="text-xs text-destructive">End date must be on or after the start date.</p>
              )}
            </div>
          </div>

          {flatReportLoading ? (
            <p className="text-sm text-muted-foreground text-center py-10">Loading flat report data…</p>
          ) : flatReportData.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-10">
              No financial activity found for the selected period{flatReportSelectedFlat !== 'all' ? ` (Flat ${flatReportSelectedFlat})` : ''}.
            </p>
          ) : (
            <>
              {/* Summary cards */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                <DescriptiveStatCard
                  {...FINANCE_FLAT_REPORT_METRICS.totalReceipts}
                  variant="stat"
                  value={`₹${flatReportData.reduce((s, r) => s + r.maintenance_paid, 0).toLocaleString('en-IN')}`}
                  valueClassName="text-lg text-green-600"
                />
                <DescriptiveStatCard
                  {...FINANCE_FLAT_REPORT_METRICS.expenseShare}
                  variant="stat"
                  value={`₹${flatReportData.reduce((s, r) => s + r.expense_share, 0).toLocaleString('en-IN')}`}
                  valueClassName="text-lg text-red-600"
                />
                <DescriptiveStatCard
                  {...FINANCE_FLAT_REPORT_METRICS.settled}
                  variant="stat"
                  value={`₹${flatReportData.reduce((s, r) => s + r.settled_amount, 0).toLocaleString('en-IN')}`}
                  valueClassName="text-lg text-blue-600"
                />
                <DescriptiveStatCard
                  {...FINANCE_FLAT_REPORT_METRICS.unsettled}
                  variant="stat"
                  value={`₹${flatReportData.reduce((s, r) => s + r.unsettled_amount, 0).toLocaleString('en-IN')}`}
                  valueClassName="text-lg text-amber-600"
                />
              </div>

              {/* Per-flat breakdown */}
              <div className="space-y-3">
                {flatReportData.map((row) => (
                  <details key={row.flat_number} className="card-section overflow-hidden">
                    <summary className="p-4 cursor-pointer hover:bg-muted/30 transition-colors">
                      <div className="flex items-center justify-between gap-3">
                        <div className="min-w-0">
                          <p className="text-sm font-semibold">Flat {row.flat_number}</p>
                          <p className="text-[11px] text-muted-foreground truncate">{row.resident_name}</p>
                        </div>
                        <div className="text-right shrink-0 space-y-0.5">
                          <p className="text-xs">
                            <span className="text-green-600 font-medium">Paid ₹{row.maintenance_paid.toLocaleString('en-IN')}</span>
                            {' · '}
                            <span className="text-red-600 font-medium">Share ₹{row.expense_share.toLocaleString('en-IN')}</span>
                          </p>
                          <p className={`text-xs font-bold ${row.net_position >= 0 ? 'text-green-700' : 'text-red-700'}`}>
                            Net: {row.net_position >= 0 ? '+' : ''}₹{row.net_position.toLocaleString('en-IN')}
                          </p>
                        </div>
                      </div>
                    </summary>
                    <div className="border-t border-border px-4 py-3 space-y-2">
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-[11px]">
                        <div>
                          <span className="text-muted-foreground">Maintenance receipts:</span>{' '}
                          <span className="font-medium">{row.maintenance_count}</span>
                        </div>
                        <div>
                          <span className="text-muted-foreground">Expense splits:</span>{' '}
                          <span className="font-medium">{row.expense_count}</span>
                        </div>
                        <div>
                          <span className="text-muted-foreground">Settled:</span>{' '}
                          <span className="font-medium text-blue-600">₹{row.settled_amount.toLocaleString('en-IN')}</span>
                        </div>
                        <div>
                          <span className="text-muted-foreground">Unsettled:</span>{' '}
                          <span className="font-medium text-amber-600">₹{row.unsettled_amount.toLocaleString('en-IN')}</span>
                        </div>
                      </div>
                      {row.details.length > 0 && (
                        <div className="overflow-x-auto mt-2">
                          <table className="w-full text-xs border border-border rounded-md overflow-hidden">
                            <thead>
                              <tr className="bg-muted/50 text-left">
                                <th className="p-2 border-b border-border">Type</th>
                                <th className="p-2 border-b border-border">Description</th>
                                <th className="p-2 border-b border-border text-right">Amount</th>
                                <th className="p-2 border-b border-border">Date</th>
                                <th className="p-2 border-b border-border">Method</th>
                                <th className="p-2 border-b border-border">Status</th>
                              </tr>
                            </thead>
                            <tbody>
                              {row.details.map((d, idx) => (
                                <tr key={idx} className="border-b border-border/60">
                                  <td className="p-2">
                                    <span className={`inline-block px-1.5 py-0.5 rounded text-[10px] font-medium ${d.type === 'maintenance' ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400'}`}>
                                      {d.type === 'maintenance' ? 'Receipt' : 'Expense'}
                                    </span>
                                  </td>
                                  <td className="p-2 max-w-[180px] truncate" title={d.group_name ? `${d.group_name}: ${d.title}` : d.title}>
                                    {d.group_name ? <span className="text-muted-foreground">[{d.group_name}] </span> : null}
                                    {d.title}
                                  </td>
                                  <td className="p-2 text-right font-mono font-medium">₹{d.amount.toLocaleString('en-IN')}</td>
                                  <td className="p-2 text-muted-foreground">{fmtIsoDateToDisplay(d.date)}</td>
                                  <td className="p-2 capitalize">{d.method.replace(/_/g, ' ')}</td>
                                  <td className="p-2">
                                    <span className={`text-[10px] px-1.5 py-0.5 rounded-full ${d.status === 'paid' || d.status === 'verified' || d.status === 'settled' ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400'}`}>
                                      {d.status}
                                    </span>
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      )}
                    </div>
                  </details>
                ))}
              </div>
            </>
          )}
        </div>
      )}

      {subTab === 'reminders' && (
        <div>
          <div className="card-section p-4 mb-4">
            <div className="flex items-center gap-2 mb-2">
              <AlertTriangle className="w-5 h-5 text-amber-500" />
              <h3 className="font-semibold">Unpaid Flats</h3>
            </div>
            <p className="text-sm text-muted-foreground mb-3">{unpaidFlats.length} flats have not paid maintenance</p>
            {unpaidFlats.length > 0 && (
              <button onClick={sendReminders} className="btn-primary w-full flex items-center justify-center gap-2">
                Send reminders to all ({unpaidFlats.length})
              </button>
            )}
          </div>
          <div className="space-y-2">
            {unpaidFlats.map(f => (
              <div key={f.id} className="card-section p-3 flex justify-between items-center">
                <p className="text-sm font-medium">Flat {f.flat_number}</p>
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-destructive/20 text-destructive">Unpaid</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {currentHeadSummaryModal && (
        <ReportDetailModal
          open={headSummaryModalOpen}
          onClose={closeHeadSummaryModal}
          title={currentHeadSummaryModal.title}
          subtitle={currentHeadSummaryModal.subtitle}
          totalAmount={currentHeadSummaryModal.total}
          rows={currentHeadSummaryModal.rows}
          drillable={currentHeadSummaryModal.drillable}
          onRowClick={currentHeadSummaryModal.drillable ? openHeadSummaryEntryDetail : undefined}
          onBack={headSummaryModalStack.length > 1 ? headSummaryModalBack : undefined}
        />
      )}
    </div>
  );
};

export default FinanceManager;
