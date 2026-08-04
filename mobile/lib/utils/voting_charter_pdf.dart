import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'voting_charter.dart';

enum CharterPdfShareResult { shared, dismissed, failed }

String _formatGeneratedAt(DateTime when) =>
    DateFormat('yyyy-MM-dd HH:mm').format(when.toLocal());

/// Build Voting Charter PDF bytes (English or Hindi with embedded fonts).
Future<Uint8List> buildVotingCharterPdfBytes({
  String? societyName,
  required CharterLang lang,
}) async {
  final content = votingCharterContent(lang);
  final isHi = lang == CharterLang.hi;

  // Always embed Devanagari (same as web) so Hindi society names render in English PDFs too.
  final fontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
  final boldData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
  final font = pw.Font.ttf(fontData);
  final fontBold = pw.Font.ttf(boldData);
  final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

  final doc = pw.Document(theme: theme);
  final indigo = PdfColor.fromInt(0xFF4338CA);
  final muted = PdfColor.fromInt(0xFF6B7280);
  final body = PdfColor.fromInt(0xFF1F2937);
  final heading = PdfColor.fromInt(0xFF312E81);
  final societyLabel =
      (societyName != null && societyName.trim().isNotEmpty) ? societyName.trim() : (isHi ? 'सोसाइटी' : 'Society');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => [
        pw.Text(
          societyLabel,
          style: pw.TextStyle(font: fontBold, fontSize: 11, color: indigo),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          content.title,
          style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColor.fromInt(0xFF111827)),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          isHi
              ? 'तैयार: ${_formatGeneratedAt(DateTime.now())}  ·  भाषा: हिंदी'
              : 'Generated: ${_formatGeneratedAt(DateTime.now())}  ·  Language: English',
          style: pw.TextStyle(font: font, fontSize: 8, color: muted),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          isHi
              ? 'इस PDF में Noto Sans Devanagari फ़ॉन्ट एम्बेड है।'
              : 'This PDF embeds Noto Sans Devanagari for Hindi glyphs and society names.',
          style: pw.TextStyle(font: font, fontSize: 7.5, color: muted),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColor.fromInt(0xFFC7D2FE), thickness: 1),
        pw.SizedBox(height: 10),
        pw.Text(
          content.programHeading,
          style: pw.TextStyle(font: fontBold, fontSize: 13, color: heading),
        ),
        pw.SizedBox(height: 4),
        pw.Text(content.programIntro, style: pw.TextStyle(font: font, fontSize: 10, color: muted)),
        pw.SizedBox(height: 10),
        for (var i = 0; i < content.steps.length; i++) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 18,
                height: 18,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE0E7FF),
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Text(
                  '${i + 1}',
                  style: pw.TextStyle(font: fontBold, fontSize: 8, color: indigo),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(content.steps[i].title, style: pw.TextStyle(font: fontBold, fontSize: 11, color: body)),
                    pw.SizedBox(height: 2),
                    pw.Text(content.steps[i].detail, style: pw.TextStyle(font: font, fontSize: 9.5, color: muted)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          content.rulesHeading,
          style: pw.TextStyle(font: fontBold, fontSize: 13, color: heading),
        ),
        pw.SizedBox(height: 8),
        for (final sec in content.sections) ...[
          pw.Text(
            sec.heading,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 11,
              color: PdfColor.fromInt(0xFF1E1B4B),
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 4),
          for (final p in sec.points) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 4, bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('•  ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: indigo)),
                  pw.Expanded(child: pw.Text(p, style: pw.TextStyle(font: font, fontSize: 9.5, color: body))),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 8),
        ],
        pw.Divider(color: PdfColor.fromInt(0xFFC7D2FE), thickness: 0.8),
        pw.SizedBox(height: 6),
        pw.Text(
          content.footerNote,
          style: pw.TextStyle(font: font, fontSize: 8.5, color: muted),
        ),
      ],
    ),
  );

  return doc.save();
}

String votingCharterPdfFilename({String? societyName, required CharterLang lang}) {
  var slug = (societyName ?? 'society')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  if (slug.length > 40) slug = slug.substring(0, 40).replaceAll(RegExp(r'-$'), '');
  final day = DateTime.now().toIso8601String().substring(0, 10);
  return 'voting-charter-${lang.name}-${slug.isEmpty ? 'society' : slug}-$day.pdf';
}

/// Write PDF to a temp file and open the system share sheet (Save / WhatsApp / Files).
Future<CharterPdfShareResult> downloadOrShareVotingCharterPdf({
  String? societyName,
  required CharterLang lang,
}) async {
  final bytes = await buildVotingCharterPdfBytes(societyName: societyName, lang: lang);
  if (bytes.length < 100) {
    throw StateError(lang == CharterLang.hi ? 'PDF खाली था' : 'PDF was empty');
  }
  final name = votingCharterPdfFilename(societyName: societyName, lang: lang);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);

  final result = await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf', name: name)],
    subject: votingCharterContent(lang).title,
    text: votingCharterShareMessageFor(lang),
  );
  if (result.status == ShareResultStatus.dismissed) {
    return CharterPdfShareResult.dismissed;
  }
  if (result.status == ShareResultStatus.unavailable) {
    return CharterPdfShareResult.failed;
  }
  return CharterPdfShareResult.shared;
}
