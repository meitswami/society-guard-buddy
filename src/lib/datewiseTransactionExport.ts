import jsPDF from 'jspdf';
import * as XLSX from 'xlsx';
import { format } from 'date-fns';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { moneyInr, rowsToCsvBlob, rowsToXlsxBlob } from '@/lib/reportExportUtils';

export type DatewiseTransactionRow = {
  date: string;
  dateIso: string;
  account: string;
  type: string;
  description: string;
  amount: number;
  status: string;
  notes: string;
};

export interface HeadwiseSummaryRow {
  head: string;
  entries: number;
  amount: number;
  cash: number;
  bank: number;
  other: number;
}

type AccountFilter = 'all' | 'cash' | 'bank' | 'other';
type TypeFilter = 'all' | 'receipt' | 'payment';

interface Totals {
  receipt: number;
  payment: number;
  cash: number;
  bank: number;
  total: number;
}

// Helper function to group transactions by month
function groupByMonth(rows: DatewiseTransactionRow[]): Record<string, DatewiseTransactionRow[]> {
  const grouped: Record<string, DatewiseTransactionRow[]> = {};

  for (const row of rows) {
    const [year, month] = row.dateIso.split('-');
    const monthKey = `${month}/${year}`;

    if (!grouped[monthKey]) {
      grouped[monthKey] = [];
    }
    grouped[monthKey].push(row);
  }

  return grouped;
}

/**
 * Build PDF with all detailed transactions
 */
export async function buildDatewiseTransactionPdf(
  rows: DatewiseTransactionRow[],
  startDate: Date,
  endDate: Date,
  accountFilter: AccountFilter,
  typeFilter: TypeFilter,
  totals: Totals
): Promise<Blob> {
  const doc = new jsPDF('p', 'mm', 'a4');
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const margin = 8;
  let currentY = margin;

  // Title
  doc.setFontSize(14);
  doc.setTextColor(0);
  doc.text('Transaction Report - Detailed', margin, currentY);
  currentY += 6;

  // Metadata
  doc.setFontSize(8);
  doc.setTextColor(100);
  doc.text(`Period: ${fmtIsoDateToDisplay(format(startDate, 'yyyy-MM-dd'))} to ${fmtIsoDateToDisplay(format(endDate, 'yyyy-MM-dd'))}`, margin, currentY);
  currentY += 3;
  doc.text(`Generated: ${format(new Date(), 'dd-MMM-yyyy HH:mm')}`, margin, currentY);
  currentY += 3;
  doc.text(`Account: ${accountFilter} | Type: ${typeFilter}`, margin, currentY);
  currentY += 6;

  // Summary totals
  doc.setFontSize(9);
  doc.setTextColor(0);
  doc.text('Summary:', margin, currentY);
  currentY += 4;

  doc.setFontSize(8);
  doc.setTextColor(60);
  doc.text(`Receipt: ${moneyInr(totals.receipt)} | Payment: ${moneyInr(totals.payment)} | Total: ${moneyInr(totals.total)}`, margin + 3, currentY);
  currentY += 3;
  doc.text(`Cash: ${moneyInr(totals.cash)} | Bank: ${moneyInr(totals.bank)}`, margin + 3, currentY);
  currentY += 8;

  // Transactions
  if (rows.length === 0) {
    doc.setFontSize(8);
    doc.setTextColor(150);
    doc.text('No transactions', margin, currentY);
    return new Promise((resolve) => resolve(doc.output('blob')));
  }

  // Table header
  doc.setFontSize(7);
  doc.setTextColor(0);
  const colX = [margin, margin + 20, margin + 35, margin + 50, margin + 110];
  doc.text('Date', colX[0], currentY);
  doc.text('Account', colX[1], currentY);
  doc.text('Type', colX[2], currentY);
  doc.text('Description', colX[3], currentY);
  doc.text('Amount', colX[4], currentY, { align: 'right' });
  currentY += 2;
  doc.line(margin, currentY, pageWidth - margin, currentY);
  currentY += 2;

  // Table rows
  doc.setTextColor(40);
  for (const row of rows) {
    if (currentY > pageHeight - 12) {
      doc.addPage();
      currentY = margin;
    }

    doc.text(row.date, colX[0], currentY);
    doc.text(row.account.substring(0, 10), colX[1], currentY);
    doc.text(row.type.substring(0, 4), colX[2], currentY);
    doc.text(row.description.substring(0, 50), colX[3], currentY);
    doc.text(moneyInr(row.amount), colX[4], currentY, { align: 'right' });
    currentY += 2.5;
  }

  return new Promise((resolve) => resolve(doc.output('blob')));
}

/**
 * Build PDF with SUMMARY ONLY (headwise breakdown)
 * Used for WhatsApp sharing when "Summary" format is selected
 */
export async function buildDatewiseTransactionSummaryPdf(
  headwiseSummary: HeadwiseSummaryRow[],
  startDate: Date,
  endDate: Date,
  accountFilter: AccountFilter,
  typeFilter: TypeFilter,
  totals: Totals
): Promise<Blob> {
  const doc = new jsPDF('p', 'mm', 'a4');
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageHeight = doc.internal.pageSize.getHeight();
  const margin = 8;
  let currentY = margin;

  // Title
  doc.setFontSize(14);
  doc.setTextColor(0);
  doc.text('Transaction Report - Summary', margin, currentY);
  currentY += 6;

  // Metadata
  doc.setFontSize(8);
  doc.setTextColor(100);
  doc.text(`Period: ${fmtIsoDateToDisplay(format(startDate, 'yyyy-MM-dd'))} to ${fmtIsoDateToDisplay(format(endDate, 'yyyy-MM-dd'))}`, margin, currentY);
  currentY += 3;
  doc.text(`Generated: ${format(new Date(), 'dd-MMM-yyyy HH:mm')}`, margin, currentY);
  currentY += 3;
  doc.text(`Account: ${accountFilter} | Type: ${typeFilter}`, margin, currentY);
  currentY += 6;

  // Summary totals
  doc.setFontSize(9);
  doc.setTextColor(0);
  doc.text('Totals:', margin, currentY);
  currentY += 4;

  doc.setFontSize(8);
  doc.setTextColor(60);
  doc.text(`Receipt: ${moneyInr(totals.receipt)} | Payment: ${moneyInr(totals.payment)} | Total: ${moneyInr(totals.total)}`, margin + 3, currentY);
  currentY += 3;
  doc.text(`Cash: ${moneyInr(totals.cash)} | Bank: ${moneyInr(totals.bank)}`, margin + 3, currentY);
  currentY += 8;

  // Headwise table
  if (headwiseSummary.length === 0) {
    doc.setFontSize(8);
    doc.setTextColor(150);
    doc.text('No data', margin, currentY);
    return new Promise((resolve) => resolve(doc.output('blob')));
  }

  // Table header
  doc.setFontSize(7);
  doc.setTextColor(0);
  const colX = [margin, margin + 70, margin + 85, margin + 100, margin + 115, margin + 130];
  doc.text('Head / Category', colX[0], currentY);
  doc.text('Entries', colX[1], currentY, { align: 'right' });
  doc.text('Amount', colX[2], currentY, { align: 'right' });
  doc.text('Cash', colX[3], currentY, { align: 'right' });
  doc.text('Bank', colX[4], currentY, { align: 'right' });
  doc.text('Other', colX[5], currentY, { align: 'right' });
  currentY += 2;
  doc.line(margin, currentY, pageWidth - margin, currentY);
  currentY += 2;

  // Table rows
  doc.setTextColor(40);
  for (const row of headwiseSummary) {
    if (currentY > pageHeight - 12) {
      doc.addPage();
      currentY = margin;
      // Repeat header on new page
      doc.setFontSize(7);
      doc.setTextColor(0);
      doc.text('Head / Category', colX[0], currentY);
      doc.text('Entries', colX[1], currentY, { align: 'right' });
      doc.text('Amount', colX[2], currentY, { align: 'right' });
      doc.text('Cash', colX[3], currentY, { align: 'right' });
      doc.text('Bank', colX[4], currentY, { align: 'right' });
      doc.text('Other', colX[5], currentY, { align: 'right' });
      currentY += 2;
      doc.line(margin, currentY, pageWidth - margin, currentY);
      currentY += 2;
      doc.setTextColor(40);
    }

    doc.text(row.head.substring(0, 40), colX[0], currentY);
    doc.text(String(row.entries), colX[1], currentY, { align: 'right' });
    doc.text(moneyInr(row.amount), colX[2], currentY, { align: 'right' });
    doc.text(moneyInr(row.cash), colX[3], currentY, { align: 'right' });
    doc.text(moneyInr(row.bank), colX[4], currentY, { align: 'right' });
    doc.text(moneyInr(row.other), colX[5], currentY, { align: 'right' });
    currentY += 2.5;
  }

  return new Promise((resolve) => resolve(doc.output('blob')));
}

export function buildDatewiseTransactionExcel(
  rows: DatewiseTransactionRow[],
  startDate: Date,
  endDate: Date,
  accountFilter: AccountFilter,
  typeFilter: TypeFilter,
  totals: Totals
): Blob {
  const grouped = groupByMonth(rows);
  const months = Object.keys(grouped).sort();

  // Create multiple sheets
  const sheets: Array<{ name: string; headers: string[]; rows: unknown[][] }> = [];

  // Sheet 1: All transactions
  sheets.push({
    name: 'All Transactions',
    headers: ['Date', 'Account', 'Type', 'Description', 'Amount'],
    rows: rows.map((r) => [r.date, r.account, r.type, r.description, r.amount]),
  });

  // Sheet 2: Monthly summaries
  const monthlySummary: unknown[][] = [];
  for (const month of months) {
    const monthRows = grouped[month];
    const monthReceipt = monthRows.reduce((sum, r) => (r.type === 'Receipt' ? sum + r.amount : sum), 0);
    const monthPayment = monthRows.reduce((sum, r) => (r.type === 'Payment' ? sum + r.amount : sum), 0);
    const monthCash = monthRows.reduce((sum, r) => (r.account === 'Cash' ? sum + r.amount : sum), 0);
    const monthBank = monthRows.reduce((sum, r) => (r.account === 'Bank' ? sum + r.amount : sum), 0);

    monthlySummary.push([month, monthReceipt, monthPayment, monthCash, monthBank, monthReceipt + monthPayment]);
  }

  sheets.push({
    name: 'Monthly Summary',
    headers: ['Month', 'Receipt', 'Payment', 'Cash', 'Bank', 'Total'],
    rows: monthlySummary,
  });

  // Sheet 3: Summary statistics
  sheets.push({
    name: 'Statistics',
    headers: ['Metric', 'Value'],
    rows: [
      ['Total Transactions', rows.length],
      ['Total Receipt', totals.receipt],
      ['Total Payment', totals.payment],
      ['Total Cash', totals.cash],
      ['Total Bank', totals.bank],
      ['Net Total', totals.total],
      ['Period', `${fmtIsoDateToDisplay(format(startDate, 'yyyy-MM-dd'))} to ${fmtIsoDateToDisplay(format(endDate, 'yyyy-MM-dd'))}`],
      ['Account Filter', accountFilter],
      ['Type Filter', typeFilter],
      ['Generated', format(new Date(), 'dd-MMM-yyyy HH:mm')],
    ],
  });

  return rowsToXlsxBlob(sheets);
}

export function buildDatewiseTransactionCsv(rows: DatewiseTransactionRow[]): Blob {
  const headers = ['Date', 'Account', 'Type', 'Description', 'Amount'];
  const csvRows = rows.map((r) => [r.date, r.account, r.type, r.description, r.amount]);

  return rowsToCsvBlob(headers, csvRows);
}
