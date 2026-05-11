import { jsPDF } from 'jspdf';
import { fmtDateTimeFull, fmtIsoDateToDisplay } from '@/lib/dateFormat';

export type FinancePeriodReportPdfInput = {
  societyName: string;
  periodFrom: string;
  periodTo: string;
  generatedAt: string;
  receiptByMethod: { cash: number; bank: number; other: number };
  totalReceipts: number;
  expenseByHead: [string, { cash: number; bank: number; other: number; total: number }][];
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

/** Build a printable finance period report PDF (returns Blob). */
export function buildFinancePeriodReportPdfBlob(input: FinancePeriodReportPdfInput): Blob {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const margin = 14;
  let y = margin;

  const line = (text: string, size = 10, gap = 5) => {
    const maxY = doc.internal.pageSize.getHeight() - margin;
    if (y + gap > maxY) {
      doc.addPage();
      y = margin;
    }
    doc.setFontSize(size);
    doc.text(text, margin, y);
    y += gap;
  };

  doc.setFontSize(15);
  doc.text(input.societyName || 'Society', margin, y);
  y += 8;
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
  y += 10;

  line('Collection receipts (verified maintenance + ledger-only inflows)', 11, 6);
  line(`  Cash: ${money(input.receiptByMethod.cash)}`, 9, 5);
  line(`  Bank / UPI / online: ${money(input.receiptByMethod.bank)}`, 9, 5);
  line(`  Other: ${money(input.receiptByMethod.other)}`, 9, 5);
  line(`  Total receipts: ${money(input.totalReceipts)}`, 10, 6);
  line(`  Rows: ${input.verifiedPaymentCount} verified payments · Ledger-only add: ${money(input.extraLedgerReceipt)}`, 8, 7);

  line('Expenses (separate-entry ledger), by head', 11, 6);
  if (input.expenseByHead.length === 0) {
    line('  (none in this period)', 9, 6);
  } else {
    for (const [head, v] of input.expenseByHead) {
      line(`  ${head}`, 9, 4);
      line(`    Cash ${money(v.cash)} · Bank ${money(v.bank)} · Other ${money(v.other)} · Total ${money(v.total)}`, 8, 5);
    }
  }
  line(`  All expenses: ${money(input.totalExpenses)}`, 10, 7);

  line('Summary', 11, 6);
  line(`  Cash in hand (net): ${money(input.cashInHand)}`, 10, 5);
  line(`  Cash in bank (net): ${money(input.cashInBank)}`, 10, 5);
  line(`  Other channels (net): ${money(input.otherNet)}`, 10, 5);
  doc.setFontSize(11);
  line(`  Total balance: ${money(input.totalBalance)}`, 11, 7);

  doc.setFontSize(8);
  doc.setTextColor(120, 120, 120);
  const foot = 'Receipts use verified maintenance payment dates (verified_at / payment_date / created_at). Expenses use ledger separate-entry rows by created_at.';
  const split = doc.splitTextToSize(foot, pageW - 2 * margin);
  for (const row of split) {
    line(row, 8, 4);
  }

  return doc.output('blob');
}
