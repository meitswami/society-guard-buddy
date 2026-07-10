import { useState, useMemo, useCallback } from 'react';
import { ArrowDownLeft, ArrowUpRight, Banknote, Building2, ChevronRight, TrendingUp } from 'lucide-react';
import { fmtDate, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import ReportDetailModal, { type ReportDetailRow } from '@/components/ReportDetailModal';
import { DescriptiveValueButton } from '@/components/DescriptiveStatCard';
import { FINANCE_PERIOD_METRICS } from '@/lib/descriptiveMetricCopy';
import type { FinancePeriodLedgerEntry, FinancePeriodPayment, FinancePeriodReserveTransfer, FinanceOpeningBalanceAnchor } from '@/lib/financePeriodReport';
import {
  computeCashFlowStatement,
  filterStatementByChannel,
  filterStatementEntriesForDrill,
  addRunningBalance,
  type CashFlowLine,
  type StatementEntry,
} from '@/lib/cashFlowStatement';

interface Props {
  periodFrom: string;
  periodTo: string;
  periodLabel?: string;
  societyName?: string;
  loading?: boolean;
  payments: FinancePeriodPayment[];
  societyLedgerEntries: FinancePeriodLedgerEntry[];
  expenseCategoryById: Map<string, string>;
  reserveTransfers: FinancePeriodReserveTransfer[];
  openingBalanceAnchors?: FinanceOpeningBalanceAnchor[];
}

type ModalLayer = {
  title: string;
  subtitle?: string;
  total?: number;
  rows: ReportDetailRow[];
  drillable: boolean;
};

const fmtAmt = (n: number) => {
  if (n === 0) return '—';
  const sign = n < 0 ? '−' : '';
  return `${sign}₹${Math.abs(n).toLocaleString('en-IN')}`;
};

const CashFlowStatement = ({
  periodFrom,
  periodTo,
  periodLabel,
  societyName,
  loading = false,
  payments,
  societyLedgerEntries,
  expenseCategoryById,
  reserveTransfers,
  openingBalanceAnchors = [],
}: Props) => {
  const displayPeriod = periodLabel ?? `${fmtIsoDateToDisplay(periodFrom)} – ${fmtIsoDateToDisplay(periodTo)}`;
  const invalidRange = periodFrom > periodTo;

  const [modalOpen, setModalOpen] = useState(false);
  const [modalStack, setModalStack] = useState<ModalLayer[]>([]);

  const cfs = useMemo(
    () =>
      invalidRange
        ? null
        : computeCashFlowStatement(
            { from: periodFrom, to: periodTo },
            payments,
            societyLedgerEntries,
            reserveTransfers,
            expenseCategoryById,
            openingBalanceAnchors,
          ),
    [periodFrom, periodTo, payments, societyLedgerEntries, reserveTransfers, expenseCategoryById, openingBalanceAnchors, invalidRange],
  );

  const pushModal = useCallback((layer: ModalLayer) => {
    setModalStack((s) => [...s, layer]);
    setModalOpen(true);
  }, []);

  const closeModal = () => {
    setModalOpen(false);
    setModalStack([]);
  };

  const modalBack = () => {
    setModalStack((s) => {
      const next = s.slice(0, -1);
      if (next.length === 0) setModalOpen(false);
      return next;
    });
  };

  const statementEntryToRow = (e: StatementEntry & { runningBalance?: number }): ReportDetailRow => ({
    id: e.id,
    label: e.label,
    sublabel: e.sublabel,
    amount: e.amount,
    date: fmtDate(e.date),
    dateIso: e.date,
    status: e.type === 'expense' ? 'expense' : e.type === 'receipt' ? 'receipt' : e.type,
    extra: e.runningBalance !== undefined ? `Bal: ₹${e.runningBalance.toLocaleString('en-IN')}` : undefined,
    meta: { entry: e },
  });

  const openEntryDetail = (row: ReportDetailRow) => {
    const entry = row.meta?.entry as StatementEntry | undefined;
    if (!entry) return;

    const detailRows: ReportDetailRow[] = [
      { id: 'd-source', label: 'Source', sublabel: entry.source ?? '—' },
      { id: 'd-dest', label: 'Destination', sublabel: entry.destination?.replace(/_/g, ' ') ?? '—' },
      { id: 'd-amt', label: 'Amount', amount: entry.amount },
      { id: 'd-method', label: 'Payment method', sublabel: entry.payment_method ?? '—' },
      { id: 'd-txn', label: 'Transaction ID', sublabel: entry.transaction_id || '—' },
      { id: 'd-date', label: 'Date', sublabel: fmtDate(entry.date) },
      ...(entry.aggregate_flat_count != null
        ? [{ id: 'd-flats', label: 'Flats in entry', sublabel: String(entry.aggregate_flat_count) }]
        : []),
      { id: 'd-notes', label: 'Notes', sublabel: entry.notes || '—' },
    ];

    pushModal({
      title: 'Entry detail',
      subtitle: entry.label,
      total: entry.amount,
      rows: detailRows,
      drillable: false,
    });
  };

  const openCashStatement = () => {
    if (!cfs) return;
    const cashEntries = filterStatementByChannel(cfs.statementEntries, 'cash');
    const withBal = addRunningBalance(cashEntries, cfs.opening.cash);
    pushModal({
      title: 'Cash Statement',
      subtitle: `Chronological cash transactions — ${displayPeriod}`,
      total: cashEntries.reduce((s, r) => s + r.amount, 0),
      rows: withBal.map(statementEntryToRow),
      drillable: true,
    });
  };

  const openBankStatement = () => {
    if (!cfs) return;
    const bankEntries = filterStatementByChannel(cfs.statementEntries, 'bank');
    const withBal = addRunningBalance(bankEntries, cfs.opening.bank);
    pushModal({
      title: 'Bank Statement',
      subtitle: `Chronological bank / UPI transactions — ${displayPeriod}`,
      total: bankEntries.reduce((s, r) => s + r.amount, 0),
      rows: withBal.map(statementEntryToRow),
      drillable: true,
    });
  };

  const drillLine = (line: CashFlowLine) => {
    if (!cfs || !line.drillable || !line.drillKind) return;

    if (line.drillKind === 'cash_statement') {
      openCashStatement();
      return;
    }
    if (line.drillKind === 'bank_statement') {
      openBankStatement();
      return;
    }

    if (line.drillKind === 'reserve') {
      const filtered = cfs.statementEntries.filter((e) => {
        if (e.type !== 'reserve') return false;
        const out = e.amount < 0;
        return line.drillKey === 'out' ? out : !out;
      });
      pushModal({
        title: line.drillKey === 'out' ? 'Reserve transfers (out)' : 'Reserve draw (in)',
        subtitle: displayPeriod,
        total: filtered.reduce((s, r) => s + r.amount, 0),
        rows: filtered.map(statementEntryToRow),
        drillable: true,
      });
      return;
    }

    const filtered = filterStatementEntriesForDrill(cfs.statementEntries, line.drillKind, line.drillKey);
    const title =
      line.drillKind === 'corpus'
        ? 'Corpus receipts'
        : line.drillKind === 'expense_head'
          ? `Payments — ${line.drillKey}`
          : 'Collections — Detail';

    pushModal({
      title,
      subtitle: displayPeriod,
      total: filtered.reduce((s, r) => s + r.amount, 0),
      rows: filtered.map(statementEntryToRow),
      drillable: true,
    });
  };

  const currentModal = modalStack[modalStack.length - 1];

  const sectionIcon = (section: CashFlowLine['section']) => {
    if (section === 'operating') return <TrendingUp className="w-3.5 h-3.5 text-green-600" />;
    if (section === 'investing') return <Building2 className="w-3.5 h-3.5 text-blue-600" />;
    if (section === 'financing') return <ArrowDownLeft className="w-3.5 h-3.5 text-purple-600" />;
    return null;
  };

  return (
    <div className="mb-5 rounded-xl border border-border bg-card/40 overflow-hidden">
      <div className="flex items-center justify-between gap-2 p-3 border-b border-border/60 bg-muted/20">
        <div>
          <h2 className="text-sm font-semibold">Cash Flow Statement</h2>
          <p className="text-[10px] text-muted-foreground">
            {displayPeriod} · Synced with Finance → Period report
          </p>
        </div>
        <div className="flex gap-1.5 shrink-0">
          <button
            type="button"
            onClick={openCashStatement}
            disabled={!cfs}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400 hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            <Banknote className="w-3 h-3" />
            Cash Stmt
          </button>
          <button
            type="button"
            onClick={openBankStatement}
            disabled={!cfs}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400 hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            <Building2 className="w-3 h-3" />
            Bank Stmt
          </button>
        </div>
      </div>

      {invalidRange ? (
        <p className="text-xs text-destructive text-center py-6">End date must be on or after start date.</p>
      ) : loading ? (
        <p className="text-xs text-muted-foreground text-center py-6">Loading cash flow data…</p>
      ) : !cfs ? null : (
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="text-left text-muted-foreground border-b border-border/60">
                <th className="py-2 pl-3 pr-2 font-medium">Particulars</th>
                <th className="py-2 pr-3 font-medium text-right w-28">Amount (₹)</th>
              </tr>
            </thead>
            <tbody>
              {cfs.lines.map((line) => {
                if (line.id.startsWith('sep')) {
                  return (
                    <tr key={line.id}>
                      <td colSpan={2} className="py-1" />
                    </tr>
                  );
                }
                const isSectionHeader = line.bold && line.amount === 0 && !line.indent;

                if (line.drillable) {
                  return (
                    <tr key={line.id} className="border-b border-border/40">
                      <td colSpan={2} className="p-0">
                        <button
                          type="button"
                          onClick={() => drillLine(line)}
                          className="w-full flex items-center justify-between gap-2 py-2 pl-3 pr-3 hover:bg-muted/40 transition-colors text-left"
                        >
                          <span
                            className={`flex items-center gap-1.5 ${line.indent ? 'pl-4' : ''} ${line.bold ? 'font-semibold' : ''}`}
                          >
                            {isSectionHeader && sectionIcon(line.section)}
                            {line.label}
                            <ChevronRight className="w-3 h-3 text-muted-foreground inline" />
                          </span>
                          <span
                            className={`font-mono shrink-0 ${line.bold ? 'font-semibold' : ''} ${
                              line.amount < 0 ? 'text-red-600 dark:text-red-400' : line.amount > 0 ? '' : 'text-muted-foreground'
                            }`}
                          >
                            {fmtAmt(line.amount)}
                          </span>
                        </button>
                      </td>
                    </tr>
                  );
                }

                return (
                  <tr key={line.id} className={`border-b border-border/40 ${line.bold ? 'bg-muted/10' : ''}`}>
                    <td className={`py-2 pl-3 pr-2 ${line.indent ? 'pl-7' : ''} ${line.bold ? 'font-semibold' : ''}`}>
                      <span className="flex items-center gap-1.5">
                        {isSectionHeader && sectionIcon(line.section)}
                        {line.label}
                      </span>
                    </td>
                    <td
                      className={`py-2 pr-3 text-right font-mono ${line.bold ? 'font-semibold' : ''} ${
                        line.amount < 0 ? 'text-red-600 dark:text-red-400' : line.amount > 0 ? '' : 'text-muted-foreground'
                      }`}
                    >
                      {fmtAmt(line.amount)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
            <tfoot>
              <tr className="border-t border-border bg-primary/5">
                <td className="py-2.5 pl-3 font-semibold text-xs">Closing cash + bank</td>
                <td className="py-2.5 pr-3 text-right font-mono font-semibold text-primary text-xs">
                  <DescriptiveValueButton
                    {...FINANCE_PERIOD_METRICS.closingBalance}
                    title="Closing cash + bank"
                    description="Combined cash and bank position at period end (excludes other channels)."
                    howCalculated="Closing cash + closing bank from the cash flow statement."
                    value={`₹${(cfs.closing.cash + cfs.closing.bank).toLocaleString('en-IN')}`}
                    valueClassName="text-xs font-mono font-semibold text-primary"
                    className="justify-end w-full px-0.5 py-0"
                  />
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {cfs && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 p-3 border-t border-border/60 bg-muted/10">
          <button
            type="button"
            onClick={openCashStatement}
            className="rounded-lg border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20 p-2 text-left hover:ring-2 hover:ring-green-500/20 transition-all"
          >
            <p className="text-[10px] text-muted-foreground flex items-center gap-1">
              <ArrowUpRight className="w-3 h-3 text-green-600" /> Closing cash
            </p>
            <p className="text-xs font-mono font-semibold">₹{cfs.closing.cash.toLocaleString('en-IN')}</p>
          </button>
          <button
            type="button"
            onClick={openBankStatement}
            className="rounded-lg border border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 p-2 text-left hover:ring-2 hover:ring-blue-500/20 transition-all"
          >
            <p className="text-[10px] text-muted-foreground flex items-center gap-1">
              <Building2 className="w-3 h-3 text-blue-600" /> Closing bank
            </p>
            <p className="text-xs font-mono font-semibold">₹{cfs.closing.bank.toLocaleString('en-IN')}</p>
          </button>
          <div className="rounded-lg border border-border bg-background/60 p-2">
            <p className="text-[10px] text-muted-foreground">Period net (cash)</p>
            <DescriptiveValueButton
              {...FINANCE_PERIOD_METRICS.cashInHand}
              value={`₹${cfs.periodReport.cashInHand.toLocaleString('en-IN')}`}
              valueClassName="text-xs font-mono font-semibold"
              className="px-0.5 py-0"
            />
          </div>
          <div className="rounded-lg border border-border bg-background/60 p-2">
            <p className="text-[10px] text-muted-foreground">Period net (bank)</p>
            <DescriptiveValueButton
              {...FINANCE_PERIOD_METRICS.cashInBank}
              value={`₹${cfs.periodReport.cashInBank.toLocaleString('en-IN')}`}
              valueClassName="text-xs font-mono font-semibold"
              className="px-0.5 py-0"
            />
          </div>
        </div>
      )}

      {currentModal && (
        <ReportDetailModal
          open={modalOpen}
          onClose={closeModal}
          onBack={modalStack.length > 1 ? modalBack : undefined}
          title={currentModal.title}
          subtitle={currentModal.subtitle}
          totalAmount={currentModal.total}
          rows={currentModal.rows}
          drillable={currentModal.drillable}
          onRowClick={currentModal.drillable ? openEntryDetail : undefined}
          societyName={societyName}
        />
      )}
    </div>
  );
};

export default CashFlowStatement;
