import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/events/data/events_models.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/cash_bank_channel.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/event_food_fund.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/reconciliation.dart';

/// `EventFoodReconciliation` totals / rows parity (expected values produced by the web code).
void main() {
  const events = [
    ReconEvent(id: 'e1', title: 'Holi', eventDate: '2026-03-14'),
    ReconEvent(id: 'e2', title: 'Diwali', eventDate: '2026-11-01'),
    ReconEvent(id: 'e3', title: 'Quiet', eventDate: '2026-05-01'),
    ReconEvent(id: 'e4', title: 'Adj only', eventDate: '2026-01-01'),
  ];
  const contributions = [
    EventContribution(id: 'c1', eventId: 'e1', amount: 500, paymentMethod: 'cash'),
    EventContribution(id: 'c2', eventId: 'e1', amount: 700, paymentMethod: 'upi'),
    EventContribution(id: 'c3', eventId: 'e2', amount: 300, paymentMethod: 'Bank Transfer'),
    EventContribution(id: 'c4', eventId: 'zz', amount: 50, paymentMethod: 'cash'),
  ];
  FoodExpenseRow food(String id, String? eventId, double amount, String method) => FoodExpenseRow(
        id: id,
        title: id,
        totalAmount: amount,
        expenseDate: '2026-01-01',
        paymentMethod: method,
        groupId: 'g',
        groupName: 'G',
        eventId: eventId,
      );
  final foodExpenses = [
    food('x1', 'e1', 1500, 'cash'),
    food('x2', null, 200, 'cheque'),
    food('x3', 'gone', 100, 'other'),
    food('x4', 'e2', 100, 'card'),
  ];
  const adjustments = [
    EventFoodAdjustment(id: 'a1', eventId: 'e1', adjustmentKind: 'shortfall_cover', amount: 100, sourceType: 'corpus'),
    EventFoodAdjustment(id: 'a2', eventId: 'e2', adjustmentKind: 'surplus_to_pool', amount: 50, sourceType: 'society_pool'),
    EventFoodAdjustment(id: 'a3', eventId: 'e4', adjustmentKind: 'shortfall_cover', amount: 10, sourceType: 'corpus'),
    EventFoodAdjustment(id: 'a4', adjustmentKind: 'shortfall_cover', amount: 20, sourceType: 'member_advance'),
  ];

  test('per-event rows', () {
    final rows = reconciliationRows(
      events: events,
      contributions: contributions,
      foodExpenses: foodExpenses,
      adjustments: adjustments,
    );
    expect(rows.map((r) => r.event.id).toList(), ['e2', 'e1', 'e4', kUnlinkedEventKey]);

    final e2 = rows[0];
    expect([e2.contribIn, e2.foodOut, e2.shortfallCovers, e2.surplusTransfers], [300, 100, 0, 50]);
    expect([e2.receiptChannels.cash, e2.receiptChannels.bank, e2.receiptChannels.other], [0, 0, 300]);
    expect([e2.paymentChannels.cash, e2.paymentChannels.bank, e2.paymentChannels.other], [0, 100, 0]);
    expect([e2.remainingShortfall, e2.remainingSurplus, e2.adjustedNet], [0, 150, 150]);

    final e1 = rows[1];
    expect([e1.contribIn, e1.foodOut, e1.rawNet], [1200, 1500, -300]);
    expect([e1.remainingShortfall, e1.remainingSurplus, e1.adjustedNet], [200, 0, -200]);
    expect(e1.eventAdjustments.map((a) => a.id).toList(), ['a1']);

    final e4 = rows[2];
    expect([e4.contribIn, e4.foodOut, e4.adjustedNet], [0, 0, 10]);

    final un = rows[3];
    expect(un.event.title, 'Food not linked to an event');
    expect(un.expenses.map((e) => e.id).toList(), ['x2', 'x3']);
    expect([un.paymentChannels.bank, un.paymentChannels.other], [200, 100]);
    expect([un.shortfallCovers, un.remainingShortfall, un.adjustedNet], [20, 280, -280]);
  });

  test('society-wide totals', () {
    final t = reconciliationTotals(contributions: contributions, foodExpenses: foodExpenses, adjustments: adjustments);
    expect([t.contribIn, t.foodOut, t.net], [1550, 1900, -350]);
    expect([t.balance.remainingShortfall, t.balance.remainingSurplus, t.balance.adjustedNet], [220, 0, -270]);
    expect([t.balance.shortfallCovers, t.balance.surplusTransfers], [130, 50]);
    expect(channelTotal(t.netChannels), -350);
  });

  test('eventFoodBalance', () {
    final b = eventFoodBalance(contribIn: 1000, foodOut: 400, shortfallCovers: 0, surplusTransfers: 250);
    expect([b.rawNet, b.remainingShortfall, b.remainingSurplus, b.adjustedNet], [600, 0, 350, 350]);
  });

  test('food receipt links: bill first, attachments deduplicated', () {
    const ex = FoodExpenseRow(
      id: 'x',
      title: 't',
      totalAmount: 1,
      expenseDate: '',
      paymentMethod: 'cash',
      groupId: 'g',
      groupName: 'G',
      billScreenshotUrl: 'https://h/a/1111-2222_bill.jpg',
      attachmentUrls: ['https://h/a/1111-2222_bill.jpg', 'https://h/a/abcd_menu%20card.pdf', ''],
    );
    final links = foodReceiptLinks(ex);
    expect(links.map((l) => l.label).toList(), ['Bill / receipt', 'menu card.pdf']);
    expect(links.first.isBill, isTrue);
  });

  group('cash / bank channel', () {
    test('normalizePaymentChannel', () {
      expect(normalizePaymentChannel(null), PaymentChannel.cash);
      expect(normalizePaymentChannel('Cash'), PaymentChannel.cash);
      expect(normalizePaymentChannel('upi'), PaymentChannel.bank);
      expect(normalizePaymentChannel('bank_transfer'), PaymentChannel.bank);
      expect(normalizePaymentChannel('Bank Transfer'), PaymentChannel.other);
      expect(normalizePaymentChannel('cheque'), PaymentChannel.bank);
      expect(normalizePaymentChannel('NEFT payment'), PaymentChannel.bank);
      expect(normalizePaymentChannel(''), PaymentChannel.other);
      expect(normalizePaymentChannel('other'), PaymentChannel.other);
    });

    test('sum / net / format', () {
      final r = sumByChannel<List<Object>>([
        [100, 'cash'],
        [50, 'upi'],
        [double.nan, 'cash'],
        [25, 'barter'],
      ], (e) => e[0] as num, (e) => e[1]);
      expect([r.cash, r.bank, r.other], [100, 50, 25]);
      final p = ChannelTotals(cash: 40, bank: 80);
      final n = netChannels(r, p);
      expect([n.cash, n.bank, n.other], [60, -30, 25]);
      expect(formatChannelParts(ChannelTotals(cash: 150000, other: 2.5)), 'Cash ₹1,50,000 · Other ₹2.5');
      expect(formatChannelParts(ChannelTotals()), '₹0');
      expect(channelDisplayLabel('neft'), 'Bank / UPI');
      expect(channelDisplayLabel('barter'), 'barter');
    });
  });
}
