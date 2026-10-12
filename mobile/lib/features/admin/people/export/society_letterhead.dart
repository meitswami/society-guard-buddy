import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/supabase/db.dart';
import '../../../../utils/member_photo.dart';

/// Web `LETTERHEAD_NOT_CONFIGURED_WARNING`.
const kLetterheadNotConfiguredWarning = 'Official society letterhead has not been configured.';

/// `PDF_MARGIN_MM` of the web (`src/lib/pdfPage.ts`).
const double kPdfMarginMm = 19.05;

/// Society branding used for report letterheads — port of the parts of web
/// `src/lib/pdfLetterhead.ts` / `letterheadReportEngine.ts` the residents PDF needs.
class SocietyLetterhead {
  SocietyLetterhead({
    required this.name,
    this.letterheadMode = 'auto',
    this.defaultReportFormat = 'letterhead',
    this.topMm = 40,
    this.bottomMm = 18,
    this.leftMm = kPdfMarginMm,
    this.rightMm = kPdfMarginMm,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.contactPhone,
    this.contactEmail,
    this.hasOfficialAsset = false,
    this.logo,
    this.letterheadImage,
  });

  final String name;
  final String letterheadMode;
  final String defaultReportFormat;
  final double topMm;
  final double bottomMm;
  final double leftMm;
  final double rightMm;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? contactPhone;
  final String? contactEmail;
  final bool hasOfficialAsset;
  Uint8List? logo;
  Uint8List? letterheadImage;

  /// Web `letterheadAddressLine`.
  String get addressLine {
    final cityState = [city, state].where((p) => (p ?? '').trim().isNotEmpty).join(', ');
    return [address, cityState, pincode].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');
  }

  /// Web `letterheadContactLine`.
  String get contactLine => [contactPhone, contactEmail].map((p) => (p ?? '').trim()).where((p) => p.isNotEmpty).join(' · ');

  /// Web `modeOf`.
  String get brandMode {
    if (letterheadMode == 'image' || letterheadMode == 'stationery' || letterheadMode == 'auto') return letterheadMode;
    return hasOfficialAsset ? 'image' : 'auto';
  }
}

/// Resolved letterhead + mode (web `resolveLetterheadReportContext`).
class LetterheadContext {
  const LetterheadContext({required this.letterhead, required this.plain, this.warning});

  final SocietyLetterhead letterhead;

  /// `mode === 'plain'`.
  final bool plain;
  final String? warning;
}

Future<Uint8List?> _fetchImage(String? url) async {
  final u = url?.trim() ?? '';
  if (u.isEmpty) return null;
  if (u.startsWith('data:')) return dataUrlBytes(u);
  if (u.toLowerCase().contains('.pdf')) return null; // PDF stationery cannot be embedded as an image
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(u));
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final type = res.headers.contentType?.mimeType ?? '';
      if (type.contains('pdf')) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  } catch (_) {
    return null;
  }
}

double _num(Object? v, double fallback, {double min = 0}) {
  final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  if (n == null || !n.isFinite || n <= 0) return fallback;
  return n < min ? min : n;
}

/// Fetch the society letterhead and decide letterhead vs plain mode.
Future<LetterheadContext> resolveLetterheadContext(String societyId, {String fallbackName = 'Society'}) async {
  Map<String, dynamic>? row;
  if (dbReady) {
    const full =
        'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
    const fallback =
        'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';
    try {
      row = await db.from('societies').select(full).eq('id', societyId).maybeSingle();
    } catch (_) {
      try {
        row = await db.from('societies').select(fallback).eq('id', societyId).maybeSingle();
      } catch (_) {
        row = null;
      }
    }
  }
  if (row == null) {
    return LetterheadContext(
      letterhead: SocietyLetterhead(name: fallbackName),
      plain: true,
      warning: kLetterheadNotConfiguredWarning,
    );
  }
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
  final lh = SocietyLetterhead(
    name: s('name') ?? fallbackName,
    letterheadMode: s('letterhead_mode') ?? 'auto',
    defaultReportFormat: s('default_report_format') == 'plain' ? 'plain' : 'letterhead',
    topMm: _num(row['letterhead_top_mm'], 40),
    bottomMm: _num(row['letterhead_bottom_mm'], 18, min: 16),
    leftMm: _num(row['letterhead_left_mm'], kPdfMarginMm),
    rightMm: _num(row['letterhead_right_mm'], kPdfMarginMm),
    address: s('address'),
    city: s('city'),
    state: s('state'),
    pincode: s('pincode'),
    contactPhone: s('contact_phone'),
    contactEmail: s('contact_email'),
    hasOfficialAsset: s('letterhead_url') != null || storagePath != null,
  );
  final assets = await Future.wait([_fetchImage(s('logo_url')), _fetchImage(letterheadUrl)]);
  lh.logo = assets[0];
  lh.letterheadImage = assets[1];

  final requested = lh.defaultReportFormat;
  if (requested == 'letterhead' && !lh.hasOfficialAsset && lh.letterheadMode != 'stationery') {
    return LetterheadContext(letterhead: lh, plain: true, warning: kLetterheadNotConfiguredWarning);
  }
  return LetterheadContext(letterhead: lh, plain: requested == 'plain');
}

const _headerRule = PdfColor.fromInt(0xFF374178); // rgb(55, 65, 120)
const _footerRule = PdfColor.fromInt(0xFF787D87); // rgb(120, 125, 135)
const _nameColor = PdfColor.fromInt(0xFF111827);
const _metaColor = PdfColor.fromInt(0xFF4B5563);

/// Page theme (margins + optional full-page letterhead background) for [ctx].
pw.PageTheme letterheadPageTheme(LetterheadContext ctx, {pw.ThemeData? theme}) {
  final lh = ctx.letterhead;
  const mm = PdfPageFormat.mm;
  if (ctx.plain) {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(kPdfMarginMm * mm, kPdfMarginMm * mm, kPdfMarginMm * mm, 8 * mm),
    );
  }
  final fullPage = lh.brandMode == 'image' && lh.letterheadImage != null;
  final reserved = lh.brandMode == 'stationery' || fullPage;
  final left = lh.leftMm * mm, right = lh.rightMm * mm;
  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: reserved
        ? pw.EdgeInsets.fromLTRB(left, lh.topMm * mm, right, 6 * mm)
        : pw.EdgeInsets.fromLTRB(left, left - 2 * mm, right, 6 * mm),
    buildBackground: fullPage
        ? (_) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(pw.MemoryImage(lh.letterheadImage!), fit: pw.BoxFit.fill),
            )
        : null,
  );
}

/// Auto-mode header band (logo · bold society name · address · contact · indigo rule).
pw.Widget? letterheadHeader(LetterheadContext ctx) {
  final lh = ctx.letterhead;
  if (ctx.plain) return null;
  final fullPage = lh.brandMode == 'image' && lh.letterheadImage != null;
  if (lh.brandMode == 'stationery' || fullPage) return null;
  const mm = PdfPageFormat.mm;
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 6 * mm),
    padding: const pw.EdgeInsets.only(bottom: 2.5 * mm),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _headerRule, width: 2.4))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (lh.logo != null) ...[
          pw.SizedBox(width: 14 * mm, height: 14 * mm, child: pw.Image(pw.MemoryImage(lh.logo!), fit: pw.BoxFit.contain)),
          pw.SizedBox(width: 3.5 * mm),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(lh.name, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _nameColor)),
              if (lh.addressLine.isNotEmpty) pw.Text(lh.addressLine, style: const pw.TextStyle(fontSize: 8, color: _metaColor)),
              if (lh.contactLine.isNotEmpty) pw.Text(lh.contactLine, style: const pw.TextStyle(fontSize: 8, color: _metaColor)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Footer: plain → `n/N` only; stationery / full-page image → page numbers in the reserve;
/// auto → charcoal rule + society name + `n/N`.
pw.Widget letterheadFooter(LetterheadContext ctx, pw.Context page) {
  final lh = ctx.letterhead;
  final numbers = pw.Text('${page.pageNumber}/${page.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _metaColor));
  final fullPage = lh.brandMode == 'image' && lh.letterheadImage != null;
  if (ctx.plain || lh.brandMode == 'stationery' || fullPage) {
    return pw.Align(alignment: pw.Alignment.centerRight, child: numbers);
  }
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 4),
    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _footerRule, width: 2))),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(lh.name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _nameColor)),
        pw.Text('${page.pageNumber}/${page.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: _metaColor)),
      ],
    ),
  );
}
