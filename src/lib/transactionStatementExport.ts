import { fmtDate, fmtDateTimeFull } from '@/lib/dateFormat';
import {
  buildFinancePeriodReportPdf,
  buildTransactionStatementPdfBlob,
  buildFinancePeriodReportCsv,
  buildFinancePeriodReportExcel,
  buildFinancePeriodReportWord,
  type FinancePeriodReportExportInput,
} from '@/lib/financePeriodReportExport';
import { monthlyAmountTotals, sumAmountRows } from '@/lib/statementAmountTotals';
import {
  buildHtmlTable,
  htmlToWordBlob,
  moneyInr,
  rowsToCsvBlob,
  type ExportFormat,
  triggerDownload,
} from '@/lib/reportExportUtils';
import { rowsToXlsxBlob } from '@/lib/xlsxExport';

export type TransactionExportRow = {
  date: string;
  dateIso: string;
  type: string;
  flat: string;
  description: string;
  counterparty: string;
  method: string;
  transactionId: string;
  amount: number;
  status: string;
  notes: string;
};

const TXN_HEADERS = [
  'Date',
  'Type',
  'Flat',
  'Description',
  'Counterparty',
  'Method',
  'Transaction ID',
  'Amount',
  'Status',
  'Notes',
];

export function transactionRowToCells(r: TransactionExportRow): string[] {
  return [
    r.date,
    r.type,
    r.flat,
    r.description,
    r.counterparty,
    r.method,
    r.transactionId,
    moneyInr(r.amount),
    r.status,
    r.notes,
  ];
}

export function transactionRowToRawCells(r: TransactionExportRow): unknown[] {
  return [
    r.date,
    r.type,
    r.flat,
    r.description,
    r.counterparty,
    r.method,
    r.transactionId,
    r.amount,
    r.status,
    r.notes,
  ];
}

export function buildTransactionStatementExcel(rows: TransactionExportRow[]): Blob {
  const monthly = monthlyAmountTotals(rows);
  const total = sumAmountRows(rows);
  return rowsToXlsxBlob([
    {
      name: 'Transactions',
      headers: TXN_HEADERS,
      rows: [
        ...rows.map(transactionRowToRawCells),
        ['', '', '', '', '', '', 'Total', total, '', ''],
      ],
    },
    {
      name: 'Monthly totals',
      headers: ['Month', 'Entries', 'Total amount'],
      rows: [
        ...monthly.map((m) => [m.label, m.count, m.total]),
        ['Total', rows.length, total],
      ],
    },
  ]);
}

export function buildTransactionStatementWord(opts: {
  societyName: string;
  title: string;
  subtitle: string;
  generatedAt: string;
  rows: TransactionExportRow[];
}): Blob {
  const monthly = monthlyAmountTotals(opts.rows);
  const total = sumAmountRows(opts.rows);
  const table = buildHtmlTable(
    TXN_HEADERS,
    [...opts.rows.map(transactionRowToCells), ['', '', '', '', '', '', 'Total', moneyInr(total), '', '']],
    new Set([7]),
  );
  const monthlyTable = buildHtmlTable(
    ['Month', 'Entries', 'Total amount'],
    [
      ...monthly.map((m) => [m.label, String(m.count), moneyInr(m.total)]),
      ['Total', String(opts.rows.length), moneyInr(total)],
    ],
    new Set([2]),
  );
  const body = `
    <h1>${opts.societyName}</h1>
    <p class="meta">${opts.title}</p>
    <p class="meta">${opts.subtitle}</p>
    <p class="meta">Generated: ${fmtDateTimeFull(opts.generatedAt)} · ${opts.rows.length} row(s) · Total ${moneyInr(total)}</p>
    <h2>Transactions</h2>${table}
    <h2>Monthly totals</h2>${monthlyTable}`;
  return htmlToWordBlob(opts.title, body);
}

export function buildTransactionStatementCsv(rows: TransactionExportRow[]): Blob {
  const monthly = monthlyAmountTotals(rows);
  const total = sumAmountRows(rows);
  const dataRows = [
    ...rows.map(transactionRowToRawCells),
    ['', '', '', '', '', '', 'Total', total, '', ''],
    ['', ''],
    ['Monthly totals', '', ''],
    ['Month', 'Entries', 'Total amount'],
    ...monthly.map((m) => [m.label, m.count, m.total]),
    ['Total', rows.length, total],
  ];
  return rowsToCsvBlob(TXN_HEADERS, dataRows);
}

export function getTransactionStatementPdfBlob(opts: {
  societyName: string;
  title: string;
  subtitle: string;
  rows: TransactionExportRow[];
}): Blob {
  const generatedAt = new Date().toISOString();
  const cellRows = opts.rows.map(transactionRowToCells);
  const monthly = monthlyAmountTotals(opts.rows);
  const transactionTotal = sumAmountRows(opts.rows);
  return buildTransactionStatementPdfBlob({
    societyName: opts.societyName,
    title: opts.title,
    subtitle: opts.subtitle,
    generatedAt,
    headers: TXN_HEADERS,
    rows: [...cellRows, ['', '', '', '', '', '', 'Total', moneyInr(transactionTotal), '', '']],
    monthlyTotals: monthly,
    transactionTotal,
  });
}

export function downloadTransactionStatement(
  format: ExportFormat,
  opts: {
    societyName: string;
    title: string;
    subtitle: string;
    filenameBase: string;
    rows: TransactionExportRow[];
  },
) {
  const generatedAt = new Date().toISOString();
  let blob: Blob;
  let ext: string;

  switch (format) {
    case 'pdf':
      blob = getTransactionStatementPdfBlob(opts);
      ext = 'pdf';
      break;
    case 'excel':
      blob = buildTransactionStatementExcel(opts.rows);
      ext = 'xlsx';
      break;
    case 'word':
      blob = buildTransactionStatementWord({ ...opts, generatedAt });
      ext = 'doc';
      break;
    case 'csv':
      blob = buildTransactionStatementCsv(opts.rows);
      ext = 'csv';
      break;
  }

  triggerDownload(blob, `${opts.filenameBase}.${ext}`);
}

export function downloadFinancePeriodReport(
  format: ExportFormat,
  input: FinancePeriodReportExportInput,
  filenameBase: string,
) {
  let blob: Blob;
  let ext: string;

  switch (format) {
    case 'pdf':
      blob = buildFinancePeriodReportPdf(input);
      ext = 'pdf';
      break;
    case 'excel':
      blob = buildFinancePeriodReportExcel(input);
      ext = 'xlsx';
      break;
    case 'word':
      blob = buildFinancePeriodReportWord(input);
      ext = 'doc';
      break;
    case 'csv':
      blob = buildFinancePeriodReportCsv(input);
      ext = 'csv';
      break;
  }

  triggerDownload(blob, `${filenameBase}.${ext}`);
}

/** Build export rows from FinanceManager receipt line items. */
export function buildTransactionExportRows(input: {
  items: { kind: 'mp' | 'ledger'; p?: Record<string, unknown>; e?: Record<string, unknown> }[];
  chargeTitleById: Map<string, string>;
}): TransactionExportRow[] {
  const rows: TransactionExportRow[] = [];

  for (const item of input.items) {
    if (item.kind === 'mp' && item.p) {
      const p = item.p;
      const chargeId = String(p.charge_id ?? '');
      rows.push({
        date: fmtDate(String(p.created_at ?? '')),
        dateIso: String(p.created_at ?? ''),
        type: 'Maintenance receipt',
        flat: String(p.flat_number ?? ''),
        description: input.chargeTitleById.get(chargeId) || 'Unknown charge',
        counterparty: String(p.resident_name ?? ''),
        method: String(p.payment_method ?? '').toUpperCase(),
        transactionId: String(p.transaction_id ?? ''),
        amount: Number(p.amount ?? 0),
        status: String(p.payment_status ?? ''),
        notes: String(p.notes ?? ''),
      });
    } else if (item.kind === 'ledger' && item.e) {
      const e = item.e;
      const rawCp = e.finance_entry_counterparties;
      const cp = Array.isArray(rawCp) ? rawCp[0] : rawCp;
      const cpName =
        cp && typeof cp === 'object' && 'name' in cp ? String((cp as { name?: string }).name ?? '') : '';
      const flats = Array.isArray(e.finance_entry_allocations)
        ? (e.finance_entry_allocations as { flat_number: string }[]).map((a) => a.flat_number).join(', ')
        : '';
      rows.push({
        date: fmtDate(String(e.created_at ?? '')),
        dateIso: String(e.created_at ?? ''),
        type: String(e.destination ?? 'ledger').replace(/_/g, ' '),
        flat: flats || '—',
        description: String(e.title ?? e.record_mode ?? 'Ledger entry').replace(/_/g, ' '),
        counterparty: cpName,
        method: String(e.payment_method ?? '').toUpperCase(),
        transactionId: String(e.transaction_id ?? ''),
        amount: Number(e.total_amount ?? 0),
        status: String(e.payment_status ?? ''),
        notes: String(e.notes ?? ''),
      });
    }
  }

  return rows;
}
