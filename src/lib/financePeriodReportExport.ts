import { createSocietyPdf } from '@/lib/pdfPage';
import { applyLetterheadPage, finalizeLetterheadFooters, letterheadEnsureSpace } from '@/lib/pdfLetterhead';
import { fmtDateTimeFull, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { buildFinancePeriodReportPdfBlob, type FinancePeriodReportPdfInput } from '@/lib/financePeriodReportPdf';
import type { FinancePeriodReportResult } from '@/lib/financePeriodReport';
import {
  buildHtmlTable,
  htmlToWordBlob,
  moneyInr,
  rowsToCsvBlob,
} from '@/lib/reportExportUtils';
import { rowsToXlsxBlob } from '@/lib/xlsxExport';

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

export function toFinancePeriodReportExportInput(
  report: FinancePeriodReportResult,
  meta: { societyName: string; periodFrom: string; periodTo: string; generatedAt?: string },
): FinancePeriodReportExportInput {
  const { maintenanceReceipts: _maintenanceReceipts, corpusReceipts: _corpusReceipts, ...exportFields } = report;
  return {
    societyName: meta.societyName,
    periodFrom: meta.periodFrom,
    periodTo: meta.periodTo,
    generatedAt: meta.generatedAt ?? new Date().toISOString(),
    ...exportFields,
  };
}

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

function headWiseRows(rows: [string, { cash: number; bank: number; other: number; total: number }][]): unknown[][] {
  return rows.map(([head, v]) => [head, v.cash, v.bank, v.other, v.total]);
}

function receiptHeadRows(input: FinancePeriodReportExportInput): unknown[][] {
  return headWiseRows(input.receiptByHead);
}

function expenseHeadRows(input: FinancePeriodReportExportInput): unknown[][] {
  return headWiseRows(input.expenseByHead);
}

const HEAD_WISE_HEADERS = ['Head', 'Cash', 'Bank / UPI', 'Other', 'Total'] as const;

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
      name: 'Receipts by head',
      headers: [...HEAD_WISE_HEADERS],
      rows: receiptHeadRows(input),
    },
    {
      name: 'Expenses by head',
      headers: [...HEAD_WISE_HEADERS],
      rows: expenseHeadRows(input),
    },
  ]);
}

export function buildFinancePeriodReportWord(input: FinancePeriodReportExportInput): Blob {
  const receiptTable = buildHtmlTable(
    [...HEAD_WISE_HEADERS],
    receiptHeadRows(input).map((r) => r.map((c) => (typeof c === 'number' ? moneyInr(c) : String(c)))),
    new Set([1, 2, 3, 4]),
  );
  const expenseTable = buildHtmlTable(
    [...HEAD_WISE_HEADERS],
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
    <h2>Collection receipts (head-wise)</h2>${receiptTable}
    <h2>Expenses (head-wise)</h2>${expenseTable}
    <p class="meta">Receipts use verified maintenance payment dates. Expenses use ledger separate-entry rows by transaction_date.</p>`;
  return htmlToWordBlob('Finance period report', body);
}

export function buildFinancePeriodReportCsv(input: FinancePeriodReportExportInput): Blob {
  const rows: unknown[][] = [
    ...summaryRows(input),
    ['', ''],
    ['Collection receipts (head-wise)', ''],
    [...HEAD_WISE_HEADERS],
    ...receiptHeadRows(input),
    ['', ''],
    ['Expenses (head-wise)', ''],
    [...HEAD_WISE_HEADERS],
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
  monthlyTotals?: { label: string; count: number; total: number }[];
  transactionTotal?: number;
}): Blob {
  const doc = createSocietyPdf({ orientation: 'landscape' });
  const lh = opts.societyName || 'Society';
  let layout = applyLetterheadPage(doc, lh);
  const { margin, pageW } = layout;
  let y = layout.contentTop;

  doc.setFontSize(11);
  doc.text(opts.title, margin, y);
  y += 5;
  doc.setFontSize(9);
  doc.setTextColor(80, 80, 80);
  doc.text(opts.subtitle, margin, y);
  y += 4;
  doc.text(`Generated: ${fmtDateTimeFull(opts.generatedAt)}`, margin, y);
  if (opts.transactionTotal != null) {
    y += 4;
    doc.text(`Transaction total: ${moneyInr(opts.transactionTotal)}`, margin, y);
  }
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
    const before = y;
    const next = letterheadEnsureSpace(doc, layout, y, rowH + 1, lh);
    layout = next.layout;
    y = next.y;
    if (y === layout.contentTop && before !== y) drawHeader();
    row.forEach((cell, i) => {
      const text = doc.splitTextToSize(String(cell ?? ''), colW - 2);
      doc.text(text[0] ?? '', margin + i * colW + 1, y + 3.5);
    });
    y += rowH;
  }

  if (opts.monthlyTotals && opts.monthlyTotals.length > 0) {
    const next = letterheadEnsureSpace(doc, layout, y, rowH * (opts.monthlyTotals.length + 4), lh);
    layout = next.layout;
    y = next.y;
    y += 6;
    doc.setFontSize(10);
    doc.text('Monthly totals', margin, y);
    y += 6;
    doc.setFontSize(7);
    doc.setFillColor(240, 240, 240);
    doc.rect(margin, y - 3.5, pageW - 2 * margin, rowH, 'F');
    doc.text('Month', margin + 1, y);
    doc.text('Entries', margin + 50, y);
    doc.text('Total', pageW - margin - 1, y, { align: 'right' });
    y += rowH;
    for (const m of opts.monthlyTotals) {
      const n2 = letterheadEnsureSpace(doc, layout, y, rowH + 1, lh);
      layout = n2.layout;
      y = n2.y;
      doc.text(m.label, margin + 1, y);
      doc.text(String(m.count), margin + 50, y);
      doc.text(moneyInr(m.total), pageW - margin - 1, y, { align: 'right' });
      y += rowH;
    }
    if (opts.transactionTotal != null) {
      doc.setFontSize(8);
      doc.text('Grand total', margin + 1, y);
      doc.text(moneyInr(opts.transactionTotal), pageW - margin - 1, y, { align: 'right' });
    }
  }

  finalizeLetterheadFooters(doc, lh);
  return doc.output('blob');
}
