import { Plus, Pencil, Trash2 } from 'lucide-react';
import { capsFieldChange } from '@/lib/entryCaps';
import { SOCIETY_PAYMENT_MAJOR_HEADS, type SocietyPaymentMajorHead } from '@/lib/financeExpenseHead';
import type { PaymentHeadFormState } from '@/lib/financeManagerTypes';

interface Props {
  showForm: boolean;
  editingGroupId: string | null;
  form: PaymentHeadFormState;
  onFormChange: React.Dispatch<React.SetStateAction<PaymentHeadFormState>>;
  onToggleForm: () => void;
  onCancelEdit: () => void;
  onSaveGroup: () => void;
  groupsByMajorHead: Map<string, { id: string; name: string; description?: string | null; major_head?: string | null }[]>;
  groupIdsInUse: Set<string>;
  onStartEditGroup: (group: { id: string; name: string; description?: string | null; major_head?: string | null }) => void;
  onDeleteGroup: (id: string) => void;
}

export function FinanceCreatePaymentTab({
  showForm,
  editingGroupId,
  form,
  onFormChange,
  onToggleForm,
  onCancelEdit,
  onSaveGroup,
  groupsByMajorHead,
  groupIdsInUse,
  onStartEditGroup,
  onDeleteGroup,
}: Props) {
  return (
    <div>
      <button
        type="button"
        onClick={onToggleForm}
        className="btn-primary w-full mb-4 flex items-center justify-center gap-2"
      >
        <Plus className="w-4 h-4" /> {showForm && !editingGroupId ? 'Close form' : 'Add payment type'}
      </button>

      {showForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <p className="text-xs font-medium text-muted-foreground">
            {editingGroupId ? 'Edit payment type' : 'New payment type'}
          </p>
          <select
            className="input-field"
            value={form.major_head}
            onChange={(e) =>
              onFormChange({
                ...form,
                major_head: e.target.value as SocietyPaymentMajorHead | '',
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
          <input
            className="input-field"
            placeholder="Sub-head name (e.g. Electricity bill, Lift AMC)"
            value={form.name}
            onChange={capsFieldChange(onFormChange, 'name')}
          />
          <textarea
            className="input-field"
            placeholder="Description (optional)"
            value={form.description}
            onChange={(e) => onFormChange({ ...form, description: e.target.value })}
          />
          <p className="text-[10px] text-muted-foreground leading-snug">
            Payment types appear under the major head in period reports. Use specific names — e.g. Electricity, Security
            guards — not generic labels.
          </p>
          <div className="flex gap-2">
            <button type="button" onClick={onSaveGroup} className="btn-primary flex-1">
              {editingGroupId ? 'Update payment type' : 'Save payment type'}
            </button>
            {editingGroupId && (
              <button type="button" className="btn-secondary flex-1" onClick={onCancelEdit}>
                Cancel edit
              </button>
            )}
          </div>
        </div>
      )}

      {[...SOCIETY_PAYMENT_MAJOR_HEADS, 'Uncategorized' as const].map((major) => {
        const list = groupsByMajorHead.get(major) ?? [];
        if (list.length === 0) return null;
        return (
          <div key={major} className="mb-4">
            <h3 className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground mb-2 border-b border-border/60 pb-1">
              {major}
            </h3>
            {list.map((g) => (
              <div key={g.id} className="card-section p-3 mb-2">
                <div className="flex justify-between items-start gap-2">
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold">{g.name}</p>
                    {g.description && <p className="text-xs text-muted-foreground mt-0.5">{g.description}</p>}
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <button
                      type="button"
                      className="p-1.5 text-muted-foreground hover:text-primary"
                      title="Edit"
                      onClick={() => onStartEditGroup(g)}
                    >
                      <Pencil className="w-4 h-4" />
                    </button>
                    {!groupIdsInUse.has(g.id) ? (
                      <button
                        type="button"
                        className="p-1.5 text-muted-foreground hover:text-destructive"
                        title="Delete payment type"
                        onClick={() => onDeleteGroup(g.id)}
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    ) : (
                      <span
                        className="text-[9px] text-muted-foreground max-w-[72px] text-right leading-tight"
                        title="Remove linked receipts or recorded payments first"
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
