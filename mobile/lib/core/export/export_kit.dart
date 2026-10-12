import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// PDF / Excel / CSV export and sharing — the mobile counterpart of the web
/// `reportExportUtils`, `xlsxExport`, `sharePdfWhatsApp` helpers.
abstract final class ExportKit {
  static pw.ThemeData? _pdfTheme;

  /// PDF theme with Latin + Devanagari fonts so Hindi text renders in PDFs.
  static Future<pw.ThemeData> pdfTheme() async {
    if (_pdfTheme != null) return _pdfTheme!;
    Future<pw.Font> font(String path) async => pw.Font.ttf(await rootBundle.load(path));
    final regular = await font('assets/fonts/NotoSans-Regular.ttf');
    final bold = await font('assets/fonts/NotoSans-Bold.ttf');
    final devRegular = await font('assets/fonts/NotoSansDevanagari-Regular.ttf');
    final devBold = await font('assets/fonts/NotoSansDevanagari-Bold.ttf');
    _pdfTheme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [devRegular, devBold],
    );
    return _pdfTheme!;
  }

  /// A4 document with the shared theme. Add pages with `doc.addPage(...)`.
  static Future<pw.Document> newPdf({String? title}) async {
    return pw.Document(theme: await pdfTheme(), title: title, author: 'Kutumbika');
  }

  /// Quick tabular PDF (title, optional subtitle lines, one table).
  static Future<Uint8List> tablePdf({
    required String title,
    List<String> subtitleLines = const [],
    required List<String> headers,
    required List<List<String>> rows,
    PdfPageFormat format = PdfPageFormat.a4,
    String? footer,
  }) async {
    final doc = await newPdf(title: title);
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            for (final l in subtitleLines) pw.Text(l, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(footer ?? 'Kutumbika', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// `.xlsx` bytes with one sheet.
  static Uint8List excelBytes({required String sheetName, required List<String> headers, required List<List<Object?>> rows}) {
    final book = Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    final safeName = sheetName.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
    final name = safeName.isEmpty ? 'Sheet1' : (safeName.length > 31 ? safeName.substring(0, 31) : safeName);
    if (defaultSheet != null && defaultSheet != name) book.rename(defaultSheet, name);
    final sheet = book[name];
    CellValue? cell(Object? v) {
      if (v == null) return null;
      if (v is int) return IntCellValue(v);
      if (v is num) return DoubleCellValue(v.toDouble());
      if (v is bool) return BoolCellValue(v);
      return TextCellValue(v.toString());
    }

    sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    for (final r in rows) {
      sheet.appendRow([for (final v in r) cell(v)]);
    }
    return Uint8List.fromList(book.encode() ?? const []);
  }

  /// UTF-8 CSV with BOM (opens correctly in Excel with Hindi text).
  static Uint8List csvBytes({required List<String> headers, required List<List<Object?>> rows}) {
    final text = csv.encode([headers, ...rows.map((r) => r.map((v) => v ?? '').toList())]);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ..._utf8(text)]);
  }

  static List<int> _utf8(String s) => utf8.encode(s);

  /// Save to a temp file and open the system share sheet.
  static Future<void> shareBytes(Uint8List bytes, String fileName, {String? mimeType, String? text}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeFileName(fileName)}');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], text: text);
  }

  static Future<void> sharePdf(Uint8List bytes, String fileName, {String? text}) =>
      shareBytes(bytes, fileName.endsWith('.pdf') ? fileName : '$fileName.pdf', mimeType: 'application/pdf', text: text);

  static Future<void> shareExcel(Uint8List bytes, String fileName) => shareBytes(
        bytes,
        fileName.endsWith('.xlsx') ? fileName : '$fileName.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

  static Future<void> shareCsv(Uint8List bytes, String fileName) =>
      shareBytes(bytes, fileName.endsWith('.csv') ? fileName : '$fileName.csv', mimeType: 'text/csv');

  /// System print / preview dialog for a PDF.
  static Future<void> printPdf(Uint8List bytes, {String name = 'document'}) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

  /// Open WhatsApp with a message (optionally to one number, digits only with country code).
  static Future<bool> openWhatsApp(String message, {String? phone}) async {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    final to = digits.length == 10 ? '91$digits' : digits;
    final uri = Uri.parse('https://wa.me/${to.isEmpty ? '' : to}?text=${Uri.encodeComponent(message)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  static Future<bool> email(String to, {String? subject, String? body}) => launchUrl(
        Uri(scheme: 'mailto', path: to, queryParameters: {
          if (subject != null) 'subject': subject,
          if (body != null) 'body': body,
        }),
      );

  static Future<bool> openUrl(String url, {bool inApp = false}) =>
      launchUrl(Uri.parse(url), mode: inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);

  static String _safeFileName(String name) => name.replaceAll(RegExp(r'[^\w.\- ]+'), '_');
}
