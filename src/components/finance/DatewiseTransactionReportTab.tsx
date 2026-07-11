import { useState, useMemo, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import { Calendar, Download, Share2, Filter, Eye } from 'lucide-react';
import { toast } from 'sonner';
import { format, subDays, startOfMonth, endOfMonth, subMonths } from 'date-fns';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { DateInput } from '@/components/DateInput';
import ExportFormatMenu from '@/components/ExportFormatMenu';
import { Button } from '@/components/ui/button';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import type { ExportFormat } from '@/lib/reportExportUtils';
import { triggerDownload, moneyInr } from '@/lib/reportExportUtils';
import {
  buildDatewiseTransactionPdf,
  buildDatewiseTransactionSummaryPdf,
  buildDatewiseTransactionExcel,
  buildDatewiseTransactionCsv,
  type HeadwiseSummaryRow,
} from '@/lib/datewiseTransactionExport';
import DatewisePdfPreviewModal from './DatewisePdfPreviewModal';

type AccountFilter = 'all' | 'cash' | 'bank' | 'other';
type TypeFilter = 'all' | 'receipt' | 'payment';
type PeriodFilter = 'custom' | 'today' | 'this_week' | 'this_month' | 'last_month' | 'last_3_months' | 'last_6_months' | 'this_year';

interface TransactionData {
  id: string;
  transaction_date: string;
  payment_method: string;
  record_mode: string;
  payment_status: string;
  total_amount: number;
  title: string | null;
  notes: string | null;
  destination: string | null;
  allocation_style: string | null;
}

export default function DatewiseTransactionReportTab() {
  const { t } = useLanguage();
  const { societyId } = useStore();
  const [loading, setLoading] = useState(false);
  const [transactions, setTransactions] = useState<TransactionData[]>([]);
  const [showPdfModal, setShowPdfModal] = useState(false);
  const [pdfBlob, setPdfBlob] = useState<Blob | null>(null);
  const [reportGenerated, setReportGenerated] = useState(false);

  // Filters
  const [periodFilter, setPeriodFilter] = useState<PeriodFilter>('this_month');
  const [accountFilter, setAccountFilter] = useState<AccountFilter>('all');
  const [typeFilter, setTypeFilter] = useState<TypeFilter>('all');
  const [customStartDate, setCustomStartDate] = useState<string>(format(subDays(new Date(), 30), 'yyyy-MM-dd'));
  const [customEndDate, setCustomEndDate] = useState<string>(format(new Date(), 'yyyy-MM-dd'));

  // Calculate date range from period filter
  const { startDate, endDate } = useMemo(() => {
    const today = new Date();
    let start: Date;
    let end = today;

    switch (periodFilter) {
      case 'today':
        start = today;
        break;
      case 'this_week':
        start = subDays(today, 7);
        break;
      case 'this_month':
        start = startOfMonth(today);
        end = endOfMonth(today);
        break;
      case 'last_month': {
        const lastMonth = subMonths(today, 1);
        start = startOfMonth(lastMonth);
        end = endOfMonth(lastMonth);
        break;
      }
      case 'last_3_months':
        start = subDays(today, 90);
        break;
      case 'last_6_months':
        start = subDays(today, 180);
        break;
      case 'this_year':
        start = new Date(today.getFullYear(), 0, 1);
        end = today;
        break;
      case 'custom':
        start = new Date(customStartDate);
        end = new Date(customEndDate);
        break;
      default:
        start = today;
    }

    return { startDate: start, endDate: end };
  }, [periodFilter, customStartDate, customEndDate]);

  // Fetch transactions
  const fetchTransactions = useCallback(async () => {
    if (!societyId) {
      toast.error('Please select a society');
      return;
    }

    setLoading(true);
    try {
      const startIso = format(startDate, 'yyyy-MM-dd');
      const endIso = format(endDate, 'yyyy-MM-dd');

      let query = supabase
        .from('finance_entries')
        .select('id, transaction_date, payment_method, record_mode, payment_status, total_amount, title, notes, destination, allocation_style')
        .eq('society_id', societyId)
        .gte('transaction_date', startIso)
        .lte('transaction_date', endIso)
        .order('transaction_date', { ascending: false });

      // Filter by payment method (cash/bank/other)
      if (accountFilter !== 'all') {
        if (accountFilter === 'cash') {
          query = query.eq('payment_method', 'cash');
        } else if (accountFilter === 'bank') {
          query = query.eq('payment_method', 'bank');
        } else if (accountFilter === 'other') {
          query = query.in('payment_method', ['cheque', 'upi', 'online', 'other']);
        }
      }

      const { data, error } = await query;

      if (error) throw error;

      // Filter by record mode (receipt/payment)
      let filtered = data || [];
      if (typeFilter !== 'all') {
        const isReceipt = typeFilter === 'receipt';
        filtered = filtered.filter((t) => isReceipt ? t.record_mode === 'receipt' : t.record_mode === 'payment');
      }

      setTransactions(filtered);
      setReportGenerated(true);
      toast.success(`Report generated with ${filtered.length} transactions`);
    } catch (error) {
      console.error('Error fetching transactions:', error);
      toast.error('Failed to load transactions');
      setReportGenerated(false);
    } finally {
      setLoading(false);
    }
  }, [societyId, startDate, endDate, accountFilter, typeFilter]);

  // Build headwise summary
  const headwiseSummary = useMemo((): HeadwiseSummaryRow[] => {
    const map = new Map<string, HeadwiseSummaryRow>();

    for (const t of transactions) {
      const head = t.title || 'Uncategorized';
      if (!map.has(head)) {
        map.set(head, {
          head,
          entries: 0,
          amount: 0,
          cash: 0,
          bank: 0,
          other: 0,
        });
      }
      const row = map.get(head)!;
      row.entries += 1;
      row.amount += t.total_amount || 0;

      if (t.payment_method === 'cash') {
        row.cash += t.total_amount || 0;
      } else if (t.payment_method === 'bank') {
        row.bank += t.total_amount || 0;
      } else {
        row.other += t.total_amount || 0;
      }
    }

    return Array.from(map.values()).sort((a, b) => b.amount - a.amount);
  }, [transactions]);

  // Calculate totals
  const totals = useMemo(() => {
    let receipt = 0;
    let payment = 0;
    let cash = 0;
    let bank = 0;

    for (const t of transactions) {
      const amt = t.total_amount || 0;
      if (t.record_mode === 'receipt') {
        receipt += amt;
      } else if (t.record_mode === 'payment') {
        payment += amt;
      }

      if (t.payment_method === 'cash') {
        cash += amt;
      } else if (t.payment_method === 'bank') {
        bank += amt;
      }
    }

    return { receipt, payment, cash, bank, total: receipt + payment };
  }, [transactions]);

  // Handle preview
  const handlePreviewPdf = async () => {
    if (headwiseSummary.length === 0) {
      toast.error('No transactions to preview');
      return;
    }

    try {
      const blob = await buildDatewiseTransactionSummaryPdf(
        headwiseSummary,
        startDate,
        endDate,
        accountFilter,
        typeFilter,
        totals
      );
      setPdfBlob(blob);
      setShowPdfModal(true);
    } catch (error) {
      console.error('Preview error:', error);
      toast.error('Failed to generate PDF preview');
    }
  };

  // Export handler
  const handleExport = async (exportFormat: ExportFormat) => {
    if (headwiseSummary.length === 0) {
      toast.error('No transactions to export');
      return;
    }

    try {
      const filename = `Datewise_Report_${format(startDate, 'yyyy-MM-dd')}_to_${format(endDate, 'yyyy-MM-dd')}`;
      let blob: Blob;

      switch (exportFormat) {
        case 'pdf': {
          blob = await buildDatewiseTransactionSummaryPdf(headwiseSummary, startDate, endDate, accountFilter, typeFilter, totals);
          triggerDownload(blob, `${filename}.pdf`);
          break;
        }
        case 'excel': {
          blob = buildDatewiseTransactionExcel(transactions, startDate, endDate, accountFilter, typeFilter, totals);
          triggerDownload(blob, `${filename}.xlsx`);
          break;
        }
        case 'csv': {
          blob = buildDatewiseTransactionCsv(transactions);
          triggerDownload(blob, `${filename}.csv`);
          break;
        }
        default:
          toast.error('Format not supported');
          return;
      }

      toast.success(`${exportFormat.toUpperCase()} exported successfully`);
    } catch (error) {
      console.error('Export error:', error);
      toast.error(`Failed to export ${exportFormat}`);
    }
  };

  const getDetailedBlob = async () => {
    return buildDatewiseTransactionPdf(transactions, startDate, endDate, accountFilter, typeFilter, totals);
  };

  const getSummaryBlob = async () => {
    return buildDatewiseTransactionSummaryPdf(headwiseSummary, startDate, endDate, accountFilter, typeFilter, totals);
  };

  return (
    <div className="space-y-6">
      {/* Step 1: Filter Section */}
      <div className="border rounded-lg p-4 bg-card">
        <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
          <Filter className="w-4 h-4" />
          Step 1: Select Filters
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Period filter */}
          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">Period</label>
            <Select value={periodFilter} onValueChange={(v) => setPeriodFilter(v as PeriodFilter)}>
              <SelectTrigger className="h-9 text-sm">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="today">Today</SelectItem>
                <SelectItem value="this_week">This Week</SelectItem>
                <SelectItem value="this_month">This Month</SelectItem>
                <SelectItem value="last_month">Last Month</SelectItem>
                <SelectItem value="last_3_months">Last 3 Months</SelectItem>
                <SelectItem value="last_6_months">Last 6 Months</SelectItem>
                <SelectItem value="this_year">This Year</SelectItem>
                <SelectItem value="custom">Custom Range</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Account filter */}
          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">Account</label>
            <Select value={accountFilter} onValueChange={(v) => setAccountFilter(v as AccountFilter)}>
              <SelectTrigger className="h-9 text-sm">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Accounts</SelectItem>
                <SelectItem value="cash">Cash Only</SelectItem>
                <SelectItem value="bank">Bank Only</SelectItem>
                <SelectItem value="other">Other Payments</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Type filter */}
          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">Type</label>
            <Select value={typeFilter} onValueChange={(v) => setTypeFilter(v as TypeFilter)}>
              <SelectTrigger className="h-9 text-sm">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Types</SelectItem>
                <SelectItem value="receipt">Receipt Only</SelectItem>
                <SelectItem value="payment">Payment Only</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* Custom date range */}
        {periodFilter === 'custom' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">From Date</label>
              <DateInput
                value={customStartDate}
                onChange={setCustomStartDate}
                className="h-9 text-sm"
              />
            </div>
            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">To Date</label>
              <DateInput
                value={customEndDate}
                onChange={setCustomEndDate}
                className="h-9 text-sm"
              />
            </div>
          </div>
        )}

        {/* Date display */}
        <div className="mt-4 text-xs text-muted-foreground border-t pt-3">
          <strong>Report Period:</strong> {fmtIsoDateToDisplay(format(startDate, 'yyyy-MM-dd'))} to {fmtIsoDateToDisplay(format(endDate, 'yyyy-MM-dd'))}
        </div>
      </div>

      {/* Step 2: Generate Report Button */}
      <div className="flex gap-2">
        <Button
          onClick={fetchTransactions}
          disabled={loading}
          className="h-10 px-6 flex items-center gap-2"
        >
          {loading ? (
            <>
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              Generating Report...
            </>
          ) : (
            <>
              <Calendar className="w-4 h-4" />
              Generate Report
            </>
          )}
        </Button>
        <div className="text-xs text-muted-foreground flex items-center">
          {reportGenerated && transactions.length > 0 && (
            <span>✓ {transactions.length} transactions found</span>
          )}
        </div>
      </div>

      {/* Step 3: Report Display & Export/Share */}
      {reportGenerated && transactions.length > 0 && (
        <>
          {/* Summary cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div className="bg-blue-50 p-3 rounded-lg border border-blue-200">
              <p className="text-xs text-muted-foreground">Receipt Total</p>
              <p className="text-lg font-semibold text-blue-700">{moneyInr(totals.receipt)}</p>
            </div>
            <div className="bg-red-50 p-3 rounded-lg border border-red-200">
              <p className="text-xs text-muted-foreground">Payment Total</p>
              <p className="text-lg font-semibold text-red-700">{moneyInr(totals.payment)}</p>
            </div>
            <div className="bg-green-50 p-3 rounded-lg border border-green-200">
              <p className="text-xs text-muted-foreground">Cash Total</p>
              <p className="text-lg font-semibold text-green-700">{moneyInr(totals.cash)}</p>
            </div>
            <div className="bg-purple-50 p-3 rounded-lg border border-purple-200">
              <p className="text-xs text-muted-foreground">Bank Total</p>
              <p className="text-lg font-semibold text-purple-700">{moneyInr(totals.bank)}</p>
            </div>
          </div>

          {/* Headwise summary table */}
          <div className="border rounded-lg overflow-hidden">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow className="bg-secondary">
                    <TableHead className="text-left font-medium">Head / Category</TableHead>
                    <TableHead className="text-center font-medium">Entries</TableHead>
                    <TableHead className="text-right font-medium">Total Amount</TableHead>
                    <TableHead className="text-right font-medium">Cash</TableHead>
                    <TableHead className="text-right font-medium">Bank</TableHead>
                    <TableHead className="text-right font-medium">Other</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {headwiseSummary.map((row, idx) => (
                    <TableRow key={idx} className="hover:bg-secondary/30">
                      <TableCell className="text-left">{row.head}</TableCell>
                      <TableCell className="text-center text-sm">{row.entries}</TableCell>
                      <TableCell className="text-right font-medium">{moneyInr(row.amount)}</TableCell>
                      <TableCell className="text-right text-green-600">{moneyInr(row.cash)}</TableCell>
                      <TableCell className="text-right text-blue-600">{moneyInr(row.bank)}</TableCell>
                      <TableCell className="text-right text-gray-600">{moneyInr(row.other)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </div>

          {/* Step 3: Export & Share Options */}
          <div className="border rounded-lg p-4 bg-secondary/30">
            <h3 className="text-sm font-semibold mb-4 flex items-center gap-2">
              <Share2 className="w-4 h-4" />
              Step 3: Export or Share
            </h3>

            <div className="flex flex-wrap gap-2">
              <Button
                onClick={handlePreviewPdf}
                variant="outline"
                size="sm"
                className="gap-2"
              >
                <Eye className="w-4 h-4" />
                Preview PDF
              </Button>

              <ExportFormatMenu
                onExport={handleExport}
                formats={['pdf', 'excel', 'csv']}
                label="Download"
                className="btn-secondary text-xs px-3 py-2 flex items-center gap-1.5 h-9"
              />
            </div>

            <div className="text-xs text-muted-foreground mt-3">
              Preview PDF in the app, or download in your preferred format (PDF, Excel, CSV). Share PDF directly to WhatsApp from the preview.
            </div>
          </div>

          {/* Footer info */}
          <div className="text-xs text-muted-foreground bg-secondary/30 p-3 rounded-lg">
            <p>Summary: {headwiseSummary.length} head(s) • Total Entries: {transactions.length} • Total Amount: {moneyInr(totals.total)}</p>
          </div>
        </>
      )}

      {/* No data state */}
      {reportGenerated && transactions.length === 0 && (
        <div className="p-8 text-center text-muted-foreground border rounded-lg bg-secondary/20">
          <Filter className="w-10 h-10 mx-auto mb-2 opacity-50" />
          <p>No transactions found for the selected filters.</p>
          <p className="text-xs mt-1">Try adjusting your filters and click "Generate Report" again.</p>
        </div>
      )}

      {/* PDF Preview Modal */}
      {pdfBlob && (
        <DatewisePdfPreviewModal
          open={showPdfModal}
          onOpenChange={setShowPdfModal}
          pdfBlob={pdfBlob}
          filename={`Datewise_Report_${format(startDate, 'yyyy-MM-dd')}_to_${format(endDate, 'yyyy-MM-dd')}`}
          getDetailedBlob={getDetailedBlob}
          getSummaryBlob={getSummaryBlob}
        />
      )}
    </div>
  );
}
