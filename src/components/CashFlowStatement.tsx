import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { ArrowDownLeft, ArrowUpRight, Banknote, Building2, ChevronRight, TrendingUp } from 'lucide-react';
import { fmtDate, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import ReportDetailModal, { type ReportDetailRow } from '@/components/ReportDetailModal';
import {
  computeCashFlowStatement,
  filterStatementByChannel,
  addRunningBalance,
  type FinanceEntryForCfs,
  type ReserveTransferForCfs,
  type CashFlowLine,
  type StatementEntry,
} from '@/lib/cashFlowStatement';
import { financeExpenseHeadFromLedgerEntry } from '@/lib/financeExpenseHead';
import { dateInInclusiveRange, ledgerTransactionDate } from '@/lib/financeDates';
import type { PaymentChannel } from '@/lib/cashBankChannel';

interface Props {
  periodFrom: string;
  periodTo: string;
  periodLabel?: string;
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

const CashFlowStatement = ({ periodFrom, periodTo, periodLabel }: Props) => {
  const { societyId } = useStore();
  const [entries, setEntries] = useState<FinanceEntryForCfs[]>([]);
  const [reserveTransfers, setReserveTransfers] = useState<ReserveTransferForCfs[]>([]);
  const [expenseCategoryById, setExpenseCategoryById] = useState<Map<string, string>>(new Map());
  const [loading, setLoading] = useState(false);

  const periodEndMonth = periodTo.slice(0, 7);
  const displayPeriod = periodLabel ?? `${fmtIsoDateToDisplay(periodFrom)} – ${fmtIsoDateToDisplay(periodTo)}`;
  const invalidRange = periodFrom > periodTo;

  const [modalOpen, setModalOpen] = useState(false);
  const [modalStack, setModalStack] = useState<ModalLayer[]>([]);

  useEffect(() => {
    const load = async () => {
      if (!societyId || invalidRange) {
        setEntries([]);
        setReserveTransfers([]);
        return;
      }
      setLoading(true);
      const { data: feData } = await supabase
        .from('finance_entries')
        .select(
          'id, record_mode, destination, total_amount, entry_month, created_at, payment_status, payment_method, title, notes, transaction_id, transaction_date, expense_id, aggregate_flat_count',
        )
        .eq('society_id', societyId)
        .lte('entry_month', periodEndMonth)
        .order('entry_month', { ascending: true })
        .limit(3000);

      setEntries((feData as FinanceEntryForCfs[]) ?? []);

      const { data: rtData } = await supabase
        .from('reserve_fund_transfers')
        .select('id, entry_month, amount, direction, payment_method, notes, created_at')
        .eq('society_id', societyId)
        .lte('entry_month', periodEndMonth);

      setReserveTransfers((rtData as ReserveTransferForCfs[]) ?? []);

      const expIds = [...new Set((feData ?? []).map((e: FinanceEntryForCfs) => e.expense_id).filter(Boolean))] as string[];
      if (expIds.length) {
        const { data: exData } = await supabase.from('expenses').select('id, expense_category').in('id', expIds);
        const map = new Map<string, string>();
        for (const ex of (exData as { id: string; expense_category: string }[] | null) ?? []) {
          map.set(ex.id, ex.expense_category);
        }
        setExpenseCategoryById(map);
      } else {
        setExpenseCategoryById(new Map());
      }
      setLoading(false);
    };
    void load();
  }, [societyId, periodEndMonth, invalidRange]);

  const cfs = useMemo(
    () => computeCashFlowStatement({ from: periodFrom, to: periodTo }, entries, reserveTransfers, expenseCategoryById),
    [periodFrom, periodTo, entries, reserveTransfers, expenseCategoryById],
  );

  const periodEntries = useMemo(
    () =>
      entries.filter(
        (e) =>
          String(e.payment_status) === 'verified' &&
          dateInInclusiveRange(ledgerTransactionDate(e), periodFrom, periodTo),
      ),
    [entries, periodFrom, periodTo],
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
    status: e.type === 'expense' ? 'expense' : e.type === 'receipt' ? 'receipt' : e.type,
    extra: e.runningBalance !== undefined ? `Bal: ₹${e.runningBalance.toLocaleString('en-IN')}` : undefined,
    meta: { entry: e },
  });

  const financeEntryToRow = (e: FinanceEntryForCfs): ReportDetailRow => {
    const isExpense = e.destination === 'separate_entry';
    const head =
      isExpense
        ? financeExpenseHeadFromLedgerEntry(e.title, e.expense_id ? expenseCategoryById.get(e.expense_id) : null)
        : undefined;
    return {
      id: e.id,
      label: e.title || `${e.record_mode.replace(/_/g, ' ')} → ${e.destination.replace(/_/g, ' ')}`,
      sublabel: head ? `Head: ${head} · ${e.payment_method}` : `Method: ${e.payment_method}`,
      amount: isExpense ? -Number(e.total_amount || 0) : Number(e.total_amount || 0),
      date: fmtDate(ledgerTransactionDate(e)),
      status: isExpense ? 'expense' : 'receipt',
      meta: { financeEntry: e },
    };
  };

  const openEntryDetail = (row: ReportDetailRow) => {
    const entry = row.meta?.entry as StatementEntry | undefined;
    const fe = row.meta?.financeEntry as FinanceEntryForCfs | undefined;
    const detail = entry ?? (fe ? {
      label: fe.title || `${fe.record_mode} → ${fe.destination}`,
      date: fe.transaction_date || fe.entry_month || fe.created_at,
      amount: fe.destination === 'separate_entry' ? -Number(fe.total_amount) : Number(fe.total_amount),
      record_mode: fe.record_mode,
      destination: fe.destination,
      payment_method: fe.payment_method,
      notes: fe.notes ?? undefined,
      transaction_id: fe.transaction_id ?? undefined,
      aggregate_flat_count: fe.aggregate_flat_count,
    } : null);

    if (!detail) return;

    const detailRows: ReportDetailRow[] = [
      { id: 'd-mode', label: 'Record mode', sublabel: detail.record_mode?.replace(/_/g, ' ') ?? '—' },
      { id: 'd-dest', label: 'Destination', sublabel: detail.destination?.replace(/_/g, ' ') ?? '—' },
      { id: 'd-amt', label: 'Amount', amount: 'amount' in detail ? detail.amount : undefined },
      { id: 'd-method', label: 'Payment method', sublabel: detail.payment_method ?? '—' },
      { id: 'd-txn', label: 'Transaction ID', sublabel: detail.transaction_id || '—' },
      { id: 'd-date', label: 'Date', sublabel: fmtDate(String(detail.date || '')) },
      { id: 'd-flats', label: 'Flats in entry', sublabel: String(detail.aggregate_flat_count ?? '—') },
      { id: 'd-notes', label: 'Notes', sublabel: detail.notes || '—' },
    ].filter((r) => r.id !== 'd-flats' || detail.aggregate_flat_count != null);

    pushModal({
      title: 'Entry detail',
      subtitle: detail.label,
      total: 'amount' in detail ? detail.amount : undefined,
      rows: detailRows,
      drillable: false,
    });
  };

  const openCashStatement = () => {
    const cashEntries = filterStatementByChannel(cfs.statementEntries, 'cash');
    const withBal = addRunningBalance(cashEntries, cfs.opening.cash);
    pushModal({
      title: 'Cash Statement',
      subtitle: `Chronological cash transactions — ${displayPeriod}`,
      total: cfs.closing.cash,
      rows: withBal.map(statementEntryToRow),
      drillable: true,
    });
  };

  const openBankStatement = () => {
    const bankEntries = filterStatementByChannel(cfs.statementEntries, 'bank');
    const withBal = addRunningBalance(bankEntries, cfs.opening.bank);
    pushModal({
      title: 'Bank Statement',
      subtitle: `Chronological bank / UPI transactions — ${displayPeriod}`,
      total: cfs.closing.bank,
      rows: withBal.map(statementEntryToRow),
      drillable: true,
    });
  };

  const drillLine = (line: CashFlowLine) => {
    if (!line.drillable || !line.drillKind) return;

    if (line.drillKind === 'cash_statement') {
      openCashStatement();
      return;
    }
    if (line.drillKind === 'bank_statement') {
      openBankStatement();
      return;
    }

    if (line.drillKind === 'receipts') {
      const rows = periodEntries
        .filter((e) => e.destination === 'current_month_maintenance' || e.destination === 'corpus')
        .map(financeEntryToRow);
      pushModal({
        title: 'Collections — Detail',
        subtitle: displayPeriod,
        total: cfs.periodReceipts,
        rows,
        drillable: true,
      });
      return;
    }

    if (line.drillKind === 'corpus') {
      const rows = periodEntries.filter((e) => e.destination === 'corpus').map(financeEntryToRow);
      pushModal({
        title: 'Corpus receipts',
        subtitle: displayPeriod,
        total: rows.reduce((s, r) => s + (r.amount ?? 0), 0),
        rows,
        drillable: true,
      });
      return;
    }

    if (line.drillKind === 'expense_head' && line.drillKey) {
      const rows = periodEntries
        .filter((e) => {
          if (e.destination !== 'separate_entry') return false;
          const head = financeExpenseHeadFromLedgerEntry(
            e.title,
            e.expense_id ? expenseCategoryById.get(e.expense_id) : null,
          );
          return head === line.drillKey;
        })
        .map(financeEntryToRow);
      pushModal({
        title: `Payments — ${line.drillKey}`,
        subtitle: displayPeriod,
        total: rows.reduce((s, r) => s + (r.amount ?? 0), 0),
        rows,
        drillable: true,
      });
      return;
    }

    if (line.drillKind === 'reserve') {
      const periodRt = reserveTransfers.filter((r) =>
        dateInInclusiveRange(`${r.entry_month}-01`, periodFrom, periodTo),
      );
      const filtered =
        line.drillKey === 'out'
          ? periodRt.filter((r) => ['operating_to_reserve', 'reserve_to_fixed', 'reserve_to_emergency'].includes(r.direction))
          : periodRt.filter((r) => r.direction === 'reserve_to_operating');

      const rows: ReportDetailRow[] = filtered.map((r) => ({
        id: r.id,
        label: r.direction.replace(/_/g, ' '),
        sublabel: r.notes || r.payment_method,
        amount: line.drillKey === 'out' ? -Number(r.amount) : Number(r.amount),
        date: fmtDate(`${r.entry_month}-01`),
        status: 'reserve',
        meta: { reserve: r },
      }));
      pushModal({
        title: line.drillKey === 'out' ? 'Reserve transfers (out)' : 'Reserve draw (in)',
        subtitle: displayPeriod,
        total: rows.reduce((s, r) => s + (r.amount ?? 0), 0),
        rows,
        drillable: false,
      });
    }
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
          <p className="text-[10px] text-muted-foreground">{displayPeriod} · Tap lines to drill down to entries</p>
        </div>
        <div className="flex gap-1.5 shrink-0">
          <button
            type="button"
            onClick={openCashStatement}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400 hover:opacity-90 transition-opacity"
          >
            <Banknote className="w-3 h-3" />
            Cash Stmt
          </button>
          <button
            type="button"
            onClick={openBankStatement}
            className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[10px] font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400 hover:opacity-90 transition-opacity"
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
      ) : (
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
                const RowTag = line.drillable ? 'button' : 'tr';

                if (RowTag === 'button') {
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
                            {line.drillable && <ChevronRight className="w-3 h-3 text-muted-foreground inline" />}
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
                  ₹{(cfs.closing.cash + cfs.closing.bank).toLocaleString('en-IN')}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {/* Summary chips */}
      <div className="grid grid-cols-3 gap-2 p-3 border-t border-border/60 bg-muted/10">
        <button
          type="button"
          onClick={openCashStatement}
          className="rounded-lg border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20 p-2 text-left hover:ring-2 hover:ring-green-500/20 transition-all"
        >
          <p className="text-[10px] text-muted-foreground flex items-center gap-1">
            <ArrowUpRight className="w-3 h-3 text-green-600" /> Cash in hand
          </p>
          <p className="text-xs font-mono font-semibold">₹{cfs.closing.cash.toLocaleString('en-IN')}</p>
        </button>
        <button
          type="button"
          onClick={openBankStatement}
          className="rounded-lg border border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 p-2 text-left hover:ring-2 hover:ring-blue-500/20 transition-all"
        >
          <p className="text-[10px] text-muted-foreground flex items-center gap-1">
            <Building2 className="w-3 h-3 text-blue-600" /> Bank balance
          </p>
          <p className="text-xs font-mono font-semibold">₹{cfs.closing.bank.toLocaleString('en-IN')}</p>
        </button>
        <div className="rounded-lg border border-border bg-background/60 p-2">
          <p className="text-[10px] text-muted-foreground">Net change</p>
          <p
            className={`text-xs font-mono font-semibold ${
              cfs.netChange.total < 0 ? 'text-red-600' : cfs.netChange.total > 0 ? 'text-green-600' : ''
            }`}
          >
            {fmtAmt(cfs.netChange.total)}
          </p>
        </div>
      </div>

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
        />
      )}
    </div>
  );
};

export default CashFlowStatement;
