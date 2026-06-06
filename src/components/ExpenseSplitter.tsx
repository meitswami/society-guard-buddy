import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Split, Plus, Trash2, Pencil, Paperclip, X, Search } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { useStore } from '@/store/useStore';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { flatOptionsWithPrimaryLabel, residentLabelForFlatRow } from '@/lib/flatMultiSelectOptions';
import { format } from 'date-fns';
import { fmtIsoDateToDisplay, fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import { notifyResidentsOfRecord, type AdminRecordNotifyAudience } from '@/lib/adminRecordNotifications';
import { insertFinanceLedgerForGroupExpense, syncFinanceLedgerFromGroupExpenseEdit } from '@/lib/groupExpenseFinanceLedger';
import { computeHeadcountAmounts, headcountForFlat, type FlatMemberRow } from '@/lib/flatHeadcountSplit';
import { DateInput } from '@/components/DateInput';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import { RecordingDateBanner } from '@/components/RecordingDateBanner';
import { EVENT_EXPENSE_METRICS } from '@/lib/descriptiveMetricCopy';
import { billingMonthFromDate, isBillingDateInEntryMonth, todayRecordingDate } from '@/lib/financeDates';
import {
  SOCIETY_PAYMENT_MAJOR_HEADS,
  groupMatchesPaymentHeadSearch,
  paymentGroupsByMajorHead,
  type SocietyPaymentMajorHead,
} from '@/lib/financeExpenseHead';

interface Props {
  adminName?: string;
  foodOnly?: boolean;
  paymentOnly?: boolean;
  embedded?: boolean;
  onOpenFinance?: () => void;
}

function ledgerCounterpartyPrefix(foodOnly: boolean, paymentOnly: boolean): string {
  if (foodOnly) return 'Event food';
  if (paymentOnly) return 'Society payment';
  return 'Event expense';
}

type FundingSource = 'residents' | 'society_fund';
type SplitMode = 'even' | 'by_headcount' | 'custom';

type ExpenseGroupRow = {
  id: string;
  name: string;
  description: string | null;
  event_id?: string | null;
  group_kind?: string | null;
  major_head?: string | null;
  adult_weight?: number | null;
  child_weight?: number | null;
};

function parsePaidByFlats(exp: { paid_by_flats?: unknown; paid_by_flat: string }): string[] {
  const raw = exp.paid_by_flats;
  if (Array.isArray(raw) && raw.length) return raw.map(String);
  if (raw && typeof raw === 'object') {
    const arr = raw as string[];
    if (Array.isArray(arr) && arr.length) return arr.map(String);
  }
  return exp.paid_by_flat ? [exp.paid_by_flat] : [];
}

async function uploadExpenseBill(groupId: string, file: File): Promise<string | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `expense-bills/${groupId}/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, file, {
    cacheControl: '3600',
    upsert: false,
  });
  if (error) {
    toast.error(error.message);
    return null;
  }
  const { data } = supabase.storage.from('notification-media').getPublicUrl(path);
  return data.publicUrl;
}

const ExpenseSplitter = ({
  adminName = 'Admin',
  foodOnly = false,
  paymentOnly = false,
  embedded = false,
  onOpenFinance,
}: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [groups, setGroups] = useState<ExpenseGroupRow[]>([]);
  const [events, setEvents] = useState<{ id: string; title: string; event_date: string }[]>([]);
  const [flatMembers, setFlatMembers] = useState<FlatMemberRow[]>([]);
  const [expenses, setExpenses] = useState<any[]>([]);
  const [splits, setSplits] = useState<any[]>([]);
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null; is_occupied: boolean | null }[]>([]);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [fundingSource, setFundingSource] = useState<FundingSource>('residents');
  const [splitMode, setSplitMode] = useState<SplitMode>('by_headcount');
  const [splitFlats, setSplitFlats] = useState<string[]>([]);
  const [paidByFlats, setPaidByFlats] = useState<string[]>([]);
  const [customSplits, setCustomSplits] = useState<Record<string, string>>({});
  const [showGroupForm, setShowGroupForm] = useState(false);
  const [showExpenseForm, setShowExpenseForm] = useState<string | null>(null);
  const [gf, setGf] = useState({
    name: '',
    description: '',
    event_id: '',
    group_kind: 'event' as 'event' | 'general',
    major_head: '' as SocietyPaymentMajorHead | '',
    adult_weight: '1',
    child_weight: '0.5',
  });
  const [headSearchQuery, setHeadSearchQuery] = useState('');

  const ledgerExpenseCategory = (): 'food' | 'payment' => (foodOnly ? 'food' : 'payment');

  const eventTitleForGroup = (groupId: string): string | null => {
    const g = groups.find((x) => x.id === groupId);
    if (!g?.event_id) return null;
    return events.find((ev) => ev.id === g.event_id)?.title ?? null;
  };
  const [ef, setEf] = useState({
    title: '',
    total_amount: '',
    vendor_or_service: '',
    service_kind: 'one_time' as 'recurring' | 'one_time' | 'temporary',
    expense_date: format(new Date(), 'yyyy-MM-dd'),
    payment_method: 'cash',
    notes: '',
  });
  const [billUploading, setBillUploading] = useState(false);
  const [expenseNotifyAudience, setExpenseNotifyAudience] = useState<AdminRecordNotifyAudience>('none');
  const [editingGroup, setEditingGroup] = useState<{
    id: string;
    name: string;
    description: string;
    event_id: string;
    adult_weight: string;
    child_weight: string;
  } | null>(null);
  const [selectedExpenseIds, setSelectedExpenseIds] = useState<Set<string>>(new Set());
  const [expenseEdit, setExpenseEdit] = useState<{
    id: string;
    title: string;
    total_amount: string;
    vendor_or_service: string;
    service_kind: string;
    expense_date: string;
    recording_date: string;
    payment_method: string;
    notes: string;
    record_status: string;
    attachment_urls: string[];
  } | null>(null);
  const [editAttachmentFiles, setEditAttachmentFiles] = useState<File[]>([]);
  const [editAttachmentUploading, setEditAttachmentUploading] = useState(false);

  const activeFlats = includeVacantFlats ? flats : flats.filter((f) => f.is_occupied);

  const loadAll = useCallback(async () => {
    if (!societyId) {
      setGroups([]);
      setExpenses([]);
      setSplits([]);
      setFlats([]);
      setFlatMembers([]);
      setEvents([]);
      setPrimaryByFlatId(new Map());
      return;
    }
    const { data: flatRows } = await supabase
      .from('flats')
      .select('flat_number, id, owner_name, is_occupied')
      .eq('society_id', societyId)
      .order('flat_number');
    if (flatRows) setFlats(flatRows);

    const flatIds = (flatRows ?? []).map((f) => f.id);
    const mRes =
      flatIds.length > 0
        ? await supabase.from('members').select('flat_id, name').eq('is_primary', true).in('flat_id', flatIds)
        : { data: [] as { flat_id: string; name: string }[] };
    const map = new Map<string, string>();
    for (const row of mRes.data ?? []) {
      if (row.flat_id && row.name?.trim()) map.set(row.flat_id, row.name.trim());
    }
    setPrimaryByFlatId(map);

    const memberRes =
      flatIds.length > 0
        ? await supabase.from('members').select('id, flat_id, name, age, relation').in('flat_id', flatIds)
        : { data: [] as FlatMemberRow[] };
    setFlatMembers((memberRes.data as FlatMemberRow[]) ?? []);

    if (foodOnly) {
      const { data: ev } = await supabase
        .from('events')
        .select('id, title, event_date')
        .eq('society_id', societyId)
        .order('event_date', { ascending: false })
        .limit(80);
      setEvents((ev as { id: string; title: string; event_date: string }[]) ?? []);
    } else {
      setEvents([]);
    }

    let groupQuery = supabase.from('expense_groups').select('*').eq('society_id', societyId);
    if (foodOnly) {
      groupQuery = groupQuery.eq('group_kind', 'event');
    } else if (paymentOnly) {
      groupQuery = groupQuery.eq('group_kind', 'general');
    }
    const { data: g } = await groupQuery.order('created_at', { ascending: false });
    if (g) setGroups(g);

    const groupIds = (g ?? []).map((x) => x.id);
    if (groupIds.length === 0) {
      setExpenses([]);
      setSplits([]);
      return;
    }
    let expQuery = supabase.from('expenses').select('*').in('group_id', groupIds);
    if (foodOnly) {
      expQuery = expQuery.eq('expense_category', 'food');
    } else if (paymentOnly) {
      expQuery = expQuery.eq('expense_category', 'payment');
    }
    const { data: e } = await expQuery.order('created_at', { ascending: false });
    if (e) setExpenses(e);
    const expIds = (e ?? []).map((x) => x.id);
    if (expIds.length === 0) {
      setSplits([]);
      return;
    }
    const { data: s } = await supabase.from('expense_splits').select('*').in('expense_id', expIds);
    if (s) setSplits(s);
  }, [societyId, foodOnly, paymentOnly]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  const resetExpenseForm = () => {
    setEf({
      title: '',
      total_amount: '',
      vendor_or_service: '',
      service_kind: 'one_time',
      expense_date: format(new Date(), 'yyyy-MM-dd'),
      payment_method: 'cash',
      notes: '',
    });
    setSplitMode(paymentOnly ? 'even' : 'by_headcount');
    setSplitFlats([]);
    setPaidByFlats([]);
    setCustomSplits({});
    setFundingSource('residents');
    setExpenseNotifyAudience('none');
    setShowExpenseForm(null);
  };

  const addGroup = async () => {
    if (!societyId) {
      toast.error('Select a society from the admin context');
      return;
    }
    if (!gf.name) return;
    if (foodOnly && !gf.event_id) {
      toast.error('Link this food expense group to a calendar event');
      return;
    }
    if (paymentOnly && !gf.major_head) {
      toast.error('Select a major head (e.g. Operation & maintenance)');
      return;
    }
    await supabase.from('expense_groups').insert([
      {
        name: gf.name.trim(),
        description: gf.description?.trim() || null,
        created_by: adminName,
        society_id: societyId,
        event_id: foodOnly ? gf.event_id || null : paymentOnly ? null : gf.event_id || null,
        group_kind: foodOnly ? 'event' : paymentOnly ? 'general' : gf.group_kind,
        major_head: paymentOnly ? gf.major_head : null,
        adult_weight: Number(gf.adult_weight) || 1,
        child_weight: Number(gf.child_weight) || 0.5,
      },
    ]);
    setGf({
      name: '',
      description: '',
      event_id: '',
      group_kind: 'event',
      major_head: '',
      adult_weight: '1',
      child_weight: '0.5',
    });
    setShowGroupForm(false);
    toast.success('Group created');
    loadAll();
  };

  const targetFlatNumbers = (): string[] => {
    const eligible = new Set(activeFlats.map((f) => f.flat_number));
    const chosen = splitFlats.length > 0 ? splitFlats : [...eligible];
    return [...new Set(chosen.filter((n) => eligible.has(n)))];
  };

  const groupWeights = (groupId: string) => {
    const g = groups.find((x) => x.id === groupId);
    return {
      adult: Number(g?.adult_weight ?? 1) || 1,
      child: Number(g?.child_weight ?? 0.5) || 0.5,
    };
  };

  const headcountPreviewForGroup = (groupId: string) => {
    const targets = targetFlatNumbers();
    const { adult, child } = groupWeights(groupId);
    const rows = targets.map((num) => {
      const flat = activeFlats.find((f) => f.flat_number === num);
      return headcountForFlat(num, flat?.id ?? null, flatMembers, adult, child);
    });
    const total = Number(ef.total_amount) || 0;
    const amounts = total > 0 ? computeHeadcountAmounts(total, rows) : [];
    return { rows, amounts, adult, child };
  };

  const setCustomFlatAmount = (flatNumber: string, amount: string) => {
    setCustomSplits((prev) => ({ ...prev, [flatNumber]: amount }));
  };

  const addExpense = async (groupId: string) => {
    if (!ef.title?.trim() || !ef.total_amount) {
      toast.error('Title and total amount are required');
      return;
    }
    const recordingDate = todayRecordingDate();
    const billingDate = ef.expense_date.slice(0, 10);
    const entryMonth = billingMonthFromDate(billingDate);
    if (!isBillingDateInEntryMonth(billingDate, entryMonth)) {
      toast.error('Billing date must fall within its calendar month.');
      return;
    }
    const total = Number(ef.total_amount);
    if (!total || total <= 0) {
      toast.error('Enter a valid total amount');
      return;
    }

    // Duplicate detection: check if same title + amount + expense_date already exists in this group
    const { data: existingExp } = await supabase
      .from('expenses')
      .select('id')
      .eq('group_id', groupId)
      .eq('title', ef.title.trim())
      .eq('total_amount', total)
      .eq('expense_date', ef.expense_date)
      .limit(1);
    if (existingExp && existingExp.length > 0) {
      const confirmed = await confirmAction(
        'Duplicate entry detected',
        `An expense with the same title, amount (₹${total}), and date already exists in this group. Do you still want to proceed?`,
        'Record anyway',
        'Cancel',
      );
      if (!confirmed) return;
    }

    let billUrl: string | null = null;
    const fileInput = document.getElementById(`expense-bill-${groupId}`) as HTMLInputElement | null;
    const file = fileInput?.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/') && !file.type.startsWith('audio/') && file.type !== 'application/pdf') {
        toast.error('Bill attachment: use image, PDF, or short audio');
        return;
      }
      if (file.size > 8 * 1024 * 1024) {
        toast.error('Bill file must be 8MB or smaller');
        return;
      }
      setBillUploading(true);
      billUrl = await uploadExpenseBill(groupId, file);
      setBillUploading(false);
      if (!billUrl) return;
      if (fileInput) fileInput.value = '';
    }

    if (fundingSource === 'society_fund') {
      const groupName = groups.find((x) => x.id === groupId)?.name ?? 'Expense group';
      const { data: socExpense, error } = await supabase
        .from('expenses')
        .insert([
          {
            group_id: groupId,
            title: ef.title.trim(),
            total_amount: total,
            paid_by_flat: 'SOCIETY',
            paid_by_flats: [],
            paid_by_name: adminName,
            split_type: 'society_fund',
            payment_method: ef.payment_method,
            bill_screenshot_url: billUrl,
            service_kind: ef.service_kind,
            vendor_or_service: ef.vendor_or_service?.trim() || null,
            expense_date: billingDate,
            recording_date: recordingDate,
            notes: ef.notes?.trim() || null,
            record_status: 'active',
            expense_category: foodOnly ? 'food' : 'payment',
          },
        ])
        .select('id')
        .single();
      if (error || !socExpense?.id) {
        toast.error(error?.message || 'Could not save expense');
        return;
      }

      const ledgerRes = await insertFinanceLedgerForGroupExpense(supabase, {
        societyId: societyId!,
        adminName,
        groupName,
        expenseId: socExpense.id,
        title: ef.title.trim(),
        total,
        expenseDate: billingDate,
        payment_method: ef.payment_method,
        screenshot_url: billUrl,
        notes: ef.notes?.trim() || null,
        vendor_or_service: ef.vendor_or_service?.trim() || null,
        allocationSplits: [{ flat_number: 'SOCIETY', amount: total }],
        flats,
        counterpartyName: `${ledgerCounterpartyPrefix(foodOnly, paymentOnly)}: ${groupName}`,
        counterpartyRelation: 'Society fund (no per-flat split)',
        expenseCategory: ledgerExpenseCategory(),
        eventTitle: eventTitleForGroup(groupId),
      });
      if (ledgerRes.error) {
        toast.error(ledgerRes.error);
        await supabase.from('expenses').delete().eq('id', socExpense.id);
        return;
      }

      const notifyAudience = expenseNotifyAudience;
      const allFlatNums = flats.map((f) => f.flat_number);
      const snapTitle = ef.title.trim();
      const snapVendor = ef.vendor_or_service?.trim() || '';
      const snapKind = ef.service_kind;
      const snapPm = ef.payment_method;
      const snapDate = ef.expense_date;
      const snapNotes = ef.notes?.trim() || '';
      const snapBill = billUrl;

      resetExpenseForm();
      let suffix = '';
      if (notifyAudience === 'all' && societyId) {
        const title = `Society expense: ${snapTitle}`;
        const lines = [
          `${adminName} recorded a society / corpus expense in “${groupName}”.`,
          `“${snapTitle}” — ₹${total.toLocaleString('en-IN')} (${snapPm}, ${snapKind}). No per-flat split.`,
        ];
        if (snapVendor) lines.push(`Vendor / service: ${snapVendor}.`);
        if (snapDate) lines.push(`Expense date: ${snapDate}.`);
        if (snapNotes) lines.push(snapNotes);
        lines.push(`Shared with all ${allFlatNums.length} society flat(s).`);
        if (snapBill) lines.push('A receipt image may be attached when available.');
        const ok = await notifyResidentsOfRecord({
          societyId,
          adminName,
          audience: 'all',
          selectedFlatNumbers: [],
          title,
          message: lines.join(' '),
          notificationType: 'society_expense',
          billUrl: snapBill,
          saveSucceededHint:
            'Expense saved, but notifying residents failed. You can send a manual notice from Notifications.',
        });
        if (ok) suffix = ' · Residents notified';
      }
      toast.success('Society expense recorded (no split to flats)' + suffix);
      loadAll();
      return;
    }

    if (paidByFlats.length === 0) {
      toast.error('Select at least one flat under “Paid by (flats)” (who advanced the payment)');
      return;
    }

    const targets = targetFlatNumbers();
    if (targets.length === 0) {
      toast.error('Select flats to split among, or leave empty to use all eligible flats');
      return;
    }

    const paidBySorted = [...paidByFlats];
    const primaryPaidBy = paidBySorted[0];

    let splitRows: Array<{
      expense_id: string;
      flat_number: string;
      amount: number;
      is_settled: boolean;
      settled_at: string | null;
      resident_name: string | null;
    }> = [];

    const splitType =
      splitMode === 'custom'
        ? 'custom'
        : splitMode === 'by_headcount'
          ? 'by_headcount'
          : splitFlats.length > 0
            ? 'equal_selected'
            : 'equal_all';

    if (splitMode === 'even') {
      const splitAmount = total / targets.length;
      splitRows = targets.map((num) => {
        const flat = activeFlats.find((f) => f.flat_number === num);
        return {
          expense_id: '',
          flat_number: num,
          amount: Number(splitAmount.toFixed(2)),
          is_settled: paidBySorted.includes(num),
          settled_at: paidBySorted.includes(num) ? new Date().toISOString() : null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
        };
      });
    } else if (splitMode === 'by_headcount') {
      const { adult, child } = groupWeights(groupId);
      const headRows = targets.map((num) => {
        const flat = activeFlats.find((f) => f.flat_number === num);
        return headcountForFlat(num, flat?.id ?? null, flatMembers, adult, child);
      });
      const unitSum = headRows.reduce((s, r) => s + r.units, 0);
      if (unitSum <= 0) {
        toast.error('No headcount units — add members (age/relation) per flat in Residents');
        return;
      }
      const amounts = computeHeadcountAmounts(total, headRows);
      splitRows = amounts.map(({ flat_number, amount }) => {
        const flat = activeFlats.find((f) => f.flat_number === flat_number);
        return {
          expense_id: '',
          flat_number,
          amount,
          is_settled: paidBySorted.includes(flat_number),
          settled_at: paidBySorted.includes(flat_number) ? new Date().toISOString() : null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
        };
      });
    } else {
      const entries = targets
        .map((num) => [num, customSplits[num] ?? ''] as const)
        .filter(([, v]) => Number(v) > 0);
      if (entries.length === 0) {
        toast.error('Enter amounts for flats in custom split');
        return;
      }
      const customTotal = Number(entries.reduce((sum, [, v]) => sum + Number(v), 0).toFixed(2));
      if (Math.abs(customTotal - total) > 0.01) {
        toast.error(`Custom split total ₹${customTotal.toFixed(2)} must match expense total ₹${total.toFixed(2)}`);
        return;
      }
      splitRows = entries.map(([flatNumber, amount]) => {
        const flat = activeFlats.find((f) => f.flat_number === flatNumber);
        return {
          expense_id: '',
          flat_number: flatNumber,
          amount: Number(Number(amount).toFixed(2)),
          is_settled: paidBySorted.includes(flatNumber),
          settled_at: paidBySorted.includes(flatNumber) ? new Date().toISOString() : null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
        };
      });
    }

    const { data: expense, error: insErr } = await supabase
      .from('expenses')
      .insert([
        {
          group_id: groupId,
          title: ef.title.trim(),
          total_amount: total,
          paid_by_flat: primaryPaidBy,
          paid_by_flats: paidBySorted,
          paid_by_name: adminName,
          split_type: splitType,
          payment_method: ef.payment_method,
          bill_screenshot_url: billUrl,
          service_kind: ef.service_kind,
          vendor_or_service: ef.vendor_or_service?.trim() || null,
          expense_date: billingDate,
          recording_date: recordingDate,
          notes: ef.notes?.trim() || null,
          record_status: 'active',
          expense_category: foodOnly ? 'food' : 'payment',
        },
      ])
      .select()
      .single();
    if (insErr || !expense) {
      toast.error(insErr?.message || 'Could not save expense');
      return;
    }

    splitRows = splitRows.map((r) => ({ ...r, expense_id: expense.id }));
    const { error: spErr } = await supabase.from('expense_splits').insert(splitRows);
    if (spErr) {
      toast.error(spErr.message);
      await supabase.from('expenses').delete().eq('id', expense.id);
      return;
    }

    const groupName = groups.find((x) => x.id === groupId)?.name ?? 'Expense group';
    const ledgerRes = await insertFinanceLedgerForGroupExpense(supabase, {
      societyId: societyId!,
      adminName,
      groupName,
      expenseId: expense.id,
      title: ef.title.trim(),
      total,
      expenseDate: ef.expense_date,
      payment_method: ef.payment_method,
      screenshot_url: billUrl,
      notes: ef.notes?.trim() || null,
      vendor_or_service: ef.vendor_or_service?.trim() || null,
      allocationSplits: splitRows.map((r) => ({ flat_number: r.flat_number, amount: r.amount })),
      flats,
      counterpartyName: `${ledgerCounterpartyPrefix(foodOnly, paymentOnly)}: ${groupName}`,
      counterpartyRelation: `Advanced by flat(s): ${paidBySorted.join(', ')}`,
      expenseCategory: ledgerExpenseCategory(),
      eventTitle: eventTitleForGroup(groupId),
    });
    if (ledgerRes.error) {
      toast.error(ledgerRes.error);
      await supabase.from('expense_splits').delete().eq('expense_id', expense.id);
      await supabase.from('expenses').delete().eq('id', expense.id);
      return;
    }

    const notifyAudience = expenseNotifyAudience;
    const allFlatNums = flats.map((f) => f.flat_number);
    const notifyFlats = [...new Set([...targets, ...paidBySorted])];
    const snapTitle = ef.title.trim();
    const snapVendor = ef.vendor_or_service?.trim() || '';
    const snapKind = ef.service_kind;
    const snapPm = ef.payment_method;
    const snapDate = ef.expense_date;
    const snapNotes = ef.notes?.trim() || '';
    const snapBill = billUrl;
    const snapTotal = total;
    const snapTargets = [...targets];
    const snapPaidBy = [...paidBySorted];

    resetExpenseForm();

    let suffix = '';
    if (notifyAudience !== 'none' && societyId) {
      const methodLabel = snapPm.replace(/_/g, ' ');
      const title = `Expense recorded: ${snapTitle}`;
      const lines = [
        `${adminName} added an expense in “${groupName}”.`,
        `“${snapTitle}” — total ₹${snapTotal.toLocaleString('en-IN')} (${methodLabel}, ${snapKind}).`,
        `Split across: ${snapTargets.join(', ')}.`,
        `Paid by (advanced): ${snapPaidBy.join(', ')}.`,
      ];
      if (snapVendor) lines.push(`Vendor / service: ${snapVendor}.`);
      if (snapDate) lines.push(`Expense date: ${snapDate}.`);
      if (snapNotes) lines.push(snapNotes);
      if (notifyAudience === 'all') {
        lines.push(`This update was shared with all ${allFlatNums.length} society flat(s).`);
      }
      if (snapBill) lines.push('Open the notification to view the attached receipt image (when available).');
      const message = lines.join(' ');
      const ok = await notifyResidentsOfRecord({
        societyId,
        adminName,
        audience: notifyAudience,
        selectedFlatNumbers: notifyFlats,
        title,
        message,
        notificationType: 'society_expense',
        billUrl: snapBill,
        saveSucceededHint:
          'Expense saved, but notifying residents failed. You can send a manual notice from Notifications.',
      });
      if (ok) suffix = ' · Residents notified';
    }

    const splitMsg =
      splitMode === 'custom'
        ? 'Expense added with custom split'
        : splitMode === 'by_headcount'
          ? 'Expense split by adults & kids per flat'
          : 'Expense added & split';
    toast.success(splitMsg + suffix);
    loadAll();
  };

  const settleUp = async (splitId: string) => {
    const ok = await confirmAction('Settle Up?', 'Mark this split as settled?', 'Yes, Settle', 'Cancel');
    if (!ok) return;
    await supabase.from('expense_splits').update({ is_settled: true, settled_at: new Date().toISOString() }).eq('id', splitId);
    showSuccess('Settled!', 'Payment marked as settled');
    loadAll();
  };

  const deleteExpense = async (expenseId: string) => {
    const ok = await confirmAction('Delete expense?', 'This removes the expense and its flat splits.', 'Delete', 'Cancel');
    if (!ok) return;
    await supabase.from('expenses').delete().eq('id', expenseId);
    setSelectedExpenseIds((prev) => {
      const next = new Set(prev);
      next.delete(expenseId);
      return next;
    });
    toast.success('Expense deleted');
    loadAll();
  };

  const deleteGroup = async (groupId: string) => {
    const count = expenses.filter((e) => e.group_id === groupId).length;
    if (count > 0) {
      toast.error('Remove all expenses in this group before deleting it.');
      return;
    }
    const ok = await confirmAction('Delete this group?', 'This cannot be undone.', 'Delete group', 'Cancel');
    if (!ok) return;
    await supabase.from('expense_groups').delete().eq('id', groupId).eq('society_id', societyId);
    if (editingGroup?.id === groupId) setEditingGroup(null);
    toast.success('Group deleted');
    loadAll();
  };

  const saveGroupEdit = async () => {
    if (!editingGroup || !societyId) return;
    const name = editingGroup.name.trim();
    if (!name) {
      toast.error('Group name is required');
      return;
    }
    const { error } = await supabase
      .from('expense_groups')
      .update({
        name,
        description: editingGroup.description.trim() || null,
        event_id: editingGroup.event_id || null,
        adult_weight: Number(editingGroup.adult_weight) || 1,
        child_weight: Number(editingGroup.child_weight) || 0.5,
      })
      .eq('id', editingGroup.id)
      .eq('society_id', societyId);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Group updated');
    setEditingGroup(null);
    loadAll();
  };

  const openExpenseEdit = (exp: any) => {
    const existingAttachments: string[] = Array.isArray(exp.attachment_urls) ? exp.attachment_urls : [];
    const legacyBill = exp.bill_screenshot_url && !existingAttachments.includes(exp.bill_screenshot_url)
      ? [exp.bill_screenshot_url]
      : [];
    setExpenseEdit({
      id: exp.id,
      title: exp.title ?? '',
      total_amount: String(exp.total_amount ?? ''),
      vendor_or_service: exp.vendor_or_service ?? '',
      service_kind: exp.service_kind ?? 'one_time',
      expense_date: (exp.expense_date || '').toString().slice(0, 10),
      recording_date: (exp.recording_date || exp.created_at || '').toString().slice(0, 10),
      payment_method: exp.payment_method ?? 'cash',
      notes: exp.notes ?? '',
      record_status: exp.record_status ?? 'active',
      attachment_urls: [...legacyBill, ...existingAttachments],
    });
    setEditAttachmentFiles([]);
  };

  const saveExpenseEdit = async () => {
    if (!expenseEdit) return;
    const old = expenses.find((e) => e.id === expenseEdit.id);
    if (!old) return;
    const newTotal = Number(expenseEdit.total_amount);
    if (!newTotal || newTotal <= 0) {
      toast.error('Enter a valid total amount');
      return;
    }

    // Upload new attachment files
    let allAttachmentUrls = [...expenseEdit.attachment_urls];
    if (editAttachmentFiles.length > 0) {
      setEditAttachmentUploading(true);
      for (const file of editAttachmentFiles) {
        if (file.size > 8 * 1024 * 1024) {
          toast.error(`File too large (max 8 MB): ${file.name}`);
          setEditAttachmentUploading(false);
          return;
        }
        const url = await uploadExpenseBill(old.group_id, file);
        if (!url) {
          setEditAttachmentUploading(false);
          return;
        }
        allAttachmentUrls.push(url);
      }
      setEditAttachmentUploading(false);
    }

    const oldTotal = Number(old.total_amount);
    const expSplits = splits.filter((s) => s.expense_id === old.id);

    if (old.split_type !== 'society_fund' && expSplits.length > 0 && Math.abs(newTotal - oldTotal) > 0.01) {
      const ratio = newTotal / oldTotal;
      for (const s of expSplits) {
        const { error: uErr } = await supabase
          .from('expense_splits')
          .update({ amount: Number((Number(s.amount) * ratio).toFixed(2)) })
          .eq('id', s.id);
        if (uErr) {
          toast.error(uErr.message);
          return;
        }
      }
    }

    const { error } = await supabase
      .from('expenses')
      .update({
        title: expenseEdit.title.trim(),
        total_amount: newTotal,
        vendor_or_service: expenseEdit.vendor_or_service.trim() || null,
        service_kind: expenseEdit.service_kind,
        expense_date: expenseEdit.expense_date,
        recording_date: expenseEdit.recording_date,
        payment_method: expenseEdit.payment_method,
        notes: expenseEdit.notes.trim() || null,
        record_status: expenseEdit.record_status,
        attachment_urls: allAttachmentUrls,
        bill_screenshot_url: allAttachmentUrls[0] || null,
      })
      .eq('id', expenseEdit.id);
    if (error) {
      toast.error(error.message);
      return;
    }

    const groupId = String(old.group_id || '');
    const groupName = groups.find((g) => g.id === groupId)?.name ?? 'Expense group';
    const editCategory: 'food' | 'payment' =
      String(old.expense_category) === 'food' || foodOnly ? 'food' : 'payment';
    const { data: splitFresh } = await supabase.from('expense_splits').select('flat_number, amount').eq('expense_id', expenseEdit.id);
    const allocationSplits =
      old.split_type === 'society_fund'
        ? [{ flat_number: 'SOCIETY', amount: newTotal }]
        : (splitFresh ?? []).map((s) => ({ flat_number: s.flat_number, amount: Number(s.amount) }));
    const paidBy = parsePaidByFlats(old);
    const counterpartyRelation =
      old.split_type === 'society_fund'
        ? 'Society fund (no per-flat split)'
        : paidBy.length
          ? `Advanced by flat(s): ${paidBy.join(', ')}`
          : 'Event / function expense';

    const syncRes = await syncFinanceLedgerFromGroupExpenseEdit(supabase, {
      adminName,
      groupName,
      expenseId: expenseEdit.id,
      title: expenseEdit.title.trim(),
      total: newTotal,
      expenseDate: expenseEdit.expense_date,
      payment_method: expenseEdit.payment_method,
      notes: expenseEdit.notes.trim() || null,
      vendor_or_service: expenseEdit.vendor_or_service.trim() || null,
      flats,
      allocationSplits,
      counterpartyName: `${ledgerCounterpartyPrefix(foodOnly, paymentOnly)}: ${groupName}`,
      counterpartyRelation,
      expenseCategory: editCategory,
      eventTitle: editCategory === 'food' ? eventTitleForGroup(groupId) : null,
    });
    if (syncRes.error) {
      toast.error(`Expense updated, but ledger sync failed: ${syncRes.error}`);
    }

    toast.success('Expense updated');
    setExpenseEdit(null);
    setEditAttachmentFiles([]);
    loadAll();
  };

  const updateExpenseRecordStatus = async (expenseId: string, record_status: string) => {
    const { error } = await supabase.from('expenses').update({ record_status }).eq('id', expenseId);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Status updated');
    loadAll();
  };

  const bulkDeleteSelectedExpenses = async () => {
    if (selectedExpenseIds.size === 0) return;
    const ok = await confirmAction(
      `Delete ${selectedExpenseIds.size} expenses?`,
      'This removes each expense and its flat splits.',
      'Delete all',
      'Cancel',
    );
    if (!ok) return;
    for (const id of selectedExpenseIds) {
      await supabase.from('expenses').delete().eq('id', id);
    }
    setSelectedExpenseIds(new Set());
    toast.success('Selected expenses deleted');
    loadAll();
  };

  const bulkSetExpenseRecordStatus = async (record_status: 'active' | 'archived') => {
    if (selectedExpenseIds.size === 0) return;
    const ok = await confirmAction(
      `Set ${selectedExpenseIds.size} expenses to ${record_status}?`,
      '',
      'Apply',
      'Cancel',
    );
    if (!ok) return;
    for (const id of selectedExpenseIds) {
      await supabase.from('expenses').update({ record_status }).eq('id', id);
    }
    setSelectedExpenseIds(new Set());
    toast.success('Status updated');
    loadAll();
  };

  const toggleExpenseSelect = (id: string, checked: boolean) => {
    setSelectedExpenseIds((prev) => {
      const next = new Set(prev);
      if (checked) next.add(id);
      else next.delete(id);
      return next;
    });
  };

  const selectAllExpenses = () => {
    setSelectedExpenseIds(new Set(expenses.map((e) => e.id)));
  };

  const balances: Record<string, number> = {};
  flats.forEach((f) => {
    balances[f.flat_number] = 0;
  });
  expenses.forEach((exp) => {
    if ((exp as { record_status?: string }).record_status === 'archived') return;
    if (exp.split_type === 'society_fund') return;
    const creditors = parsePaidByFlats(exp);
    if (creditors.length === 0) return;
    const expSplits = splits.filter((s) => s.expense_id === exp.id);
    expSplits.forEach((s) => {
      if (!s.is_settled && !creditors.includes(s.flat_number)) {
        balances[s.flat_number] = (balances[s.flat_number] || 0) - s.amount;
        const share = s.amount / creditors.length;
        creditors.forEach((c) => {
          balances[c] = (balances[c] || 0) + share;
        });
      }
    });
  });

  const flatOptions = flatOptionsWithPrimaryLabel(flats, primaryByFlatId);

  const filteredPaymentGroups = useMemo(() => {
    if (!paymentOnly) return groups;
    return groups.filter((g) => groupMatchesPaymentHeadSearch(g, headSearchQuery));
  }, [groups, headSearchQuery, paymentOnly]);

  const paymentGroupsGrouped = useMemo(
    () => paymentGroupsByMajorHead(filteredPaymentGroups),
    [filteredPaymentGroups],
  );

  const subHeadsUnderSelectedMajor = useMemo(() => {
    if (!gf.major_head) return [];
    return paymentGroupsGrouped.get(gf.major_head as SocietyPaymentMajorHead) ?? [];
  }, [paymentGroupsGrouped, gf.major_head]);

  type GroupListItem =
    | { kind: 'major'; major: SocietyPaymentMajorHead }
    | { kind: 'group'; group: ExpenseGroupRow };

  const groupListItems = useMemo((): GroupListItem[] => {
    if (!paymentOnly) return groups.map((group) => ({ kind: 'group' as const, group }));
    const items: GroupListItem[] = [];
    for (const major of SOCIETY_PAYMENT_MAJOR_HEADS) {
      const sectionGroups = paymentGroupsGrouped.get(major) ?? [];
      if (sectionGroups.length === 0) continue;
      items.push({ kind: 'major', major });
      for (const group of sectionGroups) items.push({ kind: 'group', group });
    }
    return items;
  }, [groups, paymentOnly, paymentGroupsGrouped]);

  if (!societyId) {
    return (
      <div className={embedded ? '' : 'page-container pb-24'}>
        <p className="text-sm text-muted-foreground text-center py-12">Select a society to use expense splitting.</p>
      </div>
    );
  }

  return (
    <div className={embedded ? '' : 'page-container pb-24'}>
      {!(paymentOnly && embedded) && <RecordingDateBanner className={embedded ? 'mb-3' : 'mb-4'} />}

      {!embedded && (
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-orange-500/10 flex items-center justify-center">
            <Split className="w-5 h-5 text-orange-500" />
          </div>
          <div>
            <h1 className="page-title">
              {foodOnly
                ? 'Food expenses (events)'
                : paymentOnly
                  ? 'Record payment'
                  : 'Event & function expenses'}
            </h1>
            <p className="text-xs text-muted-foreground">
              {foodOnly
                ? 'Catering and meal costs split by adults & kids per flat'
                : paymentOnly
                  ? 'Society outflows — utilities, vendors, repairs — split across flats or society fund'
                  : 'Split celebration / function costs by family — adults & kids per flat (not monthly maintenance)'}
            </p>
          </div>
        </div>
      )}

      {foodOnly && onOpenFinance && (
        <p className="text-[10px] text-muted-foreground mb-3 leading-snug">
          Non-food payments (electricity, vendors, repairs) →{' '}
          <button type="button" className="text-primary underline" onClick={onOpenFinance}>
            Finance → Record Payment
          </button>
        </p>
      )}

      <div className="flex items-stretch gap-2 mb-4">
        <DescriptiveStatCard
          {...EVENT_EXPENSE_METRICS.eligibleFlatsPool}
          className="flex-1 !p-3"
          value={includeVacantFlats ? flats.length : activeFlats.length}
          caption={includeVacantFlats ? `All flats (${flats.length})` : `Occupied / sold (${activeFlats.length})`}
        />
        <button
          type="button"
          onClick={() => setIncludeVacantFlats((v) => !v)}
          className="text-xs px-2.5 py-1.5 rounded-lg border border-border self-center shrink-0"
        >
          {includeVacantFlats ? 'Include vacant: ON' : 'Include vacant: OFF'}
        </button>
      </div>

      <DescriptiveStatCard
        {...EVENT_EXPENSE_METRICS.balances}
        className="mb-4"
        value={
          Object.values(balances).every((v) => v === 0) ? (
            <span className="text-sm font-medium text-muted-foreground">All settled</span>
          ) : (
            <span className="text-sm font-medium">{Object.values(balances).filter((v) => v !== 0).length} flats with balance</span>
          )
        }
      >
        <div className="space-y-1 mt-2 w-full">
          {Object.entries(balances)
            .filter(([_, v]) => v !== 0)
            .map(([flat, amount]) => (
              <div key={flat} className="flex justify-between text-sm">
                <span>Flat {flat}</span>
                <span className={amount > 0 ? 'text-green-600 font-bold' : 'text-destructive font-bold'}>
                  {amount > 0 ? `+₹${amount.toFixed(2)}` : `-₹${Math.abs(amount).toFixed(2)}`}
                </span>
              </div>
            ))}
          {Object.values(balances).every((v) => v === 0) && <p className="text-xs text-muted-foreground">All settled! 🎉</p>}
        </div>
      </DescriptiveStatCard>

      {paymentOnly && (
        <div className="relative mb-4">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
          <input
            className="input-field pl-9"
            type="search"
            placeholder="Search expense heads (e.g. Electricity, Security, Fixed assets)…"
            value={headSearchQuery}
            onChange={(e) => setHeadSearchQuery(e.target.value)}
          />
        </div>
      )}

      <button
        type="button"
        onClick={() => setShowGroupForm(!showGroupForm)}
        className="btn-primary w-full mb-4 flex items-center justify-center gap-2"
      >
        <Plus className="w-4 h-4" />{' '}
        {foodOnly ? 'New food expense group' : paymentOnly ? 'New expense head' : 'New event / function group'}
      </button>

      {showGroupForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          {paymentOnly ? (
            <>
              <label className="text-[10px] font-medium text-muted-foreground uppercase">Major head</label>
              <select
                className="input-field"
                value={gf.major_head}
                onChange={(e) => setGf({ ...gf, major_head: e.target.value as SocietyPaymentMajorHead | '' })}
              >
                <option value="">Choose major head…</option>
                {SOCIETY_PAYMENT_MAJOR_HEADS.map((h) => (
                  <option key={h} value={h}>
                    {h}
                  </option>
                ))}
              </select>
              {gf.major_head && subHeadsUnderSelectedMajor.length > 0 && (
                <div className="rounded-lg border border-border bg-muted/20 p-2.5 space-y-1.5">
                  <p className="text-[10px] font-medium text-muted-foreground uppercase">Existing sub-heads</p>
                  <div className="flex flex-wrap gap-1.5">
                    {subHeadsUnderSelectedMajor.map((g) => (
                      <button
                        key={g.id}
                        type="button"
                        className="text-[10px] px-2 py-1 rounded-md border border-border bg-background hover:border-primary/40"
                        onClick={() => {
                          setShowGroupForm(false);
                          setShowExpenseForm(g.id);
                        }}
                      >
                        {g.name}
                      </button>
                    ))}
                  </div>
                  <p className="text-[10px] text-muted-foreground leading-snug">
                    Tap a sub-head to record a payment, or add a new one below.
                  </p>
                </div>
              )}
              <label className="text-[10px] font-medium text-muted-foreground uppercase">New sub-head name</label>
              <input
                className="input-field"
                placeholder="e.g. Electricity bill, Lift AMC, Security guards"
                value={gf.name}
                onChange={(e) => setGf({ ...gf, name: e.target.value })}
              />
              <p className="text-[10px] text-muted-foreground leading-snug">
                Sub-heads appear under the major head in period reports. Use specific names — not generic
                &quot;Events &amp; Functions&quot;.
              </p>
            </>
          ) : (
            <input
              className="input-field"
              placeholder={
                foodOnly
                  ? 'Group name (e.g. Annual day lunch, Diwali dinner)'
                  : 'Group name (e.g. Diwali 2026, Annual day lunch)'
              }
              value={gf.name}
              onChange={(e) => setGf({ ...gf, name: e.target.value })}
            />
          )}
          {(foodOnly || (!paymentOnly && !foodOnly)) && (
            <select
              className="input-field"
              value={gf.event_id}
              onChange={(e) => setGf({ ...gf, event_id: e.target.value })}
            >
              <option value="">{foodOnly ? 'Select calendar event (required)' : 'Link to calendar event (optional)'}</option>
              {events.map((ev) => (
                <option key={ev.id} value={ev.id}>
                  {ev.title} ({ev.event_date})
                </option>
              ))}
            </select>
          )}
          <textarea
            className="input-field"
            placeholder="Description (optional)"
            value={gf.description}
            onChange={(e) => setGf({ ...gf, description: e.target.value })}
          />
          {(foodOnly || (!paymentOnly && !foodOnly)) && (
            <>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground uppercase">Adult weight</label>
                  <input
                    className="input-field"
                    type="number"
                    step="0.1"
                    min="0.1"
                    value={gf.adult_weight}
                    onChange={(e) => setGf({ ...gf, adult_weight: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground uppercase">Child weight</label>
                  <input
                    className="input-field"
                    type="number"
                    step="0.1"
                    min="0"
                    value={gf.child_weight}
                    onChange={(e) => setGf({ ...gf, child_weight: e.target.value })}
                  />
                </div>
              </div>
              <p className="text-[10px] text-muted-foreground leading-snug">
                Default split uses each flat&apos;s members from Residents (age &amp; relation). Child = under 18 or
                son/daughter. Weights apply per person (e.g. adult 1, child 0.5).
              </p>
            </>
          )}
          {paymentOnly && (
            <p className="text-[10px] text-muted-foreground leading-snug">
              Split equally across flats by default, or pick flats and custom amounts per payment.
            </p>
          )}
          <button type="button" onClick={addGroup} className="btn-primary">
            Create group
          </button>
        </div>
      )}

      {expenses.length > 0 && (
        <div className="card-section p-2 mb-3 flex flex-wrap gap-2 items-center">
          <button type="button" className="btn-secondary text-[10px] py-1.5 px-2" onClick={selectAllExpenses}>
            Select all expenses
          </button>
          <button
            type="button"
            className="btn-secondary text-[10px] py-1.5 px-2"
            onClick={() => setSelectedExpenseIds(new Set())}
          >
            Clear selection
          </button>
          {selectedExpenseIds.size > 0 && (
            <>
              <span className="text-[10px] text-muted-foreground">{selectedExpenseIds.size} selected</span>
              <button
                type="button"
                className="btn-secondary text-[10px] py-1.5 px-2 border border-destructive text-destructive"
                onClick={() => void bulkDeleteSelectedExpenses()}
              >
                Delete selected
              </button>
              <select
                className="input-field text-[10px] py-1.5 max-w-[210px]"
                defaultValue=""
                onChange={(e) => {
                  const v = e.target.value as '' | 'active' | 'archived';
                  if (!v) return;
                  void bulkSetExpenseRecordStatus(v);
                  e.target.value = '';
                }}
              >
                <option value="">Bulk record status…</option>
                <option value="active">Set active</option>
                <option value="archived">Set archived</option>
              </select>
            </>
          )}
        </div>
      )}

      {paymentOnly && headSearchQuery.trim() && filteredPaymentGroups.length === 0 && (
        <p className="text-sm text-muted-foreground text-center py-6 mb-3">
          No expense heads match &quot;{headSearchQuery.trim()}&quot;.
        </p>
      )}

      {groupListItems.map((item) => {
        if (item.kind === 'major') {
          return (
            <h3
              key={`major-${item.major}`}
              className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground mb-2 mt-1 border-b border-border/60 pb-1"
            >
              {item.major}
            </h3>
          );
        }
        const g = item.group;
        const gExpenses = expenses.filter((e) => e.group_id === g.id);
        return (
          <div key={g.id} className="card-section p-4 mb-3">
            <div className="flex justify-between items-start gap-2 mb-1">
              <div className="min-w-0 flex-1">
                <p className="font-semibold">{g.name}</p>
                {g.event_id && (
                  <p className="text-[10px] text-primary mt-0.5">
                    Linked event: {events.find((ev) => ev.id === g.event_id)?.title ?? 'Calendar event'}
                  </p>
                )}
                {!paymentOnly && (
                  <p className="text-[10px] text-muted-foreground">
                    Split weights: adult ×{g.adult_weight ?? 1}, child ×{g.child_weight ?? 0.5}
                  </p>
                )}
                {g.description && <p className="text-xs text-muted-foreground mt-0.5">{g.description}</p>}
              </div>
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  className="p-1.5 text-muted-foreground hover:text-primary"
                  title="Edit group"
                  onClick={() =>
                    setEditingGroup({
                      id: g.id,
                      name: g.name,
                      description: g.description || '',
                      event_id: g.event_id ?? '',
                      adult_weight: String(g.adult_weight ?? 1),
                      child_weight: String(g.child_weight ?? 0.5),
                    })
                  }
                >
                  <Pencil className="w-4 h-4" />
                </button>
                {gExpenses.length === 0 ? (
                  <button
                    type="button"
                    className="p-1.5 text-muted-foreground hover:text-destructive"
                    title="Delete group"
                    onClick={() => void deleteGroup(g.id)}
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                ) : (
                  <span
                    className="text-[9px] text-muted-foreground max-w-[52px] text-right leading-tight"
                    title="Delete expenses in this group before removing it"
                  >
                    In use
                  </span>
                )}
              </div>
            </div>

            <button
              type="button"
              onClick={() => {
                if (showExpenseForm === g.id) resetExpenseForm();
                else setShowExpenseForm(g.id);
              }}
              className="text-xs text-primary underline mb-2 flex items-center gap-1"
            >
              <Plus className="w-3 h-3" /> Add expense
            </button>

            {showExpenseForm === g.id && (
              <div className="flex flex-col gap-2 mb-3 pt-2 border-t border-border">
                <input
                  className="input-field text-sm"
                  placeholder={
                    foodOnly
                      ? 'Food item (e.g. Lunch catering, Snacks)'
                      : paymentOnly
                        ? 'Payment title (e.g. Electricity bill, Plumber)'
                        : 'Expense title (e.g. Common area electricity)'
                  }
                  value={ef.title}
                  onChange={(e) => setEf({ ...ef, title: e.target.value })}
                />
                <input
                  className="input-field text-sm"
                  placeholder={
                    foodOnly ? 'Caterer / vendor (optional)' : paymentOnly ? 'Payee / vendor (optional)' : 'Vendor / service (optional)'
                  }
                  value={ef.vendor_or_service}
                  onChange={(e) => setEf({ ...ef, vendor_or_service: e.target.value })}
                />
                <div className={foodOnly || paymentOnly ? '' : 'grid grid-cols-2 gap-2'}>
                  {!foodOnly && !paymentOnly && (
                    <select
                      className="input-field text-sm"
                      value={ef.service_kind}
                      onChange={(e) => setEf({ ...ef, service_kind: e.target.value as typeof ef.service_kind })}
                    >
                      <option value="one_time">One-time</option>
                      <option value="recurring">Recurring (monthly)</option>
                      <option value="temporary">Temporary / ad-hoc</option>
                    </select>
                  )}
                  <div>
                    <label className="text-[10px] font-medium text-muted-foreground uppercase">Billing / transaction date</label>
                    <DateInput
                      className="input-field text-sm"
                      value={ef.expense_date}
                      onChange={(e) => setEf({ ...ef, expense_date: e.target.value })}
                    />
                    <p className="text-[10px] text-muted-foreground mt-1">
                      Used in reports · month: {fmtIsoMonthToDisplay(billingMonthFromDate(ef.expense_date))}
                    </p>
                  </div>
                </div>
                <input
                  className="input-field text-sm"
                  placeholder="Total amount (₹)"
                  type="number"
                  value={ef.total_amount}
                  onChange={(e) => setEf({ ...ef, total_amount: e.target.value })}
                />
                <select
                  className="input-field text-sm"
                  value={ef.payment_method}
                  onChange={(e) => setEf({ ...ef, payment_method: e.target.value })}
                >
                  <option value="cash">Cash</option>
                  <option value="upi">UPI</option>
                  <option value="bank_transfer">Bank transfer</option>
                  <option value="cheque">Cheque</option>
                  <option value="other">Other</option>
                </select>
                <textarea
                  className="input-field text-sm min-h-[4rem]"
                  placeholder="Internal notes (optional)"
                  value={ef.notes}
                  onChange={(e) => setEf({ ...ef, notes: e.target.value })}
                />
                <label className="text-[10px] font-medium text-muted-foreground uppercase">Bill / receipt (optional)</label>
                <input id={`expense-bill-${g.id}`} type="file" accept="image/*,application/pdf,audio/*" className="text-xs" />

                <div className="rounded-lg border border-border bg-muted/20 p-2 space-y-2">
                  <p className="text-xs font-medium">Who pays?</p>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name={`fund-${g.id}`}
                      checked={fundingSource === 'residents'}
                      onChange={() => {
                        setFundingSource('residents');
                        setExpenseNotifyAudience('none');
                      }}
                    />
                    Split across flats (committee paid upfront, flats owe share)
                  </label>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name={`fund-${g.id}`}
                      checked={fundingSource === 'society_fund'}
                      onChange={() => {
                        setFundingSource('society_fund');
                        setExpenseNotifyAudience('none');
                      }}
                    />
                    Society / corpus only (no split — e.g. absorbed from maintenance pool)
                  </label>
                </div>

                {fundingSource === 'residents' && (
                  <>
                    <FlatMultiSelect
                      flats={flatOptions}
                      selected={paidByFlats}
                      onChange={setPaidByFlats}
                      label="Paid by (flats — who advanced)"
                      compact
                    />
                    <FlatMultiSelect
                      flats={flatOptions}
                      selected={splitFlats}
                      onChange={(nums) => {
                        setSplitFlats(nums);
                        setCustomSplits((prev) => {
                          const next: Record<string, string> = {};
                          for (const n of nums) {
                            if (prev[n] !== undefined) next[n] = prev[n];
                          }
                          return next;
                        });
                      }}
                      label="Split among (leave empty = all eligible flats)"
                      compact
                      emptyHint="Pick flats to limit who shares this bill."
                    />
                    <select
                      className="input-field text-sm"
                      value={splitMode}
                      onChange={(e) => {
                        const mode = e.target.value as SplitMode;
                        setSplitMode(mode);
                        if (mode !== 'custom') setCustomSplits({});
                      }}
                    >
                      <option value="by_headcount">
                        By family headcount (adults + kids per flat) — recommended for functions
                      </option>
                      <option value="even">Equal ₹ per flat (ignore family size)</option>
                      <option value="custom">Custom amount per flat (only “split among” flats)</option>
                    </select>
                    {splitMode === 'by_headcount' ? (
                      <div className="rounded-lg border border-border p-2.5 space-y-1.5 max-h-52 overflow-y-auto">
                        <p className="text-[10px] text-muted-foreground">
                          Uses member list per flat (Residents). Missing members → 1 adult assumed.
                        </p>
                        {(() => {
                          const { rows, amounts, adult, child } = headcountPreviewForGroup(g.id);
                          if (rows.length === 0) {
                            return <p className="text-xs text-muted-foreground">Select flats or leave empty for all.</p>;
                          }
                          return rows.map((row) => {
                            const amt = amounts.find((a) => a.flat_number === row.flat_number);
                            return (
                              <div key={row.flat_number} className="flex justify-between text-xs gap-2">
                                <span>
                                  Flat {row.flat_number}: {row.adults} adult{row.adults !== 1 ? 's' : ''},{' '}
                                  {row.kids} kid{row.kids !== 1 ? 's' : ''} (×{adult}/×{child})
                                </span>
                                <span className="font-mono shrink-0">{amt ? `₹${amt.amount}` : '—'}</span>
                              </div>
                            );
                          });
                        })()}
                      </div>
                    ) : splitMode === 'even' ? (
                      <p className="text-[11px] text-muted-foreground">
                        Each selected flat pays ₹
                        {(() => {
                          const t = targetFlatNumbers();
                          const tot = Number(ef.total_amount) || 0;
                          return t.length && tot ? (tot / t.length).toFixed(2) : '…'}
                        )}{' '}
                        (÷ {targetFlatNumbers().length || activeFlats.length} flats)
                      </p>
                    ) : (
                      <div className="rounded-lg border border-border p-2.5 space-y-2">
                        <p className="text-[10px] text-muted-foreground">Amounts must sum to total. Flats listed come from “Split among”.</p>
                        <div className="max-h-48 overflow-y-auto space-y-1.5">
                          {(splitFlats.length ? splitFlats : activeFlats.map((f) => f.flat_number)).map((num) => (
                            <div key={num} className="flex items-center gap-2">
                              <span className="text-xs w-16">Flat {num}</span>
                              <input
                                className="input-field text-xs flex-1"
                                placeholder="₹"
                                type="number"
                                value={customSplits[num] ?? ''}
                                onChange={(e) => setCustomFlatAmount(num, e.target.value)}
                              />
                            </div>
                          ))}
                        </div>
                        <p className="text-[10px] text-muted-foreground">
                          Sum: ₹{Object.entries(customSplits).reduce((sum, [, v]) => sum + (Number(v) || 0), 0).toFixed(2)}
                        </p>
                      </div>
                    )}
                  </>
                )}

                <div className="rounded-lg border border-border p-3 space-y-2 bg-muted/30">
                  <p className="text-xs font-medium text-foreground">Notify residents</p>
                  <p className="text-[10px] text-muted-foreground leading-snug">
                    Optional: send an in-app notice (and push, if configured) when this expense or receipt is saved.
                  </p>
                  <label className="flex items-start gap-2 text-xs cursor-pointer">
                    <input
                      type="radio"
                      name={`exp-notify-${g.id}`}
                      className="mt-0.5"
                      checked={expenseNotifyAudience === 'none'}
                      onChange={() => setExpenseNotifyAudience('none')}
                    />
                    <span>Do not notify</span>
                  </label>
                  {fundingSource === 'residents' && (
                    <label className="flex items-start gap-2 text-xs cursor-pointer">
                      <input
                        type="radio"
                        name={`exp-notify-${g.id}`}
                        className="mt-0.5"
                        checked={expenseNotifyAudience === 'selected_flats'}
                        onChange={() => setExpenseNotifyAudience('selected_flats')}
                      />
                      <span>
                        Flats in this expense ({new Set([...targetFlatNumbers(), ...paidByFlats]).size}) — split
                        participants and who advanced payment
                      </span>
                    </label>
                  )}
                  <label className="flex items-start gap-2 text-xs cursor-pointer">
                    <input
                      type="radio"
                      name={`exp-notify-${g.id}`}
                      className="mt-0.5"
                      checked={expenseNotifyAudience === 'all'}
                      onChange={() => setExpenseNotifyAudience('all')}
                    />
                    <span>All society flats ({flats.length}) — e.g. common-area or guard bills</span>
                  </label>
                </div>

                <button
                  type="button"
                  onClick={() => void addExpense(g.id)}
                  className="btn-primary text-sm"
                  disabled={billUploading}
                >
                  {billUploading
                    ? 'Uploading…'
                    : fundingSource === 'society_fund'
                      ? 'Record society expense'
                      : splitMode === 'custom'
                        ? 'Add with custom split'
                        : splitMode === 'by_headcount'
                          ? 'Add & split by adults/kids'
                          : 'Add & split equally per flat'}
                </button>
              </div>
            )}

            {gExpenses.map((exp) => {
              const expSplits = splits.filter((s) => s.expense_id === exp.id);
              const creditors = parsePaidByFlats(exp);
              const recStatus = (exp as { record_status?: string }).record_status ?? 'active';
              return (
                <div
                  key={exp.id}
                  className={`bg-muted/30 rounded-lg p-3 mb-2 relative ${
                    recStatus === 'archived' ? 'opacity-80 border border-dashed border-border' : ''
                  }`}
                >
                  <div className="flex gap-2 items-start mb-1">
                    <input
                      type="checkbox"
                      className="mt-1 shrink-0"
                      checked={selectedExpenseIds.has(exp.id)}
                      onChange={(e) => toggleExpenseSelect(exp.id, e.target.checked)}
                      aria-label={`Select ${exp.title}`}
                    />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <span className="text-sm font-medium block truncate">{exp.title}</span>
                          {exp.vendor_or_service && (
                            <span className="text-[10px] text-muted-foreground block truncate">{exp.vendor_or_service}</span>
                          )}
                          <span className="text-[10px] text-muted-foreground capitalize">
                            {exp.service_kind || 'one_time'} · {exp.payment_method || 'cash'} ·{' '}
                            Bill: {exp.expense_date ? fmtIsoDateToDisplay(String(exp.expense_date)) : ''}
                            {exp.recording_date && exp.recording_date !== exp.expense_date
                              ? ` · Rec: ${fmtIsoDateToDisplay(String(exp.recording_date))}`
                              : ''}
                          </span>
                        </div>
                        <span className="font-bold text-sm shrink-0">₹{exp.total_amount}</span>
                      </div>
                      {recStatus === 'archived' && (
                        <span className="text-[9px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground inline-block mt-1">
                          Archived
                        </span>
                      )}
                    </div>
                  </div>
                  {exp.split_type === 'society_fund' ? (
                    <p className="text-[10px] text-muted-foreground mb-2">Paid from society / corpus — no flat split</p>
                  ) : (
                    <p className="text-[10px] text-muted-foreground mb-2">
                      Paid by: {creditors.map((c) => `Flat ${c}`).join(', ')}
                    </p>
                  )}
                  {exp.bill_screenshot_url && (
                    <a
                      href={exp.bill_screenshot_url}
                      target="_blank"
                      rel="noreferrer"
                      className="text-[10px] text-primary underline block mb-2"
                    >
                      View bill / receipt
                    </a>
                  )}
                  {Array.isArray((exp as any).attachment_urls) && (exp as any).attachment_urls.length > 0 && (
                    <div className="flex flex-wrap gap-1.5 mb-2">
                      {((exp as any).attachment_urls as string[]).map((url, idx) => {
                        const fileName = decodeURIComponent(url.split('/').pop() || 'Attachment').replace(/^[a-f0-9-]+_/, '');
                        return (
                          <a
                            key={idx}
                            href={url}
                            target="_blank"
                            rel="noreferrer"
                            className="text-[10px] text-primary underline inline-flex items-center gap-0.5"
                          >
                            <Paperclip className="w-2.5 h-2.5" />{fileName}
                          </a>
                        );
                      })}
                    </div>
                  )}
                  {exp.notes && <p className="text-[10px] text-muted-foreground mb-2 italic">{exp.notes}</p>}
                  <div className="space-y-1 mb-2">
                    {expSplits.map((s) => (
                      <div key={s.id} className="flex justify-between items-center text-xs">
                        <span>
                          Flat {s.flat_number}
                          {s.resident_name ? <span className="text-muted-foreground"> · {s.resident_name}</span> : null}
                        </span>
                        <div className="flex items-center gap-2">
                          <span>₹{s.amount}</span>
                          {s.is_settled ? (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-green-500/20 text-green-600">✓</span>
                          ) : (
                            <button
                              type="button"
                              onClick={() => void settleUp(s.id)}
                              className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary"
                            >
                              Settle
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                  <div className="flex flex-wrap gap-2 pt-2 border-t border-border/60 items-center">
                    <button
                      type="button"
                      className="btn-secondary text-[10px] py-1 px-2 inline-flex items-center gap-1"
                      onClick={() => openExpenseEdit(exp)}
                    >
                      <Pencil className="w-3 h-3" /> Edit
                    </button>
                    <select
                      className="input-field text-[10px] py-1 max-w-[130px]"
                      value={recStatus}
                      onChange={(e) => void updateExpenseRecordStatus(exp.id, e.target.value)}
                    >
                      <option value="active">Active</option>
                      <option value="archived">Archived</option>
                    </select>
                    <button
                      type="button"
                      className="text-[10px] py-1 px-2 rounded-lg border border-destructive text-destructive inline-flex items-center gap-1"
                      onClick={() => void deleteExpense(exp.id)}
                    >
                      <Trash2 className="w-3 h-3" /> Delete
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        );
      })}

      {editingGroup && (
        <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
          <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3 max-h-[90vh] overflow-auto">
            <p className="text-sm font-semibold">Edit expense group</p>
            <input
              className="input-field"
              value={editingGroup.name}
              onChange={(e) => setEditingGroup({ ...editingGroup, name: e.target.value })}
              placeholder="Group name"
            />
            <textarea
              className="input-field"
              value={editingGroup.description}
              onChange={(e) => setEditingGroup({ ...editingGroup, description: e.target.value })}
              placeholder="Description (optional)"
            />
            <select
              className="input-field"
              value={editingGroup.event_id}
              onChange={(e) => setEditingGroup({ ...editingGroup, event_id: e.target.value })}
            >
              <option value="">No linked event</option>
              {events.map((ev) => (
                <option key={ev.id} value={ev.id}>
                  {ev.title} ({ev.event_date})
                </option>
              ))}
            </select>
            <div className="grid grid-cols-2 gap-2">
              <input
                className="input-field"
                type="number"
                step="0.1"
                value={editingGroup.adult_weight}
                onChange={(e) => setEditingGroup({ ...editingGroup, adult_weight: e.target.value })}
                placeholder="Adult weight"
              />
              <input
                className="input-field"
                type="number"
                step="0.1"
                value={editingGroup.child_weight}
                onChange={(e) => setEditingGroup({ ...editingGroup, child_weight: e.target.value })}
                placeholder="Child weight"
              />
            </div>
            <div className="flex gap-2">
              <button type="button" className="btn-primary flex-1" onClick={() => void saveGroupEdit()}>
                Save
              </button>
              <button type="button" className="btn-secondary flex-1" onClick={() => setEditingGroup(null)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {expenseEdit && (
        <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
          <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3 max-h-[90vh] overflow-auto">
            <p className="text-sm font-semibold">Edit expense</p>
            <p className="text-[10px] text-muted-foreground">
              Changing the total on a split expense rescales each flat’s share proportionally. Edit split lines via Settle
              on each flat when needed.
            </p>
            <input
              className="input-field"
              value={expenseEdit.title}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, title: e.target.value })}
              placeholder="Title"
            />
            <input
              className="input-field"
              type="number"
              value={expenseEdit.total_amount}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, total_amount: e.target.value })}
              placeholder="Total (₹)"
            />
            <input
              className="input-field"
              value={expenseEdit.vendor_or_service}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, vendor_or_service: e.target.value })}
              placeholder="Vendor / service"
            />
            <div className="grid grid-cols-2 gap-2">
              <select
                className="input-field"
                value={expenseEdit.service_kind}
                onChange={(e) => setExpenseEdit({ ...expenseEdit, service_kind: e.target.value })}
              >
                <option value="one_time">One-time</option>
                <option value="recurring">Recurring</option>
                <option value="temporary">Temporary</option>
              </select>
              <div>
                <label className="text-[10px] font-medium text-muted-foreground uppercase">Billing / transaction date</label>
                <DateInput
                  className="input-field"
                  value={expenseEdit.expense_date}
                  onChange={(e) => setExpenseEdit({ ...expenseEdit, expense_date: e.target.value })}
                />
              </div>
            </div>
            <p className="text-[10px] text-muted-foreground">
              Recorded on: {expenseEdit.recording_date ? fmtIsoDateToDisplay(expenseEdit.recording_date) : '—'}
            </p>
            <select
              className="input-field"
              value={expenseEdit.payment_method}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, payment_method: e.target.value })}
            >
              <option value="cash">Cash</option>
              <option value="upi">UPI</option>
              <option value="bank_transfer">Bank transfer</option>
              <option value="cheque">Cheque</option>
              <option value="other">Other</option>
            </select>
            <textarea
              className="input-field min-h-[4rem]"
              value={expenseEdit.notes}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, notes: e.target.value })}
              placeholder="Notes"
            />

            {/* Attachments section */}
            <div className="space-y-2">
              <label className="text-[10px] font-medium text-muted-foreground uppercase flex items-center gap-1">
                <Paperclip className="w-3 h-3" /> Attachments (images, PDFs, documents)
              </label>
              {expenseEdit.attachment_urls.length > 0 && (
                <div className="space-y-1">
                  {expenseEdit.attachment_urls.map((url, idx) => {
                    const fileName = decodeURIComponent(url.split('/').pop() || 'Attachment').replace(/^[a-f0-9-]+_/, '');
                    return (
                      <div key={idx} className="flex items-center gap-2 bg-muted/30 rounded px-2 py-1">
                        <a
                          href={url}
                          target="_blank"
                          rel="noreferrer"
                          className="text-[11px] text-primary underline truncate flex-1 min-w-0"
                        >
                          {fileName}
                        </a>
                        <button
                          type="button"
                          className="text-destructive hover:text-destructive/80 shrink-0"
                          onClick={() =>
                            setExpenseEdit({
                              ...expenseEdit,
                              attachment_urls: expenseEdit.attachment_urls.filter((_, i) => i !== idx),
                            })
                          }
                          aria-label={`Remove ${fileName}`}
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}
              {editAttachmentFiles.length > 0 && (
                <div className="space-y-1">
                  <p className="text-[10px] text-muted-foreground">New files to upload:</p>
                  {editAttachmentFiles.map((file, idx) => (
                    <div key={idx} className="flex items-center gap-2 bg-muted/30 rounded px-2 py-1">
                      <span className="text-[11px] truncate flex-1 min-w-0">{file.name}</span>
                      <span className="text-[10px] text-muted-foreground shrink-0">
                        {(file.size / 1024).toFixed(0)} KB
                      </span>
                      <button
                        type="button"
                        className="text-destructive hover:text-destructive/80 shrink-0"
                        onClick={() => setEditAttachmentFiles((prev) => prev.filter((_, i) => i !== idx))}
                        aria-label={`Remove ${file.name}`}
                      >
                        <X className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
              <input
                id="edit-expense-attachments"
                type="file"
                accept="image/*,application/pdf,.doc,.docx,.xls,.xlsx,.csv,audio/*"
                multiple
                className="text-xs"
                onChange={(e) => {
                  const files = Array.from(e.target.files || []);
                  if (files.length) {
                    setEditAttachmentFiles((prev) => [...prev, ...files]);
                    e.target.value = '';
                  }
                }}
              />
              <p className="text-[10px] text-muted-foreground">Max 8 MB per file. Images, PDFs, documents, audio accepted.</p>
            </div>

            <select
              className="input-field"
              value={expenseEdit.record_status}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, record_status: e.target.value })}
            >
              <option value="active">Active</option>
              <option value="archived">Archived</option>
            </select>
            <div className="flex gap-2">
              <button
                type="button"
                className="btn-primary flex-1"
                onClick={() => void saveExpenseEdit()}
                disabled={editAttachmentUploading}
              >
                {editAttachmentUploading ? 'Uploading…' : 'Save changes'}
              </button>
              <button type="button" className="btn-secondary flex-1" onClick={() => { setExpenseEdit(null); setEditAttachmentFiles([]); }}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ExpenseSplitter;
