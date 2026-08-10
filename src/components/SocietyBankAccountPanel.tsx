import { useCallback, useEffect, useState } from 'react';
import { Building2, Copy, Landmark, Loader2, Save } from 'lucide-react';
import { toast } from 'sonner';
import { useStore } from '@/store/useStore';
import {
  copyableBankDetails,
  type SocietyBankAccount,
  type SocietyBankAccountInput,
} from '@/lib/societyBankAccount';
import {
  fetchSocietyBankAccounts,
  upsertSocietyBankAccount,
} from '@/services/societyBankAccountService';

const emptyForm = (): SocietyBankAccountInput => ({
  bank_name: '',
  account_holder_name: '',
  account_number: '',
  ifsc: '',
  branch_name: '',
  branch_address: '',
  micr: '',
  account_type: '',
  currency: 'INR',
  upi_vpa: '',
  customer_id: '',
  is_primary: true,
  is_active: true,
  effective_from: '',
  notes: '',
});

export default function SocietyBankAccountPanel() {
  const societyId = useStore((s) => s.societyId);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [accounts, setAccounts] = useState<SocietyBankAccount[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<SocietyBankAccountInput>(emptyForm());

  const load = useCallback(async () => {
    if (!societyId) {
      setAccounts([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const rows = await fetchSocietyBankAccounts(societyId);
      setAccounts(rows);
      const primary = rows.find((r) => r.is_primary && r.is_active) ?? rows[0] ?? null;
      if (primary) {
        setEditingId(primary.id);
        setForm({
          bank_name: primary.bank_name,
          account_holder_name: primary.account_holder_name,
          account_number: primary.account_number,
          ifsc: primary.ifsc,
          branch_name: primary.branch_name ?? '',
          branch_address: primary.branch_address ?? '',
          micr: primary.micr ?? '',
          account_type: primary.account_type ?? '',
          currency: primary.currency || 'INR',
          upi_vpa: primary.upi_vpa ?? '',
          customer_id: primary.customer_id ?? '',
          is_primary: primary.is_primary,
          is_active: primary.is_active,
          effective_from: primary.effective_from?.slice(0, 10) ?? '',
          notes: primary.notes ?? '',
        });
      } else {
        setEditingId(null);
        setForm(emptyForm());
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not load bank accounts');
    } finally {
      setLoading(false);
    }
  }, [societyId]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    if (!societyId) return;
    if (!form.bank_name.trim() || !form.account_holder_name.trim() || !form.account_number.trim() || !form.ifsc.trim()) {
      toast.error('Bank name, account holder, account number and IFSC are required');
      return;
    }
    setSaving(true);
    try {
      await upsertSocietyBankAccount(societyId, form, editingId);
      toast.success(editingId ? 'Society bank account updated' : 'Society bank account saved');
      await load();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save bank account');
    } finally {
      setSaving(false);
    }
  };

  const copyDetails = async () => {
    const active = accounts.find((a) => a.id === editingId) ?? accounts.find((a) => a.is_primary && a.is_active);
    if (!active) {
      toast.error('Save the account first');
      return;
    }
    try {
      await navigator.clipboard.writeText(copyableBankDetails(active));
      toast.success('Bank details copied');
    } catch {
      toast.error('Could not copy');
    }
  };

  if (!societyId) return null;

  return (
    <div className="card-section mb-4">
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex items-start gap-2">
          <div className="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
            <Landmark className="w-4 h-4 text-primary" />
          </div>
          <div>
            <h2 className="text-sm font-semibold">Society bank account</h2>
            <p className="text-[10px] text-muted-foreground leading-relaxed mt-0.5">
              Members use these details for UPI / NEFT / IMPS maintenance payments. Keep IFSC and account number accurate.
            </p>
          </div>
        </div>
        {accounts.some((a) => a.is_active) && (
          <button type="button" className="btn-secondary text-xs inline-flex items-center gap-1 shrink-0" onClick={() => void copyDetails()}>
            <Copy className="w-3.5 h-3.5" /> Copy
          </button>
        )}
      </div>

      {loading ? (
        <div className="flex items-center gap-2 text-xs text-muted-foreground py-6 justify-center">
          <Loader2 className="w-4 h-4 animate-spin" /> Loading…
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
          <div className="sm:col-span-2">
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Account holder name *</label>
            <input
              className="input-field mt-1"
              value={form.account_holder_name}
              onChange={(e) => setForm((p) => ({ ...p, account_holder_name: e.target.value }))}
              placeholder="M/S. SOCIETY NAME"
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Bank *</label>
            <input
              className="input-field mt-1"
              value={form.bank_name}
              onChange={(e) => setForm((p) => ({ ...p, bank_name: e.target.value }))}
              placeholder="HDFC Bank"
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">IFSC *</label>
            <input
              className="input-field mt-1 uppercase"
              value={form.ifsc}
              onChange={(e) => setForm((p) => ({ ...p, ifsc: e.target.value.toUpperCase() }))}
              placeholder="HDFC0000000"
            />
          </div>
          <div className="sm:col-span-2">
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Account number *</label>
            <input
              className="input-field mt-1 font-mono"
              value={form.account_number}
              onChange={(e) => setForm((p) => ({ ...p, account_number: e.target.value }))}
              placeholder="Account number"
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Branch</label>
            <input
              className="input-field mt-1"
              value={form.branch_name ?? ''}
              onChange={(e) => setForm((p) => ({ ...p, branch_name: e.target.value }))}
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">UPI ID (optional)</label>
            <input
              className="input-field mt-1"
              value={form.upi_vpa ?? ''}
              onChange={(e) => setForm((p) => ({ ...p, upi_vpa: e.target.value }))}
              placeholder="society@okhdfcbank"
            />
          </div>
          <div className="sm:col-span-2">
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Branch address</label>
            <input
              className="input-field mt-1"
              value={form.branch_address ?? ''}
              onChange={(e) => setForm((p) => ({ ...p, branch_address: e.target.value }))}
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">MICR</label>
            <input
              className="input-field mt-1"
              value={form.micr ?? ''}
              onChange={(e) => setForm((p) => ({ ...p, micr: e.target.value }))}
            />
          </div>
          <div>
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Account type</label>
            <input
              className="input-field mt-1"
              value={form.account_type ?? ''}
              onChange={(e) => setForm((p) => ({ ...p, account_type: e.target.value }))}
            />
          </div>
          <div className="sm:col-span-2">
            <label className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Notes (admin only)</label>
            <textarea
              className="input-field mt-1 min-h-[64px]"
              value={form.notes ?? ''}
              onChange={(e) => setForm((p) => ({ ...p, notes: e.target.value }))}
            />
          </div>
          <div className="sm:col-span-2 flex flex-wrap gap-2 mt-1">
            <button type="button" className="btn-primary text-sm inline-flex items-center gap-1.5" onClick={() => void save()} disabled={saving}>
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              {editingId ? 'Update bank account' : 'Save bank account'}
            </button>
            {editingId && (
              <button
                type="button"
                className="btn-secondary text-sm inline-flex items-center gap-1.5"
                onClick={() => {
                  setEditingId(null);
                  setForm(emptyForm());
                }}
              >
                <Building2 className="w-4 h-4" /> Add another
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
