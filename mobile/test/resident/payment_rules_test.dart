import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/resident/data/payment_rules.dart';
import 'package:kutumbika_mobile/features/resident/data/resident_models.dart';

MaintenanceChargeRow charge(String id, String title, {double amount = 2500, String frequency = 'monthly', int dueDay = 10, bool active = true}) =>
    MaintenanceChargeRow(id: id, title: title, amount: amount, frequency: frequency, dueDay: dueDay, isActive: active);

MaintenancePaymentRow payment(String id, String chargeId, String status, String dueDate, {double amount = 2500}) => MaintenancePaymentRow(
      id: id,
      chargeId: chargeId,
      amount: amount,
      paymentMethod: 'upi',
      paymentStatus: status,
      dueDate: dueDate,
      flatNumber: '604',
      createdAt: '${dueDate}T10:00:00Z',
    );

void main() {
  // src/lib/maintenanceReceiptNumber.test.ts
  group('maintenance receipt serial format', () {
    test('pads sequential numbers to 6 digits', () {
      expect(formatMaintenanceReceiptNumber(1), 'MR-000001');
      expect(formatMaintenanceReceiptNumber(186), 'MR-000186');
      expect(formatMaintenanceReceiptNumber(187), 'MR-000187');
    });

    test('receipt pdf file name and money (web maintenanceReceiptPdf.ts)', () {
      expect(maintenanceReceiptFileName('MR-000187'), 'maintenance-receipt-MR-000187.pdf');
      expect(maintenanceReceiptFileName('MR/2026 #7'), 'maintenance-receipt-MR_2026_7.pdf');
      expect(receiptMoney(2500), '₹2,500');
      expect(receiptMoney(1234567.891), '₹12,34,567.89');
      expect(receiptMoney(2500.5), '₹2,500.5');
      expect(receiptMoney(null), '₹0');
    });
  });

  group('societyBankAccount.ts', () {
    const account = SocietyBankAccountRow(
      id: 'a',
      societyId: 's',
      bankName: 'HDFC Bank',
      accountHolderName: 'Green Park CHS',
      accountNumber: '50100012345678',
      ifsc: 'HDFC0001234',
      branchName: 'Andheri',
      upiVpa: 'greenpark@hdfcbank',
    );

    test('buildUpiPayUrl matches URLSearchParams encoding', () {
      expect(
        buildUpiPayUrl(upiVpa: ' greenpark@hdfcbank ', payeeName: 'Green Park CHS', amount: 2500, note: 'Maintenance for Flat 604'),
        'upi://pay?pa=greenpark%40hdfcbank&pn=Green+Park+CHS&cu=INR&am=2500&tn=Maintenance+for+Flat+604',
      );
      expect(buildUpiPayUrl(upiVpa: 'x@y', payeeName: '  ', amount: 0), 'upi://pay?pa=x%40y&pn=Society&cu=INR');
      expect(buildUpiPayUrl(upiVpa: 'x@y', payeeName: 'P', amount: 99.5), 'upi://pay?pa=x%40y&pn=P&cu=INR&am=99.5');
      expect(formUrlEncode('a*b-c._d~e'), 'a*b-c._d%7Ee');
    });

    test('copyable details and masking', () {
      expect(
        copyableBankDetails(account),
        'Account name: Green Park CHS\nBank: HDFC Bank\nAccount number: 50100012345678\nIFSC: HDFC0001234\nBranch: Andheri\nUPI: greenpark@hdfcbank',
      );
      expect(maskAccountNumber('5010 0012 3456 78'), '••••••••••5678');
      expect(maskAccountNumber('1234'), '1234');
      expect(maintenanceUpiNote('604'), 'Maintenance for Flat 604');
    });
  });

  group('payment form (ResidentDashboard)', () {
    test('prefers this month\'s monthly maintenance charge', () {
      final charges = [
        charge('lift', 'Lift repair', frequency: 'one-time'),
        charge('sep', 'September Monthly Maintenance'),
        charge('oct', 'October Monthly Maintenance'),
      ];
      expect(pickPreferredCharge(charges, DateTime(2026, 10, 12))!.id, 'oct');
      expect(pickPreferredCharge(charges, DateTime(2026, 11, 2))!.id, 'sep');
      expect(pickPreferredCharge([charge('x', 'Water', frequency: 'yearly')], DateTime(2026, 1, 1))!.id, 'x');
      expect(pickPreferredCharge(const [], DateTime(2026)), isNull);
    });

    test('due date clamps the charge due day to 1…28', () {
      expect(dueDateForDay(10, DateTime(2026, 10, 12)), '2026-10-10');
      expect(dueDateForDay(31, DateTime(2026, 2, 3)), '2026-02-28');
      expect(dueDateForDay(0, DateTime(2026, 2, 3)), '2026-02-01');
    });

    test('validation', () {
      expect(validateResidentPayment(chargeId: '', amountText: '10', paidOn: 'a', dueDate: 'b'), ResidentPaymentError.chargeRequired);
      expect(validateResidentPayment(chargeId: 'c', amountText: '', paidOn: 'a', dueDate: 'b'), ResidentPaymentError.amountInvalid);
      expect(validateResidentPayment(chargeId: 'c', amountText: '-5', paidOn: 'a', dueDate: 'b'), ResidentPaymentError.amountInvalid);
      expect(validateResidentPayment(chargeId: 'c', amountText: 'abc', paidOn: 'a', dueDate: 'b'), ResidentPaymentError.amountInvalid);
      expect(validateResidentPayment(chargeId: 'c', amountText: '10', paidOn: '', dueDate: 'b'), ResidentPaymentError.datesRequired);
      expect(
        validateResidentPayment(chargeId: 'c', amountText: '10', paidOn: 'a', dueDate: 'b', fileBytes: 9 * 1024 * 1024),
        ResidentPaymentError.fileTooLarge,
      );
      expect(validateResidentPayment(chargeId: 'c', amountText: ' 2500 ', paidOn: 'a', dueDate: 'b', fileBytes: 1000), isNull);
    });

    test('paid date is stored as local noon in UTC ISO', () {
      final iso = paidAtIso('2026-10-12');
      expect(iso.endsWith('Z'), isTrue);
      expect(DateTime.parse(iso).toLocal(), DateTime(2026, 10, 12, 12));
    });

    test('JS number formatting for the UPI amount', () {
      expect(jsNumberString(2500.0), '2500');
      expect(jsNumberString(2500), '2500');
      expect(jsNumberString(12.25), '12.25');
    });
  });

  group('dues for the current period', () {
    final now = DateTime(2026, 10, 12);
    final charges = [
      charge('m', 'October Monthly Maintenance'),
      charge('q', 'Sinking fund', frequency: 'quarterly', amount: 1500),
      charge('y', 'Annual insurance', frequency: 'yearly', amount: 1200),
      charge('o', 'Lift upgrade', frequency: 'one-time', amount: 5000),
      charge('off', 'Old head', active: false),
    ];

    test('period keys', () {
      expect(chargePeriodKey('monthly', now), '2026-10');
      expect(chargePeriodKey('quarterly', now), '2026-Q4');
      expect(chargePeriodKey('yearly', DateTime(2027, 2, 1)), 'FY2026');
      expect(chargePeriodKey('yearly', DateTime(2026, 4, 1)), 'FY2026');
      expect(chargePeriodKey('one-time', now), 'once');
      expect(chargePeriodLabel('yearly', now), 'FY 2026-27');
      expect(chargePeriodLabel('quarterly', now), 'Q4 2026');
      expect(chargePeriodLabel('monthly', now), '10/2026');
    });

    test('status per charge from the flat payments', () {
      final payments = [
        payment('p1', 'm', 'rejected', '2026-10-10'),
        payment('p2', 'm', 'pending', '2026-10-10'),
        payment('p3', 'q', 'verified', '2026-07-05'),
        payment('p4', 'y', 'verified', '2026-05-01'),
        payment('p5', 'o', 'rejected', '2025-01-01'),
      ];
      final dues = computeChargeDues(charges, payments, now);
      expect(dues.map((d) => d.charge.id), ['m', 'q', 'y', 'o']);
      expect(dues[0].state, DueState.pending);
      expect(dues[0].payment!.id, 'p2');
      expect(dues[1].state, DueState.due, reason: 'paid in Q3, due again in Q4');
      expect(dues[2].state, DueState.paid);
      expect(dues[3].state, DueState.rejected);
      expect(dues[0].dueDate, '2026-10-10');
      expect(totalOutstanding(dues), 1500 + 5000);
    });
  });

  // src/lib/statementAmountTotals.test.ts
  group('statementAmountTotals', () {
    test('sums row amounts', () {
      expect(sumAmountRows(const [AmountRow(amount: 100), AmountRow(amount: -30), AmountRow()]), 70);
    });

    test('groups by month from dateIso', () {
      final rows = const [
        AmountRow(amount: 500, dateIso: '2026-04-05'),
        AmountRow(amount: 200, dateIso: '2026-04-20'),
        AmountRow(amount: 100, dateIso: '2026-05-01'),
      ];
      expect(monthlyAmountTotals(rows), const [
        MonthlyAmountTotal(monthKey: '2026-04', label: '04/2026', total: 700, count: 2),
        MonthlyAmountTotal(monthKey: '2026-05', label: '05/2026', total: 100, count: 1),
      ]);
    });

    test('parses display dates when dateIso is missing', () {
      expect(monthlyAmountTotals(const [AmountRow(amount: 50, date: '15/03/2026')]), const [
        MonthlyAmountTotal(monthKey: '2026-03', label: '03/2026', total: 50, count: 1),
      ]);
    });

    test('report detail file name + statement periods', () {
      expect(reportDetailPdfFilename('Maintenance payment statement — Flat 604', DateTime.utc(2026, 10, 12, 8)),
          'maintenance-payment-statement-flat-604-2026-10-12.pdf');
      expect(reportDetailPdfFilename('***', DateTime.utc(2026, 1, 2)), 'report-detail-2026-01-02.pdf');
      final now = DateTime(2026, 2, 15);
      expect(statementRange(StatementPeriod.all, now), isNull);
      expect(statementRange(StatementPeriod.thisMonth, now), (from: '2026-02-01', to: '2026-02-28'));
      expect(statementRange(StatementPeriod.last3Months, now), (from: '2025-12-01', to: '2026-02-28'));
      expect(statementRange(StatementPeriod.thisFinancialYear, now), (from: '2025-04-01', to: '2026-03-31'));
      expect(statementRange(StatementPeriod.lastFinancialYear, now), (from: '2024-04-01', to: '2025-03-31'));
      final inRange = paymentsInRange(
        [payment('a', 'm', 'verified', '2026-02-10'), payment('b', 'm', 'verified', '2026-03-01')],
        statementRange(StatementPeriod.thisMonth, now),
      );
      expect(inRange.map((p) => p.id), ['a']);
    });
  });
}
