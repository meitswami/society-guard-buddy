import { useState, useEffect } from 'react';
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

    const { data: c } = await supabase
      .from('maintenance_charges')
      .select('*')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false });
    if (c) setCharges(c);

    const chargeIds = (c ?? []).map((x) => x.id);
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
        due_date: payForm.due_date,
        transaction_id: payForm.transaction_id || null,
        screenshot_url: screenshotUrl,
        notes: payForm.notes || null,
        verified_by: adminName,
        verified_at: now,
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
    await supabase.from('maintenance_payments').update({ payment_status: 'verified', verified_by: adminName, verified_at: new Date().toISOString() }).eq('id', id);
    showSuccess('Verified!', 'Payment verified successfully');
    await loadAll();
  };

  const rejectPayment = async (id: string) => {
    const ok = await confirmAction('Reject Payment?', 'Are you sure you want to reject this payment?', 'Yes, Reject', 'Cancel');
    if (!ok) return;
    await supabase.from('maintenance_payments').update({ payment_status: 'rejected', verified_by: adminName }).eq('id', id);
    showSuccess('Rejected', 'Payment has been rejected');
    await loadAll();
  };

  const targetFlats = includeVacantFlats ? flats : flats.filter((f) => f.is_occupied);
  const unpaidFlats = targetFlats.filter(f => !payments.some(p => p.flat_number === f.flat_number && p.payment_status === 'verified'));

  const filteredPayments = filterStatus === 'all' ? payments : payments.filter(p => p.payment_status === filterStatus);

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
              <select className="input-field" value={payForm.charge_id} onChange={e => {
                const ch = charges.find(c => c.id === e.target.value);
                setPayForm({...payForm, charge_id: e.target.value, amount: ch?.amount?.toString() || ''});
              }}>
                <option value="">Select Charge</option>
                {charges.map(c => <option key={c.id} value={c.id}>{c.title} - ₹{c.amount}</option>)}
              </select>
              <FlatMultiSelect
                flats={flatOptionsWithPrimaryLabel(flats, primaryByFlatId)}
                selected={payForm.selected_flats}
                onChange={nums => setPayForm({ ...payForm, selected_flats: nums })}
                label="Flats (multi-select)"
              />
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
              <input className="input-field" type="date" value={payForm.due_date} onChange={e => setPayForm({...payForm, due_date: e.target.value})} />
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

          {filteredPayments.map(p => (
            <div key={p.id} className="card-section p-3 mb-2">
              <div className="flex justify-between items-start">
                <div>
                  <p className="text-sm font-semibold">Flat {p.flat_number}</p>
                  <p className="text-xs text-muted-foreground">
                    {[p.resident_name, p.payment_method.toUpperCase()].filter(Boolean).join(' · ')}
                  </p>
                  {p.transaction_id && <p className="text-[10px] text-muted-foreground font-mono">TXN: {p.transaction_id}</p>}
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
                  <button onClick={() => verifyPayment(p.id)} className="flex-1 py-1.5 bg-green-600 text-white rounded-lg text-xs flex items-center justify-center gap-1">
                    <Check className="w-3 h-3" /> Verify
                  </button>
                  <button onClick={() => rejectPayment(p.id)} className="flex-1 py-1.5 bg-destructive text-destructive-foreground rounded-lg text-xs flex items-center justify-center gap-1">
                    <X className="w-3 h-3" /> Reject
                  </button>
                </div>
              )}
              {p.screenshot_url && (
                <a href={p.screenshot_url} target="_blank" className="text-xs text-primary underline mt-1 block">View Screenshot</a>
              )}
            </div>
          ))}
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
