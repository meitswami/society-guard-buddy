import { useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Paperclip, X } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import { DateInput } from '@/components/DateInput';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';

async function uploadExpenseBill(groupId: string, file: File): Promise<string | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `expense-bills/${groupId}/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, file, { cacheControl: '3600', upsert: false });
  if (error) {
    toast.error(error.message);
    return null;
  }
  const { data } = supabase.storage.from('notification-media').getPublicUrl(path);
  return data.publicUrl;
}

interface Props {
  expenseId: string | null;
  onClose: () => void;
  onSaved: () => void;
}

const FoodExpenseEditModal = ({ expenseId, onClose, onSaved }: Props) => {
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [groupId, setGroupId] = useState('');
  const [splitType, setSplitType] = useState('');
  const [form, setForm] = useState({
    title: '',
    total_amount: '',
    vendor_or_service: '',
    expense_date: '',
    recording_date: '',
    payment_method: 'cash',
    notes: '',
    attachment_urls: [] as string[],
  });
  const [newFiles, setNewFiles] = useState<File[]>([]);

  useEffect(() => {
    if (!expenseId) return;
    let cancelled = false;
    setLoading(true);
    void (async () => {
      const { data: exp, error } = await supabase.from('expenses').select('*').eq('id', expenseId).maybeSingle();
      if (cancelled) return;
      if (error || !exp) {
        toast.error('Expense not found');
        onClose();
        return;
      }
      const existingAttachments: string[] = Array.isArray(exp.attachment_urls) ? (exp.attachment_urls as string[]) : [];
      const legacyBill =
        exp.bill_screenshot_url && !existingAttachments.includes(exp.bill_screenshot_url) ? [exp.bill_screenshot_url] : [];
      setGroupId(String(exp.group_id || ''));
      setSplitType(String(exp.split_type || ''));
      setForm({
        title: exp.title ?? '',
        total_amount: String(exp.total_amount ?? ''),
        vendor_or_service: exp.vendor_or_service ?? '',
        expense_date: String(exp.expense_date || '').slice(0, 10),
        recording_date: String(exp.recording_date || exp.created_at || '').slice(0, 10),
        payment_method: exp.payment_method ?? 'cash',
        notes: exp.notes ?? '',
        attachment_urls: [...legacyBill, ...existingAttachments],
      });
      setNewFiles([]);
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [expenseId, onClose]);

  const save = async () => {
    if (!expenseId) return;
    const newTotal = Number(form.total_amount);
    if (!form.title.trim() || !newTotal || newTotal <= 0) {
      toast.error('Enter title and valid amount');
      return;
    }

    let allAttachmentUrls = [...form.attachment_urls];
    if (newFiles.length > 0) {
      setUploading(true);
      for (const file of newFiles) {
        if (file.size > 8 * 1024 * 1024) {
          toast.error(`File too large (max 8 MB): ${file.name}`);
          setUploading(false);
          return;
        }
        const url = await uploadExpenseBill(groupId, file);
        if (!url) {
          setUploading(false);
          return;
        }
        allAttachmentUrls.push(url);
      }
      setUploading(false);
    }

    const { data: old } = await supabase.from('expenses').select('total_amount, split_type').eq('id', expenseId).maybeSingle();
    const oldTotal = Number(old?.total_amount || 0);

    if (old?.split_type !== 'society_fund' && Math.abs(newTotal - oldTotal) > 0.01) {
      const { data: expSplits } = await supabase.from('expense_splits').select('id, amount').eq('expense_id', expenseId);
      if (expSplits?.length) {
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
    }

    setSaving(true);
    const { error } = await supabase
      .from('expenses')
      .update({
        title: form.title.trim(),
        total_amount: newTotal,
        vendor_or_service: form.vendor_or_service.trim() || null,
        expense_date: form.expense_date,
        payment_method: form.payment_method,
        notes: form.notes.trim() || null,
        attachment_urls: allAttachmentUrls,
        bill_screenshot_url: allAttachmentUrls[0] || null,
      })
      .eq('id', expenseId);
    setSaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Food bill updated');
    onSaved();
    onClose();
  };

  const remove = async () => {
    if (!expenseId) return;
    const ok = await confirmAction('Delete this food bill?', 'Removes the expense and flat splits.', 'Delete', 'Cancel');
    if (!ok) return;
    await supabase.from('expense_splits').delete().eq('expense_id', expenseId);
    const { error } = await supabase.from('expenses').delete().eq('id', expenseId);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Food bill deleted');
    onSaved();
    onClose();
  };

  if (!expenseId) return null;

  return (
    <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
      <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3 max-h-[90vh] overflow-auto">
        <div className="flex items-start justify-between gap-2">
          <div>
            <p className="text-sm font-semibold">Edit food bill receipt</p>
            {splitType && splitType !== 'society_fund' && (
              <p className="text-[10px] text-muted-foreground">Changing total rescales flat splits proportionally.</p>
            )}
          </div>
          <button type="button" className="text-xs px-2 py-1 border rounded-md shrink-0" onClick={onClose}>
            Close
          </button>
        </div>

        {loading ? (
          <p className="text-xs text-muted-foreground py-4 text-center">Loading…</p>
        ) : (
          <>
            <input
              className="input-field"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
              placeholder="Bill title / description"
            />
            <input
              className="input-field"
              type="number"
              value={form.total_amount}
              onChange={(e) => setForm({ ...form, total_amount: e.target.value })}
              placeholder="Total (₹)"
            />
            <input
              className="input-field"
              value={form.vendor_or_service}
              onChange={(e) => setForm({ ...form, vendor_or_service: e.target.value })}
              placeholder="Caterer / vendor (optional)"
            />
            <div>
              <label className="text-[10px] font-medium text-muted-foreground uppercase">Bill date</label>
              <DateInput
                className="input-field"
                value={form.expense_date}
                onChange={(e) => setForm({ ...form, expense_date: e.target.value })}
              />
            </div>
            <p className="text-[10px] text-muted-foreground">
              Recorded on: {form.recording_date ? fmtIsoDateToDisplay(form.recording_date) : '—'}
            </p>
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
            <textarea
              className="input-field min-h-[4rem]"
              value={form.notes}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
              placeholder="Notes (optional)"
            />
            <div className="space-y-2">
              <label className="text-[10px] font-medium text-muted-foreground uppercase flex items-center gap-1">
                <Paperclip className="w-3 h-3" /> Bill attachments
              </label>
              {form.attachment_urls.map((url, idx) => {
                const fileName = decodeURIComponent(url.split('/').pop() || 'Attachment').replace(/^[a-f0-9-]+_/, '');
                return (
                  <div key={url} className="flex items-center gap-2 bg-muted/30 rounded px-2 py-1">
                    <a href={url} target="_blank" rel="noreferrer" className="text-[11px] text-primary underline truncate flex-1">
                      {fileName}
                    </a>
                    <button
                      type="button"
                      className="text-destructive shrink-0"
                      onClick={() =>
                        setForm({ ...form, attachment_urls: form.attachment_urls.filter((_, i) => i !== idx) })
                      }
                    >
                      <X className="w-3.5 h-3.5" />
                    </button>
                  </div>
                );
              })}
              <input
                type="file"
                accept="image/*,application/pdf"
                multiple
                className="text-xs"
                onChange={(e) => setNewFiles(Array.from(e.target.files ?? []))}
              />
            </div>
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

export default FoodExpenseEditModal;
