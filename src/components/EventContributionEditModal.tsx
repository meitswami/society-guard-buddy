import { useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import { DateInput } from '@/components/DateInput';
import { residentLabelForFlatRow } from '@/lib/flatMultiSelectOptions';

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

type ContribRow = {
  id: string;
  event_id: string | null;
  receipt_basis: string | null;
  flat_number: string | null;
  flat_id: string | null;
  amount: number;
  payment_method: string;
  transaction_id: string | null;
  screenshot_url: string | null;
  batch_label: string | null;
  outsider_name: string | null;
  resident_name: string | null;
  verified_at: string | null;
};

interface Props {
  contributionId: string | null;
  onClose: () => void;
  onSaved: () => void;
  adminName?: string;
}

const EventContributionEditModal = ({ contributionId, onClose, onSaved, adminName = 'Admin' }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null }[]>([]);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [row, setRow] = useState<ContribRow | null>(null);
  const [form, setForm] = useState({
    amount: '',
    payment_method: 'cash',
    transaction_id: '',
    screenshot_url: '',
    batch_label: '',
    flat_number: '',
    verified_date: '',
  });

  useEffect(() => {
    if (!contributionId || !societyId) {
      setRow(null);
      return;
    }
    let cancelled = false;
    setLoading(true);
    void (async () => {
      const [contribRes, flatRes] = await Promise.all([
        supabase.from('event_contributions').select('*').eq('id', contributionId).maybeSingle(),
        supabase.from('flats').select('id, flat_number, owner_name').eq('society_id', societyId).order('flat_number'),
      ]);
      if (cancelled) return;
      const c = contribRes.data as ContribRow | null;
      if (!c) {
        toast.error('Receipt not found');
        onClose();
        return;
      }
      setRow(c);
      setForm({
        amount: String(c.amount ?? ''),
        payment_method: c.payment_method || 'cash',
        transaction_id: c.transaction_id || '',
        screenshot_url: c.screenshot_url || '',
        batch_label: c.batch_label || c.outsider_name || c.resident_name || '',
        flat_number: c.flat_number || '',
        verified_date: c.verified_at ? c.verified_at.slice(0, 10) : '',
      });
      const flatList = flatRes.data ?? [];
      setFlats(flatList);
      const flatIds = flatList.map((f) => f.id);
      if (flatIds.length) {
        const { data: members } = await supabase
          .from('members')
          .select('flat_id, name')
          .eq('is_primary', true)
          .in('flat_id', flatIds);
        if (!cancelled) {
          const map = new Map<string, string>();
          for (const m of members ?? []) {
            if (m.flat_id && m.name?.trim()) map.set(m.flat_id, m.name.trim());
          }
          setPrimaryByFlatId(map);
        }
      }
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [contributionId, societyId, onClose]);

  const save = async () => {
    if (!row) return;
    const amount = Number(form.amount);
    if (!amount || amount <= 0) {
      toast.error('Enter a valid amount');
      return;
    }
    const isNonFlat = row.receipt_basis === 'non_flat' || !row.flat_number;
    if (isNonFlat && !form.batch_label.trim()) {
      toast.error('Enter payer / description');
      return;
    }
    if (!isNonFlat && !form.flat_number.trim()) {
      toast.error('Select a flat');
      return;
    }

    let screenshotUrl = form.screenshot_url.trim() || null;
    const fileInput = document.getElementById('contrib-edit-receipt-file') as HTMLInputElement | null;
    const file = fileInput?.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/') && file.type !== 'application/pdf') {
        toast.error('Receipt: use image or PDF');
        return;
      }
      setUploading(true);
      screenshotUrl = await uploadContributionReceipt(file);
      setUploading(false);
      if (!screenshotUrl) return;
    }

    const flat = flats.find((f) => f.flat_number === form.flat_number.trim());
    const label = form.batch_label.trim();
    const payload: Record<string, unknown> = {
      amount,
      payment_method: form.payment_method,
      transaction_id: form.transaction_id.trim() || null,
      screenshot_url: screenshotUrl,
      verified_by: adminName,
      verified_at: form.verified_date ? `${form.verified_date}T12:00:00.000Z` : row.verified_at,
    };

    if (isNonFlat) {
      payload.batch_label = label;
      payload.resident_name = label;
      payload.outsider_name = /outsider|sponsor|vendor|guest/i.test(label) ? label : null;
      payload.flat_number = null;
      payload.flat_id = null;
    } else {
      payload.flat_number = form.flat_number.trim();
      payload.flat_id = flat?.id ?? null;
      payload.resident_name = flat
        ? residentLabelForFlatRow(flat.id, flat.owner_name, primaryByFlatId)
        : form.flat_number.trim();
    }

    setSaving(true);
    const { error } = await supabase.from('event_contributions').update(payload).eq('id', row.id);
    setSaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Contribution receipt updated');
    onSaved();
    onClose();
  };

  const remove = async () => {
    if (!row) return;
    const ok = await confirmAction('Delete this contribution receipt?', 'This cannot be undone.', 'Delete', 'Cancel');
    if (!ok) return;
    const { error } = await supabase.from('event_contributions').delete().eq('id', row.id);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Receipt deleted');
    onSaved();
    onClose();
  };

  if (!contributionId) return null;

  const isNonFlat =
    row?.receipt_basis === 'non_flat' || Boolean(row && !row.flat_number && (row.batch_label || row.receipt_basis !== 'flat'));

  return (
    <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
      <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3 max-h-[90vh] overflow-auto">
        <div className="flex items-start justify-between gap-2">
          <div>
            <p className="text-sm font-semibold">Edit contribution receipt</p>
            <p className="text-[10px] text-muted-foreground">
              {isNonFlat ? 'Without flat — single receipt' : 'Flat-wise receipt row'}
              {row?.split_mode ? ` · ${row.split_mode.replace(/_/g, ' ')}` : ''}
            </p>
          </div>
          <button type="button" className="text-xs px-2 py-1 border rounded-md shrink-0" onClick={onClose}>
            Close
          </button>
        </div>

        {loading ? (
          <p className="text-xs text-muted-foreground py-4 text-center">Loading…</p>
        ) : (
          <>
            {isNonFlat ? (
              <input
                className="input-field"
                placeholder="Payer / description"
                value={form.batch_label}
                onChange={(e) => setForm({ ...form, batch_label: e.target.value })}
              />
            ) : (
              <select
                className="input-field"
                value={form.flat_number}
                onChange={(e) => setForm({ ...form, flat_number: e.target.value })}
              >
                <option value="">Select flat</option>
                {flats.map((f) => (
                  <option key={f.id} value={f.flat_number}>
                    Flat {f.flat_number}
                  </option>
                ))}
              </select>
            )}
            <input
              className="input-field"
              type="number"
              placeholder="Amount (₹)"
              value={form.amount}
              onChange={(e) => setForm({ ...form, amount: e.target.value })}
            />
            <select
              className="input-field"
              value={form.payment_method}
              onChange={(e) => setForm({ ...form, payment_method: e.target.value })}
            >
              <option value="cash">Cash</option>
              <option value="upi">UPI</option>
              <option value="bank_transfer">Bank transfer</option>
              <option value="cheque">Cheque</option>
              <option value="other">Other</option>
            </select>
            <input
              className="input-field"
              placeholder="Transaction / reference ID (optional)"
              value={form.transaction_id}
              onChange={(e) => setForm({ ...form, transaction_id: e.target.value })}
            />
            <div>
              <label className="text-[10px] font-medium text-muted-foreground uppercase">Receipt date</label>
              <DateInput
                className="input-field"
                value={form.verified_date}
                onChange={(e) => setForm({ ...form, verified_date: e.target.value })}
              />
            </div>
            <label className="text-[10px] font-medium text-muted-foreground">Payment proof</label>
            {form.screenshot_url && (
              <a href={form.screenshot_url} target="_blank" rel="noreferrer" className="text-[10px] text-primary underline block">
                View current attachment
              </a>
            )}
            <input id="contrib-edit-receipt-file" type="file" accept="image/*,application/pdf" className="text-xs" />
            <input
              className="input-field text-sm"
              placeholder="Or paste screenshot URL"
              value={form.screenshot_url}
              onChange={(e) => setForm({ ...form, screenshot_url: e.target.value })}
            />
            <div className="flex gap-2 pt-1">
              <button type="button" className="btn-primary flex-1" disabled={saving || uploading} onClick={() => void save()}>
                {saving || uploading ? 'Saving…' : 'Save changes'}
              </button>
              <button
                type="button"
                className="text-xs px-3 py-2 rounded-lg border border-destructive text-destructive shrink-0"
                onClick={() => void remove()}
              >
                Delete
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default EventContributionEditModal;
