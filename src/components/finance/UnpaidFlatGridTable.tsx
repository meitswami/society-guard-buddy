import type { UnpaidFlatGridRow } from '@/lib/financeManagerTypes';

export function UnpaidFlatGridTable({
  rows,
  emptyMessage,
  showChargeColumn = true,
}: {
  rows: UnpaidFlatGridRow[];
  emptyMessage: string;
  showChargeColumn?: boolean;
}) {
  if (rows.length === 0) {
    return <p className="text-sm text-muted-foreground text-center py-8">{emptyMessage}</p>;
  }

  const totalDue = rows.reduce((sum, row) => sum + (row.due_amount ?? 0), 0);
  const hasDueAmounts = showChargeColumn && rows.some((row) => row.due_amount != null);

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-[10px] border border-border rounded-md overflow-hidden">
        <thead>
          <tr className="bg-muted/50 text-left">
            <th className="p-1.5 border-b border-border w-10">#</th>
            <th className="p-1.5 border-b border-border">Flat</th>
            <th className="p-1.5 border-b border-border">Resident</th>
            <th className="p-1.5 border-b border-border">Occupancy</th>
            {showChargeColumn && <th className="p-1.5 border-b border-border">Charge</th>}
            {hasDueAmounts && <th className="p-1.5 border-b border-border text-right">Due amount</th>}
            <th className="p-1.5 border-b border-border">Status</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, idx) => (
            <tr key={row.flat_number} className="border-b border-border/60 hover:bg-muted/20">
              <td className="p-1.5 text-muted-foreground">{idx + 1}</td>
              <td className="p-1.5 font-semibold font-mono">{row.flat_number}</td>
              <td className="p-1.5 max-w-[180px] truncate" title={row.primary_name || 'Primary member not found'}>
                {row.primary_name || 'Primary member not found'}
              </td>
              <td className="p-1.5">
                <span
                  className={`inline-block px-1.5 py-0.5 rounded text-[10px] font-medium ${
                    row.is_occupied
                      ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                      : 'bg-muted text-muted-foreground'
                  }`}
                >
                  {row.is_occupied ? 'Occupied' : 'Vacant'}
                </span>
              </td>
              {showChargeColumn && (
                <td className="p-1.5 max-w-[160px] truncate text-muted-foreground" title={row.charge_title ?? '—'}>
                  {row.charge_title ?? '—'}
                </td>
              )}
              {hasDueAmounts && (
                <td className="p-1.5 text-right font-mono font-medium">
                  {row.due_amount != null ? `₹${row.due_amount.toLocaleString('en-IN')}` : '—'}
                </td>
              )}
              <td className="p-1.5">
                {row.pending_payment === 'pending' ? (
                  <span className="inline-block px-1.5 py-0.5 rounded-full text-[10px] font-medium bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400">
                    Pending
                  </span>
                ) : row.pending_payment === 'rejected' ? (
                  <span className="inline-block px-1.5 py-0.5 rounded-full text-[10px] font-medium bg-muted text-muted-foreground">
                    Rejected
                  </span>
                ) : (
                  <span className="inline-block px-1.5 py-0.5 rounded-full text-[10px] font-medium bg-destructive/20 text-destructive">
                    Unpaid
                  </span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr className="bg-muted/30 font-semibold">
            <td className="p-1.5" colSpan={4 + (showChargeColumn ? 1 : 0)}>
              {rows.length} unpaid flat{rows.length === 1 ? '' : 's'}
            </td>
            {hasDueAmounts && (
              <td className="p-1.5 text-right font-mono">₹{totalDue.toLocaleString('en-IN')}</td>
            )}
            <td className="p-1.5" />
          </tr>
        </tfoot>
      </table>
    </div>
  );
}
