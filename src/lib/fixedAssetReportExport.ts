import { jsPDF } from 'jspdf';
import {
  buildHtmlTable,
  htmlToWordBlob,
  moneyInr,
  rowsToCsvBlob,
  triggerDownload,
  type ExportFormat,
} from '@/lib/reportExportUtils';
import { rowsToXlsxBlob } from '@/lib/xlsxExport';
import {
  computeFixedAssetReport,
  FIXED_ASSET_REGISTER_HEADERS,
  fixedAssetRegisterRows,
} from '@/lib/fixedAssetReport';
import type { FixedAsset } from '@/lib/fixedAssetTypes';

const PDF_HEADERS = ['Asset', 'Sub-head', 'Status', 'Date', 'Value', 'Vendor', 'Warranty', 'AMC'];
const PDF_COL_WIDTHS = [38, 28, 22, 22, 22, 28, 22, 22];

type ExportOpts = {
  societyName: string;
  assets: FixedAsset[];
  format: ExportFormat;
};

function pdfRows(assets: FixedAsset[]): string[][] {
  return assets.map((a) => [
    a.asset_name.slice(0, 40),
    (a.sub_head ?? '').slice(0, 24),
    a.status,
    a.acquisition_date ?? '',
    a.bill_value != null ? moneyInr(a.bill_value) : '',
    (a.vendor_name ?? '').slice(0, 24),
    a.warranty_end_date ?? '',
    a.amc_end_date ?? '',
  ]);
}

function drawPdfTable(doc: jsPDF, startY: number, headers: string[], rows: string[][], colWidths: number[]): number {
  const margin = 10;
  let y = startY;
  const lineH = 5;
  doc.setFontSize(7);
  doc.setFont('helvetica', 'bold');
  let x = margin;
  headers.forEach((h, i) => {
    doc.text(h, x, y);
    x += colWidths[i];
  });
  y += lineH;
  doc.setFont('helvetica', 'normal');
  for (const row of rows) {
    if (y > doc.internal.pageSize.getHeight() - 12) {
      doc.addPage();
      y = margin;
    }
    x = margin;
    row.forEach((cell, i) => {
      doc.text(String(cell ?? '').slice(0, 32), x, y);
      x += colWidths[i];
    });
    y += lineH;
  }
  return y;
}

export function exportFixedAssetReport({ societyName, assets, format }: ExportOpts): void {
  const summary = computeFixedAssetReport(assets);
  const rows = fixedAssetRegisterRows(assets);
  const stamp = new Date().toLocaleDateString('en-IN');
  const baseName = `fixed-assets-${societyName.replace(/\s+/g, '-').toLowerCase()}-${stamp}`;

  if (format === 'csv') {
    triggerDownload(rowsToCsvBlob(FIXED_ASSET_REGISTER_HEADERS, rows), `${baseName}.csv`);
    return;
  }

  if (format === 'excel') {
    const summaryRows = [
      ['Total assets', summary.totalAssets],
      ['Active', summary.activeCount],
      ['Not yet acquired', summary.placeholderCount],
      ['Total bill value', summary.totalBillValue],
      ['Warranty expiring (60d)', summary.warrantyExpiringSoon],
      ['AMC expiring (60d)', summary.amcExpiringSoon],
    ];
    triggerDownload(
      rowsToXlsxBlob([
        { name: 'Register', headers: FIXED_ASSET_REGISTER_HEADERS, rows },
        { name: 'Summary', headers: ['Metric', 'Value'], rows: summaryRows },
        {
          name: 'By sub-head',
          headers: ['Sub-head', 'Count', 'Value'],
          rows: summary.bySubHead.map((r) => [r.subHead, r.count, r.value]),
        },
      ]),
      `${baseName}.xlsx`,
    );
    return;
  }

  const summaryHtml = `
    <h1>Fixed Assets Register — ${societyName}</h1>
    <p class="meta">Generated ${stamp}</p>
    <h2>Summary</h2>
    <p class="meta">Total assets: ${summary.totalAssets} · Active: ${summary.activeCount} · Total value: ${moneyInr(summary.totalBillValue)}</p>
    <p class="meta">Warranty expiring soon: ${summary.warrantyExpiringSoon} · AMC expiring soon: ${summary.amcExpiringSoon}</p>
    <h2>Asset register</h2>
    ${buildHtmlTable(FIXED_ASSET_REGISTER_HEADERS, rows, new Set([5]))}
  `;

  if (format === 'word') {
    triggerDownload(htmlToWordBlob(`Fixed Assets — ${societyName}`, summaryHtml), `${baseName}.doc`);
    return;
  }

  const doc = new jsPDF({ orientation: 'landscape' });
  doc.setFontSize(14);
  doc.text(`Fixed Assets Register — ${societyName}`, 14, 16);
  doc.setFontSize(9);
  doc.text(`Generated ${stamp} · Total: ${summary.totalAssets} assets · Value: ${moneyInr(summary.totalBillValue)}`, 14, 22);
  drawPdfTable(doc, 28, PDF_HEADERS, pdfRows(assets), PDF_COL_WIDTHS);
  doc.save(`${baseName}.pdf`);
}
