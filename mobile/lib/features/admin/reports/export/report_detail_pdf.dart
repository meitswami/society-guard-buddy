import 'dart:typed_data';

import '../../../../shared/pdf/letterhead_report_engine.dart';
import '../logic/js_compat.dart';
import '../logic/report_detail_row.dart';
import '../logic/report_formatters.dart';
import '../logic/statement_amount_totals.dart';

/// Port of `buildReportDetailPdfBlob` / `reportDetailPdfFilename` (`src/lib/sharePdfWhatsApp.ts`).

Future<Uint8List> buildReportDetailPdf({
  String? societyName,
  SocietyLetterhead? letterhead,
  ReportPdfMode pdfMode = ReportPdfMode.letterhead,
  required String title,
  String? subtitle,
  double? totalAmount,
  required List<ReportDetailRow> rows,
}) {
  final pdf = SocietyReportPdf(
    letterhead: letterhead ?? ((societyName ?? '').isEmpty ? 'Society' : societyName),
    mode: pdfMode,
    title: title,
  );
  pdf.add(SocietyPdf.text(title, size: 11, gapAfterMm: 1));
  if (subtitle != null && subtitle.isNotEmpty) {
    pdf.add(SocietyPdf.text(subtitle, size: 9, color: LetterheadColors.grey80, gapAfterMm: 0.5));
  }
  pdf.add(SocietyPdf.text('Generated: ${fmtDateTimeFull(DateTime.now())}', size: 9, color: LetterheadColors.grey80, gapAfterMm: 3));
  if (totalAmount != null) pdf.add(SocietyPdf.text('Total: ${moneyInr(totalAmount)}', size: 10, gapAfterMm: 3));

  final withAmounts = rows.where((r) => r.amount != null).toList();
  final transactionTotal = sumAmountRows(withAmounts.map((r) => r.amount));
  final monthly = monthlyAmountTotals(withAmounts.map((r) => AmountRow(amount: r.amount, dateIso: r.dateIso, date: r.date)));

  for (final row in rows) {
    final label = (row.sublabel ?? '').isNotEmpty ? '${row.label} — ${row.sublabel}' : row.label;
    final meta = [row.date, row.status, row.extra].where((s) => s != null && s.isNotEmpty).join(' · ');
    final amount = row.amount == null
        ? ''
        : (row.amount! < 0 ? '−${moneyInr(row.amount!.abs())}' : moneyInr(row.amount!));
    final line = [label, meta, amount].where((s) => s.isNotEmpty).join(' | ');
    pdf.add(SocietyPdf.text(line, size: 8, gapAfterMm: 1));
  }

  if (monthly.isNotEmpty) {
    pdf.gap(3);
    pdf.add(SocietyPdf.text('Monthly totals', size: 10, gapAfterMm: 1.5));
    for (final m in monthly) {
      pdf.add(SocietyPdf.text('${m.label} (${m.count}): ${moneyInr(m.total)}', size: 8, gapAfterMm: 1));
    }
  }
  if (withAmounts.isNotEmpty) {
    pdf.gap(2);
    pdf.add(SocietyPdf.text('Transaction total: ${moneyInr(transactionTotal)}', size: 9));
  }
  return pdf.save();
}

String reportDetailPdfFilename(String title, [DateTime? now]) {
  var slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  if (slug.length > 48) slug = slug.substring(0, 48);
  final d = (now ?? DateTime.now()).toUtc();
  return '${slug.isEmpty ? 'report-detail' : slug}-${d.year}-${pad2(d.month)}-${pad2(d.day)}.pdf';
}
