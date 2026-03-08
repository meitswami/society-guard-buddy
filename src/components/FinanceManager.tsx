import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { DollarSign, Plus, Check, X, Upload, Eye, Filter, AlertTriangle } from 'lucide-react';
import { toast } from 'sonner';
import { format } from 'date-fns';

interface Props {
  adminName?: string;
}

const FinanceManager = ({ adminName = 'Admin' }: Props) => {
  const { t } = useLanguage();
  const [subTab, setSubTab] = useState<'maintenance' | 'payments' | 'reminders'>('maintenance');
  const [charges, setCharges] = useState<any[]>([]);
  const [payments, setPayments] = useState<any[]>([]);
  const [flats, setFlats] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [showPaymentForm, setShowPaymentForm] = useState(false);
  const [form, setForm] = useState({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
  const [payForm, setPayForm] = useState({ charge_id: '', flat_number: '', resident_name: '', amount: '', payment_method: 'cash', transaction_id: '', screenshot_url: '', notes: '', due_date: format(new Date(), 'yyyy-MM-dd') });
  const [filterStatus, setFilterStatus] = useState('all');

  useEffect(() => { loadAll(); }, []);

  const loadAll = async () => {
    const [c, p, f] = await Promise.all([
      supabase.from('maintenance_charges').select('*').order('created_at', { ascending: false }),
      supabase.from('maintenance_payments').select('*').order('created_at', { ascending: false }).limit(200),
      supabase.from('flats').select('flat_number, id').order('flat_number'),
    ]);
    if (c.data) setCharges(c.data);
    if (p.data) setPayments(p.data);
    if (f.data) setFlats(f.data);
  };

  const addCharge = async () => {
    if (!form.title || !form.amount) return;
    await supabase.from('maintenance_charges').insert([{
      title: form.title, amount: Number(form.amount), frequency: form.frequency,
      due_day: Number(form.due_day), created_by: adminName,
    }]);
    setForm({ title: '', amount: '', frequency: 'monthly', due_day: '1' });
    setShowForm(false);
    toast.success('Maintenance charge added');
    loadAll();
  };

  const recordPayment = async () => {
    if (!payForm.flat_number || !payForm.amount || !payForm.charge_id) return;
    const flat = flats.find(f => f.flat_number === payForm.flat_number);
    await supabase.from('maintenance_payments').insert([{
      charge_id: payForm.charge_id, flat_id: flat?.id || null, flat_number: payForm.flat_number,
      resident_name: payForm.resident_name, amount: Number(payForm.amount),
      payment_method: payForm.payment_method, payment_status: payForm.payment_method === 'cash' || payForm.payment_method === 'upi' ? 'verified' : 'pending',
      payment_date: new Date().toISOString(), due_date: payForm.due_date,
      transaction_id: payForm.transaction_id || null, screenshot_url: payForm.screenshot_url || null,
      notes: payForm.notes || null, verified_by: adminName, verified_at: new Date().toISOString(),
    }]);
    setPayForm({ charge_id: '', flat_number: '', resident_name: '', amount: '', payment_method: 'cash', transaction_id: '', screenshot_url: '', notes: '', due_date: format(new Date(), 'yyyy-MM-dd') });
    setShowPaymentForm(false);
    toast.success('Payment recorded');
    loadAll();
  };

  const verifyPayment = async (id: string) => {
    await supabase.from('maintenance_payments').update({ payment_status: 'verified', verified_by: adminName, verified_at: new Date().toISOString() }).eq('id', id);
    toast.success('Payment verified');
    loadAll();
  };

  const rejectPayment = async (id: string) => {
    await supabase.from('maintenance_payments').update({ payment_status: 'rejected', verified_by: adminName }).eq('id', id);
    toast.success('Payment rejected');
    loadAll();
  };

  const unpaidFlats = flats.filter(f => !payments.some(p => p.flat_number === f.flat_number && p.payment_status === 'verified'));

  const filteredPayments = filterStatus === 'all' ? payments : payments.filter(p => p.payment_status === filterStatus);

  const sendReminders = async () => {
    for (const flat of unpaidFlats) {
      await supabase.from('notifications').insert([{
        title: 'Maintenance Due Reminder',
        message: `Dear resident of Flat ${flat.flat_number}, your maintenance payment is due. Please pay at the earliest.`,
        type: 'payment_reminder',
        target_type: 'flat',
        target_id: flat.flat_number,
        created_by: adminName,
      }]);
    }
    toast.success(`Reminders sent to ${unpaidFlats.length} flats`);
  };

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
          <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
            <Plus className="w-4 h-4" /> Add Maintenance Charge
          </button>
          {showForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <input className="input-field" placeholder="Title (e.g. Monthly Maintenance)" value={form.title} onChange={e => setForm({...form, title: e.target.value})} />
              <input className="input-field" placeholder="Amount (₹)" type="number" value={form.amount} onChange={e => setForm({...form, amount: e.target.value})} />
              <select className="input-field" value={form.frequency} onChange={e => setForm({...form, frequency: e.target.value})}>
                <option value="monthly">Monthly</option>
                <option value="quarterly">Quarterly</option>
                <option value="yearly">Yearly</option>
                <option value="one-time">One-time</option>
              </select>
              <input className="input-field" placeholder="Due Day (1-28)" type="number" min="1" max="28" value={form.due_day} onChange={e => setForm({...form, due_day: e.target.value})} />
              <button onClick={addCharge} className="btn-primary">Save Charge</button>
            </div>
          )}
          {charges.map(c => (
            <div key={c.id} className="card-section p-3 mb-2">
              <div className="flex justify-between items-center">
                <div>
                  <p className="text-sm font-semibold">{c.title}</p>
                  <p className="text-xs text-muted-foreground">{c.frequency} · Due on {c.due_day}th</p>
                </div>
                <p className="text-lg font-bold text-green-600">₹{c.amount}</p>
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
              <select className="input-field" value={payForm.flat_number} onChange={e => setPayForm({...payForm, flat_number: e.target.value})}>
                <option value="">Select Flat</option>
                {flats.map(f => <option key={f.id} value={f.flat_number}>{f.flat_number}</option>)}
              </select>
              <input className="input-field" placeholder="Resident Name" value={payForm.resident_name} onChange={e => setPayForm({...payForm, resident_name: e.target.value})} />
              <input className="input-field" placeholder="Amount (₹)" type="number" value={payForm.amount} onChange={e => setPayForm({...payForm, amount: e.target.value})} />
              <select className="input-field" value={payForm.payment_method} onChange={e => setPayForm({...payForm, payment_method: e.target.value})}>
                <option value="cash">💵 Cash</option>
                <option value="upi">📱 UPI</option>
                <option value="razorpay">💳 Razorpay (Online)</option>
                <option value="bank_transfer">🏦 Bank Transfer</option>
              </select>
              {(payForm.payment_method === 'upi' || payForm.payment_method === 'bank_transfer') && (
                <>
                  <input className="input-field" placeholder="Transaction ID" value={payForm.transaction_id} onChange={e => setPayForm({...payForm, transaction_id: e.target.value})} />
                  <input className="input-field" placeholder="Screenshot URL (paste link)" value={payForm.screenshot_url} onChange={e => setPayForm({...payForm, screenshot_url: e.target.value})} />
                </>
              )}
              <input className="input-field" type="date" value={payForm.due_date} onChange={e => setPayForm({...payForm, due_date: e.target.value})} />
              <textarea className="input-field" placeholder="Notes" value={payForm.notes} onChange={e => setPayForm({...payForm, notes: e.target.value})} />
              <button onClick={recordPayment} className="btn-primary">Record Payment</button>
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
                  <p className="text-xs text-muted-foreground">{p.resident_name} · {p.payment_method.toUpperCase()}</p>
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
