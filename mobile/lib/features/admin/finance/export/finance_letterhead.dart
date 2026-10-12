// Society letterhead for finance PDFs — port of `src/lib/pdfLetterhead.ts` +
// `src/lib/letterheadReportEngine.ts` on top of the `pdf` package (MultiPage handles
// pagination; the letterhead is drawn as page background / foreground).

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/export/export_kit.dart';
import '../../../../core/supabase/db.dart';

const double kPdfMarginMm = 19.05;
const String kLetterheadNotConfiguredWarning = 'Official society letterhead has not been configured.';

const PdfColor _headerRule = PdfColor.fromInt(0xFF374178);
const PdfColor _footerRule = PdfColor.fromInt(0xFF787D87);
const PdfColor _nameColor = PdfColor.fromInt(0xFF111827);
const PdfColor _metaColor = PdfColor.fromInt(0xFF4B5563);

double mm(double v) => v * PdfPageFormat.mm;

class FinLetterhead {
  FinLetterhead({
    required this.name,
    this.societyId,
    this.logoBytes,
    this.letterheadBytes,
    this.letterheadMode = 'auto',
    this.hasAsset = false,
    this.topMm = 40,
    this.bottomMm = 18,
    this.leftMm = kPdfMarginMm,
    this.rightMm = kPdfMarginMm,
    this.defaultReportFormat = 'letterhead',
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.contactPhone,
    this.contactEmail,
  });

  /// Society name only (web passes a string letterhead → auto header with name).
  factory FinLetterhead.nameOnly(String name) => FinLetterhead(name: name.trim().isEmpty ? 'Society' : name.trim());

  final String name;
  final String? societyId;
  final Uint8List? logoBytes;
  final Uint8List? letterheadBytes;
  final String letterheadMode;
  final bool hasAsset;
  final double topMm;
  final double bottomMm;
  final double leftMm;
  final double rightMm;
  final String defaultReportFormat;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? contactPhone;
  final String? contactEmail;

  String get brandMode {
    if (letterheadMode == 'image' || letterheadMode == 'stationery' || letterheadMode == 'auto') return letterheadMode;
    return hasAsset ? 'image' : 'auto';
  }

  String get addressLine {
    final cityState = [city, state].where((v) => (v ?? '').trim().isNotEmpty).join(', ');
    return [address, cityState, pincode].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');
  }

  String get contactLine =>
      [contactPhone, contactEmail].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');
}

/// Web `LetterheadReportContext`.
class FinLetterheadContext {
  const FinLetterheadContext({required this.letterhead, required this.mode, this.warning});

  final FinLetterhead? letterhead;

  /// `letterhead` | `plain`
  final String mode;
  final String? warning;
}

const _fullSelect =
    'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
const _fallbackSelect =
    'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';

double _num(Object? v, double fallback) {
  final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  return (n == null || !n.isFinite) ? fallback : n;
}

Future<Uint8List?> _download(String? url) async {
  if (url == null || url.trim().isEmpty) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) return null;
    final ct = res.headers.contentType?.mimeType ?? '';
    if (ct == 'application/pdf' || url.toLowerCase().contains('.pdf')) return null; // raster only
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Load society branding (current society only) + preload logo / letterhead images.
Future<FinLetterhead?> fetchSocietyLetterhead(String societyId) async {
  if (!dbReady || societyId.isEmpty) return null;
  Map<String, dynamic>? row;
  try {
    row = await db.from('societies').select(_fullSelect).eq('id', societyId).maybeSingle();
  } catch (_) {
    try {
      row = await db.from('societies').select(_fallbackSelect).eq('id', societyId).maybeSingle();
    } catch (_) {
      return null;
    }
  }
  if (row == null) return null;
  if (row['id'] != null && row['id'].toString() != societyId) return null; // multi-society guard
  String? letterheadUrl = row['letterhead_url']?.toString();
  final storagePath = row['letterhead_storage_path']?.toString();
  if ((letterheadUrl == null || letterheadUrl.isEmpty) && storagePath != null && storagePath.isNotEmpty) {
    try {
      letterheadUrl = await db.storage.from('society-documents').createSignedUrl(storagePath, 3600);
    } catch (_) {
      letterheadUrl = null;
    }
  }
  final results = await Future.wait([_download(row['logo_url']?.toString()), _download(letterheadUrl)]);
  final bottom = _num(row['letterhead_bottom_mm'], 18);
  final top = _num(row['letterhead_top_mm'], 40);
  final left = _num(row['letterhead_left_mm'], kPdfMarginMm);
  final right = _num(row['letterhead_right_mm'], kPdfMarginMm);
  final hasAsset = (row['letterhead_url']?.toString() ?? '').isNotEmpty || (storagePath ?? '').isNotEmpty;
  return FinLetterhead(
    name: (row['name'] ?? 'Society').toString(),
    societyId: societyId,
    logoBytes: results[0],
    letterheadBytes: results[1],
    letterheadMode: (row['letterhead_mode'] ?? 'auto').toString(),
    hasAsset: hasAsset,
    topMm: top > 0 ? top : 40,
    bottomMm: bottom > 0 ? (bottom < 16 ? 16 : bottom) : 18,
    leftMm: left > 0 ? left : kPdfMarginMm,
    rightMm: right > 0 ? right : kPdfMarginMm,
    defaultReportFormat: row['default_report_format']?.toString() == 'plain' ? 'plain' : 'letterhead',
    address: row['address']?.toString(),
    city: row['city']?.toString(),
    state: row['state']?.toString(),
    pincode: row['pincode']?.toString(),
    contactPhone: row['contact_phone']?.toString(),
    contactEmail: row['contact_email']?.toString(),
  );
}

/// Web `resolveLetterheadReportContext` (never falls back to another society).
Future<FinLetterheadContext> resolveLetterheadContext(String societyId, {String? preferredMode}) async {
  final lh = await fetchSocietyLetterhead(societyId);
  if (lh == null) {
    return const FinLetterheadContext(letterhead: null, mode: 'plain', warning: kLetterheadNotConfiguredWarning);
  }
  final requested = preferredMode ?? lh.defaultReportFormat;
  if (requested == 'letterhead' && !lh.hasAsset && lh.letterheadMode != 'stationery') {
    return FinLetterheadContext(letterhead: lh, mode: 'plain', warning: kLetterheadNotConfiguredWarning);
  }
  return FinLetterheadContext(letterhead: lh, mode: requested);
}

/// Safe content band (mm) for a page — web `measureLetterheadLayout`.
class _Layout {
  const _Layout(this.left, this.right, this.contentTop, this.bottom);

  final double left;
  final double right;
  final double contentTop;
  final double bottom;
}

_Layout _measure(FinLetterhead lh, String mode) {
  final left = lh.leftMm, right = lh.rightMm;
  if (mode == 'plain') return _Layout(left, right, kPdfMarginMm, kPdfMarginMm);
  final top = lh.topMm > left ? lh.topMm : left;
  final bottom = lh.bottomMm > 14 ? lh.bottomMm : 14.0;
  final brand = lh.brandMode;
  if (brand == 'stationery' || (brand == 'image' && lh.hasAsset)) return _Layout(left, right, top, bottom);
  final hasLogo = lh.logoBytes != null;
  var y = left + 9.5;
  if (lh.addressLine.isNotEmpty) y += 3.6;
  if (lh.contactLine.isNotEmpty) y += 3.6;
  final ruleY = [y + 2.5, left + (hasLogo ? 14 : 6) + 2, top - 8].reduce((a, b) => a > b ? a : b);
  final contentTop = [ruleY + 6, top, left].reduce((a, b) => a > b ? a : b);
  return _Layout(left, right, contentTop, bottom);
}

/// Builds the page theme: margins = safe content area, background/foreground = letterhead.
Future<pw.PageTheme> financePageTheme({
  required FinLetterhead letterhead,
  required String mode,
  bool landscape = false,
}) async {
  final theme = await ExportKit.pdfTheme();
  final format = landscape ? PdfPageFormat.letter.landscape : PdfPageFormat.letter;
  final lay = _measure(letterhead, mode);
  final pageW = format.width / PdfPageFormat.mm;
  final pageH = format.height / PdfPageFormat.mm;
  final contentBottom = pageH - lay.bottom;
  final brand = letterhead.brandMode;
  final plain = mode == 'plain';
  final stationery = !plain && brand == 'stationery';
  final fullPage = !plain && brand == 'image' && letterhead.hasAsset && letterhead.letterheadBytes != null;
  // Auto digital band when there is no full-page stationery (also when the image could not be loaded).
  final autoBand = !plain && !stationery && !fullPage;

  pw.Widget pageNo(pw.Context ctx, {double size = 8}) =>
      pw.Text('${ctx.pageNumber}/${ctx.pagesCount}', style: pw.TextStyle(fontSize: size, color: _metaColor));

  return pw.PageTheme(
    pageFormat: format,
    theme: theme,
    margin: pw.EdgeInsets.fromLTRB(mm(lay.left), mm(lay.contentTop), mm(lay.right), mm(lay.bottom)),
    buildBackground: (ctx) {
      final children = <pw.Widget>[];
      if (fullPage) {
        children.add(pw.Positioned.fill(
          child: pw.Image(pw.MemoryImage(letterhead.letterheadBytes!), fit: pw.BoxFit.fill),
        ));
      } else if (autoBand) {
        // Auto digital header band.
        final logo = letterhead.logoBytes;
        children.add(pw.Positioned(
          left: mm(lay.left),
          top: mm(lay.left - 2),
          child: pw.SizedBox(
            width: mm(pageW - lay.left - lay.right),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null) ...[
                  pw.SizedBox(width: mm(14), height: mm(14), child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain)),
                  pw.SizedBox(width: mm(3.5)),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(letterhead.name,
                          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _nameColor)),
                      if (letterhead.addressLine.isNotEmpty)
                        pw.Text(letterhead.addressLine, style: const pw.TextStyle(fontSize: 8, color: _metaColor)),
                      if (letterhead.contactLine.isNotEmpty)
                        pw.Text(letterhead.contactLine, style: const pw.TextStyle(fontSize: 8, color: _metaColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
        children.add(pw.Positioned(
          left: mm(lay.left),
          top: mm(lay.contentTop - 6),
          child: pw.Container(width: mm(pageW - lay.left - lay.right), height: 0.85 * PdfPageFormat.mm, color: _headerRule),
        ));
        // Footer band: rule + society name + page n/N.
        children.add(pw.Positioned(
          left: mm(lay.left),
          top: mm(contentBottom),
          child: pw.Container(width: mm(pageW - lay.left - lay.right), height: 0.7 * PdfPageFormat.mm, color: _footerRule),
        ));
        children.add(pw.Positioned(
          left: mm(lay.left),
          top: mm(contentBottom + 2),
          child: pw.SizedBox(
            width: mm(pageW - lay.left - lay.right),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(letterhead.name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _nameColor)),
                pageNo(ctx, size: 9),
              ],
            ),
          ),
        ));
      }
      if (fullPage || stationery) {
        children.add(pw.Positioned(
          right: mm(lay.right),
          top: mm((contentBottom + 2.5) > pageH - 9 ? pageH - 9 : contentBottom + 2.5),
          child: pageNo(ctx),
        ));
      }
      if (plain) {
        children.add(pw.Positioned(right: mm(lay.right), top: mm(pageH - 11), child: pageNo(ctx)));
      }
      return pw.FullPage(ignoreMargins: true, child: pw.Stack(children: children));
    },
  );
}

/// Web `drawReportHeader`: title + non-empty meta rows.
pw.Widget reportHeaderBlock({
  required String title,
  String? reportNo,
  String? date,
  String? society,
  String? period,
  String? generatedBy,
}) {
  final rows = <(String, String)>[
    if ((reportNo ?? '').trim().isNotEmpty) ('Report No.', reportNo!.trim()),
    if ((date ?? '').trim().isNotEmpty) ('Date', date!.trim()),
    if ((society ?? '').trim().isNotEmpty) ('Society', society!.trim()),
    if ((period ?? '').trim().isNotEmpty) ('Period', period!.trim()),
    if ((generatedBy ?? '').trim().isNotEmpty) ('Generated By', generatedBy!.trim()),
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _nameColor)),
      pw.SizedBox(height: mm(2)),
      for (final r in rows)
        pw.Padding(
          padding: pw.EdgeInsets.only(bottom: mm(1)),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: mm(28),
                child: pw.Text('${r.$1}:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _metaColor)),
              ),
              pw.Expanded(child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 9, color: _metaColor))),
            ],
          ),
        ),
      pw.SizedBox(height: mm(4)),
    ],
  );
}

/// Web `drawSignatureSection`.
pw.Widget signatureBlock() {
  pw.Widget sig(String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _nameColor)),
          pw.SizedBox(height: mm(9)),
          pw.Container(width: mm(48), height: 0.6, color: _footerRule),
        ],
      );
  return pw.Padding(
    padding: pw.EdgeInsets.only(top: mm(6)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(children: [pw.Expanded(child: sig('Prepared By')), pw.Expanded(child: sig('Verified By'))]),
        pw.SizedBox(height: mm(10)),
        pw.Align(alignment: pw.Alignment.centerRight, child: sig('Authorized Signatory')),
      ],
    ),
  );
}

const PdfColor kPdfGreyFill = PdfColor.fromInt(0xFFF0F0F0);
const PdfColor kPdfMuted = PdfColor.fromInt(0xFF505050);
