import { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { DollarSign, Plus, Check, X, Upload, AlertTriangle, Pencil, Trash2 } from 'lucide-react';
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
  const [subTab, setSubTab] = useState<'maintenance' | 'payments' | 'reminders'>('maintenance');
  const [charges, setCharges] = useState<any[]>([]);
  const [payments, setPayments] = useState<any[]>([]);
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null; is_occupied: boolean | null }[]>([]);
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [showForm, setShowForm] = useState(false);
  const [showPaymentForm, setShowPaymentForm] = useState(false);
  const [form, setForm] = useState({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
  const [payForm, setPayForm] = useState({
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
  const [selectedPayment, setSelectedPayment] = useState<any | null>(null);
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
    const ok = await confirmAction(
      'Delete this charge?',
      'All payment records linked to this charge will be deleted as well.',
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
    if (payForm.selected_flats.length === 0 || !payForm.amount || !payForm.charge_id) return;
    if (!societyId) return;
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
    const now = new Date().toISOString();
    const rows = payForm.selected_flats.map(flat_number => {
      const flat = flats.find(f => f.flat_number === flat_number);
      return {
        charge_id: payForm.charge_id,
        flat_id: flat?.id || null,
        flat_number,
        resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
        amount: Number(payForm.amount),
        payment_method: payForm.payment_method,
        payment_status:
          payForm.payment_method === 'cash' || payForm.payment_method === 'upi' ? 'verified' : 'pending',
        payment_date: now,
        due_date: useSameDateForSelectedFlats ? payForm.due_date : (flatDueDates[flat_number] || payForm.due_date),
        transaction_id: payForm.transaction_id || null,
        screenshot_url: screenshotUrl,
        notes: payForm.notes || null,
        submitted_by: 'admin',
        submitted_by_user_id: null,
        verified_by: adminName,
        verified_at: now,
        reviewed_at: now,
        rejection_reason: null,
      };
    });
    const { error: payErr } = await supabase.from('maintenance_payments').insert(rows);
    if (payErr) {
      toast.error(payErr.message);
      return;
    }

    const notifyAudience = paymentNotifyAudience;
    const snapshotFlats = [...payForm.selected_flats];
    const amountPerFlat = Number(payForm.amount);
    const payMethod = payForm.payment_method;
    const payTxn = payForm.transaction_id;
    const payNotes = payForm.notes;
    const chargeTitle = charges.find((c) => c.id === payForm.charge_id)?.title ?? 'Maintenance charge';
    const allFlatNumbers = flats.map((f) => f.flat_number);

    setPayForm({
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
    const n = rows.length;

    let notifySuffix = '';
    if (notifyAudience !== 'none') {
      const methodLabel = payMethod.replace(/_/g, ' ');
      const title = `Payment recorded: ${chargeTitle}`;
      const totalForEntry = amountPerFlat * snapshotFlats.length;
      const lines = [
        `${adminName} recorded a ${methodLabel} payment for “${chargeTitle}”.`,
        `Flats in this record: ${snapshotFlats.join(', ')}.`,
        `₹${amountPerFlat.toLocaleString('en-IN')} per flat (₹${totalForEntry.toLocaleString('en-IN')} total).`,
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

    toast.success((n > 1 ? `Payments recorded for ${n} flats` : 'Payment recorded') + notifySuffix);
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

  const targetFlats = includeVacantFlats ? flats : flats.filter((f) => f.is_occupied);
  const unpaidFlats = targetFlats.filter(f => !payments.some(p => p.flat_number === f.flat_number && p.payment_status === 'verified'));

  const chargeById = useMemo(() => {
    const m = new Map<string, any>();
    for (const c of charges) {
      if (c?.id) m.set(c.id, c);
    }
    return m;
  }, [charges]);

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
    return options;
  }, [payments, chargeById]);

  const monthOptionsForMonthlyMaintenance = useMemo(() => {
    const uniq = new Map<string, string>();
    for (const p of payments) {
      const ch = chargeById.get(p.charge_id);
      if (!ch || !isMonthlyMaintenanceCharge(ch)) continue;
      const value = paymentMonthValue(p);
      if (!value) continue;
      if (!uniq.has(value)) uniq.set(value, paymentMonthLabel(p));
    }
    return [{ value: 'all', label: 'All months' }, ...[...uniq.entries()].sort((a, b) => (a[0] < b[0] ? 1 : -1)).map(([value, label]) => ({ value, label }))];
  }, [payments, chargeById]);

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

  const filteredPayments = payments.filter((p) => {
    if (filterStatus !== 'all' && p.payment_status !== filterStatus) return false;
    const ch = chargeById.get(p.charge_id);
    if (paymentTypeFilter === 'monthly_maintenance') {
      if (!ch || !isMonthlyMaintenanceCharge(ch)) return false;
    } else if (paymentTypeFilter === 'other') {
      if (ch) return false;
    } else if (paymentTypeFilter !== 'all') {
      if (!ch || String(ch.frequency).toLowerCase() !== paymentTypeFilter) return false;
    }
    if (paymentTypeFilter === 'monthly_maintenance' && paymentMonthFilter !== 'all') {
      if (paymentMonthValue(p) !== paymentMonthFilter) return false;
    }
    return true;
  });

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
      toast.error(error.message);
      setLastReminderTestStatus(`Last test failed at ${new Date().toLocaleTimeString()}: ${error.message}`);
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
          <p className="text-xs text-muted-foreground">{charges.length} charges · {payments.length} payments</p>
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
        {(['maintenance', 'payments', 'reminders'] as const).map(s => (
          <button key={s} onClick={() => setSubTab(s)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap ${subTab === s ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}>
            {s === 'maintenance' ? '📋 Charges' : s === 'payments' ? '💰 Payments' : '🔔 Reminders'}
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
                  <button type="button" className="p-1.5 text-muted-foreground hover:text-destructive" title="Delete" onClick={() => void deleteCharge(c.id)}>
                    <Trash2 className="w-4 h-4" />
                  </button>
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
              {autoSelectedChargeHint && (
                <p className="text-[11px] text-muted-foreground">{autoSelectedChargeHint}</p>
              )}
              <select className="input-field" value={payForm.charge_id} onChange={e => {
                const ch = charges.find(c => c.id === e.target.value);
                setAutoSelectedChargeHint('');
                setPayForm({...payForm, charge_id: e.target.value, amount: ch?.amount?.toString() || ''});
              }}>
                <option value="">Select Charge</option>
                {charges.map(c => <option key={c.id} value={c.id}>{c.title} - ₹{c.amount}</option>)}
              </select>
              <FlatMultiSelect
                flats={flatOptionsWithPrimaryLabel(flats, primaryByFlatId)}
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
              <input className="input-field" placeholder="Amount (₹)" type="number" value={payForm.amount} onChange={e => setPayForm({...payForm, amount: e.target.value})} />
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

          <div className="flex gap-1 mb-3">
            {['all', 'pending', 'verified', 'rejected'].map(s => (
              <button key={s} onClick={() => setFilterStatus(s)}
                className={`px-2 py-1 rounded text-[10px] font-medium ${filterStatus === s ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'}`}>
                {s.toUpperCase()}
              </button>
            ))}
          </div>

          <div className="card-section p-3 mb-3 space-y-2">
            <p className="text-[11px] font-medium text-muted-foreground uppercase">Record filter</p>
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
            {paymentTypeFilter === 'monthly_maintenance' && (
              <select className="input-field" value={paymentMonthFilter} onChange={(e) => setPaymentMonthFilter(e.target.value)}>
                {monthOptionsForMonthlyMaintenance.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            )}
          </div>

          {filteredPayments.map(p => (
            <div key={p.id} className="card-section p-3 mb-2 w-full text-left cursor-pointer" onClick={() => setSelectedPayment(p)}>
              <div className="flex justify-between items-start">
                <div>
                  <p className="text-[11px] text-muted-foreground">
                    {chargeById.get(p.charge_id)?.title || 'Unknown charge'} · {paymentMonthLabel(p)}
                  </p>
                  <p className="text-sm font-semibold">Flat {p.flat_number}</p>
                  <p className="text-xs text-muted-foreground">
                    {[p.resident_name, p.payment_method.toUpperCase()].filter(Boolean).join(' · ')}
                  </p>
                  {p.transaction_id && <p className="text-[10px] text-muted-foreground font-mono">TXN: {p.transaction_id}</p>}
                  {p.rejection_reason ? <p className="text-[10px] text-destructive">Reason: {p.rejection_reason}</p> : null}
                  <p className="text-[10px] text-muted-foreground">{new Date(p.created_at).toLocaleDateString()}</p>
                </div>
                <div className="text-right">
                  <p className="font-bold">₹{p.amount}</p>
                  <span className={`text-[10px] px-2 py-0.5 rounded-full ${
                    p.payment_status === 'verified' ? 'bg-green-500/20 text-green-600' :
                    p.payment_status === 'rejected' ? 'bg-destructive/20 text-destructive' :
                    'bg-amber-500/20 text-amber-600'
                  }`}>{p.payment_status}</span>
                </div>
              </div>
              {p.payment_status === 'pending' && (
                <div className="flex gap-2 mt-2">
                  <button onClick={(e) => { e.stopPropagation(); void verifyPayment(p.id); }} className="flex-1 py-1.5 bg-green-600 text-white rounded-lg text-xs flex items-center justify-center gap-1">
                    <Check className="w-3 h-3" /> Verify
                  </button>
                  <button onClick={(e) => { e.stopPropagation(); void rejectPayment(p.id); }} className="flex-1 py-1.5 bg-destructive text-destructive-foreground rounded-lg text-xs flex items-center justify-center gap-1">
                    <X className="w-3 h-3" /> Reject
                  </button>
                </div>
              )}
              {p.screenshot_url && (
                <a href={p.screenshot_url} target="_blank" onClick={(e) => e.stopPropagation()} className="text-xs text-primary underline mt-1 block">View Screenshot</a>
              )}
            </div>
          ))}

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
