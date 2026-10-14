import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/format/formatters.dart';
import 'letterhead_pdf.dart';
import 'payment_rules.dart';
import 'resident_models.dart';

/// Web `MaintenanceReceiptPdfInput`.
class MaintenanceReceiptInput {
  const MaintenanceReceiptInput({
    required this.societyId,
    required this.receiptNumber,
    required this.flatNumber,
    required this.amount,
    required this.paymentMethod,
    this.residentName,
    this.paymentDate,
    this.dueDate,
    this.chargeTitle,
    this.transactionId,
    this.verifiedBy,
    this.verifiedAt,
    this.notes,
    this.generatedBy,
  });

  factory MaintenanceReceiptInput.fromPayment(
    MaintenancePaymentRow p, {
    required String societyId,
    required String fallbackFlat,
    required String fallbackName,
    String? chargeTitle,
    String? generatedBy,
  }) =>
      MaintenanceReceiptInput(
        societyId: societyId,
        receiptNumber: p.receiptNumber ?? '',
        flatNumber: p.flatNumber.isEmpty ? fallbackFlat : p.flatNumber,
        residentName: (p.residentName ?? '').isEmpty ? fallbackName : p.residentName,
        amount: p.amount,
        paymentMethod: p.paymentMethod,
        paymentDate: p.paymentDate,
        dueDate: p.dueDate,
        chargeTitle: chargeTitle,
        transactionId: p.transactionId,
        verifiedBy: p.verifiedBy,
        verifiedAt: p.verifiedAt,
        notes: p.notes,
        generatedBy: generatedBy,
      );

  final String societyId;
  final String receiptNumber;
  final String flatNumber;
  final String? residentName;
  final double amount;
  final String paymentMethod;
  final String? paymentDate;
  final String? dueDate;
  final String? chargeTitle;
  final String? transactionId;
  final String? verifiedBy;
  final String? verifiedAt;
  final String? notes;
  final String? generatedBy;
}

class GeneratedPdf {
  const GeneratedPdf({required this.bytes, required this.filename, this.warning});
  final Uint8List bytes;
  final String filename;
  final String? warning;
}

String _or(String? v) => (v ?? '').trim().isEmpty ? '—' : v!.trim();

/// Official maintenance payment receipt on society letterhead (web `buildMaintenanceReceiptPdf`).
/// Pass [context] to skip the letterhead lookup (tests / previews).
Future<GeneratedPdf> buildMaintenanceReceiptPdf(MaintenanceReceiptInput input, {LetterheadContext? context}) async {
  final ctx = context ?? await resolveLetterheadReportContext(input.societyId, preferred: ReportPdfMode.letterhead);
  final bytes = await buildLetterheadPdf(
    ctx: ctx,
    title: 'Maintenance Receipt',
    build: () => [
      reportHeaderBlock(
        title: 'Maintenance Payment Receipt',
        reportNo: input.receiptNumber,
        date: Fmt.date(DateTime.now()),
        society: ctx.letterhead?.name,
        generatedBy: input.generatedBy,
      ),
      pw.Text(
        'This is an official acknowledgement of maintenance / charge payment received by the society.',
        style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF374151)),
      ),
      pw.SizedBox(height: 10),
      reportField('Receipt No.', input.receiptNumber),
      reportField('Flat', input.flatNumber),
      reportField('Member', _or(input.residentName)),
      reportField('Charge', (input.chargeTitle ?? '').trim().isEmpty ? 'Maintenance' : input.chargeTitle!.trim()),
      reportField('Amount', receiptMoney(input.amount)),
      reportField('Method', input.paymentMethod.trim().isEmpty ? '—' : input.paymentMethod.toUpperCase()),
      reportField('Paid on', (input.paymentDate ?? '').isEmpty ? '—' : Fmt.date(input.paymentDate)),
      reportField('Due date', (input.dueDate ?? '').isEmpty ? '—' : Fmt.date(input.dueDate)),
      reportField('Txn / UTR', _or(input.transactionId)),
      reportField('Verified by', _or(input.verifiedBy)),
      reportField('Verified at', (input.verifiedAt ?? '').isEmpty ? '—' : Fmt.dateTimeFull(input.verifiedAt)),
      if ((input.notes ?? '').trim().isNotEmpty) reportField('Notes', input.notes!.trim()),
      signatureSection(),
    ],
  );
  return GeneratedPdf(bytes: bytes, filename: maintenanceReceiptFileName(input.receiptNumber), warning: ctx.warning);
}
