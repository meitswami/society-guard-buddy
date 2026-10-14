// Finance exports — ports of `maintenanceReceiptPdf.ts`, `transactionStatementExport.ts`,
// `financePeriodReportExport.ts` / `financePeriodReportPdf.ts`, `sharePdfWhatsApp.ts`
// (`buildReportDetailPdfBlob`) and the Excel / CSV / Word (.doc HTML) helpers.

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/export/export_kit.dart';
import '../logic/finance_dates.dart';
import '../logic/finance_format.dart';
import '../logic/finance_period_report.dart';
import '../logic/maintenance_receipt_number.dart';
import '../logic/statement_amount_totals.dart';
import '../logic/transaction_statement_rows.dart';
import '../logic/transactions_view.dart';
import 'finance_letterhead.dart';

/// `pdf` | `excel` | `word` | `csv` (web `ExportFormat`).
enum FinExportFormat { pdf, excel, word, csv }

class FinExportFile {
  const FinExportFile(this.bytes, this.fileName, this.mimeType, {this.warning});

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final String? warning;
}

const _mimeExcel =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const _mimeWord = 'application/msword';
const _mimeCsv = 'text/csv';
const _mimePdf = 'application/pdf';

/// Share a generated file via the system share sheet (Save to Files / Drive / WhatsApp …).
Future<void> shareFinanceFile(FinExportFile f, {String? message}) =>
    ExportKit.shareBytes(f.bytes, f.fileName,
        mimeType: f.mimeType, text: message);

String _nowIso() => DateTime.now().toIso8601String();

// ─────────────── generic table helpers ───────────────

class FinSheet {
  const FinSheet(this.name, this.headers, this.rows);

  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;
}

/// Multi-sheet `.xlsx` (web `rowsToXlsxBlob`).
Uint8List financeExcelBytes(List<FinSheet> sheets) {
  final book = Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  final used = <String>{};
  CellValue? cell(Object? v) {
    if (v == null) return null;
    if (v is int) return IntCellValue(v);
    if (v is num) return DoubleCellValue(v.toDouble());
    if (v is bool) return BoolCellValue(v);
    return TextCellValue(v.toString());
  }

  for (final s in sheets) {
    var name = s.name.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
    if (name.isEmpty) name = 'Sheet';
    if (name.length > 31) name = name.substring(0, 31);
    used.add(name);
    final sheet = book[name];
    sheet.appendRow([for (final h in s.headers) TextCellValue(h)]);
    for (final r in s.rows) {
      sheet.appendRow([for (final v in r) cell(v)]);
    }
  }
  if (defaultSheet != null && !used.contains(defaultSheet)) {
    book.delete(defaultSheet);
  }
  return Uint8List.fromList(book.encode() ?? const []);
}

String _csvCell(Object? v) {
  final s = v == null ? '' : v.toString();
  if (RegExp(r'[",\n\r]').hasMatch(s)) return '"${s.replaceAll('"', '""')}"';
  return s;
}

/// Web `rowsToCsvBlob` (+ UTF-8 BOM so Excel opens Hindi text).
Uint8List financeCsvBytes(List<String> headers, List<List<Object?>> rows) {
  final lines = [
    headers.map(_csvCell).join(','),
    ...rows.map((r) => r.map(_csvCell).join(','))
  ];
  return Uint8List.fromList(
      [0xEF, 0xBB, 0xBF, ...utf8.encode(lines.join('\n'))]);
}

String _esc(String t) => t
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _htmlTable(List<String> headers, List<List<Object?>> rows,
    [Set<int> numericCols = const {}]) {
  final head = headers.map((h) => '<th>${_esc(h)}</th>').join();
  final body = rows.map((r) {
    final cells = [
      for (var i = 0; i < r.length; i++)
        '<td${numericCols.contains(i) ? ' class="num"' : ''}>${_esc(r[i] == null ? '' : r[i].toString())}</td>',
    ].join();
    return '<tr>$cells</tr>';
  }).join();
  return '<table><thead><tr>$head</tr></thead><tbody>$body</tbody></table>';
}

/// Web `htmlToWordBlob` (.doc opened by Word).
Uint8List financeWordBytes(String title, String bodyHtml) {
  final html = '''<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><title>${_esc(title)}</title>
<style>
  @page { size: letter; margin: 0.75in; }
  body { font-family: Calibri, Arial, sans-serif; font-size: 11pt; }
  h1 { font-size: 16pt; margin-bottom: 4pt; }
  h2 { font-size: 12pt; margin-top: 14pt; margin-bottom: 6pt; }
  p.meta { color: #555; font-size: 10pt; margin: 2pt 0; }
  table { border-collapse: collapse; width: 100%; margin-top: 6pt; }
  th, td { border: 1px solid #bbb; padding: 4pt 6pt; text-align: left; vertical-align: top; }
  th { background: #f0f0f0; font-weight: bold; }
  td.num { text-align: right; font-family: Consolas, monospace; }
</style>
</head><body>$bodyHtml</body></html>''';
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(html)]);
}

pw.Widget _pdfTable(
  List<String> headers,
  List<List<String>> rows, {
  Set<int> rightAligned = const {},
  Map<int, pw.TableColumnWidth>? widths,
  double fontSize = 7,
  Set<int> boldRows = const {},
}) {
  pw.Widget c(String text,
          {bool header = false, bool right = false, bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          maxLines: 3,
          style: pw.TextStyle(
              fontSize: header ? fontSize + 0.5 : fontSize,
              fontWeight: header || bold ? pw.FontWeight.bold : null),
        ),
      );
  return pw.Table(
    columnWidths: widths,
    border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.4)),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: kPdfGreyFill),
        repeat: true,
        children: [
          for (var i = 0; i < headers.length; i++)
            c(headers[i], header: true, right: rightAligned.contains(i))
        ],
      ),
      for (var r = 0; r < rows.length; r++)
        pw.TableRow(
          decoration: boldRows.contains(r)
              ? const pw.BoxDecoration(color: kPdfGreyFill)
              : null,
          children: [
            for (var i = 0; i < rows[r].length; i++)
              c(rows[r][i],
                  right: rightAligned.contains(i), bold: boldRows.contains(r)),
          ],
        ),
    ],
  );
}

// ─────────────── maintenance receipt ───────────────

class MaintenanceReceiptPdfInput {
  const MaintenanceReceiptPdfInput({
    required this.societyId,
    required this.receiptNumber,
    required this.flatNumber,
    this.residentName,
    required this.amount,
    required this.paymentMethod,
    this.paymentDate,
    this.dueDate,
    this.chargeTitle,
    this.transactionId,
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
    this.generatedBy,
  });

  final String societyId;
  final String receiptNumber;
  final String flatNumber;
  final String? residentName;
  final double amount;
  final String paymentMethod;
  final String? paymentDate;
  final String? dueDate;
  final String? chargeTitle;
  final String? transactionId;
  final String? verifiedBy;
  final String? verifiedAt;
  final String? notes;
  final String? generatedBy;
}

String _orDash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();

/// Official maintenance payment receipt on society letterhead (Hindi-capable fonts).
Future<FinExportFile> buildMaintenanceReceiptPdf(
    MaintenanceReceiptPdfInput input,
    {FinLetterheadContext? context}) async {
  final ctx = context ??
      await resolveLetterheadContext(input.societyId,
          preferredMode: 'letterhead');
  final lh = ctx.letterhead ?? FinLetterhead.nameOnly('Maintenance Receipt');
  final pageTheme = await financePageTheme(letterhead: lh, mode: ctx.mode);
  final doc = pw.Document(
      theme: pageTheme.theme,
      title: 'Maintenance Payment Receipt',
      author: 'Kutumbika');

  pw.Widget field(String label, String value) => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: mm(1.3)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: mm(38),
              child: pw.Text('$label:',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF4B5563))),
            ),
            pw.Expanded(
                child: pw.Text(value.isEmpty ? '—' : value,
                    style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      );

  doc.addPage(pw.MultiPage(
    pageTheme: pageTheme,
    build: (_) => [
      reportHeaderBlock(
        title: 'Maintenance Payment Receipt',
        reportNo: input.receiptNumber,
        date: fmtDateLocal(_nowIso()),
        society: ctx.letterhead?.name,
        generatedBy: input.generatedBy,
      ),
      pw.Text(
        'This is an official acknowledgement of maintenance / charge payment received by the society.',
        style: const pw.TextStyle(
            fontSize: 10, color: PdfColor.fromInt(0xFF374151)),
      ),
      pw.SizedBox(height: mm(4)),
      field('Receipt No.', input.receiptNumber),
      field('Flat', input.flatNumber),
      field('Member', _orDash(input.residentName)),
      field(
          'Charge',
          (input.chargeTitle ?? '').trim().isEmpty
              ? 'Maintenance'
              : input.chargeTitle!.trim()),
      field('Amount', moneyInr(input.amount)),
      field(
          'Method',
          input.paymentMethod.isEmpty
              ? '—'
              : input.paymentMethod.toUpperCase()),
      field(
          'Paid on',
          (input.paymentDate ?? '').isEmpty
              ? '—'
              : fmtDateLocal(input.paymentDate)),
      field('Due date',
          (input.dueDate ?? '').isEmpty ? '—' : fmtDateLocal(input.dueDate)),
      field('Txn / UTR', _orDash(input.transactionId)),
      field('Verified by', _orDash(input.verifiedBy)),
      field(
          'Verified at',
          (input.verifiedAt ?? '').isEmpty
              ? '—'
              : fmtDateTimeFullLocal(input.verifiedAt)),
      if ((input.notes ?? '').trim().isNotEmpty)
        field('Notes', input.notes!.trim()),
      signatureBlock(),
    ],
  ));
  return FinExportFile(
    await doc.save(),
    'maintenance-receipt-${safeReceiptFileToken(input.receiptNumber)}.pdf',
    _mimePdf,
    warning: ctx.warning,
  );
}

// ─────────────── transaction statement ───────────────

Future<Uint8List> buildTransactionStatementPdf({
  required String societyName,
  required String title,
  required String subtitle,
  required List<TransactionExportRow> rows,
}) async {
  final generatedAt = _nowIso();
  final total = sumAmountRows(rows.map((r) => r.amountRow));
  final monthly = monthlyAmountTotals(rows.map((r) => r.amountRow));
  final lh = FinLetterhead.nameOnly(societyName);
  final pageTheme = await financePageTheme(
      letterhead: lh, mode: 'letterhead', landscape: true);
  final doc =
      pw.Document(theme: pageTheme.theme, title: title, author: 'Kutumbika');
  final cellRows = [
    ...rows.map(transactionRowToCells),
    ['', '', '', '', '', '', 'Total', moneyInr(total), '', ''],
  ];
  doc.addPage(pw.MultiPage(
    pageTheme: pageTheme,
    build: (_) => [
      pw.Text(title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 3),
      pw.Text(subtitle,
          style: const pw.TextStyle(fontSize: 9, color: kPdfMuted)),
      pw.Text('Generated: ${fmtDateTimeFullLocal(generatedAt)}',
          style: const pw.TextStyle(fontSize: 9, color: kPdfMuted)),
      pw.Text('Transaction total: ${moneyInr(total)}',
          style: const pw.TextStyle(fontSize: 9, color: kPdfMuted)),
      pw.SizedBox(height: mm(5)),
      _pdfTable(kTransactionHeaders, cellRows,
          rightAligned: const {7},
          fontSize: 6.5,
          boldRows: {cellRows.length - 1}),
      if (monthly.isNotEmpty) ...[
        pw.SizedBox(height: mm(6)),
        pw.Text('Monthly totals',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: mm(2)),
        _pdfTable(
          const ['Month', 'Entries', 'Total'],
          [
            for (final m in monthly) [m.label, '${m.count}', moneyInr(m.total)],
            ['Grand total', '${rows.length}', moneyInr(total)],
          ],
          rightAligned: const {2},
          boldRows: {monthly.length},
          widths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(2)
          },
        ),
      ],
    ],
  ));
  return doc.save();
}

Future<FinExportFile> buildTransactionStatement(
  FinExportFormat format, {
  required String societyName,
  required String title,
  required String subtitle,
  required String filenameBase,
  required List<TransactionExportRow> rows,
}) async {
  final monthly = monthlyAmountTotals(rows.map((r) => r.amountRow));
  final total = sumAmountRows(rows.map((r) => r.amountRow));
  switch (format) {
    case FinExportFormat.pdf:
      return FinExportFile(
        await buildTransactionStatementPdf(
            societyName: societyName,
            title: title,
            subtitle: subtitle,
            rows: rows),
        '$filenameBase.pdf',
        _mimePdf,
      );
    case FinExportFormat.excel:
      return FinExportFile(
        financeExcelBytes([
          FinSheet('Transactions', kTransactionHeaders, [
            ...rows.map(transactionRowToRawCells),
            ['', '', '', '', '', '', 'Total', total, '', ''],
          ]),
          FinSheet('Monthly totals', const [
            'Month',
            'Entries',
            'Total amount'
          ], [
            for (final m in monthly) [m.label, m.count, m.total],
            ['Total', rows.length, total],
          ]),
        ]),
        '$filenameBase.xlsx',
        _mimeExcel,
      );
    case FinExportFormat.word:
      final table = _htmlTable(
        kTransactionHeaders,
        [
          ...rows.map(transactionRowToCells),
          ['', '', '', '', '', '', 'Total', moneyInr(total), '', '']
        ],
        const {7},
      );
      final monthlyTable = _htmlTable(const [
        'Month',
        'Entries',
        'Total amount'
      ], [
        for (final m in monthly) [m.label, '${m.count}', moneyInr(m.total)],
        ['Total', '${rows.length}', moneyInr(total)],
      ], const {
        2
      });
      final body = '''
    <h1>${_esc(societyName)}</h1>
    <p class="meta">${_esc(title)}</p>
    <p class="meta">${_esc(subtitle)}</p>
    <p class="meta">Generated: ${fmtDateTimeFullLocal(_nowIso())} · ${rows.length} row(s) · Total ${moneyInr(total)}</p>
    <h2>Transactions</h2>$table
    <h2>Monthly totals</h2>$monthlyTable''';
      return FinExportFile(
          financeWordBytes(title, body), '$filenameBase.doc', _mimeWord);
    case FinExportFormat.csv:
      return FinExportFile(
        financeCsvBytes(kTransactionHeaders, [
          ...rows.map(transactionRowToRawCells),
          ['', '', '', '', '', '', 'Total', total, '', ''],
          ['', ''],
          ['Monthly totals', '', ''],
          ['Month', 'Entries', 'Total amount'],
          for (final m in monthly) [m.label, m.count, m.total],
          ['Total', rows.length, total],
        ]),
        '$filenameBase.csv',
        _mimeCsv,
      );
  }
}

// ─────────────── finance period report (Totals tab) ───────────────

const _headWiseHeaders = ['Head', 'Cash', 'Bank / UPI', 'Other', 'Total'];

List<(String, String)> _periodSummaryRows(FinancePeriodReportResult r,
        String from, String to, String generatedAt) =>
    [
      ('Period', '${isoDateToDisplay(from)} to ${isoDateToDisplay(to)}'),
      ('Generated', fmtDateTimeFullLocal(generatedAt)),
      ('', ''),
      ('Collection receipts — Cash', moneyInr(r.receiptByMethod.cash)),
      (
        'Collection receipts — Bank / UPI / online',
        moneyInr(r.receiptByMethod.bank)
      ),
      ('Collection receipts — Other', moneyInr(r.receiptByMethod.other)),
      ('Total receipts', moneyInr(r.totalReceipts)),
      ('Verified payment rows', '${r.verifiedPaymentCount}'),
      ('Ledger-only inflows', moneyInr(r.extraLedgerReceipt)),
      ('', ''),
      ('Total expenses', moneyInr(r.totalExpenses)),
      ('', ''),
      ('Period cash in hand (net)', moneyInr(r.cashInHand)),
      ('Period cash in bank (net)', moneyInr(r.cashInBank)),
      ('Period other channels (net)', moneyInr(r.otherNet)),
      ('Period total balance', moneyInr(r.totalBalance)),
      ('', ''),
      ('Opening cash', moneyInr(r.openingCash)),
      ('Opening bank', moneyInr(r.openingBank)),
      ('Opening other', moneyInr(r.openingOther)),
      ('Opening balance', moneyInr(r.openingBalance)),
      ('Closing cash', moneyInr(r.closingCash)),
      ('Closing bank', moneyInr(r.closingBank)),
      ('Closing other', moneyInr(r.closingOther)),
      ('Closing balance', moneyInr(r.closingBalance)),
    ];

List<List<Object?>> _headRows(List<MapEntry<String, ChannelByHeadRow>> rows) =>
    [
      for (final e in rows)
        [e.key, e.value.cash, e.value.bank, e.value.other, e.value.total]
    ];

const _periodFootnote =
    'Receipts use verified maintenance payment dates (verified_at / payment_date / created_at). Expenses use ledger separate-entry rows by transaction_date.';

Future<Uint8List> buildFinancePeriodReportPdf({
  required FinancePeriodReportResult report,
  required String societyName,
  required String periodFrom,
  required String periodTo,
  required FinLetterheadContext context,
  String? generatedBy,
}) async {
  final generatedAt = _nowIso();
  final lh = context.letterhead ?? FinLetterhead.nameOnly(societyName);
  final pageTheme = await financePageTheme(letterhead: lh, mode: context.mode);
  final doc = pw.Document(
      theme: pageTheme.theme,
      title: 'Finance period report',
      author: 'Kutumbika');

  pw.Widget headTable(
      String title,
      List<MapEntry<String, ChannelByHeadRow>> rows,
      String footerLabel,
      double cash,
      double bank,
      double other,
      double total) {
    final cells = [
      if (rows.isEmpty)
        ['(none in this period)', '—', '—', '—', '—']
      else
        for (final e in rows)
          [
            e.key,
            moneyInr(e.value.cash),
            moneyInr(e.value.bank),
            moneyInr(e.value.other),
            moneyInr(e.value.total)
          ],
      [
        footerLabel,
        moneyInr(cash),
        moneyInr(bank),
        moneyInr(other),
        moneyInr(total)
      ],
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: mm(2)),
        _pdfTable(
          _headWiseHeaders,
          cells,
          rightAligned: const {1, 2, 3, 4},
          fontSize: 7.5,
          boldRows: {cells.length - 1},
          widths: const {
            0: pw.FlexColumnWidth(52),
            1: pw.FlexColumnWidth(28),
            2: pw.FlexColumnWidth(32),
            3: pw.FlexColumnWidth(24),
            4: pw.FlexColumnWidth(28),
          },
        ),
        pw.SizedBox(height: mm(4)),
      ],
    );
  }

  final r = report;
  doc.addPage(pw.MultiPage(
    pageTheme: pageTheme,
    build: (_) => [
      reportHeaderBlock(
        title: 'Finance period report',
        society: societyName,
        period:
            '${isoDateToDisplay(periodFrom)} to ${isoDateToDisplay(periodTo)}',
        date: fmtDateTimeFullLocal(generatedAt),
        generatedBy: generatedBy,
      ),
      pw.Text(
          '${r.verifiedPaymentCount} verified payment row(s) · Ledger-only inflows: ${moneyInr(r.extraLedgerReceipt)}',
          style: const pw.TextStyle(fontSize: 8)),
      pw.SizedBox(height: mm(4)),
      headTable(
          'Collection receipts (head-wise)',
          r.receiptByHead,
          'All receipts',
          r.receiptByMethod.cash,
          r.receiptByMethod.bank,
          r.receiptByMethod.other,
          r.totalReceipts),
      headTable(
          'Expenses (head-wise)',
          r.expenseByHead,
          'All expenses',
          r.expenseByMethod.cash,
          r.expenseByMethod.bank,
          r.expenseByMethod.other,
          r.totalExpenses),
      pw.Text('Summary',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 3),
      pw.Text('  Cash in hand (net): ${moneyInr(r.cashInHand)}',
          style: const pw.TextStyle(fontSize: 10)),
      pw.Text('  Cash in bank (net): ${moneyInr(r.cashInBank)}',
          style: const pw.TextStyle(fontSize: 10)),
      pw.Text('  Other channels (net): ${moneyInr(r.otherNet)}',
          style: const pw.TextStyle(fontSize: 10)),
      pw.Text('  Total balance: ${moneyInr(r.totalBalance)}',
          style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: mm(4)),
      pw.Text(_periodFootnote,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      signatureBlock(),
    ],
  ));
  return doc.save();
}

Future<FinExportFile> buildFinancePeriodReport(
  FinExportFormat format, {
  required FinancePeriodReportResult report,
  required String societyName,
  required String periodFrom,
  required String periodTo,
  required String filenameBase,
  required FinLetterheadContext context,
  String? generatedBy,
}) async {
  final generatedAt = _nowIso();
  final summary = _periodSummaryRows(report, periodFrom, periodTo, generatedAt);
  switch (format) {
    case FinExportFormat.pdf:
      return FinExportFile(
        await buildFinancePeriodReportPdf(
          report: report,
          societyName: societyName,
          periodFrom: periodFrom,
          periodTo: periodTo,
          context: context,
          generatedBy: generatedBy,
        ),
        '$filenameBase.pdf',
        _mimePdf,
        warning: context.warning,
      );
    case FinExportFormat.excel:
      return FinExportFile(
        financeExcelBytes([
          FinSheet('Summary', const [
            'Item',
            'Value'
          ], [
            for (final s in summary) [s.$1, s.$2]
          ]),
          FinSheet('Receipts by head', _headWiseHeaders,
              _headRows(report.receiptByHead)),
          FinSheet('Expenses by head', _headWiseHeaders,
              _headRows(report.expenseByHead)),
        ]),
        '$filenameBase.xlsx',
        _mimeExcel,
      );
    case FinExportFormat.word:
      List<List<Object?>> money(List<List<Object?>> rows) => [
            for (final r in rows)
              [for (final c in r) c is num ? moneyInr(c) : c]
          ];
      final body = '''
    <h1>${_esc(societyName.isEmpty ? 'Society' : societyName)}</h1>
    <p class="meta">Finance period report · ${isoDateToDisplay(periodFrom)} to ${isoDateToDisplay(periodTo)}</p>
    <p class="meta">Generated: ${fmtDateTimeFullLocal(generatedAt)}</p>
    <h2>Summary</h2>${_htmlTable(const [
            'Item',
            'Value'
          ], [
            for (final s in summary) [s.$1, s.$2]
          ])}
    <h2>Collection receipts (head-wise)</h2>${_htmlTable(_headWiseHeaders, money(_headRows(report.receiptByHead)), const {
            1,
            2,
            3,
            4
          })}
    <h2>Expenses (head-wise)</h2>${_htmlTable(_headWiseHeaders, money(_headRows(report.expenseByHead)), const {
            1,
            2,
            3,
            4
          })}
    <p class="meta">Receipts use verified maintenance payment dates. Expenses use ledger separate-entry rows by transaction_date.</p>''';
      return FinExportFile(financeWordBytes('Finance period report', body),
          '$filenameBase.doc', _mimeWord);
    case FinExportFormat.csv:
      return FinExportFile(
        financeCsvBytes(const [
          'Item',
          'Value'
        ], [
          for (final s in summary) [s.$1, s.$2],
          ['', ''],
          ['Collection receipts (head-wise)', ''],
          _headWiseHeaders,
          ..._headRows(report.receiptByHead),
          ['', ''],
          ['Expenses (head-wise)', ''],
          _headWiseHeaders,
          ..._headRows(report.expenseByHead),
        ]),
        '$filenameBase.csv',
        _mimeCsv,
      );
  }
}

// ─────────────── head-wise drill-down PDF (ReportDetailModal share) ───────────────

String reportDetailPdfFilename(String title) {
  var slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  if (slug.length > 48) slug = slug.substring(0, 48);
  return '${slug.isEmpty ? 'report-detail' : slug}-${todayRecordingDate()}.pdf';
}

Future<Uint8List> buildReportDetailPdf({
  required String societyName,
  required String title,
  String? subtitle,
  double? totalAmount,
  required List<FinReportRow> rows,
}) async {
  final lh = FinLetterhead.nameOnly(societyName);
  final pageTheme = await financePageTheme(letterhead: lh, mode: 'letterhead');
  final doc =
      pw.Document(theme: pageTheme.theme, title: title, author: 'Kutumbika');
  final withAmounts = rows.where((r) => r.amount != null).toList();
  final amountRows = withAmounts.map(
      (r) => AmountRow(amount: r.amount, dateIso: r.dateIso, date: r.date));
  final txTotal = sumAmountRows(amountRows);
  final monthly = monthlyAmountTotals(amountRows);
  String signed(double n) => n < 0 ? '−${moneyInr(n.abs())}' : moneyInr(n);
  doc.addPage(pw.MultiPage(
    pageTheme: pageTheme,
    build: (_) => [
      pw.Text(title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if ((subtitle ?? '').isNotEmpty)
        pw.Text(subtitle!,
            style: const pw.TextStyle(fontSize: 9, color: kPdfMuted)),
      pw.Text('Generated: ${fmtDateTimeFullLocal(_nowIso())}',
          style: const pw.TextStyle(fontSize: 9, color: kPdfMuted)),
      pw.SizedBox(height: mm(4)),
      if (totalAmount != null) ...[
        pw.Text('Total: ${moneyInr(totalAmount)}',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: mm(3)),
      ],
      for (final row in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            [
              (row.sublabel ?? '').isNotEmpty
                  ? '${row.label} — ${row.sublabel}'
                  : row.label,
              [row.date, row.status, row.extra]
                  .where((v) => (v ?? '').isNotEmpty)
                  .join(' · '),
              if (row.amount != null) signed(row.amount!),
            ].where((s) => s.isNotEmpty).join(' | '),
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      if (monthly.isNotEmpty) ...[
        pw.SizedBox(height: mm(4)),
        pw.Text('Monthly totals',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        for (final m in monthly)
          pw.Text('${m.label} (${m.count}): ${moneyInr(m.total)}',
              style: const pw.TextStyle(fontSize: 8)),
      ],
      if (withAmounts.isNotEmpty) ...[
        pw.SizedBox(height: mm(3)),
        pw.Text('Transaction total: ${moneyInr(txTotal)}',
            style: const pw.TextStyle(fontSize: 9)),
      ],
    ],
  ));
  return doc.save();
}
