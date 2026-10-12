import 'dart:typed_data';

import '../../../../shared/pdf/letterhead_report_engine.dart';
import '../../../../shared/pdf/report_export.dart';
import '../logic/js_compat.dart';
import '../logic/report_formatters.dart';
import 'report_types.dart';

/// Port of `src/services/reporting/ExportService.ts`.

String formatExportCell(ReportColumnDef? col, Object? value) {
  if (value == null || value == '') return '';
  if (col == null) return jsString(value);
  if (col.format == ReportColumnFormat.money) {
    final n = jsNumber(value);
    return n.isFinite ? moneyInr(n) : jsString(value);
  }
  if (col.format == ReportColumnFormat.date && value is String) {
    return value.length > 10 ? value.substring(0, 10) : value;
  }
  if (col.format == ReportColumnFormat.datetime && value is String) {
    final s = value.replaceFirst('T', ' ');
    return s.length > 19 ? s.substring(0, 19) : s;
  }
  return jsString(value);
}

/// UI cell (`formatCell` in MetadataReportEngine): `—` for empty values.
String formatReportCell(ReportColumnDef col, Object? value) {
  if (value == null || value == '') return '—';
  if (col.format == ReportColumnFormat.money ||
      col.type == ReportColumnType.number) {
    final n = jsNumber(value);
    if (!n.isFinite) return jsString(value);
    return col.format == ReportColumnFormat.money ? moneyInr(n) : toLocaleIn(n);
  }
  if (col.format == ReportColumnFormat.date && value is String) {
    return value.length > 10 ? value.substring(0, 10) : value;
  }
  if (col.format == ReportColumnFormat.datetime && value is String) {
    final s = value.replaceFirst('T', ' ');
    return s.length > 19 ? s.substring(0, 19) : s;
  }
  return jsString(value);
}

/// `toMatrix(result)` — formatted cells + TOTAL row.
({List<String> headers, List<List<String>> rows, Set<int> numericCols})
    reportResultMatrix(ReportResult result) {
  final headers = [for (final c in result.columns) c.label];
  final numericCols = <int>{
    for (var i = 0; i < result.columns.length; i++)
      if (result.columns[i].isNumeric) i,
  };
  final rows = [
    for (final row in result.rows)
      [for (final c in result.columns) formatExportCell(c, row[c.key])],
  ];
  if (result.totals.isNotEmpty) {
    final totalsRow = [
      for (final c in result.columns)
        () {
          for (final t in result.totals) {
            if (t.key == c.key) return formatExportCell(c, t.value);
          }
          return '';
        }(),
    ];
    if (totalsRow.any((c) => c.isNotEmpty)) {
      final firstEmpty = totalsRow.indexWhere((c) => c.isEmpty);
      if (firstEmpty >= 0 &&
          !result.totals.any((t) => t.key == result.columns[firstEmpty].key)) {
        totalsRow[firstEmpty] = 'TOTAL';
      } else if (totalsRow.first.isEmpty) {
        totalsRow[0] = 'TOTAL';
      }
      rows.add(totalsRow);
    }
  }
  return (headers: headers, rows: rows, numericCols: numericCols);
}

/// Export bytes + file name (`{reportId}-report.{ext}`).
Future<({Uint8List bytes, String filename})> exportReportResult(
  ReportResult result,
  ExportFormat format, {
  String? societyName,
  String? filenameBase,
  SocietyLetterhead? letterhead,
  ReportPdfMode pdfMode = ReportPdfMode.letterhead,
}) async {
  final m = reportResultMatrix(result);
  final base = filenameBase ?? '${result.reportId}-report';
  final subtitle = [
    if ((societyName ?? '').isNotEmpty) societyName,
    '${result.totalRows} row(s)',
    if (result.grouped) 'grouped',
  ].join(' · ');

  final Uint8List bytes;
  switch (format) {
    case ExportFormat.csv:
      bytes = rowsToCsvBytes(m.headers, m.rows);
    case ExportFormat.excel:
      bytes = rowsToXlsxBytes(
          [ExportSheet(name: result.title, headers: m.headers, rows: m.rows)]);
    case ExportFormat.word:
      bytes = htmlToWordBytes(
        result.title,
        '<h1>${escapeHtml(result.title)}</h1><p class="meta">${escapeHtml(subtitle)}</p>${buildHtmlTable(m.headers, m.rows, m.numericCols)}',
      );
    case ExportFormat.pdf:
      final pdf = SocietyReportPdf(
        letterhead: letterhead ?? societyName ?? result.title,
        mode: pdfMode,
        landscape: m.headers.length > 6,
        title: result.title,
      );
      pdf.header(ReportMeta(
          title: result.title, society: letterhead?.name, period: subtitle));
      pdf.add(SocietyPdf.table(
        headers: m.headers,
        rows: m.rows.isEmpty
            ? [
                ['(No data)', ...List.filled(m.headers.length - 1, '')]
              ]
            : m.rows,
        numericColumns: m.numericCols,
        headerSize: 8,
        cellSize: 7,
      ));
      bytes = await pdf.save();
  }
  return (bytes: bytes, filename: '$base.${format.extension}');
}
