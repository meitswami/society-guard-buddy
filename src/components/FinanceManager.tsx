import { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { DollarSign, Plus, Check, X, Upload, AlertTriangle, Pencil, Trash2, Wallet } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { format } from 'date-fns';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { flatOptionsWithPrimaryLabel, residentLabelForFlatRow } from '@/lib/flatMultiSelectOptions';
import { notifyResidentsOfRecord, type AdminRecordNotifyAudience } from '@/lib/adminRecordNotifications';

interface Props {
  adminName?: string;
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
  const raw = payment?.due_date || payment?.payment_date || payment?.created_at;
  if (!raw) return '';
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return '';
  return format(date, 'yyyy-MM');
};

const paymentMonthLabel = (payment: any) => {
  const raw = payment?.due_date || payment?.payment_date || payment?.created_at;
  if (!raw) return 'Unknown month';
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return 'Unknown month';
  return format(date, 'MMMM yyyy');
};

type FinanceLedgerRow = {
  id: string;
  society_id: string;
  record_mode: string;
  destination: string;
  allocation_style: string;
  include_vacant: boolean;
  entry_month: string | null;
  total_amount: number;
  aggregate_flat_count: number;
  charge_id: string | null;
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

const ledgerMonthValue = (e: FinanceLedgerRow) =>
  e.entry_month || format(new Date(e.created_at), 'yyyy-MM');

const ledgerMonthDisplay = (e: FinanceLedgerRow) => {
  const raw = e.entry_month ? `${e.entry_month}-01` : e.created_at;
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return 'Unknown month';
  return format(date, 'MMMM yyyy');
};

async function uploadPaymentReceipt(file: File): Promise<string | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `maintenance-receipts/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, file, { cacheControl: '3600', upsert: false });
  if (error) return null;
  const { data } = supabase.storage.from('notification-media').getPublicUrl(path);
  return data.publicUrl;
}

const FinanceManager = ({ adminName = 'Admin' }: Props) => {
  const { t } = useLanguage();
  const societyId = useStore((s) => s.societyId);
  const [subTab, setSubTab] = useState<'maintenance' | 'payments' | 'receipts' | 'totals' | 'reminders'>('maintenance');
  const [charges, setCharges] = useState<any[]>([]);
  const [payments, setPayments] = useState<any[]>([]);
  const [ledgerEntries, setLedgerEntries] = useState<FinanceLedgerRow[]>([]);
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null; is_occupied: boolean | null }[]>([]);
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [showForm, setShowForm] = useState(false);
  const [showPaymentForm, setShowPaymentForm] = useState(false);
  const [form, setForm] = useState({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
  const [payForm, setPayForm] = useState({
    recordMode: 'flats_only' as 'flats_only' | 'flats_plus_outsider' | 'outsider_only',
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
  const [receiptModeFilter, setReceiptModeFilter] = useState<'all' | 'flats_only' | 'flats_plus_outsider' | 'outsider_only'>('all');
  const [totalsMonth, setTotalsMonth] = useState(format(new Date(), 'yyyy-MM'));
  const [paymentSearchQuery, setPaymentSearchQuery] = useState('');
  const [selectedPayment, setSelectedPayment] = useState<any | null>(null);
  const [selectedLedger, setSelectedLedger] = useState<FinanceLedgerRow | null>(null);
  const [selectedReceiptKeys, setSelectedReceiptKeys] = useState<Set<string>>(new Set());
  const [paymentEdit, setPaymentEdit] = useState<{
    id: string;
    charge_id: string;
    amount: string;
    payment_method: string;
    transaction_id: string;
    notes: string;
    due_date: string;
    payment_status: string;
    rejection_reason: string;
  } | null>(null);
  const [ledgerEdit, setLedgerEdit] = useState<{
    id: string;
    title: string;
    notes: string;
    payment_status: string;
    transaction_id: string;
  } | null>(null);
  const [autoReminderEnabled, setAutoReminderEnabled] = useState(true);
  const [autoReminderSchedule, setAutoReminderSchedule] = useState<'once_12pm' | 'twice_12pm_7pm'>('once_12pm');
  const [savingAutoReminder, setSavingAutoReminder] = useState(false);
  const [testingAutoReminder, setTestingAutoReminder] = useState(false);
  const [lastReminderTestStatus, setLastReminderTestStatus] = useState<string>('');

  useEffect(() => {
    void loadAll();
  }, [societyId]);

  const loadAll = async () => {
    if (!societyId) {
      setCharges([]);
      setPayments([]);
      setFlats([]);
      setPrimaryByFlatId(new Map());
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

    const chargeIds = chargeRows.map((x) => x.id);
    let payRows: any[] = [];
    if (chargeIds.length > 0) {
      const { data: p } = await supabase
        .from('maintenance_payments')
        .select('*')
        .in('charge_id', chargeIds)
        .order('created_at', { ascending: false })
        .limit(300);
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
      .limit(500);
    setLedgerEntries((led as FinanceLedgerRow[]) ?? []);
  };

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

  const addCharge = async () => {
    if (!societyId) {
      toast.error('No society selected');
      return;
    }
    if (!form.title || !form.amount) return;
    if (editingChargeId) {
      const { error } = await supabase
        .from('maintenance_charges')
        .update({
          title: form.title,
          amount: Number(form.amount),
          frequency: form.frequency,
          due_day: Number(form.due_day),
        })
        .eq('id', editingChargeId)
        .eq('society_id', societyId);
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success('Charge updated');
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
        },
      ]);
      if (error) {
        toast.error(error.message);
        return;
      }
      toast.success('Maintenance charge added');
    }
    setForm({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
    setShowForm(false);
    await loadAll();
  };

  const startEditCharge = (charge: any) => {
    setEditingChargeId(charge.id);
    setForm({
      title: charge.title,
      amount: String(charge.amount),
      frequency: charge.frequency || 'monthly',
      due_day: String(charge.due_day ?? 1),
    });
    setShowForm(true);
  };

  const deleteCharge = async (id: string) => {
    const hasDeps =
      payments.some((p) => p.charge_id === id) || ledgerEntries.some((e) => e.charge_id === id);
    if (hasDeps) {
      toast.error('This charge has linked payments or ledger rows. Delete those entries first.');
      return;
    }
    const ok = await confirmAction(
      'Delete this charge?',
      'This will remove the charge definition only.',
      'Delete',
      'Cancel',
    );
    if (!ok) return;
    await supabase.from('maintenance_charges').delete().eq('id', id).eq('society_id', societyId);
    toast.success('Charge deleted');
    if (editingChargeId === id) {
      setEditingChargeId(null);
      setForm({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
      setShowForm(false);
    }
    await loadAll();
  };

  const recordPayment = async () => {
    if (!societyId) return;
    const mode = payForm.recordMode;
    const n = payForm.selected_flats.length;
    if (n === 0) {
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
        toast.error('Select a charge when adjusting current month maintenance');
        return;
      }
    }
    if (mode === 'flats_plus_outsider') {
      if (!payForm.charge_id || !payForm.amount) {
        toast.error('Select charge and enter maintenance amount per flat');
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
    const entryMonth = format(new Date(payForm.due_date), 'yyyy-MM');
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

    const needsCounterparty = mode === 'outsider_only' || mode === 'flats_plus_outsider';
    const entryTitle =
      mode === 'outsider_only'
        ? payForm.entryTitle.trim() || `Outsider: ${payForm.outsiderName.trim()}`
        : mode === 'flats_plus_outsider'
          ? payForm.entryTitle.trim() || `${chargeTitle} + outsider (${payForm.outsiderName.trim()})`
          : chargeTitle;

    const chargeIdForEntry =
      mode === 'outsider_only' && payForm.destination !== 'current_month_maintenance'
        ? null
        : payForm.charge_id || null;

    const destForEntry =
      mode === 'flats_only' ? 'current_month_maintenance' : payForm.destination;

    const { data: feRow, error: feErr } = await supabase
      .from('finance_entries')
      .insert({
        society_id: societyId,
        record_mode: mode,
        destination: destForEntry,
        allocation_style: allocationStyle,
        include_vacant: payForm.allocationIncludeVacant,
        entry_month: entryMonth,
        total_amount: totalAmount,
        aggregate_flat_count: n,
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
    setUseSameDateForSelectedFlats(true);
    setFlatDueDates({});
    setAutoSelectedChargeHint('');
    setPaymentNotifyAudience('none');
    setShowPaymentForm(false);
    const recordedCount = mpRows.length || n;

    let notifySuffix = '';
    if (notifyAudience !== 'none') {
      const methodLabel = payMethod.replace(/_/g, ' ');
      const title = `Payment recorded: ${entryTitle}`;
      const lines = [
        `${adminName} recorded a ${methodLabel} finance entry (“${entryTitle}”).`,
        `Flats in this record: ${snapshotFlats.join(', ')}.`,
        `Total ₹${totalAmount.toLocaleString('en-IN')}.`,
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
    const { error } = await supabase
      .from('finance_entries')
      .update({
        title: ledgerEdit.title.trim() || null,
        notes: ledgerEdit.notes.trim() || null,
        payment_status: ledgerEdit.payment_status,
        transaction_id: ledgerEdit.transaction_id.trim() || null,
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
      payment_status: p.payment_status ?? 'pending',
      rejection_reason: p.rejection_reason ?? '',
    });
  };

  const openLedgerEdit = (e: FinanceLedgerRow) => {
    setLedgerEdit({
      id: e.id,
      title: e.title ?? '',
      notes: e.notes ?? '',
      payment_status: e.payment_status ?? 'verified',
      transaction_id: e.transaction_id ?? '',
    });
  };

  const targetFlats = includeVacantFlats ? flats : flats.filter((f) => f.is_occupied);
  const paymentScopeFlats = useMemo(
    () => (payForm.allocationIncludeVacant ? flats : flats.filter((f) => f.is_occupied)),
    [flats, payForm.allocationIncludeVacant],
  );
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

    const options = [{ value: 'all', label: 'All payment records' }];
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
    for (const e of ledgerEntries) {
      const value = ledgerMonthValue(e);
      const d = new Date(`${value}-15T12:00:00`);
      const label = Number.isNaN(d.getTime()) ? value : format(d, 'MMMM yyyy');
      if (!uniq.has(value)) uniq.set(value, label);
    }
    return [{ value: 'all', label: 'All months' }, ...[...uniq.entries()].sort((a, b) => (a[0] < b[0] ? 1 : -1)).map(([value, label]) => ({ value, label }))];
  }, [payments, ledgerEntries]);

  const selectedFlatDateBadges = useMemo(() => {
    const out: Record<string, string> = {};
    for (const flatNum of payForm.selected_flats) {
      const rawDate = useSameDateForSelectedFlats ? payForm.due_date : (flatDueDates[flatNum] || '');
      if (!rawDate) continue;
      const d = new Date(rawDate);
      out[flatNum] = Number.isNaN(d.getTime()) ? rawDate : format(d, 'dd MMM yyyy');
    }
    return out;
  }, [payForm.selected_flats, payForm.due_date, useSameDateForSelectedFlats, flatDueDates]);

  const scopedReceiptPayments = payments.filter((p) => {
    if (paymentTypeFilter === 'corpus' || paymentTypeFilter === 'outsider_mixed') return false;
    if (receiptModeFilter !== 'all') {
      const fe = p.finance_entry_id ? financeEntryById.get(p.finance_entry_id as string) : undefined;
      const mode = fe?.record_mode ?? 'flats_only';
      if (mode !== receiptModeFilter) return false;
    }
    const ch = chargeById.get(p.charge_id);
    if (paymentTypeFilter === 'monthly_maintenance') {
      if (!ch || !isMonthlyMaintenanceCharge(ch)) return false;
    } else if (paymentTypeFilter === 'other') {
      if (ch) return false;
    } else if (paymentTypeFilter !== 'all') {
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
    return ledgerEntries.filter((e) => {
      if (financeEntryIdsWithPayments.has(e.id)) return false;
      if (receiptModeFilter !== 'all' && e.record_mode !== receiptModeFilter) return false;
      if (paymentMonthFilter !== 'all' && ledgerMonthValue(e) !== paymentMonthFilter) return false;

      if (paymentTypeFilter === 'all') {
        // include
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
    ledgerEntries,
    financeEntryIdsWithPayments,
    receiptModeFilter,
    paymentMonthFilter,
    paymentTypeFilter,
    paymentSearchQuery,
    chargeById,
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
    paymentTypeOptions.find((o) => o.value === paymentTypeFilter)?.label ?? 'All payment records';
  const selectedReceiptMonthLabel =
    monthOptionsForReceipts.find((o) => o.value === paymentMonthFilter)?.label ?? 'All months';

  const totalsBreakdown = useMemo(() => {
    const map = new Map<string, { total: number; flatUnits: number; entries: number }>();
    for (const e of ledgerEntries) {
      const m = e.entry_month || format(new Date(e.created_at), 'yyyy-MM');
      if (m !== totalsMonth) continue;
      const k = `${e.record_mode}||${e.destination}`;
      const cur = map.get(k) ?? { total: 0, flatUnits: 0, entries: 0 };
      cur.total += Number(e.total_amount || 0);
      cur.flatUnits += Number(e.aggregate_flat_count || 0);
      cur.entries += 1;
      map.set(k, cur);
    }
    return [...map.entries()]
      .map(([k, v]) => {
        const [mode, destination] = k.split('||');
        return { mode, destination, ...v };
      })
      .sort((a, b) => `${a.mode}${a.destination}`.localeCompare(`${b.mode}${b.destination}`));
  }, [ledgerEntries, totalsMonth]);

  const totalsMonthNet = useMemo(
    () => totalsBreakdown.reduce((s, r) => s + r.total, 0),
    [totalsBreakdown],
  );

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
      setLastReminderTestStatus(`Last test failed at ${new Date().toLocaleTimeString()}: ${hint}`);
      return;
    }
    const sent = Number((data as any)?.sent ?? 0);
    toast.success(sent > 0 ? `Test reminder sent to ${sent} flat(s)` : 'No pending dues found for test run');
    setLastReminderTestStatus(`Last test at ${new Date().toLocaleTimeString()}: sent to ${sent} flat(s)`);
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
          <DollarSign className="w-5 h-5 text-green-600" />
        </div>
        <div>
          <h1 className="page-title">Finance Management</h1>
          <p className="text-xs text-muted-foreground">
            {charges.length} charges · {payments.length} payments · {ledgerEntries.length} ledger entries
          </p>
        </div>
      </div>

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
        {(['maintenance', 'payments', 'receipts', 'totals', 'reminders'] as const).map((s) => (
          <button
            key={s}
            onClick={() => setSubTab(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap ${subTab === s ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
          >
            {s === 'maintenance'
              ? '📋 Charges'
              : s === 'payments'
                ? '💰 Record Payment'
                : s === 'receipts'
                  ? '🧾 Receipts'
                  : s === 'totals'
                    ? '📊 Totals'
                    : '🔔 Reminders'}
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
              setForm({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
              setShowForm(true);
            }}
            className="btn-primary w-full mb-4 flex items-center justify-center gap-2"
          >
            <Plus className="w-4 h-4" /> {showForm && !editingChargeId ? 'Close form' : 'Add maintenance charge'}
          </button>
          {showForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <p className="text-xs font-medium text-muted-foreground">{editingChargeId ? 'Edit charge' : 'New charge'}</p>
              <input className="input-field" placeholder="Title (e.g. Monthly Maintenance)" value={form.title} onChange={e => setForm({...form, title: e.target.value})} />
              <input className="input-field" placeholder="Amount (₹)" type="number" value={form.amount} onChange={e => setForm({...form, amount: e.target.value})} />
              <select className="input-field" value={form.frequency} onChange={e => setForm({...form, frequency: e.target.value})}>
                <option value="monthly">Monthly</option>
                <option value="quarterly">Quarterly</option>
                <option value="yearly">Yearly</option>
                <option value="one-time">One-time</option>
              </select>
              <input className="input-field" placeholder="Due Day (1-28)" type="number" min="1" max="28" value={form.due_day} onChange={e => setForm({...form, due_day: e.target.value})} />
              <div className="flex gap-2">
                <button type="button" onClick={addCharge} className="btn-primary flex-1">
                  {editingChargeId ? 'Update charge' : 'Save charge'}
                </button>
                {editingChargeId && (
                  <button
                    type="button"
                    className="btn-secondary flex-1"
                    onClick={() => {
                      setEditingChargeId(null);
                      setForm({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
                    }}
                  >
                    Cancel edit
                  </button>
                )}
              </div>
            </div>
          )}
          {charges.map(c => (
            <div key={c.id} className="card-section p-3 mb-2">
              <div className="flex justify-between items-start gap-2">
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{c.title}</p>
                  <p className="text-xs text-muted-foreground">{c.frequency} · Due on {c.due_day}th</p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <p className="text-lg font-bold text-green-600">₹{c.amount}</p>
                  <button type="button" className="p-1.5 text-muted-foreground hover:text-primary" title="Edit" onClick={() => startEditCharge(c)}>
                    <Pencil className="w-4 h-4" />
                  </button>
                  {!chargeIdsWithDependents.has(c.id) ? (
                    <button
                      type="button"
                      className="p-1.5 text-muted-foreground hover:text-destructive"
                      title="Delete charge"
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
      )}

      {subTab === 'payments' && (
        <div>
          <button onClick={() => setShowPaymentForm(!showPaymentForm)} className="btn-primary w-full mb-3 flex items-center justify-center gap-2">
            <Upload className="w-4 h-4" /> Record Payment / Upload Receipt
          </button>
          {showPaymentForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <div>
                <p className="text-[10px] font-medium text-muted-foreground uppercase mb-1">Recording mode</p>
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
                  <option value="flats_only">Flats only (maintenance)</option>
                  <option value="flats_plus_outsider">Flats + outsider</option>
                  <option value="outsider_only">Outsider only</option>
                </select>
              </div>
              {payForm.recordMode !== 'flats_only' && (
                <div>
                  <p className="text-[10px] font-medium text-muted-foreground uppercase mb-1">
                    Destination (outsider portion / ledger context)
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
                    <option value="current_month_maintenance">Adjust current month maintenance</option>
                    <option value="corpus">Corpus / sinking fund</option>
                    <option value="separate_entry">Separate ledger entry (no flat maintenance posting)</option>
                  </select>
                </div>
              )}
              <label className="flex items-center gap-2 text-xs text-muted-foreground">
                <input
                  type="checkbox"
                  checked={payForm.allocationIncludeVacant}
                  onChange={(e) => setPayForm({ ...payForm, allocationIncludeVacant: e.target.checked })}
                />
                Include vacant flats in this picker (allocation scope)
              </label>
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
              {(payForm.recordMode === 'flats_only' ||
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
                  <option value="">Select Charge</option>
                  {charges.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title} - ₹{c.amount}
                    </option>
                  ))}
                </select>
              )}
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
                <option value="cash">💵 Cash</option>
                <option value="upi">📱 UPI</option>
                <option value="razorpay">💳 Razorpay (Online)</option>
                <option value="bank_transfer">🏦 Bank Transfer</option>
              </select>
              <input className="input-field" placeholder="Transaction / reference ID (optional)" value={payForm.transaction_id} onChange={e => setPayForm({...payForm, transaction_id: e.target.value})} />
              <input className="input-field" placeholder="Screenshot URL (paste link, optional)" value={payForm.screenshot_url} onChange={e => setPayForm({...payForm, screenshot_url: e.target.value})} />
              <label className="text-[10px] font-medium text-muted-foreground uppercase">Or upload receipt / bill</label>
              <input id="finance-payment-receipt" type="file" accept="image/*,application/pdf" className="text-xs" />
              <input
                className="input-field"
                type="date"
                value={payForm.due_date}
                onChange={e => {
                  const nextDate = e.target.value;
                  setPayForm({...payForm, due_date: nextDate});
                  if (useSameDateForSelectedFlats) {
                    setFlatDueDates((prev) => {
                      const next = { ...prev };
                      for (const flat of payForm.selected_flats) next[flat] = nextDate;
                      return next;
                    });
                  }
                }}
              />
              {!useSameDateForSelectedFlats && payForm.selected_flats.length > 0 && (
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
              <textarea className="input-field" placeholder="Notes" value={payForm.notes} onChange={e => setPayForm({...payForm, notes: e.target.value})} />

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

              <button type="button" onClick={() => void recordPayment()} className="btn-primary" disabled={receiptUploading}>
                {receiptUploading ? 'Uploading…' : 'Record payment'}
              </button>
            </div>
          )}

          <p className="text-[11px] text-muted-foreground mt-1">
            Payment records and receipts are available in the new <span className="font-medium">Receipts</span> tab.
          </p>

          {flatDateModal.open && (
            <div className="fixed inset-0 z-[60] bg-black/45 p-4 flex items-center justify-center">
              <div className="w-full max-w-xs bg-card border border-border rounded-xl p-4">
                <p className="text-sm font-semibold mb-1">Select due date</p>
                <p className="text-xs text-muted-foreground mb-3">Flat {flatDateModal.flatNumber}</p>
                <input
                  className="input-field"
                  type="date"
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

      {subTab === 'receipts' && (
        <div>
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
              { key: 'pending', label: 'PENDING' },
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
            <p className="text-[11px] font-medium text-muted-foreground uppercase">Receipt filters</p>
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
              <option value="flats_only">Flats only</option>
              <option value="flats_plus_outsider">Flats + outsider</option>
              <option value="outsider_only">Outsider only</option>
            </select>
          </div>

          <p className="text-[10px] text-muted-foreground mb-2">
            {filterStatus === 'unpaid' ? (
              <>
                {unpaidReceiptRows.length} unpaid flats · Type: {selectedReceiptTypeLabel} · Month:{' '}
                {selectedReceiptMonthLabel}
              </>
            ) : (
              <>
                {receiptSummary.count} entries · ₹{receiptSummary.sum.toLocaleString('en-IN')} total ·{' '}
                {receiptSummary.flatCount} flat(s) · Type: {selectedReceiptTypeLabel} · Mode:{' '}
                {receiptModeFilter === 'all' ? 'All' : receiptModeFilter.replace(/_/g, ' ')} · Month:{' '}
                {selectedReceiptMonthLabel}
              </>
            )}
          </p>

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
                            <p className="text-[10px] text-muted-foreground">
                              {new Date(item.p.created_at).toLocaleDateString()}
                            </p>
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
                              {ledgerMonthDisplay(item.e)} · Ledger-only (no maintenance payment rows)
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
                            <p className="text-[10px] text-muted-foreground">
                              {new Date(item.e.created_at).toLocaleString()}
                            </p>
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
                      <p><span className="text-muted-foreground">Due date:</span> {selectedPayment.due_date || '-'}</p>
                      <p><span className="text-muted-foreground">Paid at:</span> {selectedPayment.payment_date ? new Date(selectedPayment.payment_date).toLocaleString() : '-'}</p>
                      <p><span className="text-muted-foreground">Created at:</span> {selectedPayment.created_at ? new Date(selectedPayment.created_at).toLocaleString() : '-'}</p>
                      <p><span className="text-muted-foreground">Transaction ID:</span> {selectedPayment.transaction_id || '-'}</p>
                      <p><span className="text-muted-foreground">Verified by:</span> {selectedPayment.verified_by || '-'}</p>
                      <p><span className="text-muted-foreground">Verified at:</span> {selectedPayment.verified_at ? new Date(selectedPayment.verified_at).toLocaleString() : '-'}</p>
                      <p><span className="text-muted-foreground">Reviewed at:</span> {selectedPayment.reviewed_at ? new Date(selectedPayment.reviewed_at).toLocaleString() : '-'}</p>
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
                      <option value="">Select charge</option>
                      {charges.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.title}
                        </option>
                      ))}
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
                    <input
                      className="input-field"
                      type="date"
                      value={paymentEdit.due_date}
                      onChange={(e) => setPaymentEdit({ ...paymentEdit, due_date: e.target.value })}
                    />
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
                  <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3">
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
                    <textarea
                      className="input-field"
                      value={ledgerEdit.notes}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, notes: e.target.value })}
                      placeholder="Notes"
                    />
                    <input
                      className="input-field"
                      value={ledgerEdit.transaction_id}
                      onChange={(e) => setLedgerEdit({ ...ledgerEdit, transaction_id: e.target.value })}
                      placeholder="Transaction / reference ID"
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
        </div>
      )}

      {subTab === 'totals' && (
        <div>
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

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mb-4">
            <div className="stat-card flex flex-col gap-1">
              <span className="text-[10px] text-muted-foreground uppercase">Inflow (ledger)</span>
              <span className="text-xl font-bold text-green-600">₹{totalsMonthNet.toLocaleString('en-IN')}</span>
            </div>
            <div className="stat-card flex flex-col gap-1">
              <span className="text-[10px] text-muted-foreground uppercase">Groups</span>
              <span className="text-xl font-bold font-mono">{totalsBreakdown.length}</span>
            </div>
            <div className="stat-card flex flex-col gap-1">
              <span className="text-[10px] text-muted-foreground uppercase">Flat allocation rows</span>
              <span className="text-xl font-bold font-mono">
                {totalsBreakdown.reduce((s, r) => s + r.flatUnits, 0)}
              </span>
            </div>
          </div>

          <div className="space-y-2">
            {totalsBreakdown.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-10">
                No ledger groups for {totalsMonth}. Record payments or outsider entries to populate totals.
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
                  </div>
                  <div className="text-right shrink-0">
                    <p className="font-bold">₹{row.total.toLocaleString('en-IN')}</p>
                    <p className="text-[10px] text-muted-foreground">{row.flatUnits} flat units</p>
                  </div>
                </div>
              ))
            )}
          </div>
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
                🔔 Send Reminders to All ({unpaidFlats.length})
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
    </div>
  );
};

export default FinanceManager;
