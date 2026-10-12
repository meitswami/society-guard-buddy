import 'package:pdf/pdf.dart';

/// Port of `src/lib/pdfPage.ts` — every society PDF is US Letter with moderate
/// 0.75" (19.05 mm) margins. Layout maths is done in millimetres like jsPDF on
/// the web and converted to PDF points only when building pages.

/// Moderate margin in millimetres (0.75 inch).
const double kPdfMarginMm = 19.05;

/// US Letter in millimetres (jsPDF `format: 'letter'`, `unit: 'mm'`).
const double kLetterWidthMm = 215.9;
const double kLetterHeightMm = 279.4;

/// Millimetres → PDF points.
double mmToPt(double mm) => mm * PdfPageFormat.mm;

/// Points → millimetres.
double ptToMm(double pt) => pt / PdfPageFormat.mm;

/// Font size in points → line metrics in millimetres (jsPDF uses pt for fonts).
double fontPtToMm(double pt) => pt * 25.4 / 72;

/// Page size (mm) for an orientation.
({double w, double h}) letterSizeMm({bool landscape = false}) =>
    landscape ? (w: kLetterHeightMm, h: kLetterWidthMm) : (w: kLetterWidthMm, h: kLetterHeightMm);

/// Letter page format with zero built-in margins (margins come from the letterhead layout).
PdfPageFormat societyPdfFormat({bool landscape = false}) {
  final s = letterSizeMm(landscape: landscape);
  return PdfPageFormat(mmToPt(s.w), mmToPt(s.h), marginAll: 0);
}
