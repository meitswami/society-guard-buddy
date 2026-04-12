import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Heart, Plus, Upload } from 'lucide-react';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { toast } from 'sonner';

interface Props { adminName?: string; }

const DonationManager = ({ adminName = 'Admin' }: Props) => {
  const [campaigns, setCampaigns] = useState<any[]>([]);
  const [donations, setDonations] = useState<any[]>([]);
  const [flats, setFlats] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [showDonateForm, setShowDonateForm] = useState<string | null>(null);
  const [cf, setCf] = useState({ title: '', description: '', target_amount: '', end_date: '' });
  const [df, setDf] = useState({
    selected_flats: [] as string[],
    resident_name: '',
    amount: '',
    payment_method: 'cash',
    transaction_id: '',
    screenshot_url: '',
  });

  useEffect(() => { loadAll(); }, []);
  const loadAll = async () => {
    const [c, d, f] = await Promise.all([
      supabase.from('donation_campaigns').select('*').order('created_at', { ascending: false }),
      supabase.from('donation_payments').select('*').order('created_at', { ascending: false }),
      supabase.from('flats').select('flat_number, id').order('flat_number'),
    ]);
    if (c.data) setCampaigns(c.data);
    if (d.data) setDonations(d.data);
    if (f.data) setFlats(f.data);
  };

  const addCampaign = async () => {
    if (!cf.title) return;
    await supabase.from('donation_campaigns').insert([{
      title: cf.title, description: cf.description || null, target_amount: Number(cf.target_amount) || 0,
      created_by: adminName, end_date: cf.end_date || null,
    }]);
    setCf({ title: '', description: '', target_amount: '', end_date: '' });
    setShowForm(false); toast.success('Campaign created'); loadAll();
  };

  const addDonation = async (campaignId: string) => {
    if (df.selected_flats.length === 0 || !df.amount) return;
    const amount = Number(df.amount);
    const verifiedAt = new Date().toISOString();
    const rows = df.selected_flats.map(flat_number => {
      const flat = flats.find(f => f.flat_number === flat_number);
      return {
        campaign_id: campaignId,
        flat_id: flat?.id || null,
        flat_number,
        resident_name: df.resident_name,
        amount,
        payment_method: df.payment_method,
        transaction_id: df.transaction_id || null,
        screenshot_url: df.screenshot_url || null,
        verified_by: adminName,
        verified_at: verifiedAt,
      };
    });
    await supabase.from('donation_payments').insert(rows);
    const camp = campaigns.find(c => c.id === campaignId);
    if (camp) {
      await supabase
        .from('donation_campaigns')
        .update({ collected_amount: (camp.collected_amount || 0) + amount * rows.length })
        .eq('id', campaignId);
    }
    setDf({
      selected_flats: [],
      resident_name: '',
      amount: '',
      payment_method: 'cash',
      transaction_id: '',
      screenshot_url: '',
    });
    setShowDonateForm(null);
    toast.success(rows.length > 1 ? `Donations recorded for ${rows.length} flats` : 'Donation recorded');
    loadAll();
  };

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-pink-500/10 flex items-center justify-center">
          <Heart className="w-5 h-5 text-pink-500" />
        </div>
        <h1 className="page-title">Donation Collection</h1>
      </div>

      <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
        <Plus className="w-4 h-4" /> New Campaign
      </button>

      {showForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <input className="input-field" placeholder="Campaign Title" value={cf.title} onChange={e => setCf({...cf, title: e.target.value})} />
          <textarea className="input-field" placeholder="Description" value={cf.description} onChange={e => setCf({...cf, description: e.target.value})} />
          <input className="input-field" placeholder="Target Amount (₹)" type="number" value={cf.target_amount} onChange={e => setCf({...cf, target_amount: e.target.value})} />
          <input className="input-field" type="date" value={cf.end_date} onChange={e => setCf({...cf, end_date: e.target.value})} />
          <button onClick={addCampaign} className="btn-primary">Create Campaign</button>
        </div>
      )}

      {campaigns.map(c => {
        const campDonations = donations.filter(d => d.campaign_id === c.id);
        const progress = c.target_amount > 0 ? Math.min(100, ((c.collected_amount || 0) / c.target_amount) * 100) : 0;
        return (
          <div key={c.id} className="card-section p-4 mb-3">
            <div className="flex justify-between items-start mb-2">
              <div>
                <p className="font-semibold">{c.title}</p>
                {c.description && <p className="text-xs text-muted-foreground">{c.description}</p>}
              </div>
              <span className={`text-[10px] px-2 py-0.5 rounded-full ${c.status === 'active' ? 'bg-green-500/20 text-green-600' : 'bg-muted text-muted-foreground'}`}>{c.status}</span>
            </div>
            {c.target_amount > 0 && (
              <div className="mb-2">
                <div className="flex justify-between text-xs mb-1">
                  <span>₹{c.collected_amount || 0}</span>
                  <span>₹{c.target_amount}</span>
                </div>
                <div className="h-2 bg-muted rounded-full overflow-hidden">
                  <div className="h-full bg-green-500 rounded-full transition-all" style={{ width: `${progress}%` }} />
                </div>
              </div>
            )}
            <p className="text-xs text-muted-foreground mb-2">{campDonations.length} donations</p>
            <button onClick={() => setShowDonateForm(showDonateForm === c.id ? null : c.id)}
              className="text-xs text-primary underline flex items-center gap-1">
              <Upload className="w-3 h-3" /> Record Donation
            </button>
            {showDonateForm === c.id && (
              <div className="mt-3 flex flex-col gap-2 pt-3 border-t border-border">
                <FlatMultiSelect
                  compact
                  flats={flats.map(f => ({ id: f.id, flat_number: f.flat_number }))}
                  selected={df.selected_flats}
                  onChange={nums => setDf({ ...df, selected_flats: nums })}
                  label="Flats"
                />
                <input className="input-field text-sm" placeholder="Resident Name" value={df.resident_name} onChange={e => setDf({...df, resident_name: e.target.value})} />
                <input className="input-field text-sm" placeholder="Amount (₹)" type="number" value={df.amount} onChange={e => setDf({...df, amount: e.target.value})} />
                <select className="input-field text-sm" value={df.payment_method} onChange={e => setDf({...df, payment_method: e.target.value})}>
                  <option value="cash">Cash</option><option value="upi">UPI</option><option value="bank_transfer">Bank Transfer</option>
                </select>
                {df.payment_method !== 'cash' && (
                  <>
                    <input className="input-field text-sm" placeholder="Transaction ID" value={df.transaction_id} onChange={e => setDf({...df, transaction_id: e.target.value})} />
                    <input className="input-field text-sm" placeholder="Screenshot URL" value={df.screenshot_url} onChange={e => setDf({...df, screenshot_url: e.target.value})} />
                  </>
                )}
                <button onClick={() => addDonation(c.id)} className="btn-primary text-sm">Record</button>
              </div>
            )}
            {campDonations.length > 0 && (
              <div className="mt-3 space-y-1">
                {campDonations.slice(0, 5).map(d => (
                  <div key={d.id} className="flex justify-between text-xs bg-muted/50 rounded p-2">
                    <span>{d.flat_number} · {d.resident_name}</span>
                    <span className="font-bold">₹{d.amount}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
};

export default DonationManager;
