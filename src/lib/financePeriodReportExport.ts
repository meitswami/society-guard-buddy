import { jsPDF } from 'jspdf';
import { fmtDateTimeFull, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { buildFinancePeriodReportPdfBlob, type FinancePeriodReportPdfInput } from '@/lib/financePeriodReportPdf';
import {
  buildHtmlTable,
  htmlToWordBlob,
  moneyInr,
  rowsToCsvBlob,
  rowsToXlsxBlob,
} from '@/lib/reportExportUtils';

export type FinancePeriodReportExportInput = FinancePeriodReportPdfInput & {
  openingCash?: number;
  openingBank?: number;
  openingOther?: number;
  openingBalance?: number;
  closingCash?: number;
  closingBank?: number;
  closingOther?: number;
  closingBalance?: number;
};

function summaryRows(input: FinancePeriodReportExportInput): [string, string][] {
  const rows: [string, string][] = [
    ['Period', `${fmtIsoDateToDisplay(input.periodFrom)} to ${fmtIsoDateToDisplay(input.periodTo)}`],
    ['Generated', fmtDateTimeFull(input.generatedAt)],
    ['', ''],
    ['Collection receipts — Cash', moneyInr(input.receiptByMethod.cash)],
    ['Collection receipts — Bank / UPI / online', moneyInr(input.receiptByMethod.bank)],
    ['Collection receipts — Other', moneyInr(input.receiptByMethod.other)],
    ['Total receipts', moneyInr(input.totalReceipts)],
    ['Verified payment rows', String(input.verifiedPaymentCount)],
    ['Ledger-only inflows', moneyInr(input.extraLedgerReceipt)],
    ['', ''],
    ['Total expenses', moneyInr(input.totalExpenses)],
    ['', ''],
    ['Period cash in hand (net)', moneyInr(input.cashInHand)],
    ['Period cash in bank (net)', moneyInr(input.cashInBank)],
    ['Period other channels (net)', moneyInr(input.otherNet)],
    ['Period total balance', moneyInr(input.totalBalance)],
  ];
  if (input.openingBalance != null) {
    rows.push(
      ['', ''],
      ['Opening cash', moneyInr(input.openingCash ?? 0)],
      ['Opening bank', moneyInr(input.openingBank ?? 0)],
      ['Opening other', moneyInr(input.openingOther ?? 0)],
      ['Opening balance', moneyInr(input.openingBalance)],
      ['Closing cash', moneyInr(input.closingCash ?? 0)],
      ['Closing bank', moneyInr(input.closingBank ?? 0)],
      ['Closing other', moneyInr(input.closingOther ?? 0)],
      ['Closing balance', moneyInr(input.closingBalance ?? 0)],
    );
  }
  return rows;
}

function expenseHeadRows(input: FinancePeriodReportExportInput): unknown[][] {
  return input.expenseByHead.map(([head, v]) => [
    head,
    v.cash,
    v.bank,
    v.other,
    v.total,
  ]);
}

export function buildFinancePeriodReportPdf(input: FinancePeriodReportExportInput): Blob {
  return buildFinancePeriodReportPdfBlob(input);
}

export function buildFinancePeriodReportExcel(input: FinancePeriodReportExportInput): Blob {
  return rowsToXlsxBlob([
    {
      name: 'Summary',
      headers: ['Item', 'Value'],
      rows: summaryRows(input),
    },
    {
      name: 'Expenses by head',
      headers: ['Expense head', 'Cash', 'Bank / UPI', 'Other', 'Total'],
      rows: expenseHeadRows(input),
    },
  ]);
}

export function buildFinancePeriodReportWord(input: FinancePeriodReportExportInput): Blob {
  const expenseTable = buildHtmlTable(
    ['Expense head', 'Cash', 'Bank / UPI', 'Other', 'Total'],
    expenseHeadRows(input).map((r) => r.map((c) => (typeof c === 'number' ? moneyInr(c) : String(c)))),
    new Set([1, 2, 3, 4]),
  );
  const summaryTable = buildHtmlTable(
    ['Item', 'Value'],
    summaryRows(input),
  );
  const body = `
    <h1>${input.societyName || 'Society'}</h1>
    <p class="meta">Finance period report · ${fmtIsoDateToDisplay(input.periodFrom)} to ${fmtIsoDateToDisplay(input.periodTo)}</p>
    <p class="meta">Generated: ${fmtDateTimeFull(input.generatedAt)}</p>
    <h2>Summary</h2>${summaryTable}
    <h2>Expenses by head</h2>${expenseTable}
    <p class="meta">Receipts use verified maintenance payment dates. Expenses use ledger separate-entry rows by created_at.</p>`;
  return htmlToWordBlob('Finance period report', body);
}

export function buildFinancePeriodReportCsv(input: FinancePeriodReportExportInput): Blob {
  const rows: unknown[][] = [
    ...summaryRows(input),
    ['', ''],
    ['Expense head', 'Cash', 'Bank / UPI', 'Other', 'Total'],
    ...expenseHeadRows(input),
  ];
  return rowsToCsvBlob(['Item', 'Value'], rows);
}

/** Transaction statement PDF for a list of rows. */
export function buildTransactionStatementPdfBlob(opts: {
  societyName: string;
  title: string;
  subtitle: string;
  generatedAt: string;
  headers: string[];
  rows: string[][];
}): Blob {
  const doc = new jsPDF({ unit: 'mm', format: 'a4', orientation: 'landscape' });
  const margin = 10;
  let y = margin;
  const pageH = doc.internal.pageSize.getHeight();
  const pageW = doc.internal.pageSize.getWidth();

  doc.setFontSize(14);
  doc.text(opts.societyName || 'Society', margin, y);
  y += 6;
  doc.setFontSize(11);
  doc.text(opts.title, margin, y);
  y += 5;
  doc.setFontSize(9);
  doc.setTextColor(80, 80, 80);
  doc.text(opts.subtitle, margin, y);
  y += 4;
  doc.text(`Generated: ${fmtDateTimeFull(opts.generatedAt)}`, margin, y);
  doc.setTextColor(0, 0, 0);
  y += 8;

  const colCount = opts.headers.length;
  const colW = (pageW - 2 * margin) / colCount;
  const rowH = 5;

  const drawHeader = () => {
    doc.setFontSize(7);
    doc.setFillColor(240, 240, 240);
    doc.rect(margin, y, pageW - 2 * margin, rowH, 'F');
    opts.headers.forEach((h, i) => {
      doc.text(h.slice(0, 18), margin + i * colW + 1, y + 3.5);
    });
    y += rowH;
  };

  drawHeader();
  doc.setFontSize(6.5);
  for (const row of opts.rows) {
    if (y + rowH > pageH - margin) {
      doc.addPage();
      y = margin;
      drawHeader();
    }
    row.forEach((cell, i) => {
      const text = doc.splitTextToSize(String(cell ?? ''), colW - 2);
      doc.text(text[0] ?? '', margin + i * colW + 1, y + 3.5);
    });
    y += rowH;
  }

  return doc.output('blob');
}
