import { DescriptiveValueButton, TableSumInsight } from '@/components/DescriptiveStatCard';
import { FINANCE_PERIOD_METRICS, SUM_INSIGHT_METRICS } from '@/lib/descriptiveMetricCopy';
import type { FinancePeriodReportResult } from '@/lib/financePeriodReport';

export type FinancePeriodHeadSection = 'receipts' | 'expenses' | 'all';

interface Props {
  report: FinancePeriodReportResult;
  className?: string;
  /** Which head-wise table(s) to render. Defaults to both. */
  section?: FinancePeriodHeadSection;
}

const FinancePeriodHeadTables = ({ report, className, section = 'all' }: Props) => {
  const showReceipts = section === 'all' || section === 'receipts';
  const showExpenses = section === 'all' || section === 'expenses';

  return (
    <div className={className ?? 'space-y-4'}>
      {showReceipts && (
        <div className="rounded-xl border border-border bg-card/40 p-4 space-y-3">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Collection receipts (head-wise)</p>
          <p className="text-[11px] text-muted-foreground flex flex-wrap items-center gap-1">
            <span>
              {report.verifiedPaymentCount} maintenance receipt row(s) in range; ledger-only inflows added:
            </span>
            <DescriptiveValueButton
              {...FINANCE_PERIOD_METRICS.extraLedgerReceipt}
              value={`₹${report.extraLedgerReceipt.toLocaleString('en-IN')}`}
              valueClassName="text-[11px] font-mono font-semibold"
            />
          </p>
          <div className="overflow-x-auto">
            <table className="w-full text-xs border border-border rounded-md overflow-hidden">
              <thead>
                <tr className="bg-muted/50 text-left">
                  <th className="p-2 border-b border-border">Receipt head</th>
                  <th className="p-2 border-b border-border text-right">Cash</th>
                  <th className="p-2 border-b border-border text-right">Bank / UPI / online</th>
                  <th className="p-2 border-b border-border text-right">Other</th>
                  <th className="p-2 border-b border-border text-right font-semibold">Total</th>
                </tr>
              </thead>
              <tbody>
                {report.receiptByHead.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="p-4 text-center text-muted-foreground">
                      No verified collections in this period.
                    </td>
                  </tr>
                ) : (
                  report.receiptByHead.map(([head, v]) => (
                    <tr key={head}>
                      <td className="p-2 border-b border-border/80 max-w-[200px] truncate" title={head}>
                        {head}
                      </td>
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.channelCash}
                        title={`${head} — cash`}
                        value={`₹${v.cash.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono"
                        cellClassName="p-2 border-b border-border/80"
                      />
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.channelBank}
                        title={`${head} — bank / UPI`}
                        value={`₹${v.bank.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono"
                        cellClassName="p-2 border-b border-border/80"
                      />
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.channelOther}
                        title={`${head} — other`}
                        value={`₹${v.other.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono"
                        cellClassName="p-2 border-b border-border/80"
                      />
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.periodReceiptHead}
                        title={head}
                        description={`${SUM_INSIGHT_METRICS.periodReceiptHead.description} Head: ${head}.`}
                        howCalculated={SUM_INSIGHT_METRICS.periodReceiptHead.howCalculated}
                        value={`₹${v.total.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono font-semibold"
                        cellClassName="p-2 border-b border-border/80"
                      />
                    </tr>
                  ))
                )}
              </tbody>
              <tfoot>
                <tr className="bg-muted/30 font-semibold">
                  <td className="p-2">All receipts</td>
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.channelCash}
                    title="All receipts — cash"
                    value={`₹${report.receiptByMethod.cash.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.channelBank}
                    title="All receipts — bank / UPI"
                    value={`₹${report.receiptByMethod.bank.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.channelOther}
                    title="All receipts — other"
                    value={`₹${report.receiptByMethod.other.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.periodVerifiedReceipts}
                    value={`₹${report.totalReceipts.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}

      {showExpenses && (
        <div className="rounded-xl border border-border bg-card/40 p-4 space-y-3">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Expenses (head-wise)</p>
          <div className="overflow-x-auto">
            <table className="w-full text-xs border border-border rounded-md overflow-hidden">
              <thead>
                <tr className="bg-muted/50 text-left">
                  <th className="p-2 border-b border-border">Expense head</th>
                  <th className="p-2 border-b border-border text-right">Cash</th>
                  <th className="p-2 border-b border-border text-right">Bank / UPI / online</th>
                  <th className="p-2 border-b border-border text-right">Other</th>
                  <th className="p-2 border-b border-border text-right font-semibold">Total</th>
                </tr>
              </thead>
              <tbody>
                {report.expenseByHead.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="p-4 text-center text-muted-foreground">
                      No separate-entry expenses in this period.
                    </td>
                  </tr>
                ) : (
                  report.expenseByHead.map(([head, v]) => (
                    <tr key={head}>
                      <td className="p-2 border-b border-border/80 max-w-[200px] truncate" title={head}>
                        {head}
                      </td>
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.channelCash}
                        title={`${head} — cash`}
                        value={`₹${v.cash.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono"
                        cellClassName="p-2 border-b border-border/80"
                      />
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.channelBank}
                        title={`${head} — bank / UPI`}
                        value={`₹${v.bank.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono"
                        cellClassName="p-2 border-b border-border/80"
                      />
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.channelOther}
                        title={`${head} — other`}
                        value={`₹${v.other.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono"
                        cellClassName="p-2 border-b border-border/80"
                      />
                      <TableSumInsight
                        {...SUM_INSIGHT_METRICS.periodExpenseHead}
                        title={head}
                        description={`${SUM_INSIGHT_METRICS.periodExpenseHead.description} Head: ${head}.`}
                        howCalculated={SUM_INSIGHT_METRICS.periodExpenseHead.howCalculated}
                        value={`₹${v.total.toLocaleString('en-IN')}`}
                        valueClassName="text-xs font-mono font-semibold"
                        cellClassName="p-2 border-b border-border/80"
                      />
                    </tr>
                  ))
                )}
              </tbody>
              <tfoot>
                <tr className="bg-muted/30 font-semibold">
                  <td className="p-2">All expenses</td>
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.channelCash}
                    title="All expenses — cash"
                    value={`₹${report.expenseByMethod.cash.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.channelBank}
                    title="All expenses — bank / UPI"
                    value={`₹${report.expenseByMethod.bank.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.channelOther}
                    title="All expenses — other"
                    value={`₹${report.expenseByMethod.other.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                  <TableSumInsight
                    {...SUM_INSIGHT_METRICS.periodAllExpenses}
                    value={`₹${report.totalExpenses.toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold"
                    cellClassName="p-2"
                  />
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};

export default FinancePeriodHeadTables;
