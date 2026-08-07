import {
  letterheadEnsureSpace,
  type ReportPdfMode,
  type SocietyLetterhead,
} from '@/lib/pdfLetterhead';
import { drawReportHeader, beginSocietyReport, finalizeSocietyReport } from '@/lib/letterheadReportEngine';
import {
  buildHtmlTable,
  htmlToWordBlob,
  moneyInr,
  rowsToCsvBlob,
  triggerDownload,
  type ExportFormat,
} from '@/lib/reportExportUtils';
import { rowsToXlsxBlob } from '@/lib/xlsxExport';
import type { ReportColumnDef, ReportResult, ReportTotal } from './types';

function formatCell(col: ReportColumnDef | undefined, value: unknown): string {
  if (value == null || value === '') return '';
  if (!col) return String(value);
  if (col.format === 'money') {
    const n = Number(value);
    return Number.isFinite(n) ? moneyInr(n) : String(value);
  }
  if (col.format === 'date' && typeof value === 'string') {
    return value.slice(0, 10);
  }
  if (col.format === 'datetime' && typeof value === 'string') {
    return value.replace('T', ' ').slice(0, 19);
  }
  return String(value);
}

function toMatrix(result: ReportResult): { headers: string[]; rows: unknown[][]; numericCols: Set<number> } {
  const headers = result.columns.map((c) => c.label);
  const numericCols = new Set<number>();
  result.columns.forEach((c, i) => {
    if (c.type === 'number' || c.format === 'money') numericCols.add(i);
  });
  const rows = result.rows.map((row) =>
    result.columns.map((c) => formatCell(c, row[c.key])),
  );
  if (result.totals.length > 0) {
    const totalsRow = result.columns.map((c) => {
      const total = result.totals.find((t) => t.key === c.key);
      return total ? formatCell(c, total.value) : '';
    });
    if (totalsRow.some((c) => c !== '')) {
      const firstEmpty = totalsRow.findIndex((c) => c === '');
      if (firstEmpty >= 0 && !result.totals.some((t) => t.key === result.columns[firstEmpty]?.key)) {
        totalsRow[firstEmpty] = 'TOTAL';
      } else if (totalsRow[0] === '') {
        totalsRow[0] = 'TOTAL';
      }
      rows.push(totalsRow);
    }
  }
  return { headers, rows, numericCols };
}

function buildPdfBlob(
  title: string,
  subtitle: string,
  headers: string[],
  rows: unknown[][],
  letterhead?: SocietyLetterhead | string | null,
  pdfMode: ReportPdfMode = 'letterhead',
): Blob {
  let renderer = beginSocietyReport(letterhead ?? title, {
    mode: pdfMode,
    orientation: headers.length > 6 ? 'landscape' : 'portrait',
  });
  renderer = drawReportHeader(renderer, {
    title,
    society: typeof letterhead === 'object' && letterhead ? letterhead.name : undefined,
    period: subtitle,
  });

  const { doc } = renderer;
  const drawOpts = { mode: pdfMode };
  const usable = renderer.layout.contentWidth;
  const colCount = Math.max(headers.length, 1);
  const colW = usable / colCount;
  const rowH = 6;
  const x0 = renderer.layout.leftMargin;

  const drawRow = (cells: string[], header: boolean) => {
    const next = letterheadEnsureSpace(doc, renderer.layout, renderer.y, rowH + 1, letterhead ?? title, drawOpts);
    renderer = { ...renderer, layout: next.layout, y: next.y };
    doc.setFontSize(header ? 8 : 7);
    doc.setFont('helvetica', header ? 'bold' : 'normal');
    cells.forEach((cell, i) => {
      const text = doc.splitTextToSize(cell, colW - 1.5);
      doc.text(text[0] ?? '', x0 + i * colW, renderer.y);
    });
    renderer = { ...renderer, y: renderer.y + rowH };
    if (header) {
      doc.setDrawColor(180);
      doc.line(x0, renderer.y - 2, renderer.layout.pageW - renderer.layout.rightMargin, renderer.y - 2);
    }
  };

  drawRow(headers, true);
  if (rows.length === 0) {
    drawRow(['(No data)', ...Array(Math.max(0, colCount - 1)).fill('')], false);
  }
  for (const row of rows) {
    drawRow(row.map((c) => (c == null ? '' : String(c))), false);
  }

  return finalizeSocietyReport(renderer);
}

/**
 * Single export pipeline for all metadata-driven reports.
 * Reuses shared CSV/XLSX/Word helpers; PDF via Letterhead Report Engine.
 */
export class ExportService {
  export(
    result: ReportResult,
    format: ExportFormat,
    opts?: {
      societyName?: string;
      filenameBase?: string;
      letterhead?: SocietyLetterhead | null;
      pdfMode?: ReportPdfMode;
    },
  ): void {
    const { headers, rows, numericCols } = toMatrix(result);
    const base = opts?.filenameBase ?? `${result.reportId}-report`;
    const subtitle = [
      opts?.societyName,
      `${result.totalRows} row(s)`,
      result.grouped ? 'grouped' : null,
    ]
      .filter(Boolean)
      .join(' · ');

    let blob: Blob;
    let ext: string;

    switch (format) {
      case 'csv':
        blob = rowsToCsvBlob(headers, rows);
        ext = 'csv';
        break;
      case 'excel':
        blob = rowsToXlsxBlob([{ name: result.title.slice(0, 31), headers, rows }]);
        ext = 'xlsx';
        break;
      case 'word': {
        const body = `<h1>${escapeHtml(result.title)}</h1><p class="meta">${escapeHtml(subtitle)}</p>${buildHtmlTable(headers, rows, numericCols)}`;
        blob = htmlToWordBlob(result.title, body);
        ext = 'doc';
        break;
      }
      case 'pdf':
        blob = buildPdfBlob(
          result.title,
          subtitle,
          headers,
          rows,
          opts?.letterhead ?? opts?.societyName,
          opts?.pdfMode ?? 'letterhead',
        );
        ext = 'pdf';
        break;
      default:
        throw new Error(`Unsupported export format: ${format as string}`);
    }

    triggerDownload(blob, `${base}.${ext}`);
  }

  formatTotalsLine(totals: ReportTotal[]): string {
    return totals.map((t) => `${t.label}: ${moneyInr(t.value)}`).join(' · ');
  }
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export const exportService = new ExportService();
