// Formatting, channels, expense heads, operating fund and head-fund matching.
import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/cash_bank_channel.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_dates.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_expense_head.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_format.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/finance_models.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/flat_sort.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/head_fund_match.dart';
import 'package:kutumbika_mobile/features/admin/finance/logic/operating_reserve_fund.dart';

void main() {
  group('format', () {
    test('Indian grouping like toLocaleString(en-IN)', () {
      expect(localeNumber(123456), '1,23,456');
      expect(localeNumber(1234.5), '1,234.5');
      expect(localeNumber(1000 / 3), '333.333');
      expect(inrLocale(-500), '₹-500');
      expect(moneyInr(1234.567), '₹1,234.57');
      expect(inrSigned(-1200), '−₹1,200');
      expect(inrRaw(2500), '₹2500');
      expect(numToInput(2500.0), '2500');
      expect(numToInput(12.5), '12.5');
    });

    test('natural flat sort', () {
      final flats = ['605', '101', '11', '2', 'A-10', 'A-9', 'B-1'];
      flats.sort(compareFlatNumbers);
      expect(flats, ['2', '11', '101', '605', 'A-9', 'A-10', 'B-1']);
      expect(compareFlatNumbers('a-1', 'A-1') < 0, isTrue);
    });
  });

  group('dates', () {
    test('billing month and entry month checks', () {
      expect(billingMonthFromDate('2026-02-30', DateTime(2026, 5, 1)), '2026-05');
      expect(isBillingDateInEntryMonth('2026-06-30', '2026-06'), isTrue);
      expect(isBillingDateInEntryMonth('2026-07-01', '2026-06'), isFalse);
      expect(addDaysYmd('2026-02-28', 1), '2026-03-01');
      expect(addDaysYmd('2026-03-01', -1), '2026-02-28');
      expect(isoDateToDisplay('2026-03-09'), '09/03/2026');
      expect(parseDisplayDateToIso('9/3/2026'), '2026-03-09');
      expect(parseDisplayDateToIso('31/02/2026'), isNull);
      expect(dateInInclusiveRange('2026-03-31', '2026-03-01', '2026-03-31'), isTrue);
      expect(isDateBefore('2026-03-01', '2026-03-01'), isFalse);
    });
  });

  group('channels', () {
    test('normalizePaymentChannel', () {
      expect(normalizePaymentChannel(null), PaymentChannel.cash);
      expect(normalizePaymentChannel('Cash'), PaymentChannel.cash);
      expect(normalizePaymentChannel('upi'), PaymentChannel.bank);
      expect(normalizePaymentChannel('bank_transfer'), PaymentChannel.bank);
      // Web strips spaces only, so "Bank Transfer" is not a bank key.
      expect(normalizePaymentChannel('Bank Transfer'), PaymentChannel.other);
      expect(normalizePaymentChannel('cheque'), PaymentChannel.bank);
      expect(normalizePaymentChannel(''), PaymentChannel.other);
      expect(normalizePaymentChannel('barter'), PaymentChannel.other);
      expect(formatChannelParts(ChannelTotals(cash: 1000, bank: 250000)), 'Cash ₹1,000 · Bank ₹2,50,000');
      expect(formatChannelParts(ChannelTotals()), '₹0');
    });
  });

  group('expense heads', () {
    test('infers major heads from names', () {
      expect(inferMajorHeadFromGroupName('Security guard salary'), 'SALARY & WAGES');
      expect(inferMajorHeadFromGroupName('Electricity bill'), 'OPERATION & MAINTENANCE');
      expect(inferMajorHeadFromGroupName('Corpus legal fund'), 'CORPUS FUND (LEGAL)');
      expect(inferMajorHeadFromGroupName('Water Softener Installation'), 'FIXED ASSETS');
      expect(inferMajorHeadFromGroupName('FD renewal'), 'FIXED DEPOSIT');
      expect(inferMajorHeadFromGroupName(''), 'MISCELLANEOUS');
      expect(resolveGroupMajorHead('Lift AMC', 'BANK'), 'BANK');
      expect(resolveGroupMajorHead('Lift AMC', 'not a head'), 'OPERATION & MAINTENANCE');
    });

    test('ledger titles to heads', () {
      expect(financeExpenseHeadFromLedgerTitle('[Events & Functions] Tent hire'), 'Tent hire');
      expect(financeExpenseHeadFromLedgerTitle('[Repairs] Pump'), 'Repairs');
      expect(financeExpenseHeadFromLedgerTitle(''), 'Society expense');
      expect(financeExpenseHeadFromLedgerEntry('[Catering] Lunch', 'food'), 'Event food — Catering');
      expect(financeExpenseHeadFromLedgerEntry('Event food — Holi', 'food'), 'Event food — Holi');
      expect(financeReceiptHeadFromLedgerEntry('corpus', null, null), 'SOCIETY CORPUS FUND');
      expect(financeReceiptHeadFromLedgerEntry('separate_entry', 'Electricity refund', null), 'OPERATION & MAINTENANCE');
      expect(isEventFoodLedgerEntry(null, 'Head contribution — Lift', const {}), isTrue);
      expect(isEventFoodLedgerEntry('e1', 'Anything', const {'e1': 'payment'}), isFalse);
    });

    test('groups bucketed by major head', () {
      final map = paymentGroupsByMajorHead(const [
        PaymentExpenseGroup(id: '1', name: 'Lift AMC'),
        PaymentExpenseGroup(id: '2', name: 'Electricity'),
        PaymentExpenseGroup(id: '3', name: 'Guard', majorHead: 'SALARY & WAGES'),
      ]);
      expect(map['OPERATION & MAINTENANCE']!.map((g) => g.name).toList(), ['Electricity', 'Lift AMC']);
      expect(map['SALARY & WAGES']!.single.id, '3');
    });
  });

  group('operating reserve fund', () {
    test('monthly inflow uses the month in the charge title (web table kept)', () {
      const charges = [
        FinanceCharge(id: 'apr', title: 'April 2026 Monthly Maintenance', frequency: 'monthly'),
        FinanceCharge(id: 'head', title: 'Lift fund', frequency: 'monthly', expenseGroupId: 'g1'),
      ];
      const payments = [
        FinancePayment(chargeId: 'apr', paymentStatus: 'verified', amount: 2500, dueDate: '2026-05-02'),
        FinancePayment(chargeId: 'head', paymentStatus: 'verified', amount: 999, dueDate: '2026-04-02'),
        FinancePayment(chargeId: 'apr', paymentStatus: 'pending', amount: 2500, dueDate: '2026-04-02'),
      ];
      final titles = {for (final c in charges) c.id: c.title};
      expect(monthlyOperatingInflow('2026-04', payments, charges, titles), 2500);
      expect(extractMonthFromChargeTitle('Maintenance 2026-09'), '2026-09');
      expect(extractMonthFromChargeTitle('Water bill'), isNull);
    });

    test('reserve balance and transfers', () {
      const ledger = [
        FinanceLedgerRow(id: 'c1', destination: 'corpus', totalAmount: 10000),
        FinanceLedgerRow(id: 'c2', destination: 'corpus', totalAmount: 500, title: 'Reserve fund — transfer'),
      ];
      const transfers = [
        ReserveTransfer(id: 't1', entryMonth: '2026-04', amount: 2000, direction: kOperatingToReserve),
        ReserveTransfer(id: 't2', entryMonth: '2026-05', amount: 700, direction: kReserveToOperating),
      ];
      expect(reserveFundBalance(ledger, transfers), 11300);
      expect(netTransferEffectForMonth(transfers, '2026-04'), -2000);
      expect(netTransferEffectForMonth(transfers, '2026-05'), 700);
    });
  });

  group('head fund matching', () {
    test('fuzzy head names', () {
      expect(headNamesMatch('Water Softner', 'water softener installation'), isTrue);
      expect(headNamesMatch('Lift AMC', 'Electricity'), isFalse);
      expect(expenseMatchesHead('Garden', title: 'Monthly garden upkeep'), isTrue);
      expect(isHeadContributionLedgerTitle('Head contribution — Lift'), isTrue);
    });
  });
}
