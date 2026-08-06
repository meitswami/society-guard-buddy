import * as XLSX from 'xlsx';

/** Excel export helper — kept separate so PDF/CSV paths do not pull in xlsx. */
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
