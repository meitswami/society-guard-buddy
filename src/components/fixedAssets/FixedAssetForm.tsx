import { useEffect, useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { DateInput } from '@/components/DateInput';
import {
  computeEndDateFromMonths,
  FIXED_ASSET_SOURCE_LABELS,
  FIXED_ASSET_STATUS_LABELS,
  type FixedAsset,
  type FixedAssetInput,
  type FixedAssetSourceType,
  type FixedAssetStatus,
} from '@/lib/fixedAssetTypes';

type ExpenseGroup = { id: string; name: string; major_head?: string | null };

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  asset?: FixedAsset | null;
  expenseGroups: ExpenseGroup[];
  onSave: (input: FixedAssetInput) => Promise<void>;
  saving?: boolean;
};

const EMPTY: FixedAssetInput = {
  asset_name: '',
  description: '',
  major_head: 'FIXED ASSETS',
  sub_head: '',
  source_type: 'manual',
  status: 'active',
  acquisition_date: '',
  bill_value: null,
  vendor_name: '',
  vendor_contact: '',
  asset_tag: '',
  serial_number: '',
  location: '',
  warranty_start_date: '',
  warranty_period_months: null,
  warranty_end_date: '',
  amc_start_date: '',
  amc_period_months: null,
  amc_end_date: '',
  amc_vendor: '',
  notes: '',
};

export default function FixedAssetForm({ open, onOpenChange, asset, expenseGroups, onSave, saving }: Props) {
  const [form, setForm] = useState<FixedAssetInput>(EMPTY);

  useEffect(() => {
    if (!open) return;
    if (asset) {
      setForm({
        asset_name: asset.asset_name,
        description: asset.description ?? '',
        major_head: asset.major_head,
        sub_head: asset.sub_head ?? '',
        expense_group_id: asset.expense_group_id,
        source_type: asset.source_type,
        status: asset.status,
        acquisition_date: asset.acquisition_date ?? '',
        bill_value: asset.bill_value,
        vendor_name: asset.vendor_name ?? '',
        vendor_contact: asset.vendor_contact ?? '',
        asset_tag: asset.asset_tag ?? '',
        serial_number: asset.serial_number ?? '',
        location: asset.location ?? '',
        warranty_start_date: asset.warranty_start_date ?? '',
        warranty_period_months: asset.warranty_period_months,
        warranty_end_date: asset.warranty_end_date ?? '',
        amc_start_date: asset.amc_start_date ?? '',
        amc_period_months: asset.amc_period_months,
        amc_end_date: asset.amc_end_date ?? '',
        amc_vendor: asset.amc_vendor ?? '',
        notes: asset.notes ?? '',
        template_key: asset.template_key,
      });
    } else {
      setForm(EMPTY);
    }
  }, [open, asset]);

  const set = <K extends keyof FixedAssetInput>(key: K, value: FixedAssetInput[K]) => {
    setForm((prev) => {
      const next = { ...prev, [key]: value };
      if (key === 'warranty_start_date' || key === 'warranty_period_months') {
        next.warranty_end_date =
          computeEndDateFromMonths(
            key === 'warranty_start_date' ? (value as string) : prev.warranty_start_date,
            key === 'warranty_period_months' ? (value as number | null) : prev.warranty_period_months,
          ) ?? prev.warranty_end_date ?? '';
      }
      if (key === 'amc_start_date' || key === 'amc_period_months') {
        next.amc_end_date =
          computeEndDateFromMonths(
            key === 'amc_start_date' ? (value as string) : prev.amc_start_date,
            key === 'amc_period_months' ? (value as number | null) : prev.amc_period_months,
          ) ?? prev.amc_end_date ?? '';
      }
      return next;
    });
  };

  const handleGroupChange = (groupId: string) => {
    const g = expenseGroups.find((x) => x.id === groupId);
    setForm((prev) => ({
      ...prev,
      expense_group_id: groupId || null,
      sub_head: g?.name ?? prev.sub_head,
    }));
  };

  const handleSubmit = async () => {
    if (!form.asset_name.trim()) return;
    await onSave({
      ...form,
      asset_name: form.asset_name.trim(),
      description: form.description?.trim() || null,
      sub_head: form.sub_head?.trim() || null,
      vendor_name: form.vendor_name?.trim() || null,
      vendor_contact: form.vendor_contact?.trim() || null,
      asset_tag: form.asset_tag?.trim() || null,
      serial_number: form.serial_number?.trim() || null,
      location: form.location?.trim() || null,
      amc_vendor: form.amc_vendor?.trim() || null,
      notes: form.notes?.trim() || null,
      acquisition_date: form.acquisition_date || null,
      warranty_start_date: form.warranty_start_date || null,
      warranty_end_date: form.warranty_end_date || null,
      amc_start_date: form.amc_start_date || null,
      amc_end_date: form.amc_end_date || null,
      bill_value: form.bill_value != null && form.bill_value !== ('' as unknown as number) ? Number(form.bill_value) : null,
      status: asset?.source_type === 'finance_transaction' && form.status === 'placeholder' ? 'active' : form.status,
    });
  };

  const isFinanceLinked = asset?.source_type === 'finance_transaction';

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{asset ? 'Edit fixed asset' : 'Add fixed asset'}</DialogTitle>
        </DialogHeader>

        <div className="flex flex-col gap-3 text-sm">
          {isFinanceLinked && (
            <p className="text-xs text-muted-foreground bg-muted/50 rounded-lg p-2">
              Linked to Finance payment. Bill value and vendor sync from the transaction; you can add warranty, AMC and location details here.
            </p>
          )}

          <label className="flex flex-col gap-1">
            <span className="text-xs font-medium">Asset name *</span>
            <input className="input-field" value={form.asset_name} onChange={(e) => set('asset_name', e.target.value)} />
          </label>

          <label className="flex flex-col gap-1">
            <span className="text-xs font-medium">Description</span>
            <textarea className="input-field min-h-[60px]" value={form.description ?? ''} onChange={(e) => set('description', e.target.value)} />
          </label>

          <div className="grid grid-cols-2 gap-2">
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Major head</span>
              <input className="input-field" value={form.major_head ?? 'FIXED ASSETS'} readOnly />
            </label>
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Sub-head</span>
              <input className="input-field" value={form.sub_head ?? ''} onChange={(e) => set('sub_head', e.target.value)} />
            </label>
          </div>

          <label className="flex flex-col gap-1">
            <span className="text-xs font-medium">Finance expense group (optional)</span>
            <select
              className="input-field"
              value={form.expense_group_id ?? ''}
              onChange={(e) => handleGroupChange(e.target.value)}
            >
              <option value="">— Select sub-head —</option>
              {expenseGroups.map((g) => (
                <option key={g.id} value={g.id}>{g.name}</option>
              ))}
            </select>
          </label>

          <div className="grid grid-cols-2 gap-2">
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Source</span>
              <select
                className="input-field"
                value={form.source_type}
                disabled={isFinanceLinked}
                onChange={(e) => set('source_type', e.target.value as FixedAssetSourceType)}
              >
                {Object.entries(FIXED_ASSET_SOURCE_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>{v}</option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Status</span>
              <select
                className="input-field"
                value={form.status}
                onChange={(e) => set('status', e.target.value as FixedAssetStatus)}
              >
                {Object.entries(FIXED_ASSET_STATUS_LABELS).map(([k, v]) => (
                  <option key={k} value={k}>{v}</option>
                ))}
              </select>
            </label>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Acquisition / creation date</span>
              <DateInput className="input-field" value={form.acquisition_date ?? ''} onChange={(e) => set('acquisition_date', e.target.value)} />
            </label>
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Bill value (₹)</span>
              <input
                type="number"
                className="input-field"
                value={form.bill_value ?? ''}
                disabled={isFinanceLinked}
                onChange={(e) => set('bill_value', e.target.value ? Number(e.target.value) : null)}
              />
            </label>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Vendor</span>
              <input className="input-field" value={form.vendor_name ?? ''} onChange={(e) => set('vendor_name', e.target.value)} />
            </label>
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Vendor contact</span>
              <input className="input-field" value={form.vendor_contact ?? ''} onChange={(e) => set('vendor_contact', e.target.value)} />
            </label>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Asset tag / ID</span>
              <input className="input-field" value={form.asset_tag ?? ''} onChange={(e) => set('asset_tag', e.target.value)} />
            </label>
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">Serial number</span>
              <input className="input-field" value={form.serial_number ?? ''} onChange={(e) => set('serial_number', e.target.value)} />
            </label>
          </div>

          <label className="flex flex-col gap-1">
            <span className="text-xs font-medium">Location</span>
            <input className="input-field" value={form.location ?? ''} onChange={(e) => set('location', e.target.value)} placeholder="e.g. Basement pump room" />
          </label>

          <div className="border-t border-border pt-3">
            <p className="text-xs font-semibold mb-2">Warranty</p>
            <div className="grid grid-cols-3 gap-2">
              <label className="flex flex-col gap-1">
                <span className="text-[10px] text-muted-foreground">Start</span>
                <DateInput className="input-field" value={form.warranty_start_date ?? ''} onChange={(e) => set('warranty_start_date', e.target.value)} />
              </label>
              <label className="flex flex-col gap-1">
                <span className="text-[10px] text-muted-foreground">Months</span>
                <input
                  type="number"
                  className="input-field"
                  value={form.warranty_period_months ?? ''}
                  onChange={(e) => set('warranty_period_months', e.target.value ? Number(e.target.value) : null)}
                />
              </label>
              <label className="flex flex-col gap-1">
                <span className="text-[10px] text-muted-foreground">End</span>
                <DateInput className="input-field" value={form.warranty_end_date ?? ''} onChange={(e) => set('warranty_end_date', e.target.value)} />
              </label>
            </div>
          </div>

          <div className="border-t border-border pt-3">
            <p className="text-xs font-semibold mb-2">AMC (Annual Maintenance Contract)</p>
            <div className="grid grid-cols-3 gap-2 mb-2">
              <label className="flex flex-col gap-1">
                <span className="text-[10px] text-muted-foreground">Start</span>
                <DateInput className="input-field" value={form.amc_start_date ?? ''} onChange={(e) => set('amc_start_date', e.target.value)} />
              </label>
              <label className="flex flex-col gap-1">
                <span className="text-[10px] text-muted-foreground">Months</span>
                <input
                  type="number"
                  className="input-field"
                  value={form.amc_period_months ?? ''}
                  onChange={(e) => set('amc_period_months', e.target.value ? Number(e.target.value) : null)}
                />
              </label>
              <label className="flex flex-col gap-1">
                <span className="text-[10px] text-muted-foreground">End</span>
                <DateInput className="input-field" value={form.amc_end_date ?? ''} onChange={(e) => set('amc_end_date', e.target.value)} />
              </label>
            </div>
            <label className="flex flex-col gap-1">
              <span className="text-xs font-medium">AMC vendor</span>
              <input className="input-field" value={form.amc_vendor ?? ''} onChange={(e) => set('amc_vendor', e.target.value)} />
            </label>
          </div>

          <label className="flex flex-col gap-1">
            <span className="text-xs font-medium">Notes</span>
            <textarea className="input-field min-h-[50px]" value={form.notes ?? ''} onChange={(e) => set('notes', e.target.value)} />
          </label>

          <button
            type="button"
            className="btn-primary w-full mt-1"
            disabled={saving || !form.asset_name.trim()}
            onClick={handleSubmit}
          >
            {saving ? 'Saving…' : asset ? 'Update asset' : 'Add asset'}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
