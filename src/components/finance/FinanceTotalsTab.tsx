import { useMemo, useState } from 'react';
import { Calendar, CalendarRange } from 'lucide-react';
import { toast } from 'sonner';
import MonthlyOperatingFundPanel from '@/components/MonthlyOperatingFundPanel';
import CashBankBreakdown from '@/components/CashBankBreakdown';
import { DescriptiveStatCard, DescriptiveValueButton } from '@/components/DescriptiveStatCard';
import ExportFormatMenu from '@/components/ExportFormatMenu';
import SharePdfWhatsAppButton from '@/components/SharePdfWhatsAppButton';
import FinancePeriodReportSendPanel from '@/components/FinancePeriodReportSendPanel';
import { DateInput } from '@/components/DateInput';
import {
  FINANCE_LEDGER_GROUP_METRICS,
  FINANCE_TOTALS_METRICS,
} from '@/lib/descriptiveMetricCopy';
import type { ChannelTotals } from '@/lib/cashBankChannel';
import type { FinanceLedgerRow } from '@/lib/financeManagerTypes';
import type { TotalsInflowRow, TotalsOutflowRow } from '@/lib/financeTotalsBreakdown';
import { formatLedgerFieldLabel } from '@/lib/financeLedgerDisplay';
import { fmtIsoDateToDisplay, fmtIsoMonthToDisplay } from '@/lib/dateFormat';
import {
  computeFinancePeriodReport,
  defaultFinancePeriodFrom,
  defaultFinancePeriodTo,
  financeReportingMonthRange,
  FINANCE_REPORTING_EARLIEST_MONTH,
  type FinancePeriodPayment,
} from '@/lib/financePeriodReport';
import {
  buildFinancePeriodReportPdf,
  toFinancePeriodReportExportInput,
} from '@/lib/financePeriodReportExport';
import { downloadFinancePeriodReport } from '@/lib/transactionStatementExport';
import type { ExportFormat } from '@/lib/reportExportUtils';
import { useSocietyOpeningBalanceAnchors } from '@/hooks/useSocietyOpeningBalanceAnchors';

type PeriodMode = 'monthly' | 'custom';

interface Props {
  societyId: string | null;
  societyName: string;
  adminName: string;
  flats: { flat_number: string }[];
  totalsMonth: string;
  onTotalsMonthChange: (month: string) => void;
  ledgerEntries: FinanceLedgerRow[];
  societyLedgerEntries: FinanceLedgerRow[];
  payments: FinancePeriodPayment[];
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
  societyName,
  adminName,
  flats,
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
  const [periodMode, setPeriodMode] = useState<PeriodMode>('monthly');
  const [customPeriodFrom, setCustomPeriodFrom] = useState(defaultFinancePeriodFrom);
  const [customPeriodTo, setCustomPeriodTo] = useState(defaultFinancePeriodTo);
  const { anchors: openingBalanceAnchors } = useSocietyOpeningBalanceAnchors(societyId);

  const monthRange = useMemo(() => financeReportingMonthRange(totalsMonth), [totalsMonth]);
  const periodFrom = periodMode === 'monthly' ? monthRange.from : customPeriodFrom;
  const periodTo = periodMode === 'monthly' ? monthRange.to : customPeriodTo;
  const periodInvalid = periodFrom > periodTo;
  const periodLabel =
    periodMode === 'monthly'
      ? fmtIsoMonthToDisplay(totalsMonth)
      : `${fmtIsoDateToDisplay(periodFrom)} – ${fmtIsoDateToDisplay(periodTo)}`;

  const periodReport = useMemo(
    () =>
      periodInvalid
        ? null
        : computeFinancePeriodReport({
            periodFrom,
            periodTo,
            payments,
            ledgerEntries: societyLedgerEntries,
            expenseCategoryById,
            openingBalanceAnchors,
          }),
    [
      periodInvalid,
      periodFrom,
      periodTo,
      payments,
      societyLedgerEntries,
      expenseCategoryById,
      openingBalanceAnchors,
    ],
  );

  const periodExportInput = useMemo(
    () =>
      periodReport
        ? toFinancePeriodReportExportInput(periodReport, {
            societyName: societyName || 'Society',
            periodFrom,
            periodTo,
          })
        : null,
    [periodReport, societyName, periodFrom, periodTo],
  );

  const exportFilenameBase = `finance-totals-${periodLabel.replace(/\s+/g, '-')}`;

  const exportPeriodReport = (format: ExportFormat) => {
    if (!periodExportInput || periodInvalid) {
      toast.error(periodInvalid ? 'End date must be on or after start date' : 'No report data for this period');
      return;
    }
    downloadFinancePeriodReport(format, periodExportInput, exportFilenameBase);
    toast.success(`${format.toUpperCase()} downloaded`);
  };

  const flatNumbers = useMemo(() => flats.map((f) => f.flat_number), [flats]);

  return (
    <div>
      <div className="mb-4 rounded-lg border border-border bg-card/40 p-3">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-[11px] font-medium text-foreground">Report period</p>
            <p className="text-[10px] text-muted-foreground">
              Download or share monthly figures as a finance period report
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex gap-1.5">
              <button
                type="button"
                onClick={() => setPeriodMode('monthly')}
                className={`flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium transition-all ${
                  periodMode === 'monthly'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-secondary text-secondary-foreground hover:bg-muted'
                }`}
              >
                <Calendar className="w-3 h-3" />
                Monthly
              </button>
              <button
                type="button"
                onClick={() => setPeriodMode('custom')}
                className={`flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium transition-all ${
                  periodMode === 'custom'
                    ? 'bg-primary text-primary-foreground'
                    : 'bg-secondary text-secondary-foreground hover:bg-muted'
                }`}
              >
                <CalendarRange className="w-3 h-3" />
                Date range
              </button>
            </div>
            <ExportFormatMenu
              label="Download report"
              disabled={!periodExportInput || periodInvalid}
              onExport={exportPeriodReport}
            />
            {periodExportInput && (
              <SharePdfWhatsAppButton
                label="Share report"
                disabled={periodInvalid}
                filename={`${exportFilenameBase}.pdf`}
                message={`${societyName || 'Society'} — ${periodLabel} finance totals report`}
                getBlob={() => buildFinancePeriodReportPdf(periodExportInput)}
              />
            )}
          </div>
        </div>

        {periodMode === 'monthly' ? (
          <div className="mt-3 flex flex-wrap items-end gap-3">
            <div className="min-w-[180px]">
              <p className="text-xs font-medium text-muted-foreground mb-1">Reporting month</p>
              <input
                type="month"
                className="input-field"
                min={FINANCE_REPORTING_EARLIEST_MONTH}
                value={totalsMonth}
                onChange={(e) => onTotalsMonthChange(e.target.value)}
              />
            </div>
            <p className="text-[10px] text-muted-foreground pb-2">
              Scope: {fmtIsoDateToDisplay(monthRange.from)} – {fmtIsoDateToDisplay(monthRange.to)}
            </p>
          </div>
        ) : (
          <div className="mt-3 grid grid-cols-2 gap-2 max-w-md">
            <div>
              <label className="text-[10px] text-muted-foreground mb-1 block">From</label>
              <DateInput
                className="input-field text-sm w-full"
                value={customPeriodFrom}
                onChange={(e) => setCustomPeriodFrom(e.target.value)}
              />
            </div>
            <div>
              <label className="text-[10px] text-muted-foreground mb-1 block">To</label>
              <DateInput
                className="input-field text-sm w-full"
                value={customPeriodTo}
                onChange={(e) => setCustomPeriodTo(e.target.value)}
              />
            </div>
          </div>
        )}
        {periodInvalid && (
          <p className="text-[10px] text-destructive mt-2">End date must be on or after start date.</p>
        )}
        {periodReport && !periodInvalid && (
          <p className="text-[10px] text-muted-foreground mt-2">
            {periodLabel} — receipts ₹{periodReport.totalReceipts.toLocaleString('en-IN')} · expenses ₹
            {periodReport.totalExpenses.toLocaleString('en-IN')} · net ₹
            {periodReport.totalBalance.toLocaleString('en-IN')}
          </p>
        )}
      </div>

      {periodReport && !periodInvalid && (
        <FinancePeriodReportSendPanel
          societyId={societyId}
          societyName={societyName || 'Society'}
          adminName={adminName}
          periodFrom={periodFrom}
          periodTo={periodTo}
          periodLabel={periodLabel}
          periodReport={periodReport}
          flatNumbers={flatNumbers}
        />
      )}

      <MonthlyOperatingFundPanel
        societyId={societyId}
        totalsMonth={totalsMonth}
        onTotalsMonthChange={onTotalsMonthChange}
        ledgerEntries={ledgerEntries}
        societyLedgerEntries={societyLedgerEntries}
        payments={payments}
        charges={charges}
        expenseCategoryById={expenseCategoryById}
        adminName={adminName}
        onRefresh={onRefresh}
      />

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
                  {row.byChannel.other > 0 ? ` · Other ₹{row.byChannel.other.toLocaleString('en-IN')}` : ''}
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
              No outflow entries for {totalsMonth}. Record separate entries (expenses / payments made) to populate this
              section.
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
                    {row.byChannel.other > 0 ? ` · Other ₹{row.byChannel.other.toLocaleString('en-IN')}` : ''}
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
