import { useState, useEffect, useMemo, useCallback, useRef, type ReactNode } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { IndianRupee, Check, X, Upload, AlertTriangle, Pencil, Trash2, Users, Calendar, UtensilsCrossed, ChevronRight } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { format } from 'date-fns';
import { fmtDate, fmtDateTimeFull, fmtIsoDateToDisplay, fmtIsoMonthToDisplay, fmtTime } from '@/lib/dateFormat';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import {
  compareByFlatThenDate,
  compareFlatNumbers,
  flatOptionsWithPrimaryLabel,
  primaryFlatFromAllocations,
  residentLabelForFlatRow,
} from '@/lib/flatMultiSelectOptions';
import { notifyResidentsOfRecord, type AdminRecordNotifyAudience } from '@/lib/adminRecordNotifications';
import { DateInput } from '@/components/DateInput';
import ExportFormatMenu from '@/components/ExportFormatMenu';
import SharePdfWhatsAppButton from '@/components/SharePdfWhatsAppButton';
import {
  buildTransactionExportRows,
  downloadTransactionStatement,
  getTransactionStatementPdfBlob,
} from '@/lib/transactionStatementExport';
import type { ExportFormat } from '@/lib/reportExportUtils';
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
  FINANCE_LEDGER_GROUP_METRICS,
  FINANCE_TOTALS_METRICS,
  SUM_INSIGHT_METRICS,
} from '@/lib/descriptiveMetricCopy';
import { uploadMaintenanceReceipt } from '@/lib/notificationMediaStorage';
import { downloadMaintenanceReceiptPdf } from '@/lib/maintenanceReceiptPdf';
import CashBankBreakdown, { ChannelBadge } from '@/components/CashBankBreakdown';
import { sumByChannel } from '@/lib/cashBankChannel';
import { FinanceRemindersTab } from '@/components/finance/FinanceRemindersTab';
import { FinanceTotalsTab } from '@/components/finance/FinanceTotalsTab';
import { FinanceMaintenanceTab } from '@/components/finance/FinanceMaintenanceTab';
import { FinanceCreatePaymentTab } from '@/components/finance/FinanceCreatePaymentTab';
import { FinanceRecordPaymentTab } from '@/components/finance/FinanceRecordPaymentTab';
import { FinanceSubTabNav } from '@/components/finance/FinanceSubTabNav';
import { UnpaidFlatGridTable } from '@/components/finance/UnpaidFlatGridTable';
import { useFinanceManagerData } from '@/hooks/useFinanceManagerData';
import { useFinanceMutations } from '@/hooks/finance/useFinanceMutations';
import { updateMaintenancePaymentStatus } from '@/services/finance/financeMutations';
import { useFinanceEventReference } from '@/hooks/finance/useFinanceEventReference';
import { useFinanceTotalsBreakdown } from '@/lib/financeTotalsBreakdown';
import {
  buildCurrentMonthChargeTitle,
  chargeForUnpaidFilters,
  chargeTitleMatchesBillingMonth,
  isCurrentMonthChargeTitle,
  isMonthlyMaintenanceCharge,
  normalizeTitle,
  paymentMonthValue,
  transactionFilterHint,
} from '@/lib/financeChargeHelpers';
import {
  addTransactionHeadRow,
  dateInInclusiveRange,
  eventContribRefLabel,
  formatLedgerFieldLabel,
  isGroupExpenseLedgerEntry,
  isLedgerInSocietyPool,
  ledgerMonthDisplay,
  ledgerMonthValue,
  paymentMonthLabel,
  paymentVerifiedAtOrDate,
  transactionHeadSummaryRows,
} from '@/lib/financeLedgerDisplay';
import {
  emptyMaintenanceChargeForm,
  emptyPaymentHeadForm,
  type EventContribRefRow,
  type EventFoodRefRow,
  type FinanceLedgerRow,
  type FinanceSubTab,
  type MaintenanceChargeFormState,
  type PaymentHeadFormState,
  type TransactionHeadModalLayer,
  type TransactionHeadSummaryRow,
  type UnpaidFlatGridRow,
} from '@/lib/financeManagerTypes';
import { filterSocietyLedgerEntries } from '@/lib/financePeriodReport';
import {
  financeExpenseHeadFromLedgerEntry,
  SOCIETY_PAYMENT_MAJOR_HEADS,
  inferMajorHeadFromGroupName,
  paymentGroupsByMajorHead,
  resolveGroupMajorHead,
  type SocietyPaymentMajorHead,
} from '@/lib/financeExpenseHead';
import {
  findMonthlyMaintenanceMonthConflicts,
  findReceiptHeadConflicts,
  type AuditPaymentRow,
} from '@/lib/financeAuditDetection';
import { queryReceiptHeadConflicts } from '@/lib/financeAuditRemediation';

export type { FinanceSubTab };

interface Props {
  adminName?: string;
  adminId?: string;
  initialSubTab?: FinanceSubTab;
  onInitialSubTabConsumed?: () => void;
  initialSearchQuery?: string;
  onInitialSearchConsumed?: () => void;
}


const FinanceManager = ({
  adminName = 'Admin',
  adminId: _adminId,
  initialSubTab,
  onInitialSubTabConsumed,
  initialSearchQuery,
  onInitialSearchConsumed,
}: Props) => {
  const { t } = useLanguage();
  const societyId = useStore((s) => s.societyId);
  const [subTab, setSubTab] = useState<FinanceSubTab>('maintenance');
  const [showRemindersPanel, setShowRemindersPanel] = useState(false);
  const recordReceiptPanelRef = useRef<HTMLDivElement>(null);
  const [headReconciliationKey, setHeadReconciliationKey] = useState(0);
  const [showHeadFundRecon, setShowHeadFundRecon] = useState(false);
  const bumpHeadReconciliation = useCallback(() => setHeadReconciliationKey((k) => k + 1), []);
  const {
    charges,
    payments,
    ledgerEntries,
    expenseCategoryById,
    flats,
    primaryByFlatId,
    societyName,
    residentUsers,
    paymentExpenseGroups,
    autoReminderEnabled,
    setAutoReminderEnabled,
    autoReminderSchedule,
    setAutoReminderSchedule,
    reminderDueDay,
    setReminderDueDay,
    autoIssueEnabled,
    setAutoIssueEnabled,
    autoIssueWhatsapp,
    setAutoIssueWhatsapp,
    autoIssueEmail,
    setAutoIssueEmail,
    reminderWhatsapp,
    setReminderWhatsapp,
    reminderEmail,
    setReminderEmail,
    billSoundKey,
    setBillSoundKey,
    isLoading: financeDataLoading,
    isFetching: financeDataFetching,
    error: financeDataError,
    loadAll,
  } = useFinanceManagerData(societyId, adminName);
  const financeMutations = useFinanceMutations(societyId);
  const {
    contributions: eventContribRef,
    foodExpenses: eventFoodRef,
    isLoading: eventRefLoading,
  } = useFinanceEventReference(societyId, subTab === 'receipts');

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
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [showPaymentHeadForm, setShowPaymentHeadForm] = useState(false);
  const [showPaymentForm, setShowPaymentForm] = useState(false);

  const scrollToRecordReceiptPanel = useCallback(() => {
    requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: 'auto' }));
  }, []);

  useEffect(() => {
    if (!initialSubTab) return;
    setSubTab(initialSubTab);
    if (initialSubTab === 'payments') {
      setShowPaymentForm(true);
      scrollToRecordReceiptPanel();
    }
    onInitialSubTabConsumed?.();
  }, [initialSubTab, onInitialSubTabConsumed, scrollToRecordReceiptPanel]);

  const handleSubTabChange = useCallback(
    (tab: FinanceSubTab) => {
      setSubTab(tab);
      if (tab === 'payments') {
        setShowPaymentForm(true);
        scrollToRecordReceiptPanel();
        return;
      }
      requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: 'auto' }));
    },
    [scrollToRecordReceiptPanel],
  );

  const openRecordReceiptTab = useCallback(() => {
    setSubTab('payments');
    setShowPaymentForm(true);
    scrollToRecordReceiptPanel();
  }, [scrollToRecordReceiptPanel]);

  const [form, setForm] = useState<MaintenanceChargeFormState>(emptyMaintenanceChargeForm);
  const [paymentHeadForm, setPaymentHeadForm] = useState<PaymentHeadFormState>(emptyPaymentHeadForm);
  const [distributingPoolEntryId, setDistributingPoolEntryId] = useState<string | null>(null);
  const [payForm, setPayForm] = useState({
    recordMode: 'flats_only' as 'society_pool' | 'flats_only' | 'flats_plus_outsider' | 'outsider_only',
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
  const [editingPaymentGroupId, setEditingPaymentGroupId] = useState<string | null>(null);
  const [receiptUploading, setReceiptUploading] = useState(false);
  const [paymentNotifyAudience, setPaymentNotifyAudience] = useState<AdminRecordNotifyAudience>('none');
  const [autoSelectedChargeHint, setAutoSelectedChargeHint] = useState('');
  const [paymentTypeFilter, setPaymentTypeFilter] = useState('all');
  const [paymentMonthFilter, setPaymentMonthFilter] = useState('all');
  const [receiptModeFilter, setReceiptModeFilter] = useState<
    'all' | 'society_pool' | 'flats_only' | 'flats_plus_outsider' | 'outsider_only'
  >('all');
  const [totalsMonth, setTotalsMonth] = useState(format(new Date(), 'yyyy-MM'));
  const [paymentSearchQuery, setPaymentSearchQuery] = useState('');
  const [selectedPayment, setSelectedPayment] = useState<any | null>(null);

  useEffect(() => {
    if (!initialSearchQuery) return;
    setPaymentSearchQuery(initialSearchQuery);
    setSubTab('receipts');
    onInitialSearchConsumed?.();
  }, [initialSearchQuery, onInitialSearchConsumed]);

  const [selectedLedger, setSelectedLedger] = useState<FinanceLedgerRow | null>(null);
  const [headSummaryModalOpen, setHeadSummaryModalOpen] = useState(false);
  const [headSummaryModalStack, setHeadSummaryModalStack] = useState<TransactionHeadModalLayer[]>([]);
  const [selectedReceiptKeys, setSelectedReceiptKeys] = useState<Set<string>>(new Set());
  const [paymentEdit, setPaymentEdit] = useState<{
    id: string;
    flat_number: string;
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
  const [savingAutoReminder, setSavingAutoReminder] = useState(false);
  const [testingAutoReminder, setTestingAutoReminder] = useState(false);
  const [lastReminderTestStatus, setLastReminderTestStatus] = useState<string>('');
  const [issuingMonthlyBill, setIssuingMonthlyBill] = useState(false);
  const [lastMonthlyBillStatus, setLastMonthlyBillStatus] = useState<string>('');

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

  const paymentGroupsByMajorHeadMap = useMemo(() => {
    const grouped = paymentGroupsByMajorHead(paymentExpenseGroups);
    const map = new Map<string, typeof paymentExpenseGroups>();
    for (const head of SOCIETY_PAYMENT_MAJOR_HEADS) map.set(head, grouped.get(head) ?? []);
    map.set('Uncategorized', []);
    return map;
  }, [paymentExpenseGroups]);

  const groupIdsInUse = useMemo(() => {
    const ids = new Set<string>();
    for (const c of charges) {
      if (c.expense_group_id) ids.add(String(c.expense_group_id));
    }
    return ids;
  }, [charges]);

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
      try {
        const newGroup = await financeMutations.createExpenseGroup({
          societyId,
          name: subName,
          major_head: form.major_head,
          created_by: adminName,
        });
        expenseGroupId = newGroup.id;
      } catch (e) {
        toast.error(e instanceof Error ? e.message : 'Could not create payment sub-head');
        return;
      }
    }

    const chargeInput = {
      title: form.title,
      amount: Number(form.amount),
      frequency: form.frequency,
      due_day: reminderDueDay,
      expense_group_id: expenseGroupId,
    };

    if (editingChargeId) {
      try {
        await financeMutations.saveCharge({
          chargeId: editingChargeId,
          charge: chargeInput,
          adminName,
        });
      } catch (e) {
        toast.error(e instanceof Error ? e.message : 'Could not update receipt type');
        return;
      }
      toast.success('Receipt type updated');
      setEditingChargeId(null);
    } else {
      try {
        await financeMutations.saveCharge({ charge: chargeInput, adminName });
      } catch (e) {
        toast.error(e instanceof Error ? e.message : 'Could not add receipt type');
        return;
      }
      toast.success('Receipt type added');
    }
    setForm(emptyMaintenanceChargeForm());
    setShowForm(false);
  };

  const startEditCharge = (charge: {
    id: string;
    title: string;
    amount: number;
    frequency?: string | null;
    expense_group_id?: string | null;
  }) => {
    const g = charge.expense_group_id ? paymentGroupById.get(charge.expense_group_id) : undefined;
    const major = g ? resolveGroupMajorHead(g) : inferMajorHeadFromGroupName(charge.title);
    setEditingChargeId(charge.id);
    setForm({
      title: charge.title,
      amount: String(charge.amount),
      frequency: charge.frequency || 'monthly',
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
    try {
      await financeMutations.deleteCharge(id);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not delete receipt type');
      return;
    }
    toast.success('Receipt type deleted');
    if (editingChargeId === id) {
      setEditingChargeId(null);
      setForm(emptyMaintenanceChargeForm());
      setShowForm(false);
    }
  };

  const addPaymentHead = async () => {
    if (!societyId) {
      toast.error('No society selected');
      return;
    }
    if (!paymentHeadForm.major_head) {
      toast.error('Choose a major head for the payment type');
      return;
    }
    const name = paymentHeadForm.name.trim();
    if (!name) {
      toast.error('Enter a sub-head name');
      return;
    }

    if (editingPaymentGroupId) {
      try {
        await financeMutations.saveExpenseGroup({
          societyId,
          groupId: editingPaymentGroupId,
          name,
          description: paymentHeadForm.description.trim() || null,
          major_head: paymentHeadForm.major_head,
        });
      } catch (e) {
        toast.error(e instanceof Error ? e.message : 'Could not update payment type');
        return;
      }
      toast.success('Payment type updated');
      setEditingPaymentGroupId(null);
    } else {
      try {
        await financeMutations.createExpenseGroup({
          societyId,
          name,
          major_head: paymentHeadForm.major_head,
          description: paymentHeadForm.description.trim() || null,
          created_by: adminName,
        });
      } catch (e) {
        toast.error(e instanceof Error ? e.message : 'Could not create payment type');
        return;
      }
      toast.success('Payment type added');
    }
    setPaymentHeadForm(emptyPaymentHeadForm());
    setShowPaymentHeadForm(false);
  };

  const startEditPaymentGroup = (group: {
    id: string;
    name: string;
    description?: string | null;
    major_head?: string | null;
  }) => {
    setEditingPaymentGroupId(group.id);
    setPaymentHeadForm({
      name: group.name,
      description: group.description ?? '',
      major_head: resolveGroupMajorHead(group),
    });
    setShowPaymentHeadForm(true);
  };

  const deletePaymentGroup = async (id: string) => {
    const ok = await confirmAction(
      'Delete this payment type?',
      'This removes the payment sub-head definition only.',
      'Delete',
      'Cancel',
    );
    if (!ok) return;
    try {
      await financeMutations.deleteExpenseGroup(id);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not delete payment type');
      return;
    }
    toast.success('Payment type deleted');
    if (editingPaymentGroupId === id) {
      setEditingPaymentGroupId(null);
      setPaymentHeadForm(emptyPaymentHeadForm());
      setShowPaymentHeadForm(false);
    }
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
        const monthlyChargeIds = charges.filter(isMonthlyMaintenanceCharge).map((c) => c.id as string);
        const conflicts = await queryReceiptHeadConflicts(supabase, {
          chargeId: entry.charge_id,
          paymentMethod: entry.payment_method,
          targets,
          monthlyMaintenanceChargeIds: monthlyChargeIds,
        });
        if (conflicts.length > 0) {
          const flatList = [...new Set(conflicts.map((c) => c.flat_number))].join(', ');
          toast.error(
            `Cannot distribute — monthly maintenance already recorded for Flat ${flatList} in ${billingDate.slice(0, 7)}. Edit or delete in Audit → Finance Alarms.`,
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

      try {
        await financeMutations.distributePool({
          entryId: entry.id,
          allocationRows,
          maintenancePaymentRows: mpRows,
          aggregateFlatCount: scopeFlats.length,
          title: entry.title || chargeTitle || 'Society receipt (distributed)',
        });
      } catch (e) {
        toast.error(e instanceof Error ? e.message : 'Could not distribute pool');
        return;
      }

      toast.success(`Distributed across ${scopeFlats.length} flat(s)`);
      setSelectedLedger(null);
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

    if (mode !== 'society_pool' && (mode === 'flats_only' || mode === 'flats_plus_outsider')) {
      if (payForm.charge_id && payForm.selected_flats.length > 0) {
        const selectedCharge = charges.find((c) => c.id === payForm.charge_id);
        if (selectedCharge && !chargeTitleMatchesBillingMonth(selectedCharge.title ?? '', payForm.due_date)) {
          toast.error(
            `Billing date must fall in the month named by the receipt type ("${selectedCharge.title}"). Change the billing date or select the matching month's receipt type.`,
            { duration: 8000 },
          );
          return;
        }
        const targets = payForm.selected_flats.map((flatNum) => ({
          flatNumber: flatNum,
          dueDate: payForm.due_date,
        }));
        const monthlyChargeIds = charges.filter(isMonthlyMaintenanceCharge).map((c) => c.id as string);
        const conflicts = await queryReceiptHeadConflicts(supabase, {
          chargeId: payForm.charge_id,
          paymentMethod: payForm.payment_method,
          targets,
          monthlyMaintenanceChargeIds: monthlyChargeIds,
        });
        if (conflicts.length > 0) {
          const chargeTitle = selectedCharge?.title ?? t('finance.receiptHead');
          const flatList = [...new Set(conflicts.map((c) => c.flat_number))].join(', ');
          toast.error(
            t('finance.receiptAlreadyRecordedDetail', {
              flat: flatList,
              month: payForm.due_date.slice(0, 7),
              head: chargeTitle,
            }),
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
      const url = await uploadMaintenanceReceipt(file);
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
      due_date: payForm.due_date,
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

    try {
      await financeMutations.recordFinanceEntry({
        entry: {
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
        },
        counterparty: needsCounterparty
          ? {
              name: payForm.outsiderName.trim(),
              relation_to_society: payForm.outsiderRelation.trim() || null,
            }
          : undefined,
        allocations: allocationRows,
        maintenancePayments: mpRows,
      });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save finance entry');
      return;
    }

    const notifyAudience =
      mode === 'flats_only' && paymentNotifyAudience === 'all' ? 'selected_flats' : paymentNotifyAudience;
    const snapshotFlats = [...payForm.selected_flats];
    const payMethod = payForm.payment_method;
    const payTxn = payForm.transaction_id;
    const payNotes = payForm.notes;
    const allFlatNumbers = flats.map((f) => f.flat_number);

    setPayForm({
      recordMode: 'flats_only',
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
    bumpHeadReconciliation();
  };

  const verifyPayment = async (id: string) => {
    const ok = await confirmAction('Verify Payment?', 'Confirm this payment as verified?', 'Yes, Verify', 'Cancel');
    if (!ok) return;
    const row = payments.find((p) => p.id === id);
    try {
      await financeMutations.setPaymentStatus({ paymentId: id, status: 'verified', adminName });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not verify payment');
      return;
    }
    if (row?.flat_number && societyId) {
      const chargeTitle = charges.find((c) => c.id === row.charge_id)?.title || 'Maintenance charge';
      await financeMutations.notifyPayment({
        societyId,
        adminName,
        flatNumber: row.flat_number,
        title: `Payment approved: ${chargeTitle}`,
        message: `Your payment of ₹${Number(row.amount || 0).toLocaleString('en-IN')} has been approved by ${adminName}.`,
      });
    }
    showSuccess('Verified!', 'Payment verified successfully');
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
    try {
      await financeMutations.setPaymentStatus({ paymentId: id, status: 'rejected', adminName, reason });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not reject payment');
      return;
    }
    if (row?.flat_number && societyId) {
      const chargeTitle = charges.find((c) => c.id === row.charge_id)?.title || 'Maintenance charge';
      await financeMutations.notifyPayment({
        societyId,
        adminName,
        flatNumber: row.flat_number,
        title: `Payment rejected: ${chargeTitle}`,
        message: `Your payment entry was rejected by ${adminName}. Reason: ${reason}`,
      });
    }
    showSuccess('Rejected', 'Payment has been rejected');
  };

  const deleteMaintenancePaymentRowInternal = async (p: any) => {
    await financeMutations.removePayment({
      id: p.id,
      flat_number: String(p.flat_number),
      finance_entry_id: p.finance_entry_id,
    });
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
  };

  const updateLedgerEntryStatus = async (entryId: string, payment_status: string) => {
    try {
      await financeMutations.setLedgerStatus({ entryId, payment_status });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not update status');
      return;
    }
    toast.success('Status updated');
  };

  const deleteLedgerRow = async (e: FinanceLedgerRow) => {
    const ok = await confirmAction(
      'Delete this ledger entry?',
      'Removes ledger allocations and counterparty data. Ledger-only rows have no maintenance payments.',
      'Delete',
      'Cancel',
    );
    if (!ok) return;
    try {
      await financeMutations.removeLedger(e.id);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Could not delete ledger entry');
      return;
    }
    toast.success('Ledger entry deleted');
    setSelectedReceiptKeys((prev) => {
      const next = new Set(prev);
      next.delete(`ledger-${e.id}`);
      return next;
    });
  };

  const applyMaintenancePaymentStatus = async (
    id: string,
    nextStatus: 'pending' | 'verified' | 'rejected',
    opts?: { reason?: string; notify?: boolean; skipReload?: boolean },
  ) => {
    const row = payments.find((x) => x.id === id);
    if (!row) return;
    const notify = opts?.notify !== false;

    const result = await updateMaintenancePaymentStatus(id, nextStatus, adminName, opts?.reason);
    if (result.error) {
      toast.error(result.error);
      return;
    }

    if (notify && societyId && row.flat_number) {
      const chargeTitle = charges.find((c) => c.id === row.charge_id)?.title || 'Maintenance charge';
      if (nextStatus === 'verified') {
        await financeMutations.notifyPayment({
          societyId,
          adminName,
          flatNumber: row.flat_number,
          title: `Payment approved: ${chargeTitle}`,
          message: `Your payment of ₹${Number(row.amount || 0).toLocaleString('en-IN')} has been approved by ${adminName}.`,
        });
      } else if (nextStatus === 'rejected') {
        const reason = opts?.reason?.trim() || 'Rejected by admin';
        await financeMutations.notifyPayment({
          societyId,
          adminName,
          flatNumber: row.flat_number,
          title: `Payment rejected: ${chargeTitle}`,
          message: `Your payment entry was rejected by ${adminName}. Reason: ${reason}`,
        });
      }
    }
    if (!opts?.skipReload) await financeMutations.invalidateAll();
  };

  const savePaymentEdit = async () => {
    if (!paymentEdit || !societyId) return;
    const editCharge = charges.find((c) => c.id === paymentEdit.charge_id);
    if (editCharge && !chargeTitleMatchesBillingMonth(editCharge.title ?? '', paymentEdit.due_date)) {
      toast.error(
        `Billing date must fall in the month named by the receipt type ("${editCharge.title}").`,
        { duration: 8000 },
      );
      return;
    }
    if (
      editCharge &&
      isMonthlyMaintenanceCharge(editCharge) &&
      (paymentEdit.payment_status === 'verified' || paymentEdit.payment_status === 'pending')
    ) {
      const monthlyIds = charges.filter(isMonthlyMaintenanceCharge).map((c) => c.id as string);
      const conflicts = await queryReceiptHeadConflicts(supabase, {
        chargeId: paymentEdit.charge_id,
        targets: [{ flatNumber: paymentEdit.flat_number, dueDate: paymentEdit.due_date }],
        monthlyMaintenanceChargeIds: monthlyIds,
      });
      const other = conflicts.filter((c) => c.id !== paymentEdit.id);
      if (other.length > 0) {
        toast.error(
          `Flat ${paymentEdit.flat_number} already has monthly maintenance for ${paymentEdit.due_date.slice(0, 7)}. Double entry for the same month is not allowed.`,
          { duration: 8000 },
        );
        return;
      }
    }
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
    try {
      await financeMutations.savePayment({ paymentId: paymentEdit.id, payload });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not update payment');
      return;
    }
    toast.success('Payment updated');
    setPaymentEdit(null);
  };

  const saveLedgerEdit = async () => {
    if (!ledgerEdit) return;
    const entryMonth = ledgerEntryMonthFromBilling(ledgerEdit.transaction_date);
    if (!isBillingDateInEntryMonth(ledgerEdit.transaction_date, entryMonth)) {
      toast.error('Billing date must fall within the entry month.');
      return;
    }
    try {
      await financeMutations.saveLedger({
        entryId: ledgerEdit.id,
        payload: {
          title: ledgerEdit.title.trim() || null,
          notes: ledgerEdit.notes.trim() || null,
          payment_status: ledgerEdit.payment_status,
          transaction_id: ledgerEdit.transaction_id.trim() || null,
          payment_method: ledgerEdit.payment_method,
          total_amount: Number(ledgerEdit.total_amount) || 0,
          entry_month: entryMonth,
          transaction_date: ledgerEdit.transaction_date,
        },
      });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not update ledger entry');
      return;
    }
    toast.success('Ledger entry updated');
    setLedgerEdit(null);
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
        await financeMutations.removeLedger(id);
      }
    }
    setSelectedReceiptKeys(new Set());
    toast.success('Selected entries deleted');
    await financeMutations.invalidateAll();
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
    await financeMutations.invalidateAll();
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
      flat_number: String(p.flat_number ?? ''),
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

  const monthlyMaintenanceChargeIds = useMemo(
    () => new Set(charges.filter(isMonthlyMaintenanceCharge).map((c) => c.id as string)),
    [charges],
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
        dueDate: payForm.due_date,
        chargeId: payForm.charge_id,
        paymentMethod: payForm.payment_method,
      }))
      .filter((t) => t.dueDate);
    if (monthlyMaintenanceChargeIds.has(payForm.charge_id)) {
      return findMonthlyMaintenanceMonthConflicts(
        payments as AuditPaymentRow[],
        monthlyMaintenanceChargeIds,
        targets,
      );
    }
    return findReceiptHeadConflicts(payments as AuditPaymentRow[], targets);
  }, [
    payForm.charge_id,
    payForm.recordMode,
    payForm.selected_flats,
    payForm.due_date,
    payForm.payment_method,
    payments,
    monthlyMaintenanceChargeIds,
  ]);

  /** Occupied flats with one row per flat_number (duplicate flat rows must not inflate unpaid). */
  const uniqueTargetFlats = useMemo(() => {
    const seen = new Set<string>();
    const rows: typeof targetFlats = [];
    for (const f of targetFlats) {
      const key = String(f.flat_number);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      rows.push(f);
    }
    return rows;
  }, [targetFlats]);

  const unpaidFlats = uniqueTargetFlats.filter((f) =>
    !payments.some((p) => p.flat_number === f.flat_number && p.payment_status === 'verified'),
  );

  const currentMaintenanceCharge = useMemo(() => {
    const monthly = charges.filter(isMonthlyMaintenanceCharge);
    const current =
      monthly.find((c) => isCurrentMonthChargeTitle(c.title)) ?? monthly[0];
    return current ? { title: current.title, amount: Number(current.amount) || 0 } : null;
  }, [charges]);

  const unpaidReminderRows = useMemo((): UnpaidFlatGridRow[] => {
    return unpaidFlats
      .map((f) => ({
        flat_number: f.flat_number,
        primary_name: residentLabelForFlatRow(f.id, f.owner_name ?? null, primaryByFlatId),
        is_occupied: f.is_occupied,
        pending_payment:
          (payments.find(
            (p) =>
              p.flat_number === f.flat_number &&
              (p.payment_status === 'pending' || p.payment_status === 'rejected'),
          )?.payment_status as 'pending' | 'rejected' | undefined) ?? null,
        due_amount: currentMaintenanceCharge?.amount ?? null,
        charge_title: currentMaintenanceCharge?.title ?? null,
      }))
      .sort((a, b) => compareFlatNumbers(a.flat_number, b.flat_number));
  }, [unpaidFlats, primaryByFlatId, payments, currentMaintenanceCharge]);

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

  const unpaidChargeContext = useMemo(
    () => chargeForUnpaidFilters(charges, paymentTypeFilter, paymentMonthFilter),
    [charges, paymentTypeFilter, paymentMonthFilter],
  );

  const unpaidReceiptRows = useMemo((): UnpaidFlatGridRow[] => {
    if (filterStatus !== 'unpaid') return [];
    const paidSet = new Set(
      scopedReceiptPayments
        .filter((p) => p.payment_status === 'verified')
        .map((p) => String(p.flat_number))
        .filter(Boolean),
    );
    const pendingByFlat = new Map<string, 'pending' | 'rejected'>();
    for (const p of scopedReceiptPayments) {
      if (p.payment_status !== 'pending' && p.payment_status !== 'rejected') continue;
      const fn = String(p.flat_number);
      if (!fn) continue;
      pendingByFlat.set(fn, p.payment_status);
    }
    const q = paymentSearchQuery.trim().toLowerCase();
    return uniqueTargetFlats
      .filter((f) => !paidSet.has(String(f.flat_number)))
      .map((f) => ({
        flat_number: f.flat_number,
        primary_name: residentLabelForFlatRow(f.id, f.owner_name ?? null, primaryByFlatId),
        is_occupied: f.is_occupied,
        pending_payment: pendingByFlat.get(String(f.flat_number)) ?? null,
        due_amount: unpaidChargeContext?.amount ?? null,
        charge_title: unpaidChargeContext?.title ?? null,
      }))
      .filter((row) => {
        if (!q) return true;
        return `${row.flat_number} ${row.primary_name}`.toLowerCase().includes(q);
      })
      .sort((a, b) => compareFlatNumbers(a.flat_number, b.flat_number));
  }, [
    filterStatus,
    scopedReceiptPayments,
    uniqueTargetFlats,
    paymentSearchQuery,
    primaryByFlatId,
    unpaidChargeContext,
  ]);

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
            sublabel: `${formatLedgerFieldLabel(e.record_mode)} · ${formatLedgerFieldLabel(e.destination)}`,
            amount: Number(e.total_amount || 0),
            date: fmtDate(e.created_at),
            dateIso: String(e.created_at ?? ''),
            status: e.payment_status,
            extra: String(e.payment_method || '').toUpperCase() || undefined,
            meta: { kind: 'ledger', entry: e },
          },
        });
      }
      items.sort((a, b) => {
        const flatA =
          a.row.meta?.kind === 'mp'
            ? String((a.row.meta.payment as { flat_number?: string })?.flat_number ?? '')
            : primaryFlatFromAllocations(
                (a.row.meta?.entry as FinanceLedgerRow | undefined)?.finance_entry_allocations,
              );
        const flatB =
          b.row.meta?.kind === 'mp'
            ? String((b.row.meta.payment as { flat_number?: string })?.flat_number ?? '')
            : primaryFlatFromAllocations(
                (b.row.meta?.entry as FinanceLedgerRow | undefined)?.finance_entry_allocations,
              );
        return compareByFlatThenDate(flatA, flatB, a.t, b.t);
      });
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
            sublabel: `${formatLedgerFieldLabel(e.record_mode)} · ${formatLedgerFieldLabel(e.destination)}`,
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
              label: 'Billing date',
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
          { id: 'd-mode', label: 'Record mode', sublabel: formatLedgerFieldLabel(e.record_mode) },
          { id: 'd-dest', label: 'Destination', sublabel: formatLedgerFieldLabel(e.destination) },
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
    items.sort((a, b) => {
      const flatA =
        a.kind === 'mp' && a.p
          ? String(a.p.flat_number || '')
          : primaryFlatFromAllocations(a.e?.finance_entry_allocations);
      const flatB =
        b.kind === 'mp' && b.p
          ? String(b.p.flat_number || '')
          : primaryFlatFromAllocations(b.e?.finance_entry_allocations);
      return compareByFlatThenDate(flatA, flatB, a.t, b.t);
    });
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

  const {
    totalsBreakdown,
    totalsMonthReceiptChannels,
    totalsMonthNet,
    totalsOutflowBreakdown,
    totalsMonthPaymentChannels,
    totalsMonthOutflow,
  } = useFinanceTotalsBreakdown(ledgerEntries, societyLedgerEntries, totalsMonth, expenseCategoryById);

  const eventRefChannelTotals = useMemo(
    () => ({
      receiptChannels: sumByChannel(eventContribRef, (c) => Number(c.amount || 0), (c) => c.payment_method),
      paymentChannels: sumByChannel(eventFoodRef, (ex) => Number(ex.total_amount || 0), (ex) => ex.payment_method),
    }),
    [eventContribRef, eventFoodRef],
  );

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

  const transactionStatementShare = useMemo(() => {
    if (filterStatus === 'unpaid') return null;
    const rows = buildTransactionExportRows({
      items: receiptLineItems,
      chargeTitleById: new Map([...chargeById.entries()].map(([id, ch]) => [id, ch.title])),
    });
    if (rows.length === 0) return null;
    return {
      societyName: societyName || 'Society',
      title: 'Transaction statement',
      subtitle: `${receiptSummary.count} entries · ₹${receiptSummary.sum.toLocaleString('en-IN')} total · ${selectedReceiptTypeLabel} · ${selectedReceiptMonthLabel}`,
      filename: `transactions-${selectedReceiptMonthLabel.replace(/\s+/g, '-')}.pdf`,
      message: `${societyName || 'Society'} — Transaction statement (${selectedReceiptMonthLabel})`,
      rows,
    };
  }, [
    filterStatus,
    receiptLineItems,
    chargeById,
    receiptSummary.count,
    receiptSummary.sum,
    selectedReceiptTypeLabel,
    selectedReceiptMonthLabel,
    societyName,
  ]);

  const sendReminders = async () => {
    if (!societyId) return;
    try {
      await financeMutations.sendReminders({
        adminName,
        flatNumbers: unpaidFlats.map((f) => f.flat_number),
      });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not send reminders');
      return;
    }
    toast.success(`Reminders sent to ${unpaidFlats.length} flats`);
  };

  const saveAutoReminderSettings = async () => {
    if (!societyId) return;
    setSavingAutoReminder(true);
    try {
      await financeMutations.saveReminderSettings({
        enabled: autoReminderEnabled,
        schedule: autoReminderSchedule,
        dueDay: reminderDueDay,
        autoIssueEnabled,
        autoIssueWhatsapp,
        autoIssueEmail,
        reminderWhatsapp,
        reminderEmail,
        billSoundKey,
      });
      toast.success('Auto reminder / bill settings saved');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save settings');
    } finally {
      setSavingAutoReminder(false);
    }
  };

  const testAutoReminderNow = async () => {
    if (!societyId) return;
    setTestingAutoReminder(true);
    try {
      const data = await financeMutations.testReminder();
      const sent = Number(data.sent ?? 0);
      toast.success(sent > 0 ? `Test reminder sent to ${sent} flat(s)` : 'No pending dues found for test run');
      setLastReminderTestStatus(`Last test at ${fmtTime(new Date())}: sent to ${sent} flat(s)`);
    } catch (error) {
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
      toast.error(generic ? 'Reminder test failed. Check edge function logs.' : detail);
      setLastReminderTestStatus(`Last test failed: ${detail}`);
    } finally {
      setTestingAutoReminder(false);
    }
  };

  const issueMonthlyBillNow = async () => {
    if (!societyId) return;
    setIssuingMonthlyBill(true);
    try {
      const data = await financeMutations.issueMonthlyBill();
      const flats = Number(data.flats ?? 0);
      const wa = Number(data.whatsapp_sent ?? 0);
      const waFail = Number(data.whatsapp_failed ?? 0);
      const title = data.charge_title || 'Monthly Maintenance';
      const amount = Number(data.amount ?? 2500);
      const msg =
        data.issued > 0
          ? `Issued ${title} (₹${amount.toLocaleString('en-IN')}) to ${flats} flat(s); WhatsApp sent ${wa}${waFail ? `, failed ${waFail}` : ''}`
          : data.note
            ? `Skipped: ${data.note}`
            : 'No bills issued';
      toast.success(msg);
      setLastMonthlyBillStatus(`Last run at ${fmtTime(new Date())}: ${msg}`);
      if (data.whatsapp_configured === false) {
        toast.message('WhatsApp not configured — set WHATSAPP_ACCESS_TOKEN and WHATSAPP_PHONE_NUMBER_ID secrets');
      }
    } catch (error) {
      const detail = String((error as any)?.message || 'Unknown function error');
      toast.error(detail);
      setLastMonthlyBillStatus(`Last run failed: ${detail}`);
    } finally {
      setIssuingMonthlyBill(false);
    }
  };

  if (!societyId) {
    return (
      <div className="page-container pb-24">
        <p className="text-sm text-muted-foreground text-center py-12">Select a society to manage finance.</p>
      </div>
    );
  }

  if (financeDataLoading && charges.length === 0 && payments.length === 0 && ledgerEntries.length === 0) {
    return (
      <div className="page-container pb-24">
        <div className="card-section p-6 text-center space-y-2">
          <p className="text-sm font-medium text-foreground">Loading finance data…</p>
          <p className="text-xs text-muted-foreground">Fetching receipts, ledger entries, and flat records.</p>
        </div>
      </div>
    );
  }

  if (financeDataError) {
    const message = financeDataError instanceof Error ? financeDataError.message : 'Could not load finance data';
    return (
      <div className="page-container pb-24">
        <div className="card-section p-4 border border-destructive/40 bg-destructive/5 space-y-3">
          <p className="text-sm font-semibold text-destructive">Finance module could not load</p>
          <p className="text-xs text-muted-foreground leading-snug">{message}</p>
          <button type="button" className="btn-primary w-full" onClick={() => void loadAll()}>
            Try again
          </button>
        </div>
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

      {financeDataFetching && !financeDataLoading && (
        <p className="text-[10px] text-muted-foreground mb-3 text-center">Refreshing finance data…</p>
      )}

      <FinanceSubTabNav
        activeTab={subTab}
        onTabChange={handleSubTabChange}
        showReminders={showRemindersPanel}
        onToggleReminders={() => setShowRemindersPanel((v) => !v)}
      />

      {showRemindersPanel && (
        <FinanceRemindersTab
          unpaidCount={unpaidFlats.length}
          rows={unpaidReminderRows}
          onSendReminders={() => void sendReminders()}
          autoReminderEnabled={autoReminderEnabled}
          autoReminderSchedule={autoReminderSchedule}
          reminderDueDay={reminderDueDay}
          onAutoReminderEnabledChange={setAutoReminderEnabled}
          onAutoReminderScheduleChange={setAutoReminderSchedule}
          onReminderDueDayChange={setReminderDueDay}
          onSaveAutoReminderSettings={() => void saveAutoReminderSettings()}
          onTestAutoReminderNow={() => void testAutoReminderNow()}
          savingAutoReminder={savingAutoReminder}
          testingAutoReminder={testingAutoReminder}
          lastReminderTestStatus={lastReminderTestStatus}
          includeVacantFlats={includeVacantFlats}
          onIncludeVacantFlatsChange={setIncludeVacantFlats}
          vacantScopeLabel={
            includeVacantFlats
              ? `Using all flats (${flats.length})`
              : `Using occupied/sold flats (${targetFlats.length})`
          }
          autoIssueEnabled={autoIssueEnabled}
          autoIssueWhatsapp={autoIssueWhatsapp}
          autoIssueEmail={autoIssueEmail}
          reminderWhatsapp={reminderWhatsapp}
          reminderEmail={reminderEmail}
          billSoundKey={billSoundKey}
          onAutoIssueEnabledChange={setAutoIssueEnabled}
          onAutoIssueWhatsappChange={setAutoIssueWhatsapp}
          onAutoIssueEmailChange={setAutoIssueEmail}
          onReminderWhatsappChange={setReminderWhatsapp}
          onReminderEmailChange={setReminderEmail}
          onBillSoundKeyChange={setBillSoundKey}
          onIssueMonthlyBillNow={() => void issueMonthlyBillNow()}
          issuingMonthlyBill={issuingMonthlyBill}
          lastMonthlyBillStatus={lastMonthlyBillStatus}
        />
      )}

      {subTab === 'maintenance' && (
        <FinanceMaintenanceTab
          showForm={showForm}
          editingChargeId={editingChargeId}
          form={form}
          onFormChange={setForm}
          onToggleForm={() => {
            if (showForm && !editingChargeId) {
              setShowForm(false);
              return;
            }
            setEditingChargeId(null);
            setForm(emptyMaintenanceChargeForm());
            setShowForm(true);
          }}
          onCancelEdit={() => {
            setEditingChargeId(null);
            setForm(emptyMaintenanceChargeForm());
          }}
          onSaveCharge={() => void addCharge()}
          subHeadsForFormMajor={subHeadsForFormMajor}
          chargesByMajorHead={chargesByMajorHead}
          paymentGroupById={paymentGroupById}
          chargeIdsWithDependents={chargeIdsWithDependents}
          onStartEditCharge={startEditCharge}
          onDeleteCharge={(id) => void deleteCharge(id)}
        />
      )}

      {subTab === 'create_payment' && (
        <FinanceCreatePaymentTab
          showForm={showPaymentHeadForm}
          editingGroupId={editingPaymentGroupId}
          form={paymentHeadForm}
          onFormChange={setPaymentHeadForm}
          onToggleForm={() => {
            if (showPaymentHeadForm && !editingPaymentGroupId) {
              setShowPaymentHeadForm(false);
              return;
            }
            setEditingPaymentGroupId(null);
            setPaymentHeadForm(emptyPaymentHeadForm());
            setShowPaymentHeadForm(true);
          }}
          onCancelEdit={() => {
            setEditingPaymentGroupId(null);
            setPaymentHeadForm(emptyPaymentHeadForm());
          }}
          onSaveGroup={() => void addPaymentHead()}
          groupsByMajorHead={paymentGroupsByMajorHeadMap}
          groupIdsInUse={groupIdsInUse}
          onStartEditGroup={startEditPaymentGroup}
          onDeleteGroup={(id) => void deletePaymentGroup(id)}
        />
      )}

      {subTab === 'payments' && (
        <div ref={recordReceiptPanelRef} id="finance-record-receipt-panel">
          <div className="card-section p-4 mb-4 flex flex-col gap-3">
            <div className="flex items-center gap-2 text-sm font-semibold text-foreground">
              <Upload className="w-4 h-4" />
              <span>Record receipt</span>
            </div>
              <div>
                <p className="text-[10px] font-medium text-muted-foreground uppercase mb-1">Recording style</p>
                <select
                  className="input-field"
                  value={payForm.recordMode}
                  onChange={(e) => {
                    const nextMode = e.target.value as typeof payForm.recordMode;
                    setPayForm({ ...payForm, recordMode: nextMode });
                    if (nextMode === 'flats_only' && paymentNotifyAudience === 'all') {
                      setPaymentNotifyAudience('none');
                    }
                  }}
                >
                  <option value="society_pool">Society pool (distribute to flats later)</option>
                  <option value="flats_only">Direct to selected flats (default — per-flat amount)</option>
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
                  onChange={(e) => setPayForm({ ...payForm, due_date: e.target.value })}
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
              <label className="text-xs flex flex-col gap-1">
                <span className="text-muted-foreground">Flat allocation scope</span>
                <select
                  className="input-field"
                  value={payForm.allocationIncludeVacant ? 'include_vacant' : 'occupied_only'}
                  onChange={(e) =>
                    setPayForm({ ...payForm, allocationIncludeVacant: e.target.value === 'include_vacant' })
                  }
                >
                  <option value="occupied_only">Occupied / sold flats only</option>
                  <option value="include_vacant">Include vacant flats</option>
                </select>
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
                onChange={(nums) => setPayForm({ ...payForm, selected_flats: nums })}
                label="Flats (multi-select)"
              />
              )}
              {payForm.recordMode === 'society_pool' && (
                <label className="text-xs flex flex-col gap-1">
                  <span className="text-muted-foreground">Distribution scope (when splitting later)</span>
                  <select
                    className="input-field"
                    value={payForm.allocationIncludeVacant ? 'include_vacant' : 'occupied_only'}
                    onChange={(e) =>
                      setPayForm({ ...payForm, allocationIncludeVacant: e.target.value === 'include_vacant' })
                    }
                  >
                    <option value="occupied_only">Occupied / sold flats only</option>
                    <option value="include_vacant">Include vacant flats in equal split</option>
                  </select>
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
                {payForm.recordMode !== 'flats_only' && (
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
                )}
              </div>

              {receiptHeadConflictsPreview.length > 0 && (
                <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-3 space-y-1.5">
                  <p className="text-xs font-semibold text-destructive flex items-center gap-1.5">
                    <AlertTriangle className="w-3.5 h-3.5" />
                    {t('finance.receiptAlreadyRecorded')}
                  </p>
                  <p className="text-[10px] text-muted-foreground leading-snug">
                    These flats already have monthly maintenance for the selected billing month (any payment mode). Double
                    entry is blocked. Edit or delete the existing entry in{' '}
                    <span className="font-medium">Audit → Finance Alarms</span> before recording again.
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

          <p className="text-[11px] text-muted-foreground mt-1 leading-snug">
            Pool receipts and flat-wise records appear under <span className="font-medium">Transactions</span>.
            Food / catering for functions → <span className="font-medium">Events &amp; food</span> (split by family). All other
            payments (vendors, utilities, repairs) → record here as society payment / expense.
          </p>
        </div>
      )}

      {subTab === 'record_payment' && (
        <FinanceRecordPaymentTab
          adminName={adminName}
          headReconciliationKey={headReconciliationKey}
          showHeadFundRecon={showHeadFundRecon}
          onToggleHeadFundRecon={() => setShowHeadFundRecon((v) => !v)}
          onRecordsChanged={bumpHeadReconciliation}
          onOpenRecordReceipt={openRecordReceiptTab}
        />
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
              <div className="flex flex-wrap items-center gap-2 shrink-0">
                <ExportFormatMenu
                  label="Export statement"
                  className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1 shrink-0"
                  onExport={exportTransactionStatement}
                />
                {transactionStatementShare && (
                  <SharePdfWhatsAppButton
                    label="Share on WhatsApp"
                    className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1 shrink-0 bg-[#25D366]/10 text-[#128C7E] border border-[#25D366]/30 hover:bg-[#25D366]/20"
                    filename={transactionStatementShare.filename}
                    message={transactionStatementShare.message}
                    getBlob={() => getTransactionStatementPdfBlob(transactionStatementShare)}
                  />
                )}
              </div>
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
                            <td className="p-1.5">{t('finance.allReceiptHeads')}</td>
                            <td className="p-1.5 text-right">
                              {transactionReceiptHeadSummary.reduce((s, r) => s + r.entries, 0)}
                            </td>
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelCash}
                              title={t('finance.allReceiptHeadsCash')}
                              value={`₹${transactionReceiptChannelTotals.cash.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelBank}
                              title={t('finance.allReceiptHeadsBank')}
                              value={`₹${transactionReceiptChannelTotals.bank.toLocaleString('en-IN')}`}
                              valueClassName="text-[10px] font-mono font-semibold"
                              cellClassName="p-1.5"
                            />
                            <TableSumInsight
                              {...SUM_INSIGHT_METRICS.channelOther}
                              title={t('finance.allReceiptHeadsOther')}
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
            <UnpaidFlatGridTable
              rows={unpaidReceiptRows}
              emptyMessage="No unpaid flats for selected filters"
            />
          ) : (
            <div className="space-y-1">
              {receiptLineItems.map((item) =>
                item.kind === 'mp' && item.p ? (
                  <div key={`mp-${item.p.id}`} className="card-section p-3 w-full text-left">
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
                                Mode: {formatLedgerFieldLabel(financeEntryById.get(item.p.finance_entry_id as string)?.record_mode)}
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
                            {item.p.receipt_number && (
                              <p className="text-[10px] text-muted-foreground font-mono">
                                Receipt: {item.p.receipt_number}
                              </p>
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
                    className="card-section p-3 w-full text-left border-l-4 border-l-primary/40"
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
                              {formatLedgerFieldLabel(item.e.record_mode)} · {formatLedgerFieldLabel(item.e.destination)}
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
                        <span className="text-muted-foreground">Billing date:</span>{' '}
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
                      <p><span className="text-muted-foreground">Receipt No.:</span> {selectedPayment.receipt_number || '-'}</p>
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

                    {selectedPayment.payment_status === 'verified' &&
                      selectedPayment.receipt_number &&
                      societyId && (
                        <button
                          type="button"
                          className="btn-primary text-xs mt-3 w-full"
                          onClick={() => {
                            void downloadMaintenanceReceiptPdf({
                              societyId,
                              receiptNumber: String(selectedPayment.receipt_number),
                              flatNumber: String(selectedPayment.flat_number),
                              residentName: selectedPayment.resident_name,
                              amount: Number(selectedPayment.amount || 0),
                              paymentMethod: String(selectedPayment.payment_method || ''),
                              paymentDate: selectedPayment.payment_date,
                              dueDate: selectedPayment.due_date,
                              chargeTitle: chargeById.get(selectedPayment.charge_id)?.title ?? null,
                              transactionId: selectedPayment.transaction_id,
                              verifiedBy: selectedPayment.verified_by,
                              verifiedAt: selectedPayment.verified_at,
                              notes: selectedPayment.notes,
                              generatedBy: adminName,
                            }).then(({ warning }) => {
                              if (warning) toast.message(warning);
                              else toast.success('Receipt downloaded');
                            });
                          }}
                        >
                          Download letterhead receipt
                        </button>
                      )}

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
            </div>
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


      {subTab === 'totals' && (
        <FinanceTotalsTab
          societyId={societyId}
          societyName={societyName || 'Society'}
          adminName={adminName}
          flats={flats}
          totalsMonth={totalsMonth}
          onTotalsMonthChange={setTotalsMonth}
          ledgerEntries={ledgerEntries}
          societyLedgerEntries={societyLedgerEntries}
          payments={payments}
          charges={charges}
          expenseCategoryById={expenseCategoryById}
          onRefresh={() => void loadAll()}
          totalsBreakdown={totalsBreakdown}
          totalsMonthReceiptChannels={totalsMonthReceiptChannels}
          totalsMonthNet={totalsMonthNet}
          totalsOutflowBreakdown={totalsOutflowBreakdown}
          totalsMonthPaymentChannels={totalsMonthPaymentChannels}
          totalsMonthOutflow={totalsMonthOutflow}
        />
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
          societyName={societyName}
        />
      )}
    </div>
  );
};

export default FinanceManager;
