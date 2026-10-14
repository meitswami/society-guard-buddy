import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../../shared/pdf/letterhead_report_engine.dart';
import '../../../../shared/pdf/report_export.dart';
import '../logic/finance_period_report.dart';
import '../logic/report_formatters.dart';

/// Port of `src/lib/financePeriodReportExport.ts` + `financePeriodReportPdf.ts`.
/// FINANCE (Totals tab) can reuse these for its "Download report" menu.

class FinancePeriodReportExportInput {
  const FinancePeriodReportExportInput({
    required this.societyName,
    required this.periodFrom,
    required this.periodTo,
    required this.generatedAt,
    required this.report,
    this.letterhead,
    this.pdfMode = ReportPdfMode.letterhead,
    this.generatedBy,
    this.includeSignatures = true,
  });

  final String societyName;
  final String periodFrom;
  final String periodTo;
  final String generatedAt;
  final FinancePeriodReportResult report;
  final SocietyLetterhead? letterhead;
  final ReportPdfMode pdfMode;
  final String? generatedBy;
  final bool includeSignatures;

  FinancePeriodReportExportInput withLetterhead(
          SocietyLetterhead? lh, ReportPdfMode mode) =>
      FinancePeriodReportExportInput(
        societyName: societyName,
        periodFrom: periodFrom,
        periodTo: periodTo,
        generatedAt: generatedAt,
        report: report,
        letterhead: lh,
        pdfMode: mode,
        generatedBy: generatedBy,
        includeSignatures: includeSignatures,
      );
}

FinancePeriodReportExportInput toFinancePeriodReportExportInput(
  FinancePeriodReportResult report, {
  required String societyName,
  required String periodFrom,
  required String periodTo,
  String? generatedAt,
  SocietyLetterhead? letterhead,
  ReportPdfMode pdfMode = ReportPdfMode.letterhead,
  String? generatedBy,
}) =>
    FinancePeriodReportExportInput(
      societyName: societyName,
      periodFrom: periodFrom,
      periodTo: periodTo,
      generatedAt: generatedAt ?? DateTime.now().toUtc().toIso8601String(),
      report: report,
      letterhead: letterhead,
      pdfMode: pdfMode,
      generatedBy: generatedBy,
    );

const List<String> kHeadWiseHeaders = [
  'Head',
  'Cash',
  'Bank / UPI',
  'Other',
  'Total'
];

List<List<Object?>> financePeriodSummaryRows(
    FinancePeriodReportExportInput input) {
  final r = input.report;
  return [
    [
      'Period',
      '${fmtIsoDateToDisplay(input.periodFrom)} to ${fmtIsoDateToDisplay(input.periodTo)}'
    ],
    ['Generated', fmtDateTimeFull(input.generatedAt)],
    ['', ''],
    ['Collection receipts — Cash', moneyInr(r.receiptByMethod.cash)],
    [
      'Collection receipts — Bank / UPI / online',
      moneyInr(r.receiptByMethod.bank)
    ],
    ['Collection receipts — Other', moneyInr(r.receiptByMethod.other)],
    ['Total receipts', moneyInr(r.totalReceipts)],
    ['Verified payment rows', '${r.verifiedPaymentCount}'],
    ['Ledger-only inflows', moneyInr(r.extraLedgerReceipt)],
    ['', ''],
    ['Total expenses', moneyInr(r.totalExpenses)],
    ['', ''],
    ['Period cash in hand (net)', moneyInr(r.cashInHand)],
    ['Period cash in bank (net)', moneyInr(r.cashInBank)],
    ['Period other channels (net)', moneyInr(r.otherNet)],
    ['Period total balance', moneyInr(r.totalBalance)],
    ['', ''],
    ['Opening cash', moneyInr(r.openingCash)],
    ['Opening bank', moneyInr(r.openingBank)],
    ['Opening other', moneyInr(r.openingOther)],
    ['Opening balance', moneyInr(r.openingBalance)],
    ['Closing cash', moneyInr(r.closingCash)],
    ['Closing bank', moneyInr(r.closingBank)],
    ['Closing other', moneyInr(r.closingOther)],
    ['Closing balance', moneyInr(r.closingBalance)],
  ];
}

List<List<Object?>> headWiseRows(List<HeadAmount> rows) => [
      for (final h in rows)
        [h.head, h.row.cash, h.row.bank, h.row.other, h.row.total]
    ];

Uint8List buildFinancePeriodReportExcel(FinancePeriodReportExportInput input) =>
    rowsToXlsxBytes([
      ExportSheet(
          name: 'Summary',
          headers: const ['Item', 'Value'],
          rows: financePeriodSummaryRows(input)),
      ExportSheet(
          name: 'Receipts by head',
          headers: kHeadWiseHeaders,
          rows: headWiseRows(input.report.receiptByHead)),
      ExportSheet(
          name: 'Expenses by head',
          headers: kHeadWiseHeaders,
          rows: headWiseRows(input.report.expenseByHead)),
    ]);

Uint8List buildFinancePeriodReportWord(FinancePeriodReportExportInput input) {
  List<List<Object?>> money(List<List<Object?>> rows) => [
        for (final r in rows) [for (final c in r) c is num ? moneyInr(c) : '$c']
      ];
  final receiptTable = buildHtmlTable(kHeadWiseHeaders,
      money(headWiseRows(input.report.receiptByHead)), {1, 2, 3, 4});
  final expenseTable = buildHtmlTable(kHeadWiseHeaders,
      money(headWiseRows(input.report.expenseByHead)), {1, 2, 3, 4});
  final summaryTable =
      buildHtmlTable(const ['Item', 'Value'], financePeriodSummaryRows(input));
  final body = '''
    <h1>${escapeHtml(input.societyName.isEmpty ? 'Society' : input.societyName)}</h1>
    <p class="meta">Finance period report · ${fmtIsoDateToDisplay(input.periodFrom)} to ${fmtIsoDateToDisplay(input.periodTo)}</p>
    <p class="meta">Generated: ${fmtDateTimeFull(input.generatedAt)}</p>
    <h2>Summary</h2>$summaryTable
    <h2>Collection receipts (head-wise)</h2>$receiptTable
    <h2>Expenses (head-wise)</h2>$expenseTable
    <p class="meta">Receipts use verified maintenance payment dates. Expenses use ledger separate-entry rows by transaction_date.</p>''';
  return htmlToWordBytes('Finance period report', body);
}

Uint8List buildFinancePeriodReportCsv(FinancePeriodReportExportInput input) =>
    rowsToCsvBytes(const [
      'Item',
      'Value'
    ], [
      ...financePeriodSummaryRows(input),
      ['', ''],
      ['Collection receipts (head-wise)', ''],
      kHeadWiseHeaders,
      ...headWiseRows(input.report.receiptByHead),
      ['', ''],
      ['Expenses (head-wise)', ''],
      kHeadWiseHeaders,
      ...headWiseRows(input.report.expenseByHead),
    ]);

const List<double> _headWidthsMm = [52, 28, 32, 24, 28];

pw.Widget _headWiseTable(String title, List<HeadAmount> rows,
    String footerLabel, ChannelTotals totals, double total) {
  final body = <List<String>>[
    if (rows.isEmpty)
      ['(none in this period)', '—', '—', '—', '—']
    else
      for (final h in rows)
        [
          h.head,
          moneyInr(h.row.cash),
          moneyInr(h.row.bank),
          moneyInr(h.row.other),
          moneyInr(h.row.total)
        ],
    [
      footerLabel,
      moneyInr(totals.cash),
      moneyInr(totals.bank),
      moneyInr(totals.other),
      moneyInr(total)
    ],
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(title, style: const pw.TextStyle(fontSize: 11)),
      ),
      SocietyPdf.table(
        headers: kHeadWiseHeaders,
        rows: body,
        columnWidthsMm: _headWidthsMm,
        numericColumns: const {1, 2, 3, 4},
        boldRows: {body.length - 1},
        filledRows: {body.length - 1},
      ),
      pw.SizedBox(height: SocietyPdf.mm(4)),
    ],
  );
}

/// Printable finance period report (`buildFinancePeriodReportPdfBlob`).
Future<Uint8List> buildFinancePeriodReportPdf(
    FinancePeriodReportExportInput input) {
  final r = input.report;
  final pdf = SocietyReportPdf(
    letterhead: input.letterhead ?? input.societyName,
    mode: input.pdfMode,
    title: 'Finance period report',
  );
  pdf.header(ReportMeta(
    title: 'Finance period report',
    society: input.societyName,
    period:
        '${fmtIsoDateToDisplay(input.periodFrom)} to ${fmtIsoDateToDisplay(input.periodTo)}',
    date: fmtDateTimeFull(input.generatedAt),
    generatedBy: input.generatedBy,
  ));
  pdf.add(SocietyPdf.text(
    '${r.verifiedPaymentCount} verified payment row(s) · Ledger-only inflows: ${moneyInr(r.extraLedgerReceipt)}',
    size: 8,
    gapAfterMm: 3,
  ));
  pdf.add(_headWiseTable('Collection receipts (head-wise)', r.receiptByHead,
      'All receipts', r.receiptByMethod, r.totalReceipts));
  pdf.add(_headWiseTable('Expenses (head-wise)', r.expenseByHead,
      'All expenses', r.expenseByMethod, r.totalExpenses));
  pdf.add(SocietyPdf.text('Summary', size: 11, gapAfterMm: 2));
  pdf.add(SocietyPdf.text('  Cash in hand (net): ${moneyInr(r.cashInHand)}'));
  pdf.add(SocietyPdf.text('  Cash in bank (net): ${moneyInr(r.cashInBank)}'));
  pdf.add(SocietyPdf.text('  Other channels (net): ${moneyInr(r.otherNet)}'));
  pdf.add(SocietyPdf.text('  Total balance: ${moneyInr(r.totalBalance)}',
      size: 11, gapAfterMm: 3));
  pdf.add(SocietyPdf.text(
    'Receipts use verified maintenance payment dates (verified_at / payment_date / created_at). Expenses use ledger separate-entry rows by transaction_date.',
    size: 8,
    color: LetterheadColors.grey120,
  ));
  if (input.includeSignatures) pdf.signatures();
  return pdf.save();
}

/// `downloadFinancePeriodReport(format, input)` bytes.
Future<Uint8List> buildFinancePeriodReportBytes(
        ExportFormat format, FinancePeriodReportExportInput input) async =>
    switch (format) {
      ExportFormat.pdf => await buildFinancePeriodReportPdf(input),
      ExportFormat.excel => buildFinancePeriodReportExcel(input),
      ExportFormat.word => buildFinancePeriodReportWord(input),
      ExportFormat.csv => buildFinancePeriodReportCsv(input),
    };
