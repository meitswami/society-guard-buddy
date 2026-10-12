import 'dart:typed_data';

import '../../../../shared/pdf/letterhead_report_engine.dart';
import '../../../../shared/pdf/report_export.dart';
import '../data/report_models.dart';
import '../logic/finance_period_report.dart';
import '../logic/js_compat.dart';
import '../logic/report_aggregations.dart';
import '../logic/report_formatters.dart';
import '../logic/statement_amount_totals.dart';

/// Port of `src/lib/monthlyReportExport.ts` — Reports page "Generate Report",
/// Download (Excel / Word / CSV) and WhatsApp share.

enum MonthlyReportTab { financial, visitor, vehicle, allModules }

extension MonthlyReportTabX on MonthlyReportTab {
  String get id => switch (this) {
        MonthlyReportTab.financial => 'financial',
        MonthlyReportTab.visitor => 'visitor',
        MonthlyReportTab.vehicle => 'vehicle',
        MonthlyReportTab.allModules => 'all_modules',
      };

  String get title => switch (this) {
        MonthlyReportTab.financial => 'Financial report',
        MonthlyReportTab.visitor => 'Visitor report',
        MonthlyReportTab.vehicle => 'Vehicle report',
        MonthlyReportTab.allModules => 'All modules report',
      };
}

class ReportVisitorStats {
  const ReportVisitorStats({
    this.totalVisitors = 0,
    this.totalVehicles = 0,
    this.totalDeliveries = 0,
    this.currentlyInside = 0,
    this.uniqueFlats = 0,
  });

  final int totalVisitors;
  final int totalVehicles;
  final int totalDeliveries;
  final int currentlyInside;
  final int uniqueFlats;

  /// Web `visitorStats` memo.
  factory ReportVisitorStats.of(List<ReportVisitor> v) => ReportVisitorStats(
        totalVisitors: v.where((x) => x.category == 'visitor').length,
        totalVehicles: v.where((x) => x.hasVehicle).length,
        totalDeliveries: v
            .where((x) => x.category == 'delivery' || x.category == 'service')
            .length,
        currentlyInside: v.where((x) => x.isInside).length,
        uniqueFlats: {for (final x in v) x.flatNumber}.length,
      );
}

class ReportExportContext {
  const ReportExportContext({
    required this.societyName,
    required this.reportMonth,
    required this.tab,
    this.letterhead,
    this.pdfMode = ReportPdfMode.letterhead,
    this.generatedBy,
    this.includeSignatures = true,
    this.financeEntries = const [],
    this.financeGroups = const [],
    this.financeMonthTotal,
    this.reportMonthNet,
    this.periodReport,
    this.visitors = const [],
    this.visitorStats,
  });

  final String societyName;

  /// Period label (`MM/yyyy` or `dd/MM/yyyy – dd/MM/yyyy`).
  final String reportMonth;
  final MonthlyReportTab tab;
  final SocietyLetterhead? letterhead;
  final ReportPdfMode pdfMode;
  final String? generatedBy;
  final bool includeSignatures;
  final List<FinancePeriodLedgerEntry> financeEntries;
  final List<LedgerInflowGroup> financeGroups;
  final double? financeMonthTotal;

  /// Period net + head-wise breakdown (web `reportMonthNet` + `periodHeadWise`).
  final FinancePeriodReportResult? reportMonthNet;
  final FinancePeriodReportResult? periodReport;
  final List<ReportVisitor> visitors;
  final ReportVisitorStats? visitorStats;

  ReportExportContext withPdf(SocietyLetterhead? lh, ReportPdfMode mode) =>
      ReportExportContext(
        societyName: societyName,
        reportMonth: reportMonth,
        tab: tab,
        letterhead: lh,
        pdfMode: mode,
        generatedBy: generatedBy,
        includeSignatures: includeSignatures,
        financeEntries: financeEntries,
        financeGroups: financeGroups,
        financeMonthTotal: financeMonthTotal,
        reportMonthNet: reportMonthNet,
        periodReport: periodReport,
        visitors: visitors,
        visitorStats: visitorStats,
      );
}

/// Sheet kind decides how numbers are printed in the PDF.
class _Sheet extends ExportSheet {
  const _Sheet(
      {required super.name,
      required super.headers,
      required super.rows,
      this.moneySummary = false});

  /// 2-column summary whose numeric values are money (financial summary).
  final bool moneySummary;
}

const List<String> _headWiseHeaders = [
  'Head',
  'Cash',
  'Bank / UPI',
  'Other',
  'Total'
];

List<List<Object?>> _headWiseSheetRows(List<HeadAmount> rows,
        String footerLabel, ChannelTotals footer, double total) =>
    [
      for (final h in rows)
        [h.head, h.row.cash, h.row.bank, h.row.other, h.row.total],
      [footerLabel, footer.cash, footer.bank, footer.other, total],
    ];

List<_Sheet> _financialSheets(ReportExportContext ctx) {
  final entries = ctx.financeEntries;
  final net = ctx.reportMonthNet;
  final entryTotal = sumAmountRows(entries.map((e) => e.totalAmount));
  final monthly = monthlyAmountTotals(entries
      .map((e) => AmountRow(amount: e.totalAmount, dateIso: e.ledgerDate)));
  final sheets = <_Sheet>[
    _Sheet(
      name: 'Summary',
      headers: const ['Item', 'Value'],
      moneySummary: true,
      rows: [
        ['Report month', ctx.reportMonth],
        ['Gross total', ctx.financeMonthTotal ?? entryTotal],
        ['Cash in hand (net)', net?.cashInHand ?? 0],
        ['Balance in bank (net)', net?.cashInBank ?? 0],
        ['Other net', net?.otherNet ?? 0],
        ['Total balance', net?.totalBalance ?? 0],
      ],
    ),
  ];
  final hw = ctx.periodReport;
  if (hw != null) {
    sheets.add(_Sheet(
      name: 'Receipts by head',
      headers: _headWiseHeaders,
      rows: _headWiseSheetRows(hw.receiptByHead, 'All receipts',
          hw.receiptByMethod, hw.totalReceipts),
    ));
    sheets.add(_Sheet(
      name: 'Expenses by head',
      headers: _headWiseHeaders,
      rows: _headWiseSheetRows(hw.expenseByHead, 'All expenses',
          hw.expenseByMethod, hw.totalExpenses),
    ));
  }
  sheets.addAll([
    _Sheet(
      name: 'Monthly totals',
      headers: const ['Month', 'Entries', 'Total amount'],
      rows: [
        for (final m in monthly) [m.label, m.count, m.total],
        ['Total', entries.length, entryTotal],
      ],
    ),
    _Sheet(
      name: 'Totals by mode',
      headers: const [
        'record_mode',
        'destination',
        'entries',
        'total_amount',
        'flat_units'
      ],
      rows: [
        for (final g in ctx.financeGroups)
          [g.recordMode, g.destination, g.count, g.total, g.flatUnits],
        ['', '', 'Total', entryTotal, ''],
      ],
    ),
    _Sheet(
      name: 'All entries',
      headers: const [
        'record_mode',
        'destination',
        'flat_units',
        'total_amount',
        'status',
        'method',
        'date'
      ],
      rows: [
        for (final e in entries)
          [
            e.recordMode ?? '',
            e.destination,
            e.aggregateFlatCount,
            e.totalAmount,
            e.effectiveStatus,
            e.paymentMethod ?? '',
            fmtDate(e.ledgerDate),
          ],
        ['', '', '', entryTotal, '', '', 'Total'],
      ],
    ),
  ]);
  return sheets;
}

List<_Sheet> _visitorSheets(ReportExportContext ctx) {
  final s = ctx.visitorStats ?? ReportVisitorStats.of(ctx.visitors);
  return [
    _Sheet(name: 'Summary', headers: const [
      'Item',
      'Value'
    ], rows: [
      ['Report month', ctx.reportMonth],
      ['Total visitors', s.totalVisitors],
      ['Vehicles', s.totalVehicles],
      ['Deliveries / service', s.totalDeliveries],
      ['Currently inside', s.currentlyInside],
      ['Unique flats', s.uniqueFlats],
    ]),
    _Sheet(
      name: 'Visitors',
      headers: const [
        'Name',
        'Phone',
        'Flat',
        'Category',
        'Purpose',
        'Entry',
        'Exit',
        'Vehicle',
        'Guard'
      ],
      rows: [
        for (final v in ctx.visitors)
          [
            v.name,
            v.phone,
            v.flatNumber,
            v.category,
            v.purpose,
            fmtDateTime(v.entryTime),
            v.isInside ? 'Inside' : fmtDateTime(v.exitTime),
            v.hasVehicle ? v.vehicleNumber : '-',
            v.guardName,
          ],
      ],
    ),
  ];
}

List<_Sheet> _vehicleSheets(ReportExportContext ctx) {
  final vehicles = ctx.visitors.where((v) => v.hasVehicle).toList();
  return [
    _Sheet(name: 'Summary', headers: const [
      'Item',
      'Value'
    ], rows: [
      ['Report month', ctx.reportMonth],
      ['Vehicle entries', vehicles.length],
    ]),
    _Sheet(
      name: 'Vehicles',
      headers: const [
        'Vehicle',
        'Name',
        'Flat',
        'Category',
        'Entry',
        'Exit',
        'Guard'
      ],
      rows: [
        for (final v in vehicles)
          [
            v.vehicleNumber ?? '-',
            v.name,
            v.flatNumber,
            v.category,
            fmtDateTime(v.entryTime),
            v.isInside ? 'Inside' : fmtDateTime(v.exitTime),
            v.guardName,
          ],
      ],
    ),
  ];
}

List<_Sheet> _sheetsForTab(ReportExportContext ctx) => switch (ctx.tab) {
      MonthlyReportTab.financial => _financialSheets(ctx),
      MonthlyReportTab.visitor => _visitorSheets(ctx),
      MonthlyReportTab.vehicle => _vehicleSheets(ctx),
      MonthlyReportTab.allModules => [
          ..._financialSheets(ctx),
          ..._visitorSheets(ctx)
        ],
    };

/// Exposed for tests: `(sheet name, headers, rows)` per tab.
List<ExportSheet> monthlyReportSheets(ReportExportContext ctx) =>
    _sheetsForTab(ctx);

String _cellText(Object? c) =>
    c == null ? '' : (c is num ? jsNumberString(c) : c.toString());

/// `buildMonthlyReportPdfBlob`.
Future<Uint8List> buildMonthlyReportPdf(ReportExportContext ctx) {
  final pdf = SocietyReportPdf(
    letterhead: ctx.letterhead ??
        (ctx.societyName.isEmpty ? 'Society' : ctx.societyName),
    mode: ctx.pdfMode,
    title: ctx.tab.title,
  );
  pdf.header(ReportMeta(
    title: ctx.tab.title,
    society: ctx.societyName,
    period: ctx.reportMonth,
    date: fmtDateTimeFull(DateTime.now()),
    generatedBy: ctx.generatedBy,
  ));
  for (final sheet in _sheetsForTab(ctx)) {
    pdf.add(SocietyPdf.text(sheet.name, size: 12, gapAfterMm: 2.5));
    if (sheet.rows.isEmpty)
      pdf.add(SocietyPdf.text('(No data)', size: 8, gapAfterMm: 1));
    for (final row in sheet.rows) {
      final parts = <String>[];
      for (var i = 0; i < row.length; i++) {
        final c = row[i];
        // Web: 2-column summaries print the value as money. Count summaries
        // (visitor / vehicle) print plain numbers instead of "₹12".
        if (c is num &&
            sheet.headers.length == 2 &&
            i == 1 &&
            sheet.moneySummary) {
          parts.add(moneyInr(c));
        } else {
          parts.add(_cellText(c));
        }
      }
      pdf.add(SocietyPdf.text(parts.join(' · '), size: 8, gapAfterMm: 0.6));
    }
    pdf.gap(4);
  }
  if (ctx.includeSignatures && ctx.tab == MonthlyReportTab.financial)
    pdf.signatures();
  return pdf.save();
}

Uint8List _buildWord(ReportExportContext ctx) {
  final parts = StringBuffer();
  for (final sheet in _sheetsForTab(ctx)) {
    final numeric = <int>{};
    final ta = sheet.headers.indexOf('total_amount');
    if (ta >= 0) numeric.add(ta);
    if (sheet.headers.contains('Value')) numeric.add(1);
    final rows = [
      for (final r in sheet.rows)
        [
          for (var i = 0; i < r.length; i++)
            (numeric.contains(i) &&
                    r[i] is num &&
                    (i != 1 || sheet.moneySummary || ta == 1))
                ? moneyInr(r[i] as num)
                : _cellText(r[i]),
        ],
    ];
    parts.write(
        '<h2>${escapeHtml(sheet.name)}</h2>${buildHtmlTable(sheet.headers, rows, numeric)}');
  }
  final body = '''
    <h1>${escapeHtml(ctx.societyName.isEmpty ? 'Society' : ctx.societyName)}</h1>
    <p class="meta">${ctx.tab.title} · ${escapeHtml(ctx.reportMonth)}</p>
    <p class="meta">Generated: ${fmtDateTimeFull(DateTime.now())}</p>
    $parts''';
  return htmlToWordBytes(ctx.tab.title, body);
}

Uint8List _buildCsv(ReportExportContext ctx) {
  final rows = <List<Object?>>[];
  for (final sheet in _sheetsForTab(ctx)) {
    rows.add(['--- ${sheet.name} ---', '']);
    rows.add(sheet.headers);
    rows.addAll(sheet.rows);
    rows.add(['', '']);
  }
  return rowsToCsvBytes(const ['Section / Column', 'Value'], rows);
}

/// `downloadMonthlyReport` bytes + file name (`{tab}-report-{period}.{ext}`).
Future<({Uint8List bytes, String filename})> buildMonthlyReportFile(
    ExportFormat format, ReportExportContext ctx) async {
  final base =
      '${ctx.tab.id}-report-${ctx.reportMonth.replaceAll(RegExp(r'\s+'), '-').replaceAll('/', '-')}';
  final bytes = switch (format) {
    ExportFormat.pdf => await buildMonthlyReportPdf(ctx),
    ExportFormat.excel => rowsToXlsxBytes(_sheetsForTab(ctx)),
    ExportFormat.word => _buildWord(ctx),
    ExportFormat.csv => _buildCsv(ctx),
  };
  return (bytes: bytes, filename: '$base.${format.extension}');
}
