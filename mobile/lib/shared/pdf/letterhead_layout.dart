import 'pdf_page.dart';
import 'society_letterhead.dart';

/// Safe content area for reports on letterhead stationery (all values in mm).
/// Content must never overlap the society header, date area, or footer.
/// Port of `LetterheadLayout` / `measureLetterheadLayout` (`src/lib/pdfLetterhead.ts`).
class LetterheadLayout {
  const LetterheadLayout({
    required this.headerHeight,
    required this.contentTop,
    required this.contentBottom,
    required this.leftMargin,
    required this.rightMargin,
    required this.footerHeight,
    required this.pageW,
    required this.pageH,
  });

  final double headerHeight;
  final double contentTop;
  final double contentBottom;
  final double leftMargin;
  final double rightMargin;
  final double footerHeight;
  final double pageW;
  final double pageH;

  /// @deprecated web alias of [leftMargin].
  double get margin => leftMargin;

  double get contentWidth {
    final w = pageW - leftMargin - rightMargin;
    return w < 10 ? 10 : w;
  }

  double get contentHeight => contentBottom - contentTop;

  /// Bottom reserve (page height below the content band).
  double get bottomReserve => pageH - contentBottom;

  @override
  String toString() =>
      'LetterheadLayout(top: $contentTop, bottom: $contentBottom, left: $leftMargin, right: $rightMargin, page: ${pageW}x$pageH)';
}

/// Measures the width (mm) of [text] at [fontSizePt].
typedef PdfTextMeasure = double Function(String text, double fontSizePt);

/// Average-glyph estimate (Helvetica / Noto Sans ≈ 0.55 em) used when no font metrics are available.
double estimateTextWidthMm(String text, double fontSizePt) =>
    text.length * 0.55 * fontPtToMm(fontSizePt);

/// jsPDF `splitTextToSize`: greedy word wrap to [maxWidthMm] (long words are broken).
List<String> splitTextToSize(String text, double maxWidthMm, double fontSizePt,
    {PdfTextMeasure? measure}) {
  final m = measure ?? estimateTextWidthMm;
  final out = <String>[];
  for (final paragraph in text.split('\n')) {
    final words = paragraph.split(RegExp(r' +'));
    var line = '';
    for (final word in words) {
      final candidate = line.isEmpty ? word : '$line $word';
      if (m(candidate, fontSizePt) <= maxWidthMm) {
        line = candidate;
        continue;
      }
      if (line.isNotEmpty) out.add(line);
      // Break words longer than the line.
      var rest = word;
      while (m(rest, fontSizePt) > maxWidthMm && rest.length > 1) {
        var cut = rest.length - 1;
        while (cut > 1 && m(rest.substring(0, cut), fontSizePt) > maxWidthMm) {
          cut--;
        }
        out.add(rest.substring(0, cut));
        rest = rest.substring(cut);
      }
      line = rest;
    }
    out.add(line);
  }
  return out;
}

double _topReserve(SocietyLetterhead info) {
  final n = info.letterheadTopMm;
  return (n != null && n.isFinite && n > 0) ? n : 40;
}

double _bottomReserve(SocietyLetterhead info) {
  final n = info.letterheadBottomMm;
  return (n != null && n.isFinite && n > 0) ? (n < 16 ? 16 : n) : 18;
}

double _leftReserve(SocietyLetterhead info) {
  final n = info.letterheadLeftMm;
  return (n != null && n.isFinite && n > 0) ? n : kPdfMarginMm;
}

double _rightReserve(SocietyLetterhead info) {
  final n = info.letterheadRightMm;
  return (n != null && n.isFinite && n > 0) ? n : kPdfMarginMm;
}

double _max(Iterable<double> v) => v.reduce((a, b) => a > b ? a : b);

/// Logo square size in the auto header band (mm).
const double kLetterheadLogoSizeMm = 14;

/// Compute the letterhead content band without drawing.
///
/// [info] may be a [SocietyLetterhead], a society name, or null.
LetterheadLayout measureLetterheadLayout(
  Object? info, {
  ReportPdfMode mode = ReportPdfMode.letterhead,
  bool landscape = false,
  PdfTextMeasure? measure,
}) {
  final lh = SocietyLetterhead.coerce(info);
  final page = letterSizeMm(landscape: landscape);
  final pageW = page.w, pageH = page.h;
  final left = _leftReserve(lh);
  final right = _rightReserve(lh);

  LetterheadLayout build(double headerHeight, double footerHeight,
          double contentTop, double contentBottom) =>
      LetterheadLayout(
        headerHeight: headerHeight,
        footerHeight: footerHeight,
        contentTop: contentTop,
        contentBottom: contentBottom,
        leftMargin: left,
        rightMargin: right,
        pageW: pageW,
        pageH: pageH,
      );

  if (mode == ReportPdfMode.plain) {
    const top = kPdfMarginMm;
    const bottom = kPdfMarginMm > 14 ? kPdfMarginMm : 14.0;
    return build(top, bottom, top, pageH - bottom);
  }

  final top = _max([_topReserve(lh), left]);
  final bottom = _max([_bottomReserve(lh), 14]);
  final contentBottom = pageH - bottom;
  final brandMode = lh.brandMode;

  if (brandMode == LetterheadMode.stationery ||
      (brandMode == LetterheadMode.image && lh.hasOfficialAsset)) {
    // Full-page stationery / uploaded letterhead — safe content inside configured reserves.
    return build(top, bottom, top, contentBottom);
  }

  // Auto: estimate rule position including wrapped address/contact.
  final hasLogo = lh.hasLogo;
  final textX = hasLogo ? left + kLetterheadLogoSizeMm + 3.5 : left;
  final maxTextW = _max([40, pageW - textX - right]);
  var y = left + 9.5;
  final addr = letterheadAddressLine(lh);
  if (addr.isNotEmpty) {
    final lines = splitTextToSize(addr, maxTextW, 8, measure: measure);
    y += _max([3.6, lines.length * 3.4]);
  }
  final contact = letterheadContactLine(lh);
  if (contact.isNotEmpty) {
    final lines = splitTextToSize(contact, maxTextW, 8, measure: measure);
    y += _max([3.6, lines.length * 3.4]);
  }
  final ruleY = _max(
      [y + 2.5, left + (hasLogo ? kLetterheadLogoSizeMm : 6) + 2, top - 8]);
  final contentTop = _max([ruleY + 6, top, left]);
  return build(contentTop, bottom, contentTop, contentBottom);
}

/// Where the auto-band header rule sits (mm) — used when drawing the band.
double autoHeaderRuleY(SocietyLetterhead lh, LetterheadLayout layout,
    {PdfTextMeasure? measure}) {
  final left = layout.leftMargin;
  final hasLogo = lh.logoBytes != null && lh.logoBytes!.isNotEmpty;
  final textX = hasLogo ? left + kLetterheadLogoSizeMm + 3.5 : left;
  final maxTextW = _max([40, layout.pageW - textX - layout.rightMargin]);
  var y = left + 9.5;
  final addr = letterheadAddressLine(lh);
  if (addr.isNotEmpty) {
    final lines = splitTextToSize(addr, maxTextW, 8, measure: measure);
    y += _max([3.6, lines.length * 3.4]);
  }
  final contact = letterheadContactLine(lh);
  if (contact.isNotEmpty) {
    final lines = splitTextToSize(contact, maxTextW, 8, measure: measure);
    y += _max([3.6, lines.length * 3.4]);
  }
  final ruleY =
      _max([y + 2.5, left + (hasLogo ? kLetterheadLogoSizeMm : 6) + 2]);
  final maxRule = layout.contentTop - 3;
  return ruleY < maxRule ? ruleY : maxRule;
}
