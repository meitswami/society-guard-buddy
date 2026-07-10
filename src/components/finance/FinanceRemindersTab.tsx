import { AlertTriangle } from 'lucide-react';
import { UnpaidFlatGridTable } from '@/components/finance/UnpaidFlatGridTable';
import type { UnpaidFlatGridRow } from '@/lib/financeManagerTypes';

interface Props {
  unpaidCount: number;
  rows: UnpaidFlatGridRow[];
  onSendReminders: () => void;
}

export function FinanceRemindersTab({ unpaidCount, rows, onSendReminders }: Props) {
  return (
    <div>
      <div className="card-section p-4 mb-4">
        <div className="flex items-center gap-2 mb-2">
          <AlertTriangle className="w-5 h-5 text-amber-500" />
          <h3 className="font-semibold">Unpaid Flats</h3>
        </div>
        <p className="text-sm text-muted-foreground mb-3">{unpaidCount} flats have not paid maintenance</p>
        {unpaidCount > 0 && (
          <button onClick={onSendReminders} className="btn-primary w-full flex items-center justify-center gap-2">
            Send reminders to all ({unpaidCount})
          </button>
        )}
      </div>
      <UnpaidFlatGridTable rows={rows} emptyMessage="All flats have paid maintenance" />
    </div>
  );
}
