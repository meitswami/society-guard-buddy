import { createSocietyPdf } from '@/lib/pdfPage';
import {
  applyLetterheadPage,
  finalizeLetterheadFooters,
  letterheadEnsureSpace,
  type SocietyLetterhead,
} from '@/lib/pdfLetterhead';
import type { ReportDetailRow } from '@/components/ReportDetailModal';
import { fmtDateTimeFull } from '@/lib/dateFormat';
import { moneyInr, triggerDownload } from '@/lib/reportExportUtils';
import { monthlyAmountTotals, sumAmountRows } from '@/lib/statementAmountTotals';

export type SharePdfResult = 'shared' | 'downloaded' | 'cancelled';

export async function sharePdfOnWhatsApp(opts: {
  blob: Blob;
  filename: string;
  message?: string;
}): Promise<SharePdfResult> {
  const filename = opts.filename.toLowerCase().endsWith('.pdf') ? opts.filename : `${opts.filename}.pdf`;
  const file = new File([opts.blob], filename, { type: 'application/pdf' });
  const shareData: ShareData = {
    files: [file],
    title: filename.replace(/\.pdf$/i, ''),
    text: opts.message,
  };

  if (typeof navigator.share === 'function' && navigator.canShare?.(shareData)) {
    try {
      await navigator.share(shareData);
      return 'shared';
    } catch (err) {
      if ((err as DOMException).name === 'AbortError') return 'cancelled';
    }
  }

  triggerDownload(opts.blob, filename);
  const baseMsg = opts.message ?? filename.replace(/\.pdf$/i, '');
  const waText = encodeURIComponent(
    `${baseMsg}\n\nPDF saved to your device — attach it in WhatsApp to share.`,
  );
  window.open(`https://wa.me/?text=${waText}`, '_blank', 'noopener,noreferrer');
  return 'downloaded';
}

export function buildReportDetailPdfBlob(opts: {
  societyName?: string;
  letterhead?: SocietyLetterhead | null;
  title: string;
  subtitle?: string;
  totalAmount?: number;
  rows: ReportDetailRow[];
}): Blob {
  const doc = createSocietyPdf();
  const lh = opts.letterhead ?? opts.societyName ?? 'Society';
  let layout = applyLetterheadPage(doc, lh);
  const { margin, pageW } = layout;
  let y = layout.contentTop;

  const ensureSpace = (need: number) => {
    const next = letterheadEnsureSpace(doc, layout, y, need, lh);
    layout = next.layout;
    y = next.y;
  };

  doc.setFontSize(11);
  doc.text(opts.title, margin, y);
  y += 5;
  if (opts.subtitle) {
    doc.setFontSize(9);
    doc.setTextColor(80, 80, 80);
    doc.text(opts.subtitle, margin, y);
    y += 4;
  }
  doc.setTextColor(80, 80, 80);
  doc.text(`Generated: ${fmtDateTimeFull(new Date().toISOString())}`, margin, y);
  doc.setTextColor(0, 0, 0);
  y += 6;

  if (opts.totalAmount !== undefined) {
    doc.setFontSize(10);
    doc.text(`Total: ${moneyInr(opts.totalAmount)}`, margin, y);
    y += 7;
  }

  const rowsWithAmounts = opts.rows.filter((r) => r.amount !== undefined);
  const transactionTotal = sumAmountRows(rowsWithAmounts);
  const monthlyTotals = monthlyAmountTotals(rowsWithAmounts);

  const rowH = 5;
  for (const row of opts.rows) {
    ensureSpace(rowH + 1);
    doc.setFontSize(8);
    const label = row.sublabel ? `${row.label} — ${row.sublabel}` : row.label;
    const meta = [row.date, row.status, row.extra].filter(Boolean).join(' · ');
    const amount =
      row.amount !== undefined
        ? row.amount < 0
          ? `−${moneyInr(Math.abs(row.amount))}`
          : moneyInr(row.amount)
        : '';
    const line = [label, meta, amount].filter(Boolean).join(' | ');
    const lines = doc.splitTextToSize(line, pageW - 2 * margin);
    doc.text(lines[0] ?? '', margin, y);
    y += rowH;
  }

  if (monthlyTotals.length > 0) {
    ensureSpace(8 + monthlyTotals.length * rowH);
    y += 4;
    doc.setFontSize(10);
    doc.text('Monthly totals', margin, y);
    y += 5;
    doc.setFontSize(8);
    for (const m of monthlyTotals) {
      ensureSpace(rowH);
      doc.text(`${m.label} (${m.count}): ${moneyInr(m.total)}`, margin, y);
      y += rowH;
    }
  }

  if (rowsWithAmounts.length > 0) {
    ensureSpace(8);
    y += 3;
    doc.setFontSize(9);
    doc.text(`Transaction total: ${moneyInr(transactionTotal)}`, margin, y);
  }

  finalizeLetterheadFooters(doc, lh);
  return doc.output('blob');
}

export function reportDetailPdfFilename(title: string): string {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 48);
  return `${slug || 'report-detail'}-${new Date().toISOString().slice(0, 10)}.pdf`;
}
