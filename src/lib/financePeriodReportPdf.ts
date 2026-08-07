import {
  letterheadEnsureSpace,
  type LetterheadLayout,
  type ReportPdfMode,
  type SocietyLetterhead,
} from '@/lib/pdfLetterhead';
import { drawReportHeader, drawSignatureSection, beginSocietyReport, finalizeSocietyReport } from '@/lib/letterheadReportEngine';
import { fmtDateTimeFull, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import type { ChannelByHeadRow } from '@/lib/financePeriodReport';
import type { jsPDF } from 'jspdf';

export type FinancePeriodReportPdfInput = {
  societyName: string;
  letterhead?: SocietyLetterhead | null;
  pdfMode?: ReportPdfMode;
  includeSignatures?: boolean;
  periodFrom: string;
  periodTo: string;
  generatedAt: string;
  generatedBy?: string | null;
  receiptByMethod: { cash: number; bank: number; other: number };
  receiptByHead: [string, ChannelByHeadRow][];
  totalReceipts: number;
  expenseByHead: [string, ChannelByHeadRow][];
  expenseByMethod: { cash: number; bank: number; other: number };
  totalExpenses: number;
  cashInHand: number;
  cashInBank: number;
  otherNet: number;
  totalBalance: number;
  verifiedPaymentCount: number;
  extraLedgerReceipt: number;
};

function money(n: number) {
  return `₹${n.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
}

const HEAD_TABLE_COLUMNS = ['Head', 'Cash', 'Bank / UPI', 'Other', 'Total'] as const;
const HEAD_TABLE_WIDTHS = [52, 28, 32, 24, 28] as const;

function drawHeadWiseTable(
  doc: jsPDF,
  margin: number,
  startY: number,
  title: string,
  rows: [string, ChannelByHeadRow][],
  footerLabel: string,
  footerTotals: { cash: number; bank: number; other: number; total: number },
  lh: SocietyLetterhead | string,
  layoutIn: LetterheadLayout,
  pdfMode: ReportPdfMode = 'letterhead',
): { y: number; layout: LetterheadLayout } {
  const rowH = 5.5;
  let y = startY;
  let layout = layoutIn;
  const drawOpts = { mode: pdfMode };

  const ensureSpace = (needed: number) => {
    const next = letterheadEnsureSpace(doc, layout, y, needed, lh, drawOpts);
    layout = next.layout;
    y = next.y;
  };

  ensureSpace(12);
  doc.setFontSize(11);
  doc.setTextColor(0, 0, 0);
  doc.text(title, margin, y);
  y += 6;

  const tableW = HEAD_TABLE_WIDTHS.reduce((s, w) => s + w, 0);
  const colX = HEAD_TABLE_WIDTHS.reduce<number[]>((acc, w, i) => {
    acc.push(i === 0 ? margin : acc[i - 1] + HEAD_TABLE_WIDTHS[i - 1]);
    return acc;
  }, []);

  const drawRow = (cells: string[], bold = false, fill = false) => {
    ensureSpace(rowH + 1);
    if (fill) {
      doc.setFillColor(240, 240, 240);
      doc.rect(margin, y - 3.5, tableW, rowH, 'F');
    }
    doc.setFontSize(bold ? 8 : 7.5);
    cells.forEach((cell, i) => {
      const alignRight = i > 0;
      const x = colX[i] + (alignRight ? HEAD_TABLE_WIDTHS[i] - 1.5 : 1);
      const text = doc.splitTextToSize(cell, HEAD_TABLE_WIDTHS[i] - 2)[0] ?? '';
      doc.text(text, x, y, { align: alignRight ? 'right' : 'left' });
    });
    y += rowH;
  };

  drawRow([...HEAD_TABLE_COLUMNS], true, true);

  if (rows.length === 0) {
    drawRow(['(none in this period)', '—', '—', '—', '—']);
  } else {
    for (const [head, v] of rows) {
      drawRow([head, money(v.cash), money(v.bank), money(v.other), money(v.total)]);
    }
  }

  drawRow(
    [
      footerLabel,
      money(footerTotals.cash),
      money(footerTotals.bank),
      money(footerTotals.other),
      money(footerTotals.total),
    ],
    true,
    true,
  );

  return { y: y + 4, layout };
}

/** Build a printable finance period report PDF (returns Blob). */
export function buildFinancePeriodReportPdfBlob(input: FinancePeriodReportPdfInput): Blob {
  const mode = input.pdfMode ?? 'letterhead';
  const lh = input.letterhead ?? input.societyName;
  let renderer = beginSocietyReport(lh, { mode });
  renderer = drawReportHeader(renderer, {
    title: 'Finance period report',
    society: input.societyName,
    period: `${fmtIsoDateToDisplay(input.periodFrom)} to ${fmtIsoDateToDisplay(input.periodTo)}`,
    date: fmtDateTimeFull(input.generatedAt),
    generatedBy: input.generatedBy,
  });

  const { doc } = renderer;
  const drawOpts = { mode };
  const margin = renderer.layout.leftMargin;
  const pageW = renderer.layout.pageW;

  const line = (text: string, size = 10, gap = 5) => {
    const next = letterheadEnsureSpace(doc, renderer.layout, renderer.y, gap + 2, lh, drawOpts);
    renderer = { ...renderer, layout: next.layout, y: next.y };
    doc.setFontSize(size);
    doc.setTextColor(0, 0, 0);
    doc.text(text, margin, renderer.y);
    renderer = { ...renderer, y: renderer.y + gap };
  };

  line(
    `${input.verifiedPaymentCount} verified payment row(s) · Ledger-only inflows: ${money(input.extraLedgerReceipt)}`,
    8,
    6,
  );

  let table = drawHeadWiseTable(
    doc,
    margin,
    renderer.y,
    'Collection receipts (head-wise)',
    input.receiptByHead,
    'All receipts',
    {
      cash: input.receiptByMethod.cash,
      bank: input.receiptByMethod.bank,
      other: input.receiptByMethod.other,
      total: input.totalReceipts,
    },
    lh,
    renderer.layout,
    mode,
  );
  renderer = { ...renderer, y: table.y, layout: table.layout };

  table = drawHeadWiseTable(
    doc,
    margin,
    renderer.y,
    'Expenses (head-wise)',
    input.expenseByHead,
    'All expenses',
    {
      cash: input.expenseByMethod.cash,
      bank: input.expenseByMethod.bank,
      other: input.expenseByMethod.other,
      total: input.totalExpenses,
    },
    lh,
    renderer.layout,
    mode,
  );
  renderer = { ...renderer, y: table.y, layout: table.layout };

  line('Summary', 11, 6);
  line(`  Cash in hand (net): ${money(input.cashInHand)}`, 10, 5);
  line(`  Cash in bank (net): ${money(input.cashInBank)}`, 10, 5);
  line(`  Other channels (net): ${money(input.otherNet)}`, 10, 5);
  line(`  Total balance: ${money(input.totalBalance)}`, 11, 7);

  doc.setFontSize(8);
  doc.setTextColor(120, 120, 120);
  const foot =
    'Receipts use verified maintenance payment dates (verified_at / payment_date / created_at). Expenses use ledger separate-entry rows by transaction_date.';
  const split = doc.splitTextToSize(foot, pageW - margin - renderer.layout.rightMargin) as string[];
  for (const row of split) {
    line(row, 8, 4);
  }

  if (input.includeSignatures !== false) {
    renderer = drawSignatureSection(renderer);
  }

  return finalizeSocietyReport(renderer);
}

