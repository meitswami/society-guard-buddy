import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Calendar, Plus, Users, Upload } from 'lucide-react';
import { toast } from 'sonner';
import { format } from 'date-fns';

interface Props { adminName?: string; }

const EventManager = ({ adminName = 'Admin' }: Props) => {
  const [events, setEvents] = useState<any[]>([]);
  const [rsvps, setRsvps] = useState<any[]>([]);
  const [contributions, setContributions] = useState<any[]>([]);
  const [flats, setFlats] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [showContrib, setShowContrib] = useState<string | null>(null);
  const [ef, setEf] = useState({ title: '', description: '', event_date: '', event_time: '', location: '', contribution_amount: '' });
  const [cf, setCf] = useState({ flat_number: '', resident_name: '', amount: '', payment_method: 'cash', screenshot_url: '' });

  useEffect(() => { loadAll(); }, []);
  const loadAll = async () => {
    const [e, r, c, f] = await Promise.all([
      supabase.from('events').select('*').order('event_date', { ascending: false }),
      supabase.from('event_rsvps').select('*'),
      supabase.from('event_contributions').select('*'),
      supabase.from('flats').select('flat_number, id').order('flat_number'),
    ]);
    if (e.data) setEvents(e.data);
    if (r.data) setRsvps(r.data);
    if (c.data) setContributions(c.data);
    if (f.data) setFlats(f.data);
  };

  const addEvent = async () => {
    if (!ef.title || !ef.event_date) return;
    await supabase.from('events').insert([{
      title: ef.title, description: ef.description || null, event_date: ef.event_date,
      event_time: ef.event_time || null, location: ef.location || null,
      contribution_amount: Number(ef.contribution_amount) || 0, created_by: adminName,
    }]);
    setEf({ title: '', description: '', event_date: '', event_time: '', location: '', contribution_amount: '' });
    setShowForm(false); toast.success('Event created'); loadAll();

    // Notify all residents
    await supabase.from('notifications').insert([{
      title: `New Event: ${ef.title}`,
      message: `${ef.title} on ${ef.event_date}${ef.location ? ' at ' + ef.location : ''}. ${ef.contribution_amount ? 'Contribution: ₹' + ef.contribution_amount : ''}`,
      type: 'event', target_type: 'all', created_by: adminName,
    }]);
  };

  const recordContribution = async (eventId: string) => {
    if (!cf.flat_number || !cf.amount) return;
    const flat = flats.find(f => f.flat_number === cf.flat_number);
    await supabase.from('event_contributions').insert([{
      event_id: eventId, flat_id: flat?.id || null, flat_number: cf.flat_number,
      resident_name: cf.resident_name, amount: Number(cf.amount), payment_method: cf.payment_method,
      screenshot_url: cf.screenshot_url || null, verified_by: adminName, verified_at: new Date().toISOString(),
    }]);
    setCf({ flat_number: '', resident_name: '', amount: '', payment_method: 'cash', screenshot_url: '' });
    setShowContrib(null); toast.success('Contribution recorded'); loadAll();
  };

  const sendContribReminders = async (event: any) => {
    const paidFlats = contributions.filter(c => c.event_id === event.id).map(c => c.flat_number);
    const unpaid = flats.filter(f => !paidFlats.includes(f.flat_number));
    for (const flat of unpaid) {
      await supabase.from('notifications').insert([{
        title: `Payment Due: ${event.title}`,
        message: `Flat ${flat.flat_number}, your contribution of ₹${event.contribution_amount} for ${event.title} is pending.`,
        type: 'event_reminder', target_type: 'flat', target_id: flat.flat_number, created_by: adminName,
      }]);
    }
    toast.success(`Reminders sent to ${unpaid.length} flats`);
  };

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
          <Calendar className="w-5 h-5 text-blue-500" />
        </div>
        <h1 className="page-title">Events & Functions</h1>
      </div>

      <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
        <Plus className="w-4 h-4" /> Create Event
      </button>

      {showForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <input className="input-field" placeholder="Event Title" value={ef.title} onChange={e => setEf({...ef, title: e.target.value})} />
          <textarea className="input-field" placeholder="Description" value={ef.description} onChange={e => setEf({...ef, description: e.target.value})} />
          <div className="grid grid-cols-2 gap-2">
            <input className="input-field" type="date" value={ef.event_date} onChange={e => setEf({...ef, event_date: e.target.value})} />
            <input className="input-field" type="time" value={ef.event_time} onChange={e => setEf({...ef, event_time: e.target.value})} />
          </div>
          <input className="input-field" placeholder="Location" value={ef.location} onChange={e => setEf({...ef, location: e.target.value})} />
          <input className="input-field" placeholder="Contribution Amount (₹)" type="number" value={ef.contribution_amount} onChange={e => setEf({...ef, contribution_amount: e.target.value})} />
          <button onClick={addEvent} className="btn-primary">Create Event</button>
        </div>
      )}

      {events.map(ev => {
        const evRsvps = rsvps.filter(r => r.event_id === ev.id);
        const evContribs = contributions.filter(c => c.event_id === ev.id);
        const totalCollected = evContribs.reduce((s, c) => s + Number(c.amount), 0);
        return (
          <div key={ev.id} className="card-section p-4 mb-3">
            <div className="flex justify-between items-start mb-2">
              <div>
                <p className="font-semibold">{ev.title}</p>
                {ev.description && <p className="text-xs text-muted-foreground">{ev.description}</p>}
                <p className="text-xs text-muted-foreground mt-1">📅 {ev.event_date} {ev.event_time && `· ⏰ ${ev.event_time}`}</p>
                {ev.location && <p className="text-xs text-muted-foreground">📍 {ev.location}</p>}
              </div>
              <span className={`text-[10px] px-2 py-0.5 rounded-full ${ev.status === 'upcoming' ? 'bg-blue-500/20 text-blue-600' : 'bg-muted text-muted-foreground'}`}>{ev.status}</span>
            </div>

            <div className="flex gap-3 text-xs text-muted-foreground mb-2">
              <span><Users className="w-3 h-3 inline" /> {evRsvps.length} RSVPs</span>
              {ev.contribution_amount > 0 && <span>₹{totalCollected} / ₹{ev.contribution_amount * flats.length}</span>}
            </div>

            <div className="flex gap-2">
              {ev.contribution_amount > 0 && (
                <>
                  <button onClick={() => setShowContrib(showContrib === ev.id ? null : ev.id)}
                    className="flex-1 py-1.5 bg-primary/10 text-primary rounded-lg text-xs flex items-center justify-center gap-1">
                    <Upload className="w-3 h-3" /> Record Payment
                  </button>
                  <button onClick={() => sendContribReminders(ev)}
                    className="flex-1 py-1.5 bg-amber-500/10 text-amber-600 rounded-lg text-xs">
                    🔔 Send Reminders
                  </button>
                </>
              )}
            </div>

            {showContrib === ev.id && (
              <div className="mt-3 flex flex-col gap-2 pt-3 border-t border-border">
                <select className="input-field text-sm" value={cf.flat_number} onChange={e => setCf({...cf, flat_number: e.target.value})}>
                  <option value="">Select Flat</option>
                  {flats.map(f => <option key={f.id} value={f.flat_number}>{f.flat_number}</option>)}
                </select>
                <input className="input-field text-sm" placeholder="Resident Name" value={cf.resident_name} onChange={e => setCf({...cf, resident_name: e.target.value})} />
                <input className="input-field text-sm" placeholder="Amount (₹)" type="number" value={cf.amount} onChange={e => setCf({...cf, amount: e.target.value})} />
                <select className="input-field text-sm" value={cf.payment_method} onChange={e => setCf({...cf, payment_method: e.target.value})}>
                  <option value="cash">Cash</option><option value="upi">UPI</option><option value="bank_transfer">Bank Transfer</option>
                </select>
                {cf.payment_method !== 'cash' && (
                  <input className="input-field text-sm" placeholder="Screenshot URL" value={cf.screenshot_url} onChange={e => setCf({...cf, screenshot_url: e.target.value})} />
                )}
                <button onClick={() => recordContribution(ev.id)} className="btn-primary text-sm">Record</button>
              </div>
            )}

            {evContribs.length > 0 && (
              <div className="mt-3 space-y-1">
                {evContribs.slice(0, 5).map(c => (
                  <div key={c.id} className="flex justify-between text-xs bg-muted/50 rounded p-2">
                    <span>{c.flat_number} · {c.resident_name}</span>
                    <span className="font-bold">₹{c.amount}</span>
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

export default EventManager;
