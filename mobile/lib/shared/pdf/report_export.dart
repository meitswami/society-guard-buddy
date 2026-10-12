import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../core/export/export_kit.dart';

/// Port of `src/lib/reportExportUtils.ts` + `src/lib/xlsxExport.ts` — CSV / Excel
/// (multi-sheet) / Word (.doc HTML) builders shared by every report export.

enum ExportFormat {
  pdf,
  excel,
  word,
  csv;

  String get extension => switch (this) {
        ExportFormat.pdf => 'pdf',
        ExportFormat.excel => 'xlsx',
        ExportFormat.word => 'doc',
        ExportFormat.csv => 'csv',
      };

  /// Menu label (web `ExportFormatMenu` FORMAT_META).
  String get label => switch (this) {
        ExportFormat.pdf => 'PDF',
        ExportFormat.excel => 'Excel (.xlsx)',
        ExportFormat.word => 'Word (.doc)',
        ExportFormat.csv => 'CSV',
      };

  String get mimeType => switch (this) {
        ExportFormat.pdf => 'application/pdf',
        ExportFormat.excel =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ExportFormat.word => 'application/msword',
        ExportFormat.csv => 'text/csv',
      };
}

/// One worksheet of a multi-sheet export.
class ExportSheet {
  const ExportSheet(
      {required this.name, required this.headers, required this.rows});

  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;
}

String _sheetName(String raw, Set<String> used) {
  var base = raw.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
  if (base.isEmpty) base = 'Sheet';
  if (base.length > 31) base = base.substring(0, 31);
  var name = base;
  var i = 2;
  // Duplicate names would make the workbook invalid (the web throws here).
  while (used.contains(name.toLowerCase())) {
    final suffix = ' ($i)';
    name = (base.length + suffix.length > 31
            ? base.substring(0, 31 - suffix.length)
            : base) +
        suffix;
    i++;
  }
  used.add(name.toLowerCase());
  return name;
}

CellValue? _cell(Object? v) {
  if (v == null) return null;
  if (v is int) return IntCellValue(v);
  if (v is num) {
    if (v == v.truncateToDouble() && v.abs() < 1e15)
      return IntCellValue(v.toInt());
    return DoubleCellValue(v.toDouble());
  }
  if (v is bool) return BoolCellValue(v);
  return TextCellValue(v.toString());
}

/// `rowsToXlsxBlob(sheets)` — `.xlsx` bytes with one worksheet per [ExportSheet].
Uint8List rowsToXlsxBytes(List<ExportSheet> sheets) {
  final book = Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  final used = <String>{};
  final names = [for (final s in sheets) _sheetName(s.name, used)];
  for (var i = 0; i < sheets.length; i++) {
    final name = names[i];
    if (i == 0 && defaultSheet != null && defaultSheet != name)
      book.rename(defaultSheet, name);
    final sheet = book[name];
    sheet.appendRow([for (final h in sheets[i].headers) TextCellValue(h)]);
    for (final r in sheets[i].rows) {
      sheet.appendRow([for (final v in r) _cell(v)]);
    }
  }
  if (names.isNotEmpty) book.setDefaultSheet(names.first);
  return Uint8List.fromList(book.encode() ?? const []);
}

/// `rowsToCsvBlob(headers, rows)` — UTF-8 with BOM (Hindi-safe in Excel).
Uint8List rowsToCsvBytes(List<String> headers, List<List<Object?>> rows) =>
    ExportKit.csvBytes(headers: headers, rows: [
      for (final r in rows) [for (final c in r) c is num ? jsNum(c) : c]
    ]);

String jsNum(num n) =>
    (n is double && n == n.truncateToDouble() && n.abs() < 1e21)
        ? n.toInt().toString()
        : n.toString();

String escapeHtml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// `buildHtmlTable(headers, rows, numericCols)`.
String buildHtmlTable(List<String> headers, List<List<Object?>> rows,
    [Set<int> numericCols = const {}]) {
  final head = headers.map((h) => '<th>${escapeHtml(h)}</th>').join();
  final body = rows.map((row) {
    final cells = <String>[];
    for (var i = 0; i < row.length; i++) {
      final cls = numericCols.contains(i) ? ' class="num"' : '';
      final c = row[i];
      cells.add(
          '<td$cls>${escapeHtml(c == null ? '' : (c is num ? jsNum(c) : c.toString()))}</td>');
    }
    return '<tr>${cells.join()}</tr>';
  }).join();
  return '<table><thead><tr>$head</tr></thead><tbody>$body</tbody></table>';
}

/// `htmlToWordBlob(title, bodyHtml)` — Word-compatible HTML `.doc` bytes (with BOM).
Uint8List htmlToWordBytes(String title, String bodyHtml) {
  final html = '''<!DOCTYPE html>
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
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

/// Share an export file (mobile equivalent of `triggerDownload`).
Future<void> shareExportFile(
    Uint8List bytes, String filename, ExportFormat format,
    {String? text}) {
  final name = filename.toLowerCase().endsWith('.${format.extension}')
      ? filename
      : '$filename.${format.extension}';
  return ExportKit.shareBytes(bytes, name,
      mimeType: format.mimeType, text: text);
}
