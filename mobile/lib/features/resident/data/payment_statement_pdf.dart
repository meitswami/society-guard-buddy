import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/format/formatters.dart';
import 'letterhead_pdf.dart';
import 'maintenance_receipt_pdf.dart';
import 'payment_rules.dart';
import 'resident_models.dart';

/// Flat maintenance payment statement for a period, on society letterhead — mobile
/// counterpart of the web report-detail PDF (`buildReportDetailPdfBlob`: rows, monthly
/// totals and transaction total). Rejected submissions are left out; totals count verified
/// payments, pending ones are listed separately.
Future<GeneratedPdf> buildPaymentStatementPdf({
  required String societyId,
  required String flatNumber,
  required String residentName,
  required String periodLabel,
  required List<MaintenancePaymentRow> payments,
  required Map<String, String> chargeTitles,
  String? generatedBy,
  LetterheadContext? context,
}) async {
  final ctx = context ?? await resolveLetterheadReportContext(societyId);
  final rows = payments.where((p) => p.paymentStatus != 'rejected').toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final verified = rows.where((p) => p.isVerified).toList();
  final pending = rows.where((p) => p.paymentStatus == 'pending').toList();
  final amountRows = [for (final p in verified) AmountRow(amount: p.amount, dateIso: p.dueDate)];
  final monthly = monthlyAmountTotals(amountRows);
  final total = sumAmountRows(amountRows);
  final pendingTotal = pending.fold<double>(0, (s, p) => s + p.amount);
  const title = 'Maintenance payment statement';

  final head = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);
  const cell = pw.TextStyle(fontSize: 8.5);
  final bytes = await buildLetterheadPdf(
    ctx: ctx,
    title: title,
    build: () => [
      reportHeaderBlock(
        title: title,
        date: Fmt.date(DateTime.now()),
        society: ctx.letterhead?.name,
        period: periodLabel,
        generatedBy: generatedBy,
      ),
      pw.Text('Flat $flatNumber · $residentName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.Text('Generated: ${Fmt.dateTimeFull(DateTime.now())}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
      pw.SizedBox(height: 6),
      pw.Text('Total (verified): ${receiptMoney(total)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      if (pending.isNotEmpty)
        pw.Text('Awaiting verification: ${receiptMoney(pendingTotal)} (${pending.length})', style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 8),
      if (rows.isEmpty)
        pw.Text('No payments in this period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
      else
        pw.TableHelper.fromTextArray(
          headers: const ['Billing date', 'Charge', 'Receipt', 'Method', 'Status', 'Amount'],
          headerStyle: head,
          cellStyle: cell,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignments: {5: pw.Alignment.centerRight},
          data: [
            for (final p in rows)
              [
                Fmt.isoToDisplay(p.dueDate),
                chargeTitles[p.chargeId] ?? 'Maintenance',
                p.receiptNumber ?? '—',
                p.paymentMethod,
                p.paymentStatus,
                receiptMoney(p.amount),
              ],
          ],
        ),
      if (monthly.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text('Monthly totals', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        for (final m in monthly) pw.Text('${m.label} (${m.count}): ${receiptMoney(m.total)}', style: cell),
      ],
      if (verified.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('Transaction total: ${receiptMoney(total)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    ],
  );
  return GeneratedPdf(
    bytes: bytes,
    filename: reportDetailPdfFilename('$title flat $flatNumber', DateTime.now()),
    warning: ctx.warning,
  );
}
