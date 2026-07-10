import { Wallet } from 'lucide-react';
import MonthlyOperatingFundPanel from '@/components/MonthlyOperatingFundPanel';
import CashBankBreakdown from '@/components/CashBankBreakdown';
import { DescriptiveStatCard, DescriptiveValueButton } from '@/components/DescriptiveStatCard';
import {
  FINANCE_LEDGER_GROUP_METRICS,
  FINANCE_TOTALS_METRICS,
} from '@/lib/descriptiveMetricCopy';
import { FINANCE_REPORTING_EARLIEST_MONTH } from '@/lib/financePeriodReport';
import type { ChannelTotals } from '@/lib/cashBankChannel';
import type { FinanceLedgerRow } from '@/lib/financeManagerTypes';
import type { TotalsInflowRow, TotalsOutflowRow } from '@/lib/financeTotalsBreakdown';
import { formatLedgerFieldLabel } from '@/lib/financeLedgerDisplay';

interface Props {
  societyId: string | null;
  adminName: string;
  totalsMonth: string;
  onTotalsMonthChange: (month: string) => void;
  ledgerEntries: FinanceLedgerRow[];
  societyLedgerEntries: FinanceLedgerRow[];
  payments: unknown[];
  charges: unknown[];
  expenseCategoryById: Map<string, string>;
  onRefresh: () => void;
  totalsBreakdown: TotalsInflowRow[];
  totalsMonthReceiptChannels: ChannelTotals;
  totalsMonthNet: number;
  totalsOutflowBreakdown: TotalsOutflowRow[];
  totalsMonthPaymentChannels: ChannelTotals;
  totalsMonthOutflow: number;
}

export function FinanceTotalsTab({
  societyId,
  adminName,
  totalsMonth,
  onTotalsMonthChange,
  ledgerEntries,
  societyLedgerEntries,
  payments,
  charges,
  expenseCategoryById,
  onRefresh,
  totalsBreakdown,
  totalsMonthReceiptChannels,
  totalsMonthNet,
  totalsOutflowBreakdown,
  totalsMonthPaymentChannels,
  totalsMonthOutflow,
}: Props) {
  return (
    <div>
      <MonthlyOperatingFundPanel
        societyId={societyId}
        totalsMonth={totalsMonth}
        ledgerEntries={ledgerEntries}
        societyLedgerEntries={societyLedgerEntries}
        payments={payments}
        charges={charges}
        expenseCategoryById={expenseCategoryById}
        adminName={adminName}
        onRefresh={onRefresh}
      />

      <div className="card-section p-4 mb-4 flex flex-wrap items-center gap-4">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
          <Wallet className="w-5 h-5 text-primary" />
        </div>
        <div className="flex-1 min-w-[180px]">
          <p className="text-xs font-medium text-muted-foreground mb-1">Reporting month</p>
          <input
            type="month"
            className="input-field"
            min={FINANCE_REPORTING_EARLIEST_MONTH}
            value={totalsMonth}
            onChange={(e) => onTotalsMonthChange(e.target.value)}
          />
          <button
            type="button"
            className="btn-secondary text-[10px] px-2 py-1 mt-1.5"
            onClick={() => onTotalsMonthChange(FINANCE_REPORTING_EARLIEST_MONTH)}
          >
            Feb 2026
          </button>
        </div>
      </div>

      <CashBankBreakdown
        className="mb-4"
        receipts={totalsMonthReceiptChannels}
        payments={totalsMonthPaymentChannels}
        receiptLabel={`Ledger inflows (${totalsMonth})`}
        paymentLabel={`Ledger outflows (${totalsMonth})`}
      />

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mb-4">
        <DescriptiveStatCard
          {...FINANCE_TOTALS_METRICS.inflow}
          variant="stat"
          value={`₹${totalsMonthNet.toLocaleString('en-IN')}`}
          valueClassName="text-xl text-green-600"
        />
        <DescriptiveStatCard
          {...FINANCE_TOTALS_METRICS.groups}
          variant="stat"
          value={totalsBreakdown.length}
          valueClassName="text-xl"
        />
        <DescriptiveStatCard
          {...FINANCE_TOTALS_METRICS.flatUnits}
          variant="stat"
          value={totalsBreakdown.reduce((s, r) => s + r.flatUnits, 0)}
          valueClassName="text-xl"
        />
      </div>

      <div className="space-y-2">
        {totalsBreakdown.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-10">
            No ledger groups for {totalsMonth}. Record Reciepts or outsider entries to populate totals.
          </p>
        ) : (
          totalsBreakdown.map((row) => (
            <div
              key={`${row.mode}-${row.destination}`}
              className="card-section p-3 flex justify-between items-start gap-3"
            >
              <div className="min-w-0">
                <p className="text-sm font-semibold capitalize">{formatLedgerFieldLabel(row.mode)}</p>
                <p className="text-[10px] text-muted-foreground capitalize">
                  {formatLedgerFieldLabel(row.destination)} · {row.entries} entr{row.entries === 1 ? 'y' : 'ies'}
                </p>
                <p className="text-[10px] text-muted-foreground mt-0.5">
                  Cash ₹{row.byChannel.cash.toLocaleString('en-IN')} · Bank ₹{row.byChannel.bank.toLocaleString('en-IN')}
                  {row.byChannel.other > 0 ? ` · Other ₹${row.byChannel.other.toLocaleString('en-IN')}` : ''}
                </p>
              </div>
              <div className="text-right shrink-0">
                <DescriptiveValueButton
                  {...FINANCE_LEDGER_GROUP_METRICS.inflowGroup}
                  title={`${formatLedgerFieldLabel(row.mode)} · ${formatLedgerFieldLabel(row.destination)}`}
                  description={`${FINANCE_LEDGER_GROUP_METRICS.inflowGroup.description} Mode: ${formatLedgerFieldLabel(row.mode)}; destination: ${formatLedgerFieldLabel(row.destination)}.`}
                  howCalculated={`${FINANCE_LEDGER_GROUP_METRICS.inflowGroup.howCalculated} This group: ${row.entries} entr${row.entries === 1 ? 'y' : 'ies'}, ${row.flatUnits} flat units.`}
                  value={`₹${row.total.toLocaleString('en-IN')}`}
                />
                <p className="text-[10px] text-muted-foreground">{row.flatUnits} flat units</p>
              </div>
            </div>
          ))
        )}
      </div>

      <div className="mt-6">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 mb-4">
          <DescriptiveStatCard
            {...FINANCE_TOTALS_METRICS.outflow}
            variant="stat"
            value={`₹${totalsMonthOutflow.toLocaleString('en-IN')}`}
            valueClassName="text-xl text-red-600"
          />
          <DescriptiveStatCard
            {...FINANCE_TOTALS_METRICS.expenseHeads}
            variant="stat"
            value={totalsOutflowBreakdown.length}
            valueClassName="text-xl"
          />
          <DescriptiveStatCard
            {...FINANCE_TOTALS_METRICS.netInflowOutflow}
            variant="stat"
            value={`₹${(totalsMonthNet - totalsMonthOutflow).toLocaleString('en-IN')}`}
            valueClassName={`text-xl ${totalsMonthNet - totalsMonthOutflow >= 0 ? 'text-green-600' : 'text-red-600'}`}
          />
        </div>

        <div className="space-y-2">
          {totalsOutflowBreakdown.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-10">
              No outflow entries for {totalsMonth}. Record separate entries (expenses / payments made) to populate this section.
            </p>
          ) : (
            totalsOutflowBreakdown.map((row) => (
              <div key={row.head} className="card-section p-3 flex justify-between items-start gap-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold">{row.head}</p>
                  <p className="text-[10px] text-muted-foreground capitalize">
                    {row.entries} entr{row.entries === 1 ? 'y' : 'ies'}
                  </p>
                  <p className="text-[10px] text-muted-foreground mt-0.5">
                    Cash ₹{row.byChannel.cash.toLocaleString('en-IN')} · Bank ₹{row.byChannel.bank.toLocaleString('en-IN')}
                    {row.byChannel.other > 0 ? ` · Other ₹${row.byChannel.other.toLocaleString('en-IN')}` : ''}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  <DescriptiveValueButton
                    {...FINANCE_LEDGER_GROUP_METRICS.outflowHead}
                    title={row.head}
                    description={`${FINANCE_LEDGER_GROUP_METRICS.outflowHead.description} Head: ${row.head}.`}
                    howCalculated={`${FINANCE_LEDGER_GROUP_METRICS.outflowHead.howCalculated} This head: ${row.entries} entr${row.entries === 1 ? 'y' : 'ies'}.`}
                    value={`₹${row.total.toLocaleString('en-IN')}`}
                    valueClassName="text-red-600"
                  />
                  <p className="text-[10px] text-muted-foreground">{row.flatUnits} flat units</p>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
