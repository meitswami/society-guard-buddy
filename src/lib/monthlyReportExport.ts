import { createSocietyPdf } from '@/lib/pdfPage';
import { applyLetterheadPage, letterheadEnsureSpace } from '@/lib/pdfLetterhead';
import { fmtDate, fmtDateTime, fmtDateTimeFull } from '@/lib/dateFormat';
import {
  buildHtmlTable,
  htmlToWordBlob,
  moneyInr,
  rowsToCsvBlob,
  type ExportFormat,
  triggerDownload,
} from '@/lib/reportExportUtils';
import { rowsToXlsxBlob } from '@/lib/xlsxExport';
import { monthlyAmountTotals, sumAmountRows } from '@/lib/statementAmountTotals';
import type { ChannelByHeadRow } from '@/lib/financePeriodReport';

const HEAD_WISE_HEADERS = ['Head', 'Cash', 'Bank / UPI', 'Other', 'Total'] as const;

type PeriodHeadWiseExport = {
  receiptByHead: [string, ChannelByHeadRow][];
  expenseByHead: [string, ChannelByHeadRow][];
  receiptByMethod: { cash: number; bank: number; other: number };
  expenseByMethod: { cash: number; bank: number; other: number };
  totalReceipts: number;
  totalExpenses: number;
};

function headWiseSheetRows(
  rows: [string, ChannelByHeadRow][],
  footerLabel: string,
  footer: { cash: number; bank: number; other: number; total: number },
): unknown[][] {
  return [
    ...rows.map(([head, v]) => [head, v.cash, v.bank, v.other, v.total]),
    [footerLabel, footer.cash, footer.bank, footer.other, footer.total],
  ];
}

type FinanceEntryRow = {
  record_mode: string;
  destination: string;
  total_amount: number;
  aggregate_flat_count: number;
  payment_status: string;
  payment_method: string;
  created_at: string;
};

type VisitorRow = {
  name: string;
  phone: string;
  flatNumber: string;
  category: string;
  purpose: string;
  entryTime: string;
  exitTime?: string | null;
  vehicleNumber?: string | null;
  guardName: string;
};

export type ReportExportContext = {
  societyName: string;
  reportMonth: string;
  tab: 'financial' | 'visitor' | 'vehicle' | 'all_modules';
  financeEntries?: FinanceEntryRow[];
  financeGroups?: { record_mode: string; destination: string; count: number; total: number; flatUnits: number }[];
  financeMonthTotal?: number;
  reportMonthNet?: { cashInHand: number; cashInBank: number; otherNet: number; totalBalance: number };
  periodHeadWise?: PeriodHeadWiseExport;
  visitors?: VisitorRow[];
  visitorStats?: {
    totalVisitors: number;
    totalVehicles: number;
    totalDeliveries: number;
    currentlyInside: number;
    uniqueFlats: number;
  };
};

function financeDetailRows(entries: FinanceEntryRow[]): unknown[][] {
  return entries.map((e) => [
    e.record_mode,
    e.destination,
    e.aggregate_flat_count,
    e.total_amount,
    e.payment_status,
    e.payment_method,
    fmtDate(e.created_at),
  ]);
}

function visitorDetailRows(visitors: VisitorRow[]): unknown[][] {
  return visitors.map((v) => [
    v.name,
    v.phone,
    v.flatNumber,
    v.category,
    v.purpose,
    fmtDateTime(v.entryTime),
    v.exitTime ? fmtDateTime(v.exitTime) : 'Inside',
    v.vehicleNumber || '-',
    v.guardName,
  ]);
}

function buildFinancialSheets(ctx: ReportExportContext) {
  const entries = ctx.financeEntries ?? [];
  const groups = ctx.financeGroups ?? [];
  const net = ctx.reportMonthNet;
  const entryTotal = sumAmountRows(entries.map((e) => ({ amount: e.total_amount })));
  const monthly = monthlyAmountTotals(
    entries.map((e) => ({ amount: e.total_amount, dateIso: e.created_at })),
  );
  const summary: unknown[][] = [
    ['Report month', ctx.reportMonth],
    ['Gross total', ctx.financeMonthTotal ?? entryTotal],
    ['Cash in hand (net)', net?.cashInHand ?? 0],
    ['Balance in bank (net)', net?.cashInBank ?? 0],
    ['Other net', net?.otherNet ?? 0],
    ['Total balance', net?.totalBalance ?? 0],
  ];
  const headWise = ctx.periodHeadWise;
  const sheets: { name: string; headers: string[]; rows: unknown[][] }[] = [
    { name: 'Summary', headers: ['Item', 'Value'], rows: summary },
  ];
  if (headWise) {
    sheets.push(
      {
        name: 'Receipts by head',
        headers: [...HEAD_WISE_HEADERS],
        rows: headWiseSheetRows(headWise.receiptByHead, 'All receipts', {
          cash: headWise.receiptByMethod.cash,
          bank: headWise.receiptByMethod.bank,
          other: headWise.receiptByMethod.other,
          total: headWise.totalReceipts,
        }),
      },
      {
        name: 'Expenses by head',
        headers: [...HEAD_WISE_HEADERS],
        rows: headWiseSheetRows(headWise.expenseByHead, 'All expenses', {
          cash: headWise.expenseByMethod.cash,
          bank: headWise.expenseByMethod.bank,
          other: headWise.expenseByMethod.other,
          total: headWise.totalExpenses,
        }),
      },
    );
  }
  sheets.push(
    {
      name: 'Monthly totals',
      headers: ['Month', 'Entries', 'Total amount'],
      rows: [
        ...monthly.map((m) => [m.label, m.count, m.total]),
        ['Total', entries.length, entryTotal],
      ],
    },
    {
      name: 'Totals by mode',
      headers: ['record_mode', 'destination', 'entries', 'total_amount', 'flat_units'],
      rows: [
        ...groups.map((g) => [g.record_mode, g.destination, g.count, g.total, g.flatUnits]),
        ['', '', 'Total', entryTotal, ''],
      ],
    },
    {
      name: 'All entries',
      headers: ['record_mode', 'destination', 'flat_units', 'total_amount', 'status', 'method', 'date'],
      rows: [
        ...financeDetailRows(entries),
        ['', '', '', entryTotal, '', '', 'Total'],
      ],
    },
  );
  return sheets;
}

function buildVisitorSheets(ctx: ReportExportContext) {
  const visitors = ctx.visitors ?? [];
  const stats = ctx.visitorStats;
  const summary: unknown[][] = [
    ['Report month', ctx.reportMonth],
    ['Total visitors', stats?.totalVisitors ?? 0],
    ['Vehicles', stats?.totalVehicles ?? 0],
    ['Deliveries / service', stats?.totalDeliveries ?? 0],
    ['Currently inside', stats?.currentlyInside ?? 0],
    ['Unique flats', stats?.uniqueFlats ?? 0],
  ];
  return [
    { name: 'Summary', headers: ['Item', 'Value'], rows: summary },
    {
      name: 'Visitors',
      headers: ['Name', 'Phone', 'Flat', 'Category', 'Purpose', 'Entry', 'Exit', 'Vehicle', 'Guard'],
      rows: visitorDetailRows(visitors),
    },
  ];
}

function buildVehicleSheets(ctx: ReportExportContext) {
  const vehicles = (ctx.visitors ?? []).filter((v) => v.vehicleNumber);
  const summary: unknown[][] = [
    ['Report month', ctx.reportMonth],
    ['Vehicle entries', vehicles.length],
  ];
  return [
    { name: 'Summary', headers: ['Item', 'Value'], rows: summary },
    {
      name: 'Vehicles',
      headers: ['Vehicle', 'Name', 'Flat', 'Category', 'Entry', 'Exit', 'Guard'],
      rows: vehicles.map((v) => [
        v.vehicleNumber || '-',
        v.name,
        v.flatNumber,
        v.category,
        fmtDateTime(v.entryTime),
        v.exitTime ? fmtDateTime(v.exitTime) : 'Inside',
        v.guardName,
      ]),
    },
  ];
}

function buildAllModulesSheets(ctx: ReportExportContext) {
  const fin = buildFinancialSheets(ctx);
  const vis = buildVisitorSheets(ctx);
  return [...fin, ...vis];
}

function tabTitle(tab: ReportExportContext['tab']): string {
  switch (tab) {
    case 'financial':
      return 'Financial report';
    case 'visitor':
      return 'Visitor report';
    case 'vehicle':
      return 'Vehicle report';
    case 'all_modules':
      return 'All modules report';
  }
}

function sheetsForTab(ctx: ReportExportContext) {
  switch (ctx.tab) {
    case 'financial':
      return buildFinancialSheets(ctx);
    case 'visitor':
      return buildVisitorSheets(ctx);
    case 'vehicle':
      return buildVehicleSheets(ctx);
    case 'all_modules':
      return buildAllModulesSheets(ctx);
  }
}

export function buildMonthlyReportPdfBlob(ctx: ReportExportContext): Blob {
  const doc = createSocietyPdf();
  const lh = ctx.societyName || 'Society';
  let layout = applyLetterheadPage(doc, lh);
  const { margin } = layout;
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
  doc.text(`${tabTitle(ctx.tab)} · ${ctx.reportMonth}`, margin, y);
  y += 5;
  doc.text(`Generated: ${fmtDateTimeFull(new Date().toISOString())}`, margin, y);
  doc.setTextColor(0, 0, 0);
  y += 10;

  for (const sheet of sheetsForTab(ctx)) {
    line(sheet.name, 12, 7);
    for (const row of sheet.rows) {
      line(row.map((c) => (typeof c === 'number' ? (sheet.headers.length === 2 && typeof c === 'number' && row.indexOf(c) === 1 ? moneyInr(c) : String(c)) : String(c ?? ''))).join(' · '), 8, 4);
    }
    y += 4;
  }

  return doc.output('blob');
}

function buildReportWord(ctx: ReportExportContext): Blob {
  const parts = sheetsForTab(ctx)
    .map((sheet) => {
      const numericCols = new Set<number>();
      if (sheet.headers.includes('total_amount')) numericCols.add(sheet.headers.indexOf('total_amount'));
      if (sheet.headers.includes('Value')) numericCols.add(1);
      const rows = sheet.rows.map((r) =>
        r.map((c, i) => {
          if (numericCols.has(i) && typeof c === 'number') return moneyInr(c);
          return String(c ?? '');
        }),
      );
      return `<h2>${sheet.name}</h2>${buildHtmlTable(sheet.headers, rows, numericCols)}`;
    })
    .join('');
  const body = `
    <h1>${ctx.societyName || 'Society'}</h1>
    <p class="meta">${tabTitle(ctx.tab)} · ${ctx.reportMonth}</p>
    <p class="meta">Generated: ${fmtDateTimeFull(new Date().toISOString())}</p>
    ${parts}`;
  return htmlToWordBlob(tabTitle(ctx.tab), body);
}

function buildReportCsv(ctx: ReportExportContext): Blob {
  const sheets = sheetsForTab(ctx);
  const rows: unknown[][] = [];
  for (const sheet of sheets) {
    rows.push([`--- ${sheet.name} ---`, '']);
    rows.push(sheet.headers);
    rows.push(...sheet.rows);
    rows.push(['', '']);
  }
  return rowsToCsvBlob(['Section / Column', 'Value'], rows);
}

export function downloadMonthlyReport(format: ExportFormat, ctx: ReportExportContext) {
  const base = `${ctx.tab}-report-${ctx.reportMonth}`;
  let blob: Blob;
  let ext: string;

  switch (format) {
    case 'pdf':
      blob = buildMonthlyReportPdfBlob(ctx);
      ext = 'pdf';
      break;
    case 'excel':
      blob = rowsToXlsxBlob(sheetsForTab(ctx));
      ext = 'xlsx';
      break;
    case 'word':
      blob = buildReportWord(ctx);
      ext = 'doc';
      break;
    case 'csv':
      blob = buildReportCsv(ctx);
      ext = 'csv';
      break;
  }

  triggerDownload(blob, `${base}.${ext}`);
}
