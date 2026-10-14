import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/export/export_kit.dart';
import '../../audit/logic/js_compat.dart';
import '../logic/fixed_asset_types.dart';
import 'society_letterhead.dart';

/// Port of `src/lib/fixedAssetReportExport.ts` (formats: pdf, excel, word, csv).
enum ExportFormat { pdf, excel, word, csv }

const _pdfHeaders = [
  'Asset',
  'Sub-head',
  'Status',
  'Date',
  'Value',
  'Vendor',
  'Warranty',
  'AMC'
];
const _pdfColWidthsMm = [38.0, 28.0, 22.0, 22.0, 22.0, 28.0, 22.0, 22.0];

/// `moneyInr` (up to 2 decimals, Indian grouping).
String moneyInr(num n) {
  final rounded = (n * 100).round() / 100;
  return '₹${jsLocale(rounded)}';
}

String _cut(String? s, int n) => jsSlice(s ?? '', 0, n);

List<List<String>> _pdfRows(List<FixedAsset> assets) => [
      for (final a in assets)
        [
          _cut(a.assetName, 40),
          _cut(a.subHead, 24),
          a.status,
          a.acquisitionDate ?? '',
          a.billValue != null ? moneyInr(a.billValue!) : '',
          _cut(a.vendorName, 24),
          a.warrantyEndDate ?? '',
          a.amcEndDate ?? '',
        ].map((c) => _cut(c, 32)).toList(),
    ];

/// `new Date().toLocaleDateString('en-IN')` → `d/M/yyyy`.
String _stamp(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _escapeHtml(String t) => t
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _htmlTable(
    List<String> headers, List<List<String>> rows, Set<int> numericCols) {
  final head = headers.map((h) => '<th>${_escapeHtml(h)}</th>').join();
  final body = rows
      .map((r) => '<tr>${[
            for (var i = 0; i < r.length; i++)
              '<td${numericCols.contains(i) ? ' class="num"' : ''}>${_escapeHtml(r[i])}</td>',
          ].join()}</tr>')
      .join();
  return '<table><thead><tr>$head</tr></thead><tbody>$body</tbody></table>';
}

String _wordHtml(String title, String bodyHtml) => '''<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><title>${_escapeHtml(title)}</title>
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

Uint8List _xlsx(
    List<({String name, List<String> headers, List<List<Object?>> rows})>
        sheets) {
  final book = Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  for (var i = 0; i < sheets.length; i++) {
    final s = sheets[i];
    final name = s.name.length > 31 ? s.name.substring(0, 31) : s.name;
    if (i == 0 && defaultSheet != null && defaultSheet != name) {
      book.rename(defaultSheet, name);
    }
    final sheet = book[name];
    sheet.appendRow([for (final h in s.headers) TextCellValue(h)]);
    for (final r in s.rows) {
      sheet.appendRow([
        for (final v in r)
          v == null
              ? null
              : v is int
                  ? IntCellValue(v)
                  : v is num
                      ? DoubleCellValue(v.toDouble())
                      : TextCellValue(v.toString()),
      ]);
    }
  }
  if (sheets.isNotEmpty) book.setDefaultSheet(sheets.first.name);
  return Uint8List.fromList(book.encode() ?? const []);
}

Future<Uint8List> buildFixedAssetPdf({
  required String societyName,
  required List<FixedAsset> assets,
  required SocietyLetterhead? letterhead,
  required String pdfMode,
  DateTime? now,
}) async {
  final summary = computeFixedAssetReport(assets, now: now);
  final stamp = _stamp(now ?? DateTime.now());
  final lh = letterhead ?? SocietyLetterhead.nameOnly(societyName);
  final doc = await ExportKit.newPdf(title: 'Fixed Assets Register');
  final theme = await ExportKit.pdfTheme();
  const mm = PdfPageFormat.mm;
  doc.addPage(
    pw.MultiPage(
      pageTheme: letterheadPageTheme(
          lh: lh,
          mode: pdfMode,
          format: PdfPageFormat.letter.landscape,
          theme: theme),
      build: (_) => [
        pw.Text('Fixed Assets Register',
            style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 2 * mm),
        pw.Text(
            'Generated $stamp · Total: ${summary.totalAssets} assets · Value: ${moneyInr(summary.totalBillValue)}',
            style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 5 * mm),
        pw.Table(
          columnWidths: {
            for (var i = 0; i < _pdfColWidthsMm.length; i++)
              i: pw.FixedColumnWidth(_pdfColWidthsMm[i] * mm)
          },
          children: [
            pw.TableRow(children: [
              for (final h in _pdfHeaders)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            fontSize: 7, fontWeight: pw.FontWeight.bold))),
            ]),
            for (final r in _pdfRows(assets))
              pw.TableRow(children: [
                for (final c in r)
                  pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3, right: 4),
                      child:
                          pw.Text(c, style: const pw.TextStyle(fontSize: 7))),
              ]),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// Builds the export and opens the share sheet (web downloads the file).
Future<void> exportFixedAssetReport({
  required String? societyId,
  required String societyName,
  required List<FixedAsset> assets,
  required ExportFormat format,
}) async {
  final now = DateTime.now();
  final summary = computeFixedAssetReport(assets, now: now);
  final rows = fixedAssetRegisterRows(assets);
  final stamp = _stamp(now);
  final baseName =
      'fixed-assets-${societyName.replaceAll(RegExp(r'\s+'), '-').toLowerCase()}-$stamp';

  switch (format) {
    case ExportFormat.csv:
      await ExportKit.shareCsv(
          ExportKit.csvBytes(headers: fixedAssetRegisterHeaders, rows: rows),
          '$baseName.csv');
    case ExportFormat.excel:
      final bytes = _xlsx([
        (name: 'Register', headers: fixedAssetRegisterHeaders, rows: rows),
        (
          name: 'Summary',
          headers: const ['Metric', 'Value'],
          rows: [
            ['Total assets', summary.totalAssets],
            ['Active', summary.activeCount],
            ['Not yet acquired', summary.placeholderCount],
            ['Total bill value', summary.totalBillValue],
            ['Warranty expiring (60d)', summary.warrantyExpiringSoon],
            ['AMC expiring (60d)', summary.amcExpiringSoon],
          ],
        ),
        (
          name: 'By sub-head',
          headers: const ['Sub-head', 'Count', 'Value'],
          rows: [
            for (final r in summary.bySubHead) [r.subHead, r.count, r.value]
          ],
        ),
      ]);
      await ExportKit.shareExcel(bytes, '$baseName.xlsx');
    case ExportFormat.word:
      final html = '''
    <h1>Fixed Assets Register — ${_escapeHtml(societyName)}</h1>
    <p class="meta">Generated $stamp</p>
    <h2>Summary</h2>
    <p class="meta">Total assets: ${summary.totalAssets} · Active: ${summary.activeCount} · Total value: ${moneyInr(summary.totalBillValue)}</p>
    <p class="meta">Warranty expiring soon: ${summary.warrantyExpiringSoon} · AMC expiring soon: ${summary.amcExpiringSoon}</p>
    <h2>Asset register</h2>
    ${_htmlTable(fixedAssetRegisterHeaders, rows, {5})}
  ''';
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(_wordHtml('Fixed Assets — $societyName', html))
      ]);
      await ExportKit.shareBytes(bytes, '$baseName.doc',
          mimeType: 'application/msword');
    case ExportFormat.pdf:
      final ctx = await resolveLetterheadReportContext(societyId);
      final bytes = await buildFixedAssetPdf(
        societyName: societyName,
        assets: assets,
        letterhead: ctx?.letterhead,
        pdfMode: ctx?.mode ?? 'letterhead',
        now: now,
      );
      await ExportKit.sharePdf(bytes, '$baseName.pdf');
  }
}
