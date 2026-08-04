import * as XLSX from 'xlsx';

export type ExportFormat = 'pdf' | 'excel' | 'word' | 'csv';

export function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.rel = 'noopener';
  a.style.display = 'none';
  // Must be in the document for reliable downloads on mobile browsers / WebViews.
  document.body.appendChild(a);
  a.click();
  a.remove();
  // Delayed revoke — immediate revoke can cancel the download on Safari / Android.
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

/** Open a blob (e.g. PDF) in a new browser tab for viewing. */
export function openBlobInNewTab(blob: Blob, filename = 'report.pdf') {
  const url = URL.createObjectURL(blob);
  const opened = window.open(url, '_blank', 'noopener,noreferrer');
  if (!opened) {
    // Popup blocked — fall back to download so the user still gets the file.
    triggerDownload(blob, filename);
    URL.revokeObjectURL(url);
    return;
  }
  // Revoke after the tab has had time to load the blob URL.
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

function escapeCsvCell(value: unknown): string {
  const s = value == null ? '' : String(value);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

export function rowsToCsvBlob(headers: string[], rows: unknown[][]): Blob {
  const lines = [headers.map(escapeCsvCell).join(','), ...rows.map((r) => r.map(escapeCsvCell).join(','))];
  return new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' });
}

export function rowsToXlsxBlob(
  sheets: { name: string; headers: string[]; rows: unknown[][] }[],
): Blob {
  const wb = XLSX.utils.book_new();
  for (const sheet of sheets) {
    const data = [sheet.headers, ...sheet.rows];
    const ws = XLSX.utils.aoa_to_sheet(data);
    XLSX.utils.book_append_sheet(wb, ws, sheet.name.slice(0, 31));
  }
  const buf = XLSX.write(wb, { bookType: 'xlsx', type: 'array' });
  return new Blob([buf], {
    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  });
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export function htmlToWordBlob(title: string, bodyHtml: string): Blob {
  const html = `<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
<style>
  body { font-family: Calibri, Arial, sans-serif; font-size: 11pt; }
  h1 { font-size: 16pt; margin-bottom: 4pt; }
  h2 { font-size: 12pt; margin-top: 14pt; margin-bottom: 6pt; }
  p.meta { color: #555; font-size: 10pt; margin: 2pt 0; }
  table { border-collapse: collapse; width: 100%; margin-top: 6pt; }
  th, td { border: 1px solid #bbb; padding: 4pt 6pt; text-align: left; vertical-align: top; }
  th { background: #f0f0f0; font-weight: bold; }
  td.num { text-align: right; font-family: Consolas, monospace; }
</style>
</head><body>${bodyHtml}</body></html>`;
  return new Blob(['\ufeff', html], { type: 'application/msword' });
}

export function moneyInr(n: number): string {
  return `₹${n.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
}

export function buildHtmlTable(headers: string[], rows: unknown[][], numericCols?: Set<number>): string {
  const head = headers.map((h) => `<th>${escapeHtml(h)}</th>`).join('');
  const body = rows
    .map((row) => {
      const cells = row
        .map((cell, i) => {
          const cls = numericCols?.has(i) ? ' class="num"' : '';
          return `<td${cls}>${escapeHtml(cell == null ? '' : String(cell))}</td>`;
        })
        .join('');
      return `<tr>${cells}</tr>`;
    })
    .join('');
  return `<table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}
