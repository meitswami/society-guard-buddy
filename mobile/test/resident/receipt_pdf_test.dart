import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/resident/data/letterhead_pdf.dart';
import 'package:kutumbika_mobile/features/resident/data/maintenance_receipt_pdf.dart';
import 'package:kutumbika_mobile/features/resident/data/payment_statement_pdf.dart';
import 'package:kutumbika_mobile/features/resident/data/resident_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const payment = MaintenancePaymentRow(
    id: 'p1',
    chargeId: 'c1',
    amount: 2500,
    paymentMethod: 'upi',
    paymentStatus: 'verified',
    dueDate: '2026-10-10',
    flatNumber: '',
    createdAt: '2026-10-10T08:00:00Z',
    receiptNumber: 'MR-000187',
    paymentDate: '2026-10-10T06:30:00Z',
    transactionId: 'UTR123',
    verifiedBy: 'Treasurer',
    verifiedAt: '2026-10-11T10:00:00Z',
  );

  test('maintenance receipt PDF (plain + auto letterhead)', () async {
    final input = MaintenanceReceiptInput.fromPayment(
      payment,
      societyId: 's1',
      fallbackFlat: 'A-101',
      fallbackName: 'Asha',
      chargeTitle: 'October Monthly Maintenance',
      generatedBy: 'Asha',
    );
    expect(input.flatNumber, 'A-101');
    expect(input.residentName, 'Asha');
    final plain = await buildMaintenanceReceiptPdf(input, context: LetterheadContext.plain);
    expect(plain.filename, 'maintenance-receipt-MR-000187.pdf');
    expect(String.fromCharCodes(plain.bytes.sublist(0, 5)), '%PDF-');

    const auto = LetterheadContext(
      letterhead: SocietyLetterhead(name: 'Green Park CHS', address: 'Plot 4', city: 'Pune', contactPhone: '020-1234'),
      mode: ReportPdfMode.letterhead,
    );
    final branded = await buildMaintenanceReceiptPdf(input, context: auto);
    expect(branded.bytes.length, greaterThan(1000));
    expect(auto.letterhead!.addressLine, 'Plot 4 · Pune');
  });

  test('payment statement PDF', () async {
    final pdf = await buildPaymentStatementPdf(
      societyId: 's1',
      flatNumber: 'A-101',
      residentName: 'Asha',
      periodLabel: 'All payments',
      payments: const [payment],
      chargeTitles: const {'c1': 'October Monthly Maintenance'},
      context: LetterheadContext.plain,
    );
    expect(pdf.filename, startsWith('maintenance-payment-statement-flat-a-101-'));
    expect(String.fromCharCodes(pdf.bytes.sublist(0, 5)), '%PDF-');
  });
}
