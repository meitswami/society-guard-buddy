/**
 * Official maintenance payment receipt PDF on society letterhead (header + footer).
 */
import {
  beginSocietyReport,
  drawReportHeader,
  drawSignatureSection,
  downloadSocietyReportPdf,
  finalizeSocietyReport,
  resolveLetterheadReportContext,
  type SocietyReportRenderer,
} from '@/lib/letterheadReportEngine';
import { fmtDate, fmtDateTimeFull } from '@/lib/dateFormat';

export type MaintenanceReceiptPdfInput = {
  societyId: string;
  receiptNumber: string;
  flatNumber: string;
  residentName?: string | null;
  amount: number;
  paymentMethod: string;
  paymentDate?: string | null;
  dueDate?: string | null;
  chargeTitle?: string | null;
  transactionId?: string | null;
  verifiedBy?: string | null;
  verifiedAt?: string | null;
  notes?: string | null;
  generatedBy?: string | null;
};

function money(n: number) {
  return `₹${Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
}

function drawField(r: SocietyReportRenderer, label: string, value: string): SocietyReportRenderer {
  const { doc, layout } = r;
  const x = layout.leftMargin;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.setTextColor(75, 85, 99);
  doc.text(`${label}:`, x, r.y);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(17, 24, 39);
  const lines = doc.splitTextToSize(value || '—', layout.contentWidth - 40) as string[];
  doc.text(lines, x + 38, r.y);
  return { ...r, y: r.y + Math.max(5, lines.length * 4.5) };
}

export async function buildMaintenanceReceiptPdf(input: MaintenanceReceiptPdfInput): Promise<{
  blob: Blob;
  filename: string;
  warning?: string;
}> {
  const ctx = await resolveLetterheadReportContext(input.societyId, 'letterhead');
  const lh = ctx?.letterhead ?? null;
  const mode = ctx?.mode ?? 'plain';

  let renderer = beginSocietyReport(lh ?? 'Maintenance Receipt', { mode });
  renderer = drawReportHeader(renderer, {
    title: 'Maintenance Payment Receipt',
    reportNo: input.receiptNumber,
    date: fmtDate(new Date()),
    society: lh?.name ?? null,
    generatedBy: input.generatedBy ?? null,
  });

  const { doc, layout } = renderer;
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.setTextColor(55, 65, 81);
  const intro =
    'This is an official acknowledgement of maintenance / charge payment received by the society.';
  const introLines = doc.splitTextToSize(intro, layout.contentWidth) as string[];
  doc.text(introLines, layout.leftMargin, renderer.y);
  renderer = { ...renderer, y: renderer.y + introLines.length * 5 + 4 };

  renderer = drawField(renderer, 'Receipt No.', input.receiptNumber);
  renderer = drawField(renderer, 'Flat', input.flatNumber);
  renderer = drawField(renderer, 'Member', input.residentName?.trim() || '—');
  renderer = drawField(renderer, 'Charge', input.chargeTitle?.trim() || 'Maintenance');
  renderer = drawField(renderer, 'Amount', money(input.amount));
  renderer = drawField(renderer, 'Method', String(input.paymentMethod || '—').toUpperCase());
  renderer = drawField(renderer, 'Paid on', input.paymentDate ? fmtDate(input.paymentDate) : '—');
  renderer = drawField(renderer, 'Due date', input.dueDate ? fmtDate(input.dueDate) : '—');
  renderer = drawField(renderer, 'Txn / UTR', input.transactionId?.trim() || '—');
  renderer = drawField(renderer, 'Verified by', input.verifiedBy?.trim() || '—');
  renderer = drawField(
    renderer,
    'Verified at',
    input.verifiedAt ? fmtDateTimeFull(input.verifiedAt) : '—',
  );
  if (input.notes?.trim()) {
    renderer = drawField(renderer, 'Notes', input.notes.trim());
  }

  renderer = drawSignatureSection(renderer, {
    preparedBy: true,
    verifiedBy: true,
    authorizedSignatory: true,
  });

  const blob = finalizeSocietyReport(renderer);
  const safeNo = input.receiptNumber.replace(/[^\w.-]+/g, '_');
  return {
    blob,
    filename: `maintenance-receipt-${safeNo}.pdf`,
    warning: ctx?.warning,
  };
}

export async function downloadMaintenanceReceiptPdf(input: MaintenanceReceiptPdfInput): Promise<{
  warning?: string;
}> {
  const { blob, filename, warning } = await buildMaintenanceReceiptPdf(input);
  await downloadSocietyReportPdf(blob, filename);
  return { warning };
}
