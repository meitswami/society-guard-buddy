import { jsPDF } from 'jspdf';
import { createSocietyPdf } from '@/lib/pdfPage';
import {
  applyLetterheadPage,
  letterheadEnsureSpace,
  type SocietyLetterhead,
} from '@/lib/pdfLetterhead';
import { fmtDateTimeFull, fmtIsoDateToDisplay } from '@/lib/dateFormat';
import type { ChannelByHeadRow } from '@/lib/financePeriodReport';

export type FinancePeriodReportPdfInput = {
  societyName: string;
  letterhead?: SocietyLetterhead | null;
  periodFrom: string;
  periodTo: string;
  generatedAt: string;
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
): number {
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const rowH = 5.5;
  let y = startY;

  const ensureSpace = (needed: number) => {
    if (y + needed > pageH - margin) {
      doc.addPage();
      y = margin;
    }
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

  return y + 4;
}

/** Build a printable finance period report PDF (returns Blob). */
export function buildFinancePeriodReportPdfBlob(input: FinancePeriodReportPdfInput): Blob {
  const doc = createSocietyPdf();
  const lh = input.letterhead ?? input.societyName;
  let layout = applyLetterheadPage(doc, lh);
  const { margin, pageW } = layout;
  let y = layout.contentTop;

  const line = (text: string, size = 10, gap = 5) => {
    const next = letterheadEnsureSpace(doc, layout, y, gap + 2, lh);
    layout = next.layout;
    y = next.y;
    doc.setFontSize(size);
    doc.text(text, margin, y);
    y += gap;
  };

  doc.setFontSize(10);
  doc.setTextColor(80, 80, 80);
  doc.text(
    `Finance period report · ${fmtIsoDateToDisplay(input.periodFrom)} to ${fmtIsoDateToDisplay(input.periodTo)}`,
    margin,
    y,
  );
  y += 5;
  doc.text(`Generated: ${fmtDateTimeFull(input.generatedAt)}`, margin, y);
  doc.setTextColor(0, 0, 0);
  y += 8;

  line(
    `${input.verifiedPaymentCount} verified payment row(s) · Ledger-only inflows: ${money(input.extraLedgerReceipt)}`,
    8,
    6,
  );

  y = drawHeadWiseTable(
    doc,
    margin,
    y,
    'Collection receipts (head-wise)',
    input.receiptByHead,
    'All receipts',
    {
      cash: input.receiptByMethod.cash,
      bank: input.receiptByMethod.bank,
      other: input.receiptByMethod.other,
      total: input.totalReceipts,
    },
  );

  y = drawHeadWiseTable(
    doc,
    margin,
    y,
    'Expenses (head-wise)',
    input.expenseByHead,
    'All expenses',
    {
      cash: input.expenseByMethod.cash,
      bank: input.expenseByMethod.bank,
      other: input.expenseByMethod.other,
      total: input.totalExpenses,
    },
  );

  line('Summary', 11, 6);
  line(`  Cash in hand (net): ${money(input.cashInHand)}`, 10, 5);
  line(`  Cash in bank (net): ${money(input.cashInBank)}`, 10, 5);
  line(`  Other channels (net): ${money(input.otherNet)}`, 10, 5);
  doc.setFontSize(11);
  line(`  Total balance: ${money(input.totalBalance)}`, 11, 7);

  doc.setFontSize(8);
  doc.setTextColor(120, 120, 120);
  const foot =
    'Receipts use verified maintenance payment dates (verified_at / payment_date / created_at). Expenses use ledger separate-entry rows by transaction_date.';
  const split = doc.splitTextToSize(foot, pageW - 2 * margin);
  for (const row of split) {
    line(row, 8, 4);
  }

  return doc.output('blob');
}
