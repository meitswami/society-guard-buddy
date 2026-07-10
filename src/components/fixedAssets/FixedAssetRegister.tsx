import { useMemo, useState } from 'react';
import { Edit, Plus, Search, Trash2, AlertTriangle, Link2 } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import {
  FIXED_ASSET_STATUS_LABELS,
  isAmcExpired,
  isAmcExpiringSoon,
  isWarrantyExpired,
  isWarrantyExpiringSoon,
  type FixedAsset,
  type FixedAssetStatus,
} from '@/lib/fixedAssetTypes';
import FixedAssetForm from '@/components/fixedAssets/FixedAssetForm';
import type { FixedAssetInput } from '@/lib/fixedAssetTypes';

type ExpenseGroup = { id: string; name: string; major_head?: string | null };

type Props = {
  assets: FixedAsset[];
  expenseGroups: ExpenseGroup[];
  loading?: boolean;
  onCreate: (input: FixedAssetInput) => Promise<void>;
  onUpdate: (id: string, input: Partial<FixedAssetInput>) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onNavigateFinance?: () => void;
};

const STATUS_FILTER_OPTIONS: { value: '' | FixedAssetStatus; label: string }[] = [
  { value: '', label: 'All statuses' },
  { value: 'active', label: 'Active' },
  { value: 'placeholder', label: 'Not yet acquired' },
  { value: 'under_repair', label: 'Under repair' },
  { value: 'disposed', label: 'Disposed' },
  { value: 'written_off', label: 'Written off' },
];

function money(n: number | null | undefined) {
  if (n == null) return '—';
  return `₹${n.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
}

function AlertBadge({ label, tone }: { label: string; tone: 'amber' | 'red' }) {
  const cls = tone === 'red' ? 'bg-destructive/10 text-destructive' : 'bg-amber-500/10 text-amber-700';
  return (
    <span className={`text-[10px] px-1.5 py-0.5 rounded inline-flex items-center gap-0.5 ${cls}`}>
      <AlertTriangle className="w-2.5 h-2.5" />
      {label}
    </span>
  );
}

export default function FixedAssetRegister({
  assets,
  expenseGroups,
  loading,
  onCreate,
  onUpdate,
  onDelete,
  onNavigateFinance,
}: Props) {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'' | FixedAssetStatus>('');
  const [subHeadFilter, setSubHeadFilter] = useState('');
  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<FixedAsset | null>(null);
  const [saving, setSaving] = useState(false);

  const subHeads = useMemo(() => {
    const set = new Set(assets.map((a) => a.sub_head?.trim()).filter(Boolean) as string[]);
    return [...set].sort();
  }, [assets]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return assets.filter((a) => {
      if (statusFilter && a.status !== statusFilter) return false;
      if (subHeadFilter && a.sub_head !== subHeadFilter) return false;
      if (!q) return true;
      const hay = [
        a.asset_name,
        a.sub_head,
        a.vendor_name,
        a.location,
        a.asset_tag,
        a.serial_number,
        a.description,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return hay.includes(q);
    });
  }, [assets, search, statusFilter, subHeadFilter]);

  const openAdd = () => {
    setEditing(null);
    setFormOpen(true);
  };

  const openEdit = (asset: FixedAsset) => {
    setEditing(asset);
    setFormOpen(true);
  };

  const handleSave = async (input: FixedAssetInput) => {
    setSaving(true);
    try {
      if (editing) {
        await onUpdate(editing.id, input);
        showSuccess('Updated', 'Fixed asset saved');
      } else {
        await onCreate(input);
        showSuccess('Added', 'Fixed asset registered');
      }
      setFormOpen(false);
      setEditing(null);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save asset');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (asset: FixedAsset) => {
    if (asset.source_type === 'finance_transaction') {
      toast.error('Finance-linked assets cannot be deleted. Remove the payment in Finance instead.');
      return;
    }
    const ok = await confirmAction('Delete asset?', `Remove "${asset.asset_name}" from the register?`, 'Delete', 'Cancel');
    if (!ok) return;
    try {
      await onDelete(asset.id);
      showSuccess('Deleted', 'Asset removed from register');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not delete');
    }
  };

  return (
    <div>
      <div className="flex flex-wrap gap-2 mb-3">
        <div className="relative flex-1 min-w-[140px]">
          <Search className="w-3.5 h-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            className="input-field pl-8 text-xs"
            placeholder="Search asset, vendor, location…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <select className="input-field text-xs w-auto" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value as '' | FixedAssetStatus)}>
          {STATUS_FILTER_OPTIONS.map((o) => (
            <option key={o.value || 'all'} value={o.value}>{o.label}</option>
          ))}
        </select>
        <select className="input-field text-xs w-auto max-w-[140px]" value={subHeadFilter} onChange={(e) => setSubHeadFilter(e.target.value)}>
          <option value="">All sub-heads</option>
          {subHeads.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
        <button type="button" className="btn-primary text-xs px-3 flex items-center gap-1" onClick={openAdd}>
          <Plus className="w-3.5 h-3.5" /> Add asset
        </button>
      </div>

      {loading ? (
        <p className="text-xs text-muted-foreground py-8 text-center">Loading assets…</p>
      ) : filtered.length === 0 ? (
        <div className="card-section p-6 text-center">
          <p className="text-sm text-muted-foreground">No fixed assets match your filters.</p>
          <button type="button" className="btn-primary text-xs mt-3" onClick={openAdd}>Add first asset</button>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map((a) => (
            <div key={a.id} className="card-section p-3">
              <div className="flex justify-between gap-2 items-start">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-1.5 mb-1">
                    <span className="font-semibold text-sm truncate">{a.asset_name}</span>
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                      {FIXED_ASSET_STATUS_LABELS[a.status]}
                    </span>
                    {a.source_type === 'finance_transaction' && (
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary inline-flex items-center gap-0.5">
                        <Link2 className="w-2.5 h-2.5" /> Finance
                      </span>
                    )}
                    {isWarrantyExpiringSoon(a) && <AlertBadge label="Warranty soon" tone="amber" />}
                    {isWarrantyExpired(a) && <AlertBadge label="Warranty expired" tone="red" />}
                    {isAmcExpiringSoon(a) && <AlertBadge label="AMC soon" tone="amber" />}
                    {isAmcExpired(a) && <AlertBadge label="AMC expired" tone="red" />}
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {a.sub_head || 'FIXED ASSETS'}
                    {a.acquisition_date ? ` · ${fmtIsoDateToDisplay(a.acquisition_date)}` : ''}
                    {a.bill_value != null ? ` · ${money(a.bill_value)}` : ''}
                  </p>
                  {(a.vendor_name || a.location) && (
                    <p className="text-[11px] text-muted-foreground mt-0.5">
                      {[a.vendor_name, a.location].filter(Boolean).join(' · ')}
                    </p>
                  )}
                  {a.description && (
                    <p className="text-[11px] text-foreground/80 mt-1 line-clamp-2">{a.description}</p>
                  )}
                  <div className="flex flex-wrap gap-x-3 gap-y-0.5 mt-1.5 text-[10px] text-muted-foreground">
                    {a.warranty_end_date && <span>Warranty till {fmtIsoDateToDisplay(a.warranty_end_date)}</span>}
                    {a.amc_end_date && <span>AMC till {fmtIsoDateToDisplay(a.amc_end_date)}{a.amc_vendor ? ` (${a.amc_vendor})` : ''}</span>}
                  </div>
                </div>
                <div className="flex gap-1 shrink-0">
                  <button type="button" className="p-2 rounded-lg bg-muted/60" onClick={() => openEdit(a)} aria-label="Edit">
                    <Edit className="w-3.5 h-3.5" />
                  </button>
                  <button type="button" className="p-2 rounded-lg bg-destructive/10 text-destructive" onClick={() => handleDelete(a)} aria-label="Delete">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {onNavigateFinance && (
        <p className="text-[11px] text-muted-foreground mt-4 leading-relaxed">
          Payments under Finance → Record Payment with major head <span className="font-medium text-foreground">FIXED ASSETS</span> are added here automatically.
          {' '}
          <button type="button" className="text-primary underline" onClick={onNavigateFinance}>Open Finance</button>
        </p>
      )}

      <FixedAssetForm
        open={formOpen}
        onOpenChange={setFormOpen}
        asset={editing}
        expenseGroups={expenseGroups}
        onSave={handleSave}
        saving={saving}
      />
    </div>
  );
}
