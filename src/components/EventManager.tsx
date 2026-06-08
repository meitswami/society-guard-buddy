import { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Calendar, Plus, Users, Upload } from 'lucide-react';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { flatOptionsWithPrimaryLabel, residentLabelForFlatRow } from '@/lib/flatMultiSelectOptions';
import { computeHeadcountAmounts, headcountForFlat, type FlatMemberRow } from '@/lib/flatHeadcountSplit';
import { toast } from 'sonner';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { DateInput } from '@/components/DateInput';

interface Props {
  adminName?: string;
  embedded?: boolean;
  onRecordsChanged?: () => void;
}

type ReceiptBasis = 'flat' | 'non_flat';
type FlatCollectMode = 'individual' | 'headcount' | 'lump_equal' | 'same_per_flat';

async function uploadContributionReceipt(file: File): Promise<string | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `event-contributions/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, file, { cacheControl: '3600', upsert: false });
  if (error) {
    toast.error(error.message);
    return null;
  }
  const { data } = supabase.storage.from('notification-media').getPublicUrl(path);
  return data.publicUrl;
}

const EventManager = ({ adminName = 'Admin', embedded = false, onRecordsChanged }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [events, setEvents] = useState<any[]>([]);
  const [rsvps, setRsvps] = useState<any[]>([]);
  const [contributions, setContributions] = useState<any[]>([]);
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null; is_occupied: boolean | null }[]>([]);
  const [flatMembers, setFlatMembers] = useState<FlatMemberRow[]>([]);
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [showForm, setShowForm] = useState(false);
  const [showContrib, setShowContrib] = useState<string | null>(null);
  const [ef, setEf] = useState({ title: '', description: '', event_date: '', event_time: '', location: '', contribution_amount: '' });
  const [receiptBasis, setReceiptBasis] = useState<ReceiptBasis>('flat');
  const [flatCollectMode, setFlatCollectMode] = useState<FlatCollectMode>('same_per_flat');
  const [cf, setCf] = useState({
    selected_flats: [] as string[],
    amount: '',
    payment_method: 'cash',
    screenshot_url: '',
  });
  const [perFlatAmounts, setPerFlatAmounts] = useState<Record<string, string>>({});
  const [headcountTotal, setHeadcountTotal] = useState('');
  const [lumpTotal, setLumpTotal] = useState('');
  const [nonFlatLabel, setNonFlatLabel] = useState('');
  const [adultWeight, setAdultWeight] = useState('1');
  const [childWeight, setChildWeight] = useState('0.5');
  const [receiptUploading, setReceiptUploading] = useState(false);

  useEffect(() => { loadAll(); }, [societyId]);

  const loadAll = async () => {
    if (!societyId) {
      setEvents([]);
      setRsvps([]);
      setContributions([]);
      setFlats([]);
      setFlatMembers([]);
      setPrimaryByFlatId(new Map());
      return;
    }
    const [e, f] = await Promise.all([
      supabase.from('events').select('*').eq('society_id', societyId).order('event_date', { ascending: false }),
      supabase.from('flats').select('flat_number, id, owner_name, is_occupied').eq('society_id', societyId).order('flat_number'),
    ]);
    if (e.data) setEvents(e.data);
    if (f.data) setFlats(f.data);
    const eventIds = (e.data ?? []).map((x) => x.id);
    const flatIds = (f.data ?? []).map((x) => x.id);
    const [r, c, m, membersRes] = await Promise.all([
      eventIds.length ? supabase.from('event_rsvps').select('*').in('event_id', eventIds) : Promise.resolve({ data: [] as any[] }),
      eventIds.length ? supabase.from('event_contributions').select('*').in('event_id', eventIds) : Promise.resolve({ data: [] as any[] }),
      flatIds.length
        ? supabase.from('members').select('flat_id, name').eq('is_primary', true).in('flat_id', flatIds)
        : Promise.resolve({ data: [] as { flat_id: string; name: string }[] }),
      flatIds.length
        ? supabase.from('members').select('id, flat_id, name, age, relation').in('flat_id', flatIds)
        : Promise.resolve({ data: [] as FlatMemberRow[] }),
    ]);
    setRsvps(r.data ?? []);
    setContributions(c.data ?? []);
    setFlatMembers((membersRes.data as FlatMemberRow[]) ?? []);
    const map = new Map<string, string>();
    for (const row of m.data ?? []) {
      if (row.flat_id && row.name?.trim()) map.set(row.flat_id, row.name.trim());
    }
    setPrimaryByFlatId(map);
  };

  const addEvent = async () => {
    if (!societyId || !ef.title || !ef.event_date) return;
    await supabase.from('events').insert([{
      title: ef.title, description: ef.description || null, event_date: ef.event_date,
      event_time: ef.event_time || null, location: ef.location || null,
      contribution_amount: Number(ef.contribution_amount) || 0, created_by: adminName, society_id: societyId,
    }]);
    setEf({ title: '', description: '', event_date: '', event_time: '', location: '', contribution_amount: '' });
    setShowForm(false); toast.success('Event created'); loadAll();

    await supabase.from('notifications').insert([{
      title: `New Event: ${ef.title}`,
      message: `${ef.title} on ${fmtIsoDateToDisplay(ef.event_date)}${ef.location ? ' at ' + ef.location : ''}. ${ef.contribution_amount ? 'Contribution: ₹' + ef.contribution_amount : ''}`,
      type: 'event', target_type: 'all', created_by: adminName, society_id: societyId,
    }]);
  };

  const targetFlats = includeVacantFlats ? flats : flats.filter((f) => f.is_occupied);
  const flatOptions = flatOptionsWithPrimaryLabel(flats, primaryByFlatId);

  const contribTargetFlats = useMemo(() => {
    if (cf.selected_flats.length > 0) return cf.selected_flats;
    return targetFlats.map((f) => f.flat_number);
  }, [cf.selected_flats, targetFlats]);

  const headcountPreview = useMemo(() => {
    const adult = Number(adultWeight) || 1;
    const child = Number(childWeight) || 0.5;
    const rows = contribTargetFlats.map((num) => {
      const flat = flats.find((f) => f.flat_number === num);
      return headcountForFlat(num, flat?.id ?? null, flatMembers, adult, child);
    });
    const total = Number(headcountTotal) || 0;
    const amounts = total > 0 ? computeHeadcountAmounts(total, rows) : [];
    return { rows, amounts, adult, child };
  }, [contribTargetFlats, flats, flatMembers, adultWeight, childWeight, headcountTotal]);

  const resetContribForm = () => {
    setCf({ selected_flats: [], amount: '', payment_method: 'cash', screenshot_url: '' });
    setReceiptBasis('flat');
    setFlatCollectMode('same_per_flat');
    setPerFlatAmounts({});
    setHeadcountTotal('');
    setLumpTotal('');
    setNonFlatLabel('');
  };

  const uploadReceiptForEvent = async (eventId: string): Promise<string | null> => {
    let screenshotUrl = cf.screenshot_url.trim() || null;
    const fileInput = document.getElementById(`event-contrib-receipt-${eventId}`) as HTMLInputElement | null;
    const file = fileInput?.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/') && file.type !== 'application/pdf') {
        toast.error('Receipt: use image or PDF');
        return null;
      }
      if (file.size > 8 * 1024 * 1024) {
        toast.error('Receipt file must be 8MB or smaller');
        return null;
      }
      setReceiptUploading(true);
      screenshotUrl = await uploadContributionReceipt(file);
      setReceiptUploading(false);
      if (!screenshotUrl) return null;
      if (fileInput) fileInput.value = '';
    }
    return screenshotUrl;
  };

  const buildContributionRows = (
    eventId: string,
    screenshotUrl: string | null,
    verifiedAt: string,
  ): Array<Record<string, unknown>> => {
    const batchId = crypto.randomUUID();
    const base = {
      event_id: eventId,
      payment_method: cf.payment_method,
      screenshot_url: screenshotUrl,
      verified_by: adminName,
      verified_at: verifiedAt,
      batch_id: batchId,
    };

    if (receiptBasis === 'non_flat') {
      const amount = Number(cf.amount);
      const label = nonFlatLabel.trim();
      if (!label) {
        toast.error('Enter payer name or description (outsider or collective receipt)');
        return [];
      }
      if (!amount || amount <= 0) {
        toast.error('Enter receipt amount');
        return [];
      }
      const isOutsider = /outsider|sponsor|vendor|guest/i.test(label) || label.toLowerCase().includes('outsider');
      return [{
        ...base,
        receipt_basis: 'non_flat',
        contributor_type: isOutsider ? 'outsider' : 'flat_owner',
        outsider_name: isOutsider ? label : null,
        batch_label: label,
        flat_number: null,
        flat_id: null,
        resident_name: label,
        amount,
        split_mode: 'non_flat',
        adult_count: null,
        kid_count: null,
      }];
    }

    if (contribTargetFlats.length === 0) {
      toast.error('Select at least one flat');
      return [];
    }

    const flatRowBase = {
      ...base,
      receipt_basis: 'flat',
      contributor_type: 'flat_owner',
      outsider_name: null,
      batch_label: null,
    };

    if (flatCollectMode === 'individual') {
      const entries = contribTargetFlats
        .map((num) => [num, Number(perFlatAmounts[num] || 0)] as const)
        .filter(([, amt]) => amt > 0);
      if (entries.length === 0) {
        toast.error('Enter amount for at least one flat');
        return [];
      }
      return entries.map(([flat_number, amount]) => {
        const flat = flats.find((f) => f.flat_number === flat_number);
        const hc = headcountForFlat(flat_number, flat?.id ?? null, flatMembers, 1, 0.5);
        return {
          ...flatRowBase,
          flat_number,
          flat_id: flat?.id ?? null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
          amount,
          split_mode: 'individual',
          adult_count: hc.adults,
          kid_count: hc.kids,
        };
      });
    }

    if (flatCollectMode === 'headcount') {
      const total = Number(headcountTotal);
      if (!total || total <= 0) {
        toast.error('Enter total amount to distribute by adults & kids');
        return [];
      }
      const { rows, amounts } = headcountPreview;
      if (rows.reduce((s, r) => s + r.units, 0) <= 0) {
        toast.error('No headcount units — add members (age/relation) per flat in Residents');
        return [];
      }
      return amounts.map(({ flat_number, amount, adults, kids }) => {
        const flat = flats.find((f) => f.flat_number === flat_number);
        return {
          ...flatRowBase,
          flat_number,
          flat_id: flat?.id ?? null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
          amount,
          split_mode: 'headcount',
          adult_count: adults,
          kid_count: kids,
        };
      });
    }

    if (flatCollectMode === 'lump_equal') {
      const total = Number(lumpTotal);
      if (!total || total <= 0) {
        toast.error('Enter lump sum total to split equally across flats');
        return [];
      }
      const share = Number((total / contribTargetFlats.length).toFixed(2));
      let allocated = 0;
      return contribTargetFlats.map((flat_number, i) => {
        const flat = flats.find((f) => f.flat_number === flat_number);
        const isLast = i === contribTargetFlats.length - 1;
        const amount = isLast ? Number((total - allocated).toFixed(2)) : share;
        allocated += amount;
        const hc = headcountForFlat(flat_number, flat?.id ?? null, flatMembers, 1, 0.5);
        return {
          ...flatRowBase,
          flat_number,
          flat_id: flat?.id ?? null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
          amount,
          split_mode: 'lump_equal',
          adult_count: hc.adults,
          kid_count: hc.kids,
        };
      });
    }

    const amount = Number(cf.amount);
    if (!amount || amount <= 0) {
      toast.error('Enter amount per flat');
      return [];
    }
    const targets = cf.selected_flats.length > 0 ? cf.selected_flats : [];
    if (targets.length === 0) {
      toast.error('Select at least one flat for same-amount receipt');
      return [];
    }
    return targets.map((flat_number) => {
      const flat = flats.find((f) => f.flat_number === flat_number);
      const hc = headcountForFlat(flat_number, flat?.id ?? null, flatMembers, 1, 0.5);
      return {
        ...flatRowBase,
        flat_number,
        flat_id: flat?.id ?? null,
        resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
        amount,
        split_mode: 'same_per_flat',
        adult_count: hc.adults,
        kid_count: hc.kids,
      };
    });
  };

  const recordContribution = async (eventId: string) => {
    if (receiptBasis === 'flat' && flatCollectMode === 'same_per_flat' && cf.selected_flats.length === 0) {
      toast.error('Select at least one flat');
      return;
    }

    const screenshotUrl = await uploadReceiptForEvent(eventId);
    if (screenshotUrl === null && document.getElementById(`event-contrib-receipt-${eventId}`)?.files?.length) {
      return;
    }

    const verifiedAt = new Date().toISOString();
    const rows = buildContributionRows(eventId, screenshotUrl, verifiedAt);
    if (rows.length === 0) return;

    const { error } = await supabase.from('event_contributions').insert(rows);
    if (error) {
      toast.error(error.message);
      return;
    }

    resetContribForm();
    setShowContrib(null);
    toast.success(rows.length > 1 ? `Contributions recorded (${rows.length} rows)` : 'Contribution recorded');
    await loadAll();
    onRecordsChanged?.();
  };

  const sendContribReminders = async (event: any) => {
    const paidFlats = contributions
      .filter((c) => c.event_id === event.id && c.receipt_basis !== 'non_flat' && c.flat_number)
      .map((c) => c.flat_number as string);
    const unpaid = targetFlats.filter(f => !paidFlats.includes(f.flat_number));
    for (const flat of unpaid) {
      await supabase.from('notifications').insert([{
        title: `Payment Due: ${event.title}`,
        message: `Flat ${flat.flat_number}, your contribution of ₹${event.contribution_amount} for ${event.title} is pending.`,
        type: 'event_reminder', target_type: 'flat', target_id: flat.flat_number, created_by: adminName, society_id: societyId,
      }]);
    }
    toast.success(`Reminders sent to ${unpaid.length} flats`);
  };

  const contribLabel = (c: any) => {
    if (c.receipt_basis === 'non_flat' || !c.flat_number) {
      return `No flat · ${c.batch_label || c.outsider_name || c.resident_name || 'Receipt'}`;
    }
    const parts = [`Flat ${c.flat_number}`];
    if (c.resident_name) parts.push(c.resident_name);
    if (c.adult_count != null || c.kid_count != null) {
      parts.push(`${c.adult_count ?? 0}A/${c.kid_count ?? 0}K`);
    }
    if (c.split_mode === 'headcount') parts.push('headcount');
    if (c.split_mode === 'lump_equal') parts.push('lump ÷');
    return parts.join(' · ');
  };

  return (
    <div className={embedded ? '' : 'page-container pb-24'}>
      {!embedded && (
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
            <Calendar className="w-5 h-5 text-blue-500" />
          </div>
          <h1 className="page-title">Events &amp; Functions</h1>
        </div>
      )}

      <div className="card-section p-3 mb-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <p className="text-xs font-medium text-foreground">Contribution base</p>
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

      <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
        <Plus className="w-4 h-4" /> Create Event
      </button>

      {showForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <input className="input-field" placeholder="Event Title" value={ef.title} onChange={e => setEf({...ef, title: e.target.value})} />
          <textarea className="input-field" placeholder="Description" value={ef.description} onChange={e => setEf({...ef, description: e.target.value})} />
          <div className="grid grid-cols-2 gap-2">
            <DateInput className="input-field" value={ef.event_date} onChange={e => setEf({...ef, event_date: e.target.value})} />
            <input className="input-field" type="time" value={ef.event_time} onChange={e => setEf({...ef, event_time: e.target.value})} />
          </div>
          <input className="input-field" placeholder="Location" value={ef.location} onChange={e => setEf({...ef, location: e.target.value})} />
          <input className="input-field" placeholder="Suggested contribution per flat (₹)" type="number" value={ef.contribution_amount} onChange={e => setEf({...ef, contribution_amount: e.target.value})} />
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
                <p className="text-xs text-muted-foreground mt-1">
                  📅 {fmtIsoDateToDisplay(ev.event_date)} {ev.event_time && `· ⏰ ${ev.event_time}`}
                </p>
                {ev.location && <p className="text-xs text-muted-foreground">📍 {ev.location}</p>}
              </div>
              <span className={`text-[10px] px-2 py-0.5 rounded-full ${ev.status === 'upcoming' ? 'bg-blue-500/20 text-blue-600' : 'bg-muted text-muted-foreground'}`}>{ev.status}</span>
            </div>

            <div className="flex gap-3 text-xs text-muted-foreground mb-2">
              <span><Users className="w-3 h-3 inline" /> {evRsvps.length} RSVPs</span>
              <span>₹{totalCollected.toLocaleString('en-IN')} collected</span>
              {ev.contribution_amount > 0 && (
                <span>Suggested ₹{ev.contribution_amount}/flat</span>
              )}
            </div>

            <div className="flex gap-2 flex-wrap">
              <button
                type="button"
                onClick={() => {
                  if (showContrib === ev.id) {
                    resetContribForm();
                    setShowContrib(null);
                  } else {
                    resetContribForm();
                    setShowContrib(ev.id);
                  }
                }}
                className="flex-1 min-w-[140px] py-1.5 bg-primary/10 text-primary rounded-lg text-xs flex items-center justify-center gap-1"
              >
                <Upload className="w-3 h-3" /> Record contribution receipt
              </button>
              {ev.contribution_amount > 0 && (
                <button
                  type="button"
                  onClick={() => sendContribReminders(ev)}
                  className="flex-1 min-w-[140px] py-1.5 bg-amber-500/10 text-amber-600 rounded-lg text-xs"
                >
                  🔔 Send Reminders
                </button>
              )}
            </div>

            {showContrib === ev.id && (
              <div className="mt-3 flex flex-col gap-2 pt-3 border-t border-border">
                <p className="text-[10px] font-medium text-muted-foreground uppercase">Contribution receipt (money in)</p>

                <div className="rounded-lg border border-border bg-muted/20 p-2 space-y-2">
                  <p className="text-xs font-medium">Receipt basis</p>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name={`receipt-basis-${ev.id}`}
                      checked={receiptBasis === 'flat'}
                      onChange={() => setReceiptBasis('flat')}
                    />
                    Flat-wise — attribute to one or more flats
                  </label>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name={`receipt-basis-${ev.id}`}
                      checked={receiptBasis === 'non_flat'}
                      onChange={() => setReceiptBasis('non_flat')}
                    />
                    Without flat — single receipt (outsider or collective lump, no flat breakdown)
                  </label>
                </div>

                {receiptBasis === 'non_flat' ? (
                  <>
                    <input
                      className="input-field text-sm"
                      placeholder="Payer / description (e.g. ABC Sponsor, Collective collection)"
                      value={nonFlatLabel}
                      onChange={(e) => setNonFlatLabel(e.target.value)}
                    />
                    <input
                      className="input-field text-sm"
                      placeholder="Total receipt amount (₹)"
                      type="number"
                      value={cf.amount}
                      onChange={(e) => setCf({ ...cf, amount: e.target.value })}
                    />
                    <p className="text-[10px] text-muted-foreground leading-snug">
                      One receipt row — not split to flats. Use flat-wise basis when each flat pays separately.
                    </p>
                  </>
                ) : (
                  <>
                    <div className="rounded-lg border border-border bg-muted/20 p-2 space-y-2">
                      <p className="text-xs font-medium">Flat-wise collection mode</p>
                      <select
                        className="input-field text-sm"
                        value={flatCollectMode}
                        onChange={(e) => {
                          setFlatCollectMode(e.target.value as FlatCollectMode);
                          setPerFlatAmounts({});
                        }}
                      >
                        <option value="same_per_flat">Same amount per selected flat</option>
                        <option value="individual">Individual flat — custom amount each</option>
                        <option value="headcount">By adults &amp; kids per flat (from Residents)</option>
                        <option value="lump_equal">Lump sum — split equally across flats</option>
                      </select>
                    </div>

                    <FlatMultiSelect
                      compact
                      flats={flatOptions}
                      selected={cf.selected_flats}
                      onChange={(nums) => {
                        setCf({ ...cf, selected_flats: nums });
                        setPerFlatAmounts((prev) => {
                          const next: Record<string, string> = {};
                          for (const n of nums) {
                            if (prev[n] !== undefined) next[n] = prev[n];
                          }
                          return next;
                        });
                      }}
                      label={
                        flatCollectMode === 'same_per_flat'
                          ? 'Select flats (required)'
                          : 'Select flats (empty = all eligible flats)'
                      }
                      emptyHint="Pick specific flats or leave empty for all occupied flats."
                    />

                    {flatCollectMode === 'same_per_flat' && (
                      <input
                        className="input-field text-sm"
                        placeholder={ev.contribution_amount > 0 ? `Amount per flat (₹) — suggested ₹${ev.contribution_amount}` : 'Amount per flat (₹)'}
                        type="number"
                        value={cf.amount}
                        onChange={(e) => setCf({ ...cf, amount: e.target.value })}
                      />
                    )}

                    {flatCollectMode === 'individual' && (
                      <div className="rounded-lg border border-border p-2.5 space-y-1.5 max-h-52 overflow-y-auto">
                        <p className="text-[10px] text-muted-foreground">Enter amount for each flat individually.</p>
                        {contribTargetFlats.map((num) => {
                          const flat = flats.find((f) => f.flat_number === num);
                          const hc = headcountForFlat(num, flat?.id ?? null, flatMembers, 1, 0.5);
                          return (
                            <div key={num} className="flex items-center gap-2">
                              <span className="text-xs w-24 shrink-0">
                                Flat {num}
                                <span className="block text-[9px] text-muted-foreground">{hc.adults}A {hc.kids}K</span>
                              </span>
                              <input
                                className="input-field text-xs flex-1"
                                placeholder="₹"
                                type="number"
                                value={perFlatAmounts[num] ?? ''}
                                onChange={(e) => setPerFlatAmounts((p) => ({ ...p, [num]: e.target.value }))}
                              />
                            </div>
                          );
                        })}
                      </div>
                    )}

                    {flatCollectMode === 'headcount' && (
                      <>
                        <div className="grid grid-cols-2 gap-2">
                          <div>
                            <label className="text-[10px] text-muted-foreground uppercase">Adult weight</label>
                            <input className="input-field text-sm" type="number" step="0.1" min="0.1" value={adultWeight} onChange={(e) => setAdultWeight(e.target.value)} />
                          </div>
                          <div>
                            <label className="text-[10px] text-muted-foreground uppercase">Child weight</label>
                            <input className="input-field text-sm" type="number" step="0.1" min="0" value={childWeight} onChange={(e) => setChildWeight(e.target.value)} />
                          </div>
                        </div>
                        <input
                          className="input-field text-sm"
                          placeholder="Total lump sum to distribute by headcount (₹)"
                          type="number"
                          value={headcountTotal}
                          onChange={(e) => setHeadcountTotal(e.target.value)}
                        />
                        <div className="rounded-lg border border-border p-2.5 space-y-1 max-h-40 overflow-y-auto">
                          {headcountPreview.amounts.map(({ flat_number, amount, adults, kids }) => (
                            <div key={flat_number} className="flex justify-between text-xs gap-2">
                              <span>Flat {flat_number}: {adults} adult{adults !== 1 ? 's' : ''}, {kids} kid{kids !== 1 ? 's' : ''}</span>
                              <span className="font-mono shrink-0">₹{amount}</span>
                            </div>
                          ))}
                          {headcountPreview.rows.length === 0 && (
                            <p className="text-xs text-muted-foreground">Select flats or leave empty for all.</p>
                          )}
                        </div>
                      </>
                    )}

                    {flatCollectMode === 'lump_equal' && (
                      <>
                        <input
                          className="input-field text-sm"
                          placeholder="Total lump sum from flat owners (₹)"
                          type="number"
                          value={lumpTotal}
                          onChange={(e) => setLumpTotal(e.target.value)}
                        />
                        <p className="text-[11px] text-muted-foreground">
                          ₹{lumpTotal && contribTargetFlats.length
                            ? (Number(lumpTotal) / contribTargetFlats.length).toFixed(2)
                            : '…'}{' '}
                          per flat (÷ {contribTargetFlats.length || targetFlats.length} flats)
                        </p>
                      </>
                    )}
                  </>
                )}

                <select className="input-field text-sm" value={cf.payment_method} onChange={e => setCf({ ...cf, payment_method: e.target.value })}>
                  <option value="cash">Cash</option>
                  <option value="upi">UPI</option>
                  <option value="bank_transfer">Bank Transfer</option>
                </select>
                <label className="text-[10px] font-medium text-muted-foreground">Upload payment proof (image / PDF)</label>
                <input id={`event-contrib-receipt-${ev.id}`} type="file" accept="image/*,application/pdf" className="text-xs" />
                {cf.payment_method !== 'cash' && (
                  <input
                    className="input-field text-sm"
                    placeholder="Or paste screenshot URL"
                    value={cf.screenshot_url}
                    onChange={e => setCf({ ...cf, screenshot_url: e.target.value })}
                  />
                )}
                <button
                  type="button"
                  onClick={() => void recordContribution(ev.id)}
                  className="btn-primary text-sm"
                  disabled={receiptUploading}
                >
                  {receiptUploading ? 'Uploading…' : 'Save contribution receipt'}
                </button>
              </div>
            )}

            {evContribs.length > 0 && (
              <div className="mt-3 space-y-1">
                <p className="text-[10px] font-semibold text-muted-foreground uppercase">Recorded receipts</p>
                {evContribs.map(c => (
                  <div key={c.id} className="flex flex-col gap-0.5 text-xs bg-muted/50 rounded p-2">
                    <div className="flex justify-between gap-2">
                      <span>
                        {contribLabel(c)}
                        {c.payment_method ? ` · ${c.payment_method}` : ''}
                      </span>
                      <span className="font-bold shrink-0">₹{Number(c.amount).toLocaleString('en-IN')}</span>
                    </div>
                    {c.screenshot_url ? (
                      <a href={c.screenshot_url} target="_blank" rel="noreferrer" className="text-[10px] text-primary underline">
                        View receipt
                      </a>
                    ) : (
                      <span className="text-[10px] text-muted-foreground">No attachment</span>
                    )}
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
