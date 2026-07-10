import { IndianRupee } from 'lucide-react';
import { DateInput } from '@/components/DateInput';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import { FINANCE_FLAT_REPORT_METRICS } from '@/lib/descriptiveMetricCopy';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import type { FlatReportRow, SocietyFlatRow } from '@/lib/financeManagerTypes';

interface Props {
  from: string;
  to: string;
  selectedFlat: string;
  onFromChange: (value: string) => void;
  onToChange: (value: string) => void;
  onSelectedFlatChange: (value: string) => void;
  flats: SocietyFlatRow[];
  primaryByFlatId: Map<string, string>;
  isLoading: boolean;
  rows: FlatReportRow[];
}

export function FinanceFlatReportTab({
  from,
  to,
  selectedFlat,
  onFromChange,
  onToChange,
  onSelectedFlatChange,
  flats,
  primaryByFlatId,
  isLoading,
  rows,
}: Props) {
  return (
    <div className="space-y-4">
      <div className="card-section p-4 flex flex-wrap items-start gap-4">
        <div className="w-10 h-10 rounded-xl bg-indigo-500/10 flex items-center justify-center shrink-0">
          <IndianRupee className="w-5 h-5 text-indigo-500" />
        </div>
        <div className="flex-1 min-w-[220px] space-y-3">
          <div>
            <h3 className="text-sm font-semibold">Flat-wise Financial Report</h3>
            <p className="text-[11px] text-muted-foreground mt-0.5">
              Per-flat breakdown of maintenance receipts and society payment splits for reporting &amp; visibility — not
              for accounting.
            </p>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <label className="text-xs flex flex-col gap-1">
              <span className="text-muted-foreground">From</span>
              <DateInput className="input-field" value={from} onChange={(e) => onFromChange(e.target.value)} />
            </label>
            <label className="text-xs flex flex-col gap-1">
              <span className="text-muted-foreground">To</span>
              <DateInput className="input-field" value={to} onChange={(e) => onToChange(e.target.value)} />
            </label>
            <label className="text-xs flex flex-col gap-1">
              <span className="text-muted-foreground">Flat</span>
              <select className="input-field" value={selectedFlat} onChange={(e) => onSelectedFlatChange(e.target.value)}>
                <option value="all">All flats</option>
                {flats.map((f) => (
                  <option key={f.id} value={f.flat_number}>
                    {f.flat_number} — {primaryByFlatId.get(f.id) || f.owner_name || 'Vacant'}
                  </option>
                ))}
              </select>
            </label>
          </div>
          {from > to && <p className="text-xs text-destructive">End date must be on or after the start date.</p>}
        </div>
      </div>

      {isLoading ? (
        <p className="text-sm text-muted-foreground text-center py-10">Loading flat report data…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-10">
          No financial activity found for the selected period{selectedFlat !== 'all' ? ` (Flat ${selectedFlat})` : ''}.
        </p>
      ) : (
        <>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <DescriptiveStatCard
              {...FINANCE_FLAT_REPORT_METRICS.totalReceipts}
              variant="stat"
              value={`₹${rows.reduce((s, r) => s + r.maintenance_paid, 0).toLocaleString('en-IN')}`}
              valueClassName="text-lg text-green-600"
            />
            <DescriptiveStatCard
              {...FINANCE_FLAT_REPORT_METRICS.expenseShare}
              variant="stat"
              value={`₹${rows.reduce((s, r) => s + r.expense_share, 0).toLocaleString('en-IN')}`}
              valueClassName="text-lg text-red-600"
            />
            <DescriptiveStatCard
              {...FINANCE_FLAT_REPORT_METRICS.settled}
              variant="stat"
              value={`₹${rows.reduce((s, r) => s + r.settled_amount, 0).toLocaleString('en-IN')}`}
              valueClassName="text-lg text-blue-600"
            />
            <DescriptiveStatCard
              {...FINANCE_FLAT_REPORT_METRICS.unsettled}
              variant="stat"
              value={`₹${rows.reduce((s, r) => s + r.unsettled_amount, 0).toLocaleString('en-IN')}`}
              valueClassName="text-lg text-amber-600"
            />
          </div>

          <div className="space-y-3">
            {rows.map((row) => (
              <details key={row.flat_number} className="card-section overflow-hidden">
                <summary className="p-4 cursor-pointer hover:bg-muted/30 transition-colors">
                  <div className="flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <p className="text-sm font-semibold">Flat {row.flat_number}</p>
                      <p className="text-[11px] text-muted-foreground truncate">{row.resident_name}</p>
                    </div>
                    <div className="text-right shrink-0 space-y-0.5">
                      <p className="text-xs">
                        <span className="text-green-600 font-medium">
                          Paid ₹{row.maintenance_paid.toLocaleString('en-IN')}
                        </span>
                        {' · '}
                        <span className="text-red-600 font-medium">
                          Share ₹{row.expense_share.toLocaleString('en-IN')}
                        </span>
                      </p>
                      <p className={`text-xs font-bold ${row.net_position >= 0 ? 'text-green-700' : 'text-red-700'}`}>
                        Net: {row.net_position >= 0 ? '+' : ''}₹{row.net_position.toLocaleString('en-IN')}
                      </p>
                    </div>
                  </div>
                </summary>
                <div className="border-t border-border px-4 py-3 space-y-2">
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-[11px]">
                    <div>
                      <span className="text-muted-foreground">Maintenance receipts:</span>{' '}
                      <span className="font-medium">{row.maintenance_count}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Expense splits:</span>{' '}
                      <span className="font-medium">{row.expense_count}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Settled:</span>{' '}
                      <span className="font-medium text-blue-600">₹{row.settled_amount.toLocaleString('en-IN')}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Unsettled:</span>{' '}
                      <span className="font-medium text-amber-600">₹{row.unsettled_amount.toLocaleString('en-IN')}</span>
                    </div>
                  </div>
                  {row.details.length > 0 && (
                    <div className="overflow-x-auto mt-2">
                      <table className="w-full text-xs border border-border rounded-md overflow-hidden">
                        <thead>
                          <tr className="bg-muted/50 text-left">
                            <th className="p-2 border-b border-border">Type</th>
                            <th className="p-2 border-b border-border">Description</th>
                            <th className="p-2 border-b border-border text-right">Amount</th>
                            <th className="p-2 border-b border-border">Date</th>
                            <th className="p-2 border-b border-border">Method</th>
                            <th className="p-2 border-b border-border">Status</th>
                          </tr>
                        </thead>
                        <tbody>
                          {row.details.map((d, idx) => (
                            <tr key={idx} className="border-b border-border/60">
                              <td className="p-2">
                                <span
                                  className={`inline-block px-1.5 py-0.5 rounded text-[10px] font-medium ${
                                    d.type === 'maintenance'
                                      ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                                      : 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400'
                                  }`}
                                >
                                  {d.type === 'maintenance' ? 'Receipt' : 'Expense'}
                                </span>
                              </td>
                              <td
                                className="p-2 max-w-[180px] truncate"
                                title={d.group_name ? `${d.group_name}: ${d.title}` : d.title}
                              >
                                {d.group_name ? <span className="text-muted-foreground">[{d.group_name}] </span> : null}
                                {d.title}
                              </td>
                              <td className="p-2 text-right font-mono font-medium">₹{d.amount.toLocaleString('en-IN')}</td>
                              <td className="p-2 text-muted-foreground">{fmtIsoDateToDisplay(d.date)}</td>
                              <td className="p-2 capitalize">{d.method.replace(/_/g, ' ')}</td>
                              <td className="p-2">
                                <span
                                  className={`text-[10px] px-1.5 py-0.5 rounded-full ${
                                    d.status === 'paid' || d.status === 'verified' || d.status === 'settled'
                                      ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                                      : 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400'
                                  }`}
                                >
                                  {d.status}
                                </span>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              </details>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
