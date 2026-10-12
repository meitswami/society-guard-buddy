import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/supabase/db.dart';

/// Port of `src/lib/pdfLetterhead.ts` + `resolveLetterheadReportContext` (letterheadReportEngine.ts):
/// official society letterhead (uploaded image / stationery / auto digital band) or plain PDFs.
/// (Candidate for the shared export kit — every official report uses it on the web.)

const double pdfMarginMm = 19.05;

const _fullSelect =
    'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
const _fallbackSelect =
    'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';

const _headerRule = PdfColor.fromInt(0xFF374178);
const _footerRule = PdfColor.fromInt(0xFF787D87);
const _nameColor = PdfColor.fromInt(0xFF111827);
const _metaColor = PdfColor.fromInt(0xFF4B5563);

class SocietyLetterhead {
  SocietyLetterhead({
    required this.name,
    this.logoUrl,
    this.letterheadUrl,
    this.letterheadStoragePath,
    this.letterheadMode = 'auto',
    this.topMm,
    this.bottomMm,
    this.leftMm,
    this.rightMm,
    this.defaultReportFormat = 'letterhead',
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.contactPhone,
    this.contactEmail,
  });

  final String name;
  final String? logoUrl;
  String? letterheadUrl;
  final String? letterheadStoragePath;
  final String letterheadMode;
  final double? topMm, bottomMm, leftMm, rightMm;
  final String defaultReportFormat;
  final String? address, city, state, pincode, contactPhone, contactEmail;
  pw.ImageProvider? logo;
  pw.ImageProvider? letterheadImage;

  factory SocietyLetterhead.nameOnly(String name) =>
      SocietyLetterhead(name: name.trim().isEmpty ? 'Society' : name.trim());

  bool get hasOfficialAsset =>
      letterheadImage != null ||
      (letterheadUrl ?? '').isNotEmpty ||
      (letterheadStoragePath ?? '').isNotEmpty;

  /// `modeOf`.
  String get brandMode {
    if (letterheadMode == 'image' ||
        letterheadMode == 'stationery' ||
        letterheadMode == 'auto') return letterheadMode;
    return hasOfficialAsset ? 'image' : 'auto';
  }

  double get _top => (topMm != null && topMm! > 0) ? topMm! : 40;
  double get _bottom => (bottomMm != null && bottomMm! > 0)
      ? (bottomMm! < 16 ? 16 : bottomMm!)
      : 18;
  double get left => (leftMm != null && leftMm! > 0) ? leftMm! : pdfMarginMm;
  double get right =>
      (rightMm != null && rightMm! > 0) ? rightMm! : pdfMarginMm;

  String get addressLine {
    final cityState =
        [city, state].where((p) => (p ?? '').trim().isNotEmpty).join(', ');
    return [address, cityState, pincode]
        .map((p) => (p ?? '').trim())
        .where((p) => p.isNotEmpty)
        .join(' · ');
  }

  String get contactLine => [contactPhone, contactEmail]
      .map((p) => (p ?? '').trim())
      .where((p) => p.isNotEmpty)
      .join(' · ');
}

double? _numOrNull(Object? v) =>
    v == null ? null : double.tryParse(v.toString());

Future<Uint8List?> _download(String? url) async {
  if (url == null || url.trim().isEmpty || url.toLowerCase().contains('.pdf'))
    return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req =
        await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 8));
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
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

pw.ImageProvider? _image(Uint8List? bytes) {
  if (bytes == null || bytes.length < 4) return null;
  final png = bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  final jpg = bytes[0] == 0xFF && bytes[1] == 0xD8;
  if (!png && !jpg) return null;
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

/// Society branding for report letterheads (current society only); `null` when the row cannot be read.
Future<SocietyLetterhead?> fetchSocietyLetterhead(String? societyId) async {
  if (societyId == null || societyId.isEmpty || !dbReady) return null;
  Map<String, dynamic>? data;
  try {
    data = await db
        .from('societies')
        .select(_fullSelect)
        .eq('id', societyId)
        .maybeSingle();
  } catch (_) {
    try {
      data = await db
          .from('societies')
          .select(_fallbackSelect)
          .eq('id', societyId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
  if (data == null) return null;
  if (data['id'] != null && data['id'].toString() != societyId) return null;
  final lh = SocietyLetterhead(
    name: (data['name'] ?? 'Society').toString(),
    logoUrl: data['logo_url']?.toString(),
    letterheadUrl: data['letterhead_url']?.toString(),
    letterheadStoragePath: data['letterhead_storage_path']?.toString(),
    letterheadMode: (data['letterhead_mode'] ?? 'auto').toString(),
    topMm: _numOrNull(data['letterhead_top_mm']) ?? 40,
    bottomMm: _numOrNull(data['letterhead_bottom_mm']) ?? 18,
    leftMm: _numOrNull(data['letterhead_left_mm']) ?? pdfMarginMm,
    rightMm: _numOrNull(data['letterhead_right_mm']) ?? pdfMarginMm,
    defaultReportFormat: data['default_report_format']?.toString() == 'plain'
        ? 'plain'
        : 'letterhead',
    address: data['address']?.toString(),
    city: data['city']?.toString(),
    state: data['state']?.toString(),
    pincode: data['pincode']?.toString(),
    contactPhone: data['contact_phone']?.toString(),
    contactEmail: data['contact_email']?.toString(),
  );
  var url = lh.letterheadUrl;
  if ((url ?? '').isEmpty && (lh.letterheadStoragePath ?? '').isNotEmpty) {
    try {
      url = await db.storage
          .from('society-documents')
          .createSignedUrl(lh.letterheadStoragePath!, 3600);
      lh.letterheadUrl = url;
    } catch (_) {}
  }
  final results = await Future.wait([_download(lh.logoUrl), _download(url)]);
  lh.logo = _image(results[0]);
  lh.letterheadImage = _image(results[1]);
  return lh;
}

class LetterheadContext {
  const LetterheadContext({required this.letterhead, required this.mode});

  final SocietyLetterhead? letterhead;

  /// `letterhead` | `plain`
  final String mode;
}

Future<LetterheadContext?> resolveLetterheadReportContext(
    String? societyId) async {
  if (societyId == null || societyId.isEmpty) return null;
  final lh = await fetchSocietyLetterhead(societyId);
  if (lh == null)
    return const LetterheadContext(letterhead: null, mode: 'plain');
  final requested = lh.defaultReportFormat;
  if (requested == 'letterhead' &&
      !lh.hasOfficialAsset &&
      lh.letterheadMode != 'stationery') {
    return LetterheadContext(letterhead: lh, mode: 'plain');
  }
  return LetterheadContext(letterhead: lh, mode: requested);
}

const double _mm = PdfPageFormat.mm;

/// Page theme drawing the letterhead band / background and `n/N` page numbers like the web.
pw.PageTheme letterheadPageTheme({
  required SocietyLetterhead lh,
  required String mode,
  required PdfPageFormat format,
  pw.ThemeData? theme,
}) {
  final pageW = format.width / _mm, pageH = format.height / _mm;
  final left = lh.left, right = lh.right;
  final plain = mode == 'plain';
  final brand = lh.brandMode;
  final useImage = !plain && brand == 'image' && lh.letterheadImage != null;
  final stationery = !plain && brand == 'stationery';
  final auto = !plain && !useImage && !stationery;

  double contentTop, contentBottom;
  if (plain) {
    contentTop = pdfMarginMm;
    contentBottom = pageH - pdfMarginMm;
  } else {
    final top = lh._top > left ? lh._top : left;
    final bottom = lh._bottom > 14 ? lh._bottom : 14;
    contentBottom = pageH - bottom;
    if (auto) {
      final hasLogo = lh.logo != null;
      var y = left + 9.5;
      if (lh.addressLine.isNotEmpty) y += 3.6;
      if (lh.contactLine.isNotEmpty) y += 3.6;
      final ruleY = [y + 2.5, left + (hasLogo ? 14 : 6) + 2, top - 8]
          .reduce((a, b) => a > b ? a : b);
      contentTop = [ruleY + 6, top, left].reduce((a, b) => a > b ? a : b);
    } else {
      contentTop = top;
    }
  }

  pw.Widget at(double xMm, double yMm, pw.Widget child) =>
      pw.Positioned(left: xMm * _mm, top: yMm * _mm, child: child);
  pw.Widget rule(double yMm, PdfColor color, double widthMm) => pw.Positioned(
        left: left * _mm,
        top: yMm * _mm,
        child: pw.Container(
            width: (pageW - left - right) * _mm,
            height: widthMm * _mm,
            color: color),
      );
  pw.Widget pageNo(pw.Context ctx, double baselineMm,
          {double size = 8, PdfColor color = _metaColor}) =>
      pw.Positioned(
        right: right * _mm,
        top: (baselineMm - size * 0.3528 * 0.8) * _mm,
        child: pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: size, color: color)),
      );

  return pw.PageTheme(
    pageFormat: format,
    theme: theme,
    margin: pw.EdgeInsets.fromLTRB(left * _mm, contentTop * _mm, right * _mm,
        (pageH - contentBottom) * _mm),
    buildBackground: (ctx) {
      final children = <pw.Widget>[];
      if (plain) {
        children.add(pageNo(ctx, pageH - 8));
      } else if (useImage || stationery) {
        if (useImage) {
          children.add(pw.Positioned.fill(
              child: pw.Image(lh.letterheadImage!, fit: pw.BoxFit.fill)));
        }
        children.add(pageNo(
            ctx,
            (contentBottom + 5.2) < pageH - 6
                ? contentBottom + 5.2
                : pageH - 6));
      } else {
        final margin = left;
        var textX = margin;
        if (lh.logo != null) {
          children.add(at(
              margin,
              margin - 2,
              pw.SizedBox(
                  width: 14 * _mm,
                  height: 14 * _mm,
                  child: pw.Image(lh.logo!, fit: pw.BoxFit.contain))));
          textX = margin + 14 + 3.5;
        }
        final maxW = (pageW - textX - right) * _mm;
        children.add(at(
            textX,
            margin + 4 - 15 * 0.3528 * 0.8,
            pw.SizedBox(
                width: maxW,
                child: pw.Text(lh.name,
                    style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: _nameColor)))));
        var y = margin + 9.5;
        for (final line in [lh.addressLine, lh.contactLine]) {
          if (line.isEmpty) continue;
          children.add(at(
              textX,
              y - 8 * 0.3528 * 0.8,
              pw.SizedBox(
                  width: maxW,
                  child: pw.Text(line,
                      style: const pw.TextStyle(
                          fontSize: 8, color: _metaColor)))));
          y += 3.6;
        }
        final rawRule = [y + 2.5, margin + (lh.logo != null ? 14 : 6) + 2]
            .reduce((a, b) => a > b ? a : b);
        final ruleY = rawRule < contentTop - 3 ? rawRule : contentTop - 3;
        children.add(rule(ruleY, _headerRule, 0.85));
        children.add(rule(contentBottom, _footerRule, 0.7));
        final footerY =
            (contentBottom + 5.2) < pageH - 6 ? contentBottom + 5.2 : pageH - 6;
        children.add(at(
            left,
            footerY - 9 * 0.3528 * 0.8,
            pw.Text(lh.name,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _nameColor))));
        children.add(pageNo(ctx, footerY, size: 9));
      }
      return pw.FullPage(
          ignoreMargins: true, child: pw.Stack(children: children));
    },
  );
}
