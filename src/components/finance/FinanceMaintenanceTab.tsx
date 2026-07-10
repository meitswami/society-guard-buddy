import { Plus, Pencil, Trash2 } from 'lucide-react';
import { capsFieldChange } from '@/lib/entryCaps';
import { SOCIETY_PAYMENT_MAJOR_HEADS, type SocietyPaymentMajorHead } from '@/lib/financeExpenseHead';
import type { MaintenanceChargeFormState } from '@/lib/financeManagerTypes';

interface Props {
  showForm: boolean;
  editingChargeId: string | null;
  form: MaintenanceChargeFormState;
  onFormChange: React.Dispatch<React.SetStateAction<MaintenanceChargeFormState>>;
  onToggleForm: () => void;
  onCancelEdit: () => void;
  onSaveCharge: () => void;
  subHeadsForFormMajor: { id: string; name: string }[];
  chargesByMajorHead: Map<string, { id: string; title: string; amount: number; frequency?: string; due_day?: number; expense_group_id?: string | null }[]>;
  paymentGroupById: Map<string, { id: string; name: string }>;
  chargeIdsWithDependents: Set<string>;
  onStartEditCharge: (charge: {
    id: string;
    title: string;
    amount: number;
    frequency?: string;
    due_day?: number;
    expense_group_id?: string | null;
  }) => void;
  onDeleteCharge: (id: string) => void;
}

export function FinanceMaintenanceTab({
  showForm,
  editingChargeId,
  form,
  onFormChange,
  onToggleForm,
  onCancelEdit,
  onSaveCharge,
  subHeadsForFormMajor,
  chargesByMajorHead,
  paymentGroupById,
  chargeIdsWithDependents,
  onStartEditCharge,
  onDeleteCharge,
}: Props) {
  return (
    <div>
      <button
        type="button"
        onClick={onToggleForm}
        className="btn-primary w-full mb-4 flex items-center justify-center gap-2"
      >
        <Plus className="w-4 h-4" /> {showForm && !editingChargeId ? 'Close form' : 'Add receipt type'}
      </button>

      {showForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <p className="text-xs font-medium text-muted-foreground">
            {editingChargeId ? 'Edit receipt type' : 'New receipt type'}
          </p>
          <input
            className="input-field"
            placeholder="Title (e.g. Monthly Maintenance)"
            value={form.title}
            onChange={capsFieldChange(onFormChange, 'title')}
          />
          <input
            className="input-field"
            placeholder="Amount (₹)"
            type="number"
            value={form.amount}
            onChange={(e) => onFormChange({ ...form, amount: e.target.value })}
          />
          <select
            className="input-field"
            value={form.frequency}
            onChange={(e) => onFormChange({ ...form, frequency: e.target.value })}
          >
            <option value="monthly">Monthly</option>
            <option value="quarterly">Quarterly</option>
            <option value="yearly">Yearly</option>
            <option value="one-time">One-time</option>
          </select>
          <input
            className="input-field"
            placeholder="Due Day (1-28)"
            type="number"
            min="1"
            max="28"
            value={form.due_day}
            onChange={(e) => onFormChange({ ...form, due_day: e.target.value })}
          />
          <select
            className="input-field"
            value={form.major_head}
            onChange={(e) =>
              onFormChange({
                ...form,
                major_head: e.target.value as SocietyPaymentMajorHead | '',
                expense_group_id: '',
                new_sub_head: '',
              })
            }
          >
            <option value="">Major head (category)</option>
            {SOCIETY_PAYMENT_MAJOR_HEADS.map((h) => (
              <option key={h} value={h}>
                {h}
              </option>
            ))}
          </select>
          {form.major_head && (
            <>
              <select
                className="input-field"
                value={form.expense_group_id}
                onChange={(e) => onFormChange({ ...form, expense_group_id: e.target.value, new_sub_head: '' })}
              >
                <option value="">Payment sub-head (optional link)</option>
                {subHeadsForFormMajor.map((g) => (
                  <option key={g.id} value={g.id}>
                    {g.name}
                  </option>
                ))}
                <option value="__new__">+ Create new sub-head under {form.major_head}</option>
              </select>
              {form.expense_group_id === '__new__' && (
                <input
                  className="input-field"
                  placeholder="New sub-head name (defaults to receipt title)"
                  value={form.new_sub_head}
                  onChange={(e) => onFormChange({ ...form, new_sub_head: e.target.value })}
                />
              )}
            </>
          )}
          <div className="flex gap-2">
            <button type="button" onClick={onSaveCharge} className="btn-primary flex-1">
              {editingChargeId ? 'Update receipt type' : 'Save receipt type'}
            </button>
            {editingChargeId && (
              <button type="button" className="btn-secondary flex-1" onClick={onCancelEdit}>
                Cancel edit
              </button>
            )}
          </div>
        </div>
      )}

      {[...SOCIETY_PAYMENT_MAJOR_HEADS, 'Uncategorized' as const].map((major) => {
        const list = chargesByMajorHead.get(major) ?? [];
        if (list.length === 0) return null;
        return (
          <div key={major} className="mb-4">
            <h3 className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground mb-2 border-b border-border/60 pb-1">
              {major}
            </h3>
            {list.map((c) => (
              <div key={c.id} className="card-section p-3 mb-2">
                <div className="flex justify-between items-start gap-2">
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold">{c.title}</p>
                    <p className="text-xs text-muted-foreground">
                      {c.frequency} · Due on {c.due_day}th
                    </p>
                    {c.expense_group_id && (
                      <p className="text-[10px] text-muted-foreground mt-0.5">
                        Sub-head: {paymentGroupById.get(String(c.expense_group_id))?.name ?? 'Linked'}
                      </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <p className="text-lg font-bold text-green-600">₹{c.amount}</p>
                    <button
                      type="button"
                      className="p-1.5 text-muted-foreground hover:text-primary"
                      title="Edit"
                      onClick={() => onStartEditCharge(c)}
                    >
                      <Pencil className="w-4 h-4" />
                    </button>
                    {!chargeIdsWithDependents.has(c.id) ? (
                      <button
                        type="button"
                        className="p-1.5 text-muted-foreground hover:text-destructive"
                        title="Delete receipt type"
                        onClick={() => onDeleteCharge(c.id)}
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    ) : (
                      <span
                        className="text-[9px] text-muted-foreground max-w-[72px] text-right leading-tight"
                        title="Remove linked receipt or ledger rows first"
                      >
                        In use
                      </span>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        );
      })}
    </div>
  );
}
