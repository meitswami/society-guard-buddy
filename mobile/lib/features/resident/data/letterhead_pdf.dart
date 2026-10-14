import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/export/export_kit.dart';
import '../../../core/supabase/db.dart';

/// Society letterhead PDFs — compact port of web `src/lib/letterheadReportEngine.ts` +
/// `src/lib/pdfLetterhead.ts` (US Letter, 0.75" margins, auto header band / uploaded
/// full-page letterhead / pre-printed stationery / plain, `n/N` page footers).

const double kPdfMarginMm = 19.05;
const String kLetterheadNotConfiguredWarning = 'Official society letterhead has not been configured.';

enum LetterheadMode { auto, image, stationery }

enum ReportPdfMode { letterhead, plain }

const _headerRule = PdfColor.fromInt(0xFF374178);
const _footerRule = PdfColor.fromInt(0xFF787D87);
const _nameColor = PdfColor.fromInt(0xFF111827);
const _metaColor = PdfColor.fromInt(0xFF4B5563);

class SocietyLetterhead {
  const SocietyLetterhead({
    required this.name,
    this.societyId,
    this.mode = LetterheadMode.auto,
    this.topMm = 40,
    this.bottomMm = 18,
    this.leftMm = kPdfMarginMm,
    this.rightMm = kPdfMarginMm,
    this.defaultReportFormat = ReportPdfMode.letterhead,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.contactPhone,
    this.contactEmail,
    this.hasAssetReference = false,
    this.logoBytes,
    this.letterheadBytes,
  });

  final String name;
  final String? societyId;
  final LetterheadMode mode;
  final double topMm;
  final double bottomMm;
  final double leftMm;
  final double rightMm;
  final ReportPdfMode defaultReportFormat;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? contactPhone;
  final String? contactEmail;

  /// `letterhead_url` or `letterhead_storage_path` is set.
  final bool hasAssetReference;
  final Uint8List? logoBytes;
  final Uint8List? letterheadBytes;

  /// Web `letterheadAddressLine`.
  String get addressLine => [
        address,
        [city, state].where((p) => (p ?? '').trim().isNotEmpty).join(', '),
        pincode
      ].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');

  /// Web `letterheadContactLine`.
  String get contactLine =>
      [contactPhone, contactEmail].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');

  double get _top => topMm > 0 ? topMm : 40;
  double get _bottom => bottomMm > 0 ? (bottomMm < 16 ? 16 : bottomMm) : 18;
  double get _left => leftMm > 0 ? leftMm : kPdfMarginMm;
  double get _right => rightMm > 0 ? rightMm : kPdfMarginMm;
}

class LetterheadContext {
  const LetterheadContext({required this.letterhead, required this.mode, this.warning});

  final SocietyLetterhead? letterhead;
  final ReportPdfMode mode;
  final String? warning;

  /// Plain document without society stationery (tests / missing society).
  static const plain = LetterheadContext(letterhead: null, mode: ReportPdfMode.plain);
}

const _fullSelect =
    'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
const _fallbackSelect =
    'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';

double _num(Object? v, double fallback) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? fallback;
}

Future<Uint8List?> _download(String? url) async {
  final u = (url ?? '').trim();
  if (u.isEmpty || u.toLowerCase().contains('.pdf')) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(Uri.parse(u));
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final type = res.headers.contentType?.mimeType ?? '';
    if (type == 'application/pdf') return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 15))) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Web `fetchSocietyLetterhead` (current society only) with logo / stationery preloaded.
Future<SocietyLetterhead?> fetchSocietyLetterhead(String societyId) async {
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
  if ((row['id'] ?? '').toString() != societyId) return null;
  String? s(String k) {
    final v = row![k]?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  var letterheadUrl = s('letterhead_url');
  final storagePath = s('letterhead_storage_path');
  if (letterheadUrl == null && storagePath != null) {
    try {
      letterheadUrl = await db.storage.from('society-documents').createSignedUrl(storagePath, 3600);
    } catch (_) {}
  }
  final rawMode = s('letterhead_mode');
  final hasAsset = letterheadUrl != null || storagePath != null;
  final mode = switch (rawMode) {
    'image' => LetterheadMode.image,
    'stationery' => LetterheadMode.stationery,
    'auto' => LetterheadMode.auto,
    _ => hasAsset ? LetterheadMode.image : LetterheadMode.auto,
  };
  final results = await Future.wait([_download(s('logo_url')), _download(letterheadUrl)]);
  return SocietyLetterhead(
    name: s('name') ?? 'Society',
    societyId: societyId,
    mode: mode,
    topMm: _num(row['letterhead_top_mm'], 40),
    bottomMm: _num(row['letterhead_bottom_mm'], 18),
    leftMm: _num(row['letterhead_left_mm'], kPdfMarginMm),
    rightMm: _num(row['letterhead_right_mm'], kPdfMarginMm),
    defaultReportFormat: s('default_report_format') == 'plain' ? ReportPdfMode.plain : ReportPdfMode.letterhead,
    address: s('address'),
    city: s('city'),
    state: s('state'),
    pincode: s('pincode'),
    contactPhone: s('contact_phone'),
    contactEmail: s('contact_email'),
    hasAssetReference: hasAsset,
    logoBytes: results[0],
    letterheadBytes: results[1],
  );
}

/// Web `resolveLetterheadReportContext` (falls back to plain + warning without letterhead).
Future<LetterheadContext> resolveLetterheadReportContext(String societyId, {ReportPdfMode? preferred}) async {
  final lh = await fetchSocietyLetterhead(societyId);
  if (lh == null) {
    return const LetterheadContext(
        letterhead: null, mode: ReportPdfMode.plain, warning: kLetterheadNotConfiguredWarning);
  }
  final requested = preferred ?? lh.defaultReportFormat;
  if (requested == ReportPdfMode.letterhead && !lh.hasAssetReference && lh.mode != LetterheadMode.stationery) {
    return LetterheadContext(letterhead: lh, mode: ReportPdfMode.plain, warning: kLetterheadNotConfiguredWarning);
  }
  return LetterheadContext(letterhead: lh, mode: requested);
}

double _mm(double v) => v * PdfPageFormat.mm;

/// Builds a Letter-size document on society stationery around [build].
Future<Uint8List> buildLetterheadPdf({
  required LetterheadContext ctx,
  required String title,
  required List<pw.Widget> Function() build,
}) async {
  final doc = await ExportKit.newPdf(title: title);
  final lh = ctx.letterhead;
  final plain = ctx.mode == ReportPdfMode.plain || lh == null;
  final format = PdfPageFormat.letter;

  pw.Widget pageNo(pw.Context c) =>
      pw.Text('${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _metaColor));

  if (plain) {
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: format, margin: pw.EdgeInsets.all(_mm(kPdfMarginMm))),
      footer: (c) => pw.Align(alignment: pw.Alignment.centerRight, child: pageNo(c)),
      build: (_) => build(),
    ));
    return doc.save();
  }

  final left = _mm(lh._left), right = _mm(lh._right);
  final imageBackground = lh.mode == LetterheadMode.image && lh.letterheadBytes != null;
  pw.MemoryImage? bg;
  if (imageBackground) {
    try {
      bg = pw.MemoryImage(lh.letterheadBytes!);
    } catch (_) {
      bg = null;
    }
  }

  if (lh.mode == LetterheadMode.stationery || bg != null) {
    final top = _mm(lh._top < lh._left ? lh._left : lh._top);
    final bottom = _mm(lh._bottom < 14 ? 14 : lh._bottom);
    final bgImage = bg;
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        margin: pw.EdgeInsets.fromLTRB(left, top, right, _mm(6)),
        buildBackground: bgImage == null
            ? null
            : (_) => pw.FullPage(ignoreMargins: true, child: pw.Image(bgImage, fit: pw.BoxFit.fill)),
      ),
      footer: (c) => pw.Container(
        height: bottom - _mm(6),
        alignment: pw.Alignment.topRight,
        padding: pw.EdgeInsets.only(top: _mm(3)),
        child: pageNo(c),
      ),
      build: (_) => build(),
    ));
    return doc.save();
  }

  // Auto digital band (logo · name · address · contact · indigo rule).
  pw.MemoryImage? logo;
  if (lh.logoBytes != null) {
    try {
      logo = pw.MemoryImage(lh.logoBytes!);
    } catch (_) {
      logo = null;
    }
  }
  final address = lh.addressLine, contact = lh.contactLine;
  final logoImage = logo;
  doc.addPage(pw.MultiPage(
    pageTheme:
        pw.PageTheme(pageFormat: format, margin: pw.EdgeInsets.fromLTRB(left, _mm(kPdfMarginMm - 4), right, _mm(8))),
    header: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoImage != null) ...[
              pw.SizedBox(width: _mm(14), height: _mm(14), child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: _mm(3.5)),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(lh.name,
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _nameColor)),
                  if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(fontSize: 8, color: _metaColor)),
                  if (contact.isNotEmpty) pw.Text(contact, style: const pw.TextStyle(fontSize: 8, color: _metaColor)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: _mm(2.5)),
        pw.Container(height: 0.85 * 2.83, color: _headerRule),
        pw.SizedBox(height: _mm(6)),
      ],
    ),
    footer: (c) => pw.Column(
      children: [
        pw.Container(height: 0.7 * 2.83, color: _footerRule),
        pw.SizedBox(height: _mm(2)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(lh.name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _nameColor)),
            pw.Text('${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: _metaColor)),
          ],
        ),
      ],
    ),
    build: (_) => build(),
  ));
  return doc.save();
}

/// Web `drawReportHeader`: bold title + only the non-empty meta rows.
pw.Widget reportHeaderBlock(
    {required String title, String? reportNo, String? date, String? society, String? period, String? generatedBy}) {
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
      pw.SizedBox(height: 6),
      for (final r in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(children: [
            pw.SizedBox(
              width: _mm(28),
              child: pw.Text('${r.$1}:',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _metaColor)),
            ),
            pw.Expanded(child: pw.Text(r.$2, style: const pw.TextStyle(fontSize: 9, color: _metaColor))),
          ]),
        ),
      pw.SizedBox(height: 10),
    ],
  );
}

/// Web `drawField`: `Label:` + wrapped value.
pw.Widget reportField(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: _mm(38),
            child:
                pw.Text('$label:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _metaColor)),
          ),
          pw.Expanded(
              child: pw.Text(value.isEmpty ? '—' : value, style: const pw.TextStyle(fontSize: 9, color: _nameColor))),
        ],
      ),
    );

/// Web `drawSignatureSection` (Prepared By · Verified By · Authorized Signatory).
pw.Widget signatureSection() {
  pw.Widget block(String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _nameColor)),
          pw.SizedBox(height: _mm(10)),
          pw.Container(width: _mm(48), height: 0.6, color: _footerRule),
        ],
      );
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.SizedBox(height: _mm(8)),
      pw.Row(children: [pw.Expanded(child: block('Prepared By')), pw.Expanded(child: block('Verified By'))]),
      pw.SizedBox(height: _mm(10)),
      pw.Align(alignment: pw.Alignment.centerRight, child: block('Authorized Signatory')),
    ],
  );
}
