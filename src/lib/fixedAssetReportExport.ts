import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import {
  buildHtmlTable,
  htmlToWordBlob,
  moneyInr,
  rowsToCsvBlob,
  rowsToXlsxBlob,
  triggerDownload,
  type ExportFormat,
} from '@/lib/reportExportUtils';
import {
  computeFixedAssetReport,
  FIXED_ASSET_REGISTER_HEADERS,
  fixedAssetRegisterRows,
} from '@/lib/fixedAssetReport';
import type { FixedAsset } from '@/lib/fixedAssetTypes';

type ExportOpts = {
  societyName: string;
  assets: FixedAsset[];
  format: ExportFormat;
};

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
  autoTable(doc, {
    head: [FIXED_ASSET_REGISTER_HEADERS],
    body: rows,
    startY: 28,
    styles: { fontSize: 7, cellPadding: 1.5 },
    headStyles: { fillColor: [41, 98, 255] },
  });
  doc.save(`${baseName}.pdf`);
}
